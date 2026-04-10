#!/bin/bash
# =============================================================================
# start_network.sh — Start single-cell 5G network with USRP B210
#
# Starts: Open5GS (Docker), OSC Near-RT RIC, srsRAN gNB (1 cell via USRP B210).
#
# The USRP B210 connects via USB 3.0 and transmits real RF on 1 channel.
# The UE (COTS phone or srsUE with another USRP) connects over the air.
#
# Logs captured in $LOGS_DIR/:
#   gnb.log            — srsRAN gNB console output
#   core.log           — Open5GS 5GC Docker logs
#   ric_e2term.log     — E2 Termination Point logs
#   ric_e2mgr.log      — E2 Manager logs
#   ric_submgr.log     — Subscription Manager logs
#   network_info.log   — Summary of PLMN, IPs, IDs, and config
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOGS_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOGS_DIR"

# Source config (USRP parameters + RIC_CHOICE)
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

# Build device_args based on serial (if provided)
if [ -n "$USRP_SERIAL" ]; then
    export USRP_DEVICE_ARGS="type=b200,serial=$USRP_SERIAL"
else
    export USRP_DEVICE_ARGS="type=b200"
fi

# Verify installation
for dir in srsRAN_Project oran-sc-ric; do
    if [ ! -d "$WORKSPACE_DIR/libs/$dir" ]; then
        echo "ERROR: libs/$dir not found. Run ./install.sh first."
        exit 1
    fi
done

# Verify USRP B210 is connected via USB
echo "Checking for USRP B210 on USB..."
if command -v uhd_find_devices &> /dev/null; then
    UHD_RESULT=$(uhd_find_devices --args "type=b200" 2>&1 || true)
    if echo "$UHD_RESULT" | grep -qi "no uhd devices found\|no devices found"; then
        echo "WARNING: No USRP B210 found on USB."
        echo "         Ensure the B210 is connected to a USB 3.0 port."
        echo "         Continuing anyway..."
    else
        echo "  Found USRP B210."
    fi
else
    echo "  uhd_find_devices not found — skipping USB check."
fi

echo "================================================================="
echo "Starting Single-Cell Network (Scenario 8, USRP B210)"
echo "================================================================="
echo "  USRP:  B210 via USB 3.0 (serial=${USRP_SERIAL:-auto-detect})"
echo "  Gains: TX=$USRP_TX_GAIN, RX=$USRP_RX_GAIN"
echo ""

