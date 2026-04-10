#!/usr/bin/env python3
"""
xapp_csv_writer.py

Runs the xApp as a subprocess, parses its stdout for KPM metric values,
and writes them to CSV continuously.

For FlexRIC: the C xApp's stdout is captured via a log file (the FlexRIC
library redirects stdout internally, so subprocess.PIPE doesn't work).
For OSC: the Python xApp's stdout is captured via subprocess.PIPE.
"""

import argparse
import subprocess
import csv
import os
import re
import sys
import signal
import time
import tempfile
from datetime import datetime, timedelta

# Paths - derive from script location (libs/grafana_monitoring/)
# Can be overridden via environment variables for per-scenario use.
WORKSPACE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGS_DIR = os.environ.get("XAPP_LOGS_DIR", os.path.join(WORKSPACE, "logs"))
os.makedirs(LOGS_DIR, exist_ok=True)

XAPP_BIN = os.path.join(WORKSPACE, "flexric/build/examples/xApp/c/monitor/xapp_oran_moni")
XAPP_CONF = os.environ.get("XAPP_CONF_FILE", os.path.join(WORKSPACE, "xapp_mon_e2sm_kpm.conf"))

HEADER = ["Timestamp", "DRB.UEThpDl_kbps", "DRB.UEThpUl_kbps", "Serving_Cell", "Cell1_Gain", "Cell2_Gain"]

BROKER_STATE_FILE = "/tmp/broker_cell"

def csv_file_for(gnb_id):
    """Return the CSV path (simplified to just KPI_Metrics.csv)."""
    return os.path.join(LOGS_DIR, "KPI_Metrics.csv")

# Regex to capture metric lines
RE_NAMED = re.compile(r"^(DRB\.\S+)\s*=\s*([\d.]+)")
RE_REAL = re.compile(r"meas record REAL_MEAS_VALUE value ([\d.]+)")
# Regex for OSC python xApp: "---Metric: DRB.UEThpDl, Value: [7]"
RE_OSC = re.compile(r"---Metric:\s+(DRB\.\S+),\s+Value:\s+\[([.\d]+)\]")
# Regex to match E2 node ID header: "KPM-v3 ind_msg ... from E2-node type 7 ID 411"
RE_E2NODE = re.compile(r"E2-node type \d+ ID (\d+)")
# Regex for OSC xApp: "RIC Indication Received from gnbd_001_001_0000019b_0"
RE_E2NODE_OSC = re.compile(r"RIC Indication Received from gnbd_\d+_\d+_([0-9a-fA-F]+)_")

running = True

def signal_handler(sig, frame):
    global running
    running = False
    print("\n[CSV Writer] Stopping...")

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


# Set of gNB IDs for which CSV files have been initialized
_initialized_gnbs = set()

def init_csv(gnb_id):
    """Initialize a per-gNB CSV file (creates header if not already done)."""
    if gnb_id in _initialized_gnbs:
        return
    path = csv_file_for(gnb_id)
    with open(path, "w", newline="") as f:
        csv.writer(f).writerow(HEADER)
    _initialized_gnbs.add(gnb_id)
    print(f"[CSV] Created {path}")


def parse_line(line):
    """Try to extract a numeric metric value from a line of xApp output.
    Returns (value, None) for metric values, or (None, gnb_id) for E2 node headers."""
    # Check for E2 node ID header (FlexRIC format)
    m = RE_E2NODE.search(line)
    if m:
        return None, int(m.group(1))
    # Check for E2 node ID header (OSC format)
    m = RE_E2NODE_OSC.search(line)
    if m:
        return None, int(m.group(1), 16)  # hex to decimal (e.g. 19b -> 411)
    m = RE_NAMED.match(line)
    if m:
        return float(m.group(2)), None
    m = RE_REAL.search(line)
    if m:
        return float(m.group(1)), None
    m = RE_OSC.search(line)
    if m:
        return float(m.group(2)), None
    return None, None


def get_broker_state():
    """Read the current serving cell and gains from the broker state file."""
    try:
        with open(BROKER_STATE_FILE, "r") as f:
            parts = f.read().strip().split()
            if len(parts) >= 3:
                return int(parts[0]), float(parts[1]), float(parts[2])
    except Exception:
        pass
    return 1, 1.0, 0.0  # Default: cell 1 serving


# Deduplication state for write_row — tracks last written (ts, gnb_id) pair
_last_written = {}  # gnb_id -> last_ts
_report_count = 0


def write_row(dl, ul, gnb_id=0):
    """Write a single (dl, ul) metric row to the per-gNB CSV file.
    Deduplicates by (second, gnb_id) to filter duplicate per-cell reports."""
    global _report_count
    ts_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    # Deduplicate: only write one row per (second, gnb_id)
    if _last_written.get(gnb_id) == ts_str:
        return
    _last_written[gnb_id] = ts_str
    # Ensure CSV file exists for this gNB
    init_csv(gnb_id)
    serving_cell, g1, g2 = get_broker_state()
    row = [ts_str, f"{dl:.1f}", f"{ul:.1f}", str(serving_cell), f"{g1:.2f}", f"{g2:.2f}"]
    with open(csv_file_for(gnb_id), "a", newline="") as f:
        csv.writer(f).writerow(row)
    _report_count += 1
    print(f"[{ts_str}] gNB={gnb_id} DL={dl:.1f} UL={ul:.1f} Cell={serving_cell} (#{_report_count})")
    sys.stdout.flush()


