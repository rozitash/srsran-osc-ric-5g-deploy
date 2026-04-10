# Scenario 8 — Clean Deployment
## 1 CU · 1 DU · 1 Cell · USRP B210 · OSC Near-RT RIC

Self-contained deployment of a single-cell 5G SA network with real RF via a
**USRP B210** and O-RAN E2 monitoring via the **OSC Near-RT RIC** (i-release).

Based on the official [srsRAN O-RAN SC RIC tutorial](https://docs.srsran.com/projects/project/en/latest/tutorials/source/near-rt-ric/source/index.html).
Everything needed to reproduce the full stack is inside this folder.

---

## Architecture

                    ┌──────────────────────────────┐
                    │       OSC Near-RT RIC         │
                    │  e2term · e2mgr · submgr      │
                    │  appmgr · dbaas · rtmgr_sim   │
                    │  xApp Monitor (kpimon)        │
                    └──────────┬───┬────────────────┘
                         E2AP  │   │ CSV Metrics
                    (SCTP)  ┌──┘   └──┐
               ┌────────────▼──┐     ┌▼─────────────┐
               │  srsRAN gNB   │     │ Grafana      │
               │ (USRP B210)   │     │ Performance  │
               └────────────┬──┘     └▲─────────────┘
                    N2/N3   │      Real RF (3489 MHz)
               ┌────────────▼┐       │
               │   Open5GS   │   ┌───▼────────────┐
               │   5G Core   │   │  COTS UE / srsUE │
               └─────────────┘   └────────────────┘

---

## Prerequisites

### Hardware
- **USRP B210** connected to a **USB 3.0** port (USB 2.0 will not work)
- UHD drivers installed on the host (`uhd_find_devices` must detect your B210)

### Software
- **Docker** ≥ 24 and **Docker Compose** plugin ≥ 2.20
- The **`srsran/gnb` Docker image** must already be built (see section below)
- Host kernel with SCTP support (`modprobe sctp` if needed)

### Verify your B210
```bash
uhd_find_devices --args "type=b200"
# Expected: shows your device with its serial number
```

### Check SCTP is available
```bash
modprobe sctp && echo "SCTP OK"
```

---

## Version Compatibility

> **Critical**: The srsRAN gNB E2AP version must match the RIC platform version.

| Component       | Version                | E2AP Spec               |
|-----------------|------------------------|-------------------------|
| srsRAN Project  | `release_24_04`        | O-RAN.WG3.E2AP-R003-**v03.00** |
| OSC Near-RT RIC | i-release              | E2AP v03.00 (encoding `3:1`) |
| E2 Termination  | `6.0.4`                |                         |
| E2 Manager      | `6.0.4`                |                         |
| Subscription Mgr| `0.10.1`               |                         |

> ⚠️ Using srsRAN `release_25_04` or later will encode E2AP as v03.01 (`3:2`),
> which causes the RIC Subscription Manager to fail decoding subscription
> responses, breaking the KPM metric pipeline.

---

## First-Time Setup (Fresh Machine)

The `srsran/gnb` Docker image is large (~5 GB) and takes 20–30 min to build.
**Skip this step if the image is already built on your machine.**

```bash
# From the repo root (srsran-osc-ric-5g-deploy/):
./build_gnb.sh
```

This script will:
1. Clone the srsRAN_Project source into `srsran/src/` (pinned to `release_24_04`)
2. Build the `srsran/gnb` Docker image using the source Dockerfile

> **To check if the image already exists:**
> ```bash
> docker image inspect srsran/gnb && echo "Image exists" || echo "Need to build"
> ```

---

## Configuration

### 1. USRP Serial and Gains (`.env`)

Open `.env` and update these values:

```bash
# Find your serial:
uhd_find_devices --args "type=b200"

# Then set it in .env:
USRP_SERIAL=34C78F0    # ← your serial here (leave empty for auto-detect)
USRP_TX_GAIN=70        # dB, range 0–89.8
USRP_RX_GAIN=70        # dB, range 0–76
```

### 2. gNB Radio Parameters (`gnb/gnb_b210_single_cell.yml`)

| Parameter             | Current Value        | Notes                           |
|-----------------------|----------------------|---------------------------------|
| `band`                | `78` (n78 TDD)       | Change if your UE needs a different band |
| `channel_bandwidth_MHz` | `10`               | 10 MHz for B210 stability       |
| `common_scs`          | `30` kHz             | Match band 78                   |
| `dl_arfcn`            | `632628`             | → 3489.42 MHz DL                |
| `plmn`                | `99970`              | MCC=999, MNC=70                 |
| `tac`                 | `7`                  |                                 |
| `pci`                 | `2`                  |                                 |
| `tx_gain` / `rx_gain` | `70` / `70`          | Also set in `.env`              |

### 3. Subscriber Database (`open5gs/subscriber_db.csv`)

Edit the CSV to add your test SIM credentials:

```csv
IMSI,subscriber_key,opc,amf,sqn,plmn
999700123456780,00112233445566778899aabbccddeeff,63bfa50ee6523365ff14c1f45f88737d,8000,000000000000,99970
```

One row per subscriber. The gNB PLMN (`99970`) must match.

---

## Running the Stack

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/rozitash/srsran-osc-ric-5g-deploy.git
cd srsran-osc-ric-5g-deploy

# 2. Edit .env — set your USRP serial and RF gains
nano .env

# 3. First time only: build the srsRAN gNB Docker image (~20-30 min)
#    Skip if 'srsran/gnb' image already exists on this machine:
#    docker image inspect srsran/gnb && echo "Already built"
./build_gnb.sh

# 4. Start the full stack
./start.sh

# 5. Verify the RIC is connected to the gNB
./check.sh

# 6. Watch live logs
./logs.sh

# 7. Stop everything
./stop.sh
```

**Expected output:**
```
✅ E2 Termination is listening on port 36421.
✅ RIC E2 Manager — connected nodes:
  - gnb_001_001_0000019b: CONNECTED
  - gnbd_999_070_0000019b_0: CONNECTED
✅ gNB E2 Agent connected to RIC.
```

### Verify Connection

```bash
./check.sh
```

Queries the RIC Manager REST API (`/v1/nodeb/states`) directly to confirm the
gNB CU-CP and DU are both marked as `CONNECTED`.

### Watch Live Logs

```bash
./logs.sh          # gNB + E2 Manager + E2 Term (Ctrl+C to stop)
```

To see all containers at once:
```bash
docker compose logs -f
```

To inspect a specific container:
```bash
docker logs ric_e2mgr   -f
docker logs srsran_gnb  -f
docker logs open5gs_5gc -f
```

### Stop

```bash
./stop.sh
```

### Restart (apply config changes)

```bash
./restart.sh
```

---

## Connecting a UE

### COTS Phone
1. Install a programmable SIM with the credentials from `subscriber_db.csv`
2. Set the APN to `srsapn`
3. The phone will scan for the network automatically (PLMN 99970)

### srsUE (software UE with a second USRP)
```bash
# On the same host, after the gNB is running:
sudo srsue /path/to/ue.conf
```

### Verify UE attachment in gNB console
```bash
docker logs srsran_gnb | grep -i "rrc\|attach\|pdu"
```

---

## Monitoring (Grafana)

Open your browser at: **http://localhost:3300**

Metrics flow: `srsRAN gNB → RIC E2 → Python xApp → CSV File → Grafana (Infinity)`

- **xApp Framework**: The `python_xapp_runner` container provides the O-RAN SC Python framework.
- **Metric Writer**: The `monitor_xapp` container runs a script that parses xApp output and writes it to `./logs/KPI_Metrics.csv`.
- **CSV Server**: The `csv_server` container serves the file over HTTP for Grafana.

---

## Troubleshooting

### gNB fails to start / USRP not found
```bash
uhd_find_devices         # check B210 is visible
lsusb                    # verify USB connection
dmesg | tail -20         # check for USB errors
```

### RIC E2 nodes not CONNECTED after start
```bash
./check.sh               # see current state
docker logs ric_e2term   # look for SCTP errors
docker logs srsran_gnb | grep E2   # check gNB side
# Then try a clean restart:
./restart.sh
```

### gNB "real-time failure" / underflow errors
Reduce bandwidth in `gnb/gnb_b210_single_cell.yml`:
```yaml
channel_bandwidth_MHz: 5    # try 5 MHz
srate: 7.68                  # match: 5 MHz → 7.68 MSPS
```

### ric_appmgr exits immediately
Usually means the bind-mounted config is a directory instead of a file.
Clean up and restart:
```bash
./stop.sh
sudo rm -rf /path/to/bad/mounts   # check `docker inspect ric_appmgr`
./start.sh
```

### Port 36421 already in use
Another process is using the SCTP port. Find and kill it:
```bash
sudo ss -lpn | grep 36421
sudo kill <PID>
```

---

## Services Reference

| Container            | Role                              | IP / Port              |
|----------------------|-----------------------------------|------------------------|
| `open5gs_5gc`        | 5G Core (AMF, SMF, UPF, NRF …)   | 10.53.1.2              |
| `srsran_gnb`         | gNB — USRP B210, 1 cell, E2      | host network           |
| `ric_dbaas`          | Redis SDL (RIC database)          | 10.0.2.12:6379         |
| `ric_rtmgr_sim`      | RMR Routing Manager Simulator     | 10.0.2.15:12020        |
| `ric_e2term`         | E2 Termination Point              | 10.0.2.10:**36421**/SCTP |
| `ric_submgr`         | E2 Subscription Manager           | 10.0.2.13:4560         |
| `ric_appmgr`         | xApp Manager                      | 10.0.2.14:8080         |
| `ric_e2mgr`          | E2 Manager (REST API)             | 10.0.2.11:**3800**/HTTP |
| `python_xapp_runner` | xApp runtime environment          | 10.0.2.20              |
| `monitor_xapp`       | Parsing xApp output to CSV       | 10.0.2.21              |
| `csv_server`         | HTTP server for Grafana CSV       | 172.25.1.7:**3030**    |
| `grafana`            | Dashboard UI (admin/admin)        | localhost:**3300**     |

---

## Log Files

Runtime logs are written automatically to `logs/`:

| File                | Container          | Contents                          |
|---------------------|--------------------|-----------------------------------|
| `gnb.log`           | `srsran_gnb`       | Full gNB console output           |
| `core.log`          | `open5gs_5gc`      | AMF, SMF, UPF, NRF logs           |
| `ric_e2term.log`    | `ric_e2term`       | E2 Setup, SCTP connections        |
| `ric_e2mgr.log`     | `ric_e2mgr`        | Node registration, keep-alives    |
| `ric_submgr.log`    | `ric_submgr`       | Subscription requests from xApps  |
| `ric_dbaas.log`     | `ric_dbaas`        | Redis activity                    |
| `ric_appmgr.log`    | `ric_appmgr`       | xApp lifecycle events             |

---

## Directory Structure

```
srsran-osc-ric-5g-deploy/
├── docker-compose.yml           ← Full stack definition
├── .env                         ← All configurable parameters ← EDIT THIS
├── start.sh                     ← Start everything
├── stop.sh                      ← Stop everything
├── restart.sh                   ← Restart (down + up + check)
├── check.sh                     ← Verify RIC/gNB connection
├── logs.sh                      ← Tail key service logs
├── build_gnb.sh                 ← Build srsran/gnb image (first time only)
├── srsran/
│   ├── docker/
│   │   └── Dockerfile           ← gNB image build recipe (latest)
│   └── src/                     ← Cloned by build_gnb.sh (release_24_04, not committed)
├── gnb/
│   └── gnb_b210_single_cell.yml ← gNB radio + E2 configuration
├── open5gs/
│   ├── Dockerfile
│   ├── open5gs-5gc.yml          ← Core network topology
│   ├── open5gs.env
│   ├── open5gs_entrypoint.sh
│   ├── add_users.py
│   ├── setup_tun.py
│   └── subscriber_db.csv        ← SIM credentials ← EDIT THIS
├── ric/
│   ├── configs/                 ← E2Term, E2Mgr, SubMgr, Routes
│   ├── xApps/                   ← Python xApps and CSV logic
│   │   ├── xapp_csv_writer.py   ← Python xApp stdout parser
│   │   ├── csv_http_server.py   ← Serves CSV on port 3030
│   │   └── python/              ← Source code for KPM xApp
│   └── images/
│       ├── rtmgr_sim/           ← Custom Routing Manager image
│       └── ric-plt-xapp-frame-py ← Python xApp Framework image
├── grafana/                     ← Dashboard provisioning (Infinity)
└── logs/                        ← Logs + KPI_Metrics.csv
```