# ==========================================================================
# Helper: write the network_info.log with all key identifiers
# ==========================================================================
write_network_info() {
    local INFO_LOG="$LOGS_DIR/network_info.log"
    {
        echo "================================================================="
        echo "  NETWORK INFO — Scenario 8 (1 CU, 1 DU, 1 Cell, USRP B210)"
        echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "================================================================="
        echo ""

        echo "--- PLMN & Identity ---"
        echo "  PLMN:              99970 (MCC=999, MNC=70)"
        echo "  gNB ID:            411 (0x19B)"
        echo "  gNB ID bit length: 32"
        echo "  NR Cell ID:        0x19B0 (6576)"
        echo "  PCI:               1"
        echo "  TAC:               7"
        echo "  S-NSSAI:           SST=1"
        echo ""

        echo "--- RF Configuration ---"
        echo "  SDR:               USRP B210 (USB 3.0)"
        echo "  Serial:            ${USRP_SERIAL:-auto-detect}"
        echo "  Device args:       ${USRP_DEVICE_ARGS}"
        echo "  Band:              3 (FDD)"
        echo "  DL ARFCN:          368500"
        echo "  DL Frequency:      1842.5 MHz"
        echo "  UL Frequency:      1747.5 MHz"
        echo "  Bandwidth:         10 MHz"
        echo "  SCS:               15 kHz"
        echo "  Sample rate:       23.04 MSPS"
        echo "  TX Gain:           ${USRP_TX_GAIN} dB"
        echo "  RX Gain:           ${USRP_RX_GAIN} dB"
        echo ""

        echo "--- Network Addresses ---"
        echo "  AMF (Open5GS):     10.53.1.2:38412  (Docker container)"
        echo "  gNB N2 bind:       10.53.1.1         (host Docker bridge)"
        echo "  gNB GTP-U bind:    10.53.1.1:2152"
        echo "  UPF GTP-U:         10.53.1.2:2152    (Docker container)"
        echo "  UE IP pool:        10.45.0.0/24"
        echo "  UE gateway:        10.45.0.1"
        echo ""

        echo "--- RIC (OSC Near-RT RIC) ---"
        echo "  E2 Termination:    127.0.0.1:36421 (SCTP)"
        echo "  E2 Manager:        10.0.2.11:3800  (REST API)"
        echo "  Subscription Mgr:  10.0.2.13"
        echo "  DBAAS (Redis):     10.0.2.12:6379"
        echo "  RIC network:       10.0.2.0/24"
        echo ""

        echo "--- E2 Agents ---"
        echo "  DU E2:             enabled (KPM)"
        echo "  E2SM-KPM:          enabled"
        echo "  E2SM-RC:           enabled"
        echo "  E2 addr:           127.0.0.1:36421"
        echo ""

        echo "--- Subscriber (Open5GS) ---"
        echo "  IMSI:              999700123456780"
        echo "  K:                 00112233445566778899aabbccddeeff"
        echo "  OPC:               63bfa50ee6523365ff14c1f45f88737d"
        echo "  APN:               srsapn"
        echo ""

        echo "--- Docker Containers ---"
        sudo docker ps --format "  {{.Names}}: {{.Status}} ({{.Image}})" 2>/dev/null || echo "  (unable to query Docker)"
        echo ""

        echo "--- RIC E2 Node Status ---"
        local E2_STATUS
        E2_STATUS=$(sudo docker exec ric_e2mgr curl -s http://localhost:3800/v1/nodeb/states 2>/dev/null || echo "[]")
        echo "  $E2_STATUS" | python3 -c "
import sys, json
try:
    nodes = json.load(sys.stdin)
    if not nodes:
        print('  No E2 nodes registered yet.')
    for n in nodes:
        print(f\"  {n.get('inventoryName','?')}: {n.get('connectionStatus','?')} (globalNbId: {n.get('globalNbId',{})})\")
except Exception as e:
    print(f'  Unable to query E2 manager: {e}')
" 2>/dev/null || echo "  Unable to parse E2 node status."
        echo ""
        echo "================================================================="
    } > "$INFO_LOG"
    echo "  Network info written to: $INFO_LOG"
}

# ==========================================================================
# Helper: start background Docker log tailers
# ==========================================================================
start_log_collectors() {
    echo "  Starting log collectors..."

    # Core network log (Open5GS)
    sudo docker logs -f open5gs_5gc > "$LOGS_DIR/core.log" 2>&1 &

    # RIC component logs
    sudo docker logs -f ric_e2term  > "$LOGS_DIR/ric_e2term.log" 2>&1 &
    sudo docker logs -f ric_e2mgr   > "$LOGS_DIR/ric_e2mgr.log" 2>&1 &
    sudo docker logs -f ric_submgr  > "$LOGS_DIR/ric_submgr.log" 2>&1 &
    sudo docker logs -f ric_dbaas   > "$LOGS_DIR/ric_dbaas.log" 2>&1 &
    sudo docker logs -f ric_appmgr  > "$LOGS_DIR/ric_appmgr.log" 2>&1 &

    echo "  Log collectors running (core.log, ric_e2term.log, ric_e2mgr.log, ric_submgr.log, ...)"
}

# --- 1. Open5GS Core ---
echo ">>> Step 1/3: Starting Open5GS Core (via Docker)..."
cd "$WORKSPACE_DIR/libs/srsRAN_Project/docker"
sudo docker compose up -d 5gc
cd "$SCRIPT_DIR"
sleep 5

# --- 2. OSC Near-RT RIC ---
echo ">>> Step 2/3: Starting OSC Near-RT RIC..."
cd "$WORKSPACE_DIR/libs/oran-sc-ric"
sudo docker compose up -d
cd "$SCRIPT_DIR"
echo "Waiting 30s for OSC RIC containers to initialize..."
sleep 30

# --- 3. gNB (1 cell via USRP B210) ---
echo ">>> Step 3/3: Starting gNB (1 cell via USRP B210)..."

# Substitute environment variables in the YAML template
GNB_CONFIG="$LOGS_DIR/gnb_usrp_resolved.yaml"
envsubst < "$SCRIPT_DIR/gnb_usrp.yaml" > "$GNB_CONFIG"

sudo bash -c "stdbuf -oL nohup $WORKSPACE_DIR/libs/srsRAN_Project/build/apps/gnb/gnb \
  -c $GNB_CONFIG \
  e2 --addr=127.0.0.1 --bind_addr=127.0.0.1 \
  > $LOGS_DIR/gnb.log 2>&1 &"
echo "Waiting 10s for gNB to initialize and connect to USRP..."
sleep 10

# --- 4. Collect logs and write network info ---
echo ">>> Collecting logs and network info..."
start_log_collectors
write_network_info

echo "================================================================="
echo "SINGLE-CELL NETWORK RUNNING (Scenario 8, USRP B210)"
echo "================================================================="
echo "  RIC:       OSC Near-RT RIC"
echo "  USRP:      B210 via USB 3.0"
echo "  Cell:      PCI 1 (0x19B0)"
echo "  E2 Agent:  DU (KPM metrics)"
echo "  Band:      3 (FDD 1800 MHz), 10 MHz BW"
echo ""
echo "  Logs:      $LOGS_DIR/"
echo "    gnb.log            — gNB console"
echo "    core.log           — Open5GS 5GC (AMF, SMF, UPF, ...)"
echo "    ric_e2term.log     — E2 Termination Point"
echo "    ric_e2mgr.log      — E2 Manager"
echo "    ric_submgr.log     — Subscription Manager"
echo "    network_info.log   — PLMN, IPs, IDs summary"
echo ""
echo "  UE: Connect a COTS UE (PLMN 99970, SIM with matching K/OPC)"
echo "      or srsUE with another USRP."
echo ""
echo "Next steps:"
echo "  ./start_traffic.sh           — Start traffic (after UE attaches)"
echo ""
echo "To stop: ./stop_network.sh"
echo "================================================================="