def run_xapp_flexric():
    """Run FlexRIC C xApp with output redirected to a log file, then tail it."""

    if not os.path.exists(XAPP_BIN):
        print(f"[ERROR] FlexRIC xApp binary not found: {XAPP_BIN}")
        sys.exit(1)

    def forward_signal(sig, frame):
        global running
        running = False
        try:
            subprocess.run(["pkill", "-f", XAPP_BIN], check=False)
            subprocess.run(["pkill", "-f", "script.*xapp_oran_moni"], check=False)
        except Exception:
            pass
            
    signal.signal(signal.SIGINT, forward_signal)
    signal.signal(signal.SIGTERM, forward_signal)

    xapp_log = os.path.join(LOGS_DIR, "xapp_raw.log")
    # Truncate/create the log file once at startup (handle root-owned leftovers)
    try:
        open(xapp_log, "w").close()
    except PermissionError:
        subprocess.run(["sudo", "rm", "-f", xapp_log], check=False)
        open(xapp_log, "w").close()
    
    last_pos = 0
    pending_dl = None
    current_gnb_id = 0  # Track which gNB's report we're processing
    
    while running:
        # Launch xApp with stdout/stderr redirected to the log file via shell
        # Using 'script -qfc' to force the C binary to think it's on a terminal
        shell_cmd = f'script -qfc "{XAPP_BIN} -c {XAPP_CONF}" /dev/null >> {xapp_log} 2>&1'
        print(f"[xApp] Starting (flexric): {shell_cmd}")
        sys.stdout.flush()

        proc = subprocess.Popen(
            shell_cmd,
            shell=True,
            cwd=WORKSPACE,
            stdin=subprocess.DEVNULL, # Fully detach stdin
            preexec_fn=os.setsid,  # New process group for clean kill
        )

        # Wait a moment for the xApp to start writing
        time.sleep(2)

        with open(xapp_log, "r") as f:
            f.seek(last_pos)
            
            while running and proc.poll() is None:
                where = f.tell()
                line = f.readline()
                if line:
                    line = line.strip()
                    # Strip ANSI escape codes and carriage returns from script output
                    line = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', line)
                    line = line.replace('\r', '').strip()

                    val, gnb_id = parse_line(line)
                    if gnb_id is not None:
                        current_gnb_id = gnb_id
                    elif val is not None:
                        if pending_dl is None:
                            pending_dl = val
                        else:
                            # Write immediately with actual wall-clock time
                            write_row(pending_dl, val, current_gnb_id)
                            pending_dl = None
                else:
                    # At EOF — seek back and wait for new data
                    f.seek(where)
                    time.sleep(0.1)
                    
            last_pos = f.tell()

        proc.wait()
        print(f"[xApp] Exited with code {proc.returncode}. Restarting in 5s...")
            
        if running:
            time.sleep(5)


def run_xapp_osc():
    """Run OSC Python xApp via docker compose exec, reading subprocess.PIPE."""
    import select

    # Run the xApp locally within the container
    cmd = ["python3", "-u", "/opt/xApps/kpm_mon_xapp.py", 
           "--metrics=DRB.UEThpDl,DRB.UEThpUl",
           "--kpm_report_style=1",
           "--e2_node_id=gnbd_999_070_000019b0_0",
           "--ran_func_id=1",
           "--http_server_port=8093"]
    cwd = "/opt/xApps"

    print(f"[xApp] Waiting 15s for RIC to settle...")
    time.sleep(15)

    print(f"[xApp] Starting (osc): {' '.join(cmd)}")
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            bufsize=0,
            cwd=cwd
        )
    except Exception as e:
        print(f"[ERROR] Failed to start xApp: {e}")
        sys.exit(1)

    def forward_signal(sig, frame):
        global running
        running = False
        proc.send_signal(sig)
    signal.signal(signal.SIGINT, forward_signal)
    signal.signal(signal.SIGTERM, forward_signal)

    line_buf = b""
    pending_dl = None
    current_gnb_id = 0

    while running and proc.poll() is None:
        ready, _, _ = select.select([proc.stdout], [], [], 2.0)
        if ready:
            chunk = os.read(proc.stdout.fileno(), 4096)
            if not chunk:
                break
            line_buf += chunk
            while b"\n" in line_buf:
                raw_line, line_buf = line_buf.split(b"\n", 1)
                line = raw_line.decode("utf-8", errors="replace").strip()
                print(f"[xApp-raw] {line}")
                val, gnb_id = parse_line(line)
                if gnb_id is not None:
                    current_gnb_id = gnb_id
                elif val is not None:
                    if pending_dl is None:
                        pending_dl = val
                    else:
                        write_row(pending_dl, val, current_gnb_id)
                        pending_dl = None

    proc.wait()
    print(f"[xApp] Exited with code {proc.returncode}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ric", choices=["flexric", "osc"], default="flexric")
    args = parser.parse_args()

    print("=" * 60)
    print(f"  O-RAN KPM Continuous Monitor ({args.ric}) → CSV for Grafana")
    print(f"  CSV: Per-gNB files in {LOGS_DIR}/")
    print("  Press Ctrl+C to stop")
    print("=" * 60)

    # Per-gNB CSV files are initialized lazily on first write

    if args.ric == "flexric":
        run_xapp_flexric()
    else:
        run_xapp_osc()

    print("[CSV Writer] Stopped.")


if __name__ == "__main__":
    main()
