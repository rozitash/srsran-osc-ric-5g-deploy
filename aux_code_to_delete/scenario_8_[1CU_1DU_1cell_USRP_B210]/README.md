# Scenario 8 — Single-Cell USRP B210 (1 CU, 1 DU, 1 Cell)

Single-cell deployment using a **real USRP B210 SDR** connected via USB 3.0. One CU-CP + one DU with a single cell (PCI 1). The OSC Near-RT RIC provides E2SM-KPM monitoring. No handover — this is a baseline single-cell setup for real RF testing.

## Architecture

```
                 ┌──────────────────────────────┐
                 │       OSC Near-RT RIC         │
                 │     KPM Monitor xApp          │
                 └──────────┬────────────────────┘
                      E2 Ind│
              ┌─────────────▼────────────────────┐
              │      srsRAN gNB (USRP B210)       │
              │   DU E2 (KPM)     CU-CP            │
              │   Cell 1 (PCI 1)                   │
              └─────────────┬────────────────────┘
                            │ Real RF (Band 3)
                   ┌────────▼───────┐
                   │  COTS UE / srsUE │
                   └────────────────┘
```

## Configuration

| Parameter | Value |
|---|---|
| RIC | OSC Near-RT RIC |
| Cells | 1 (PCI 1) |
| gNBs | 1 (1 CU-CP + 1 DU) |
| RF | **USRP B210** (UHD driver, USB 3.0) |
| Band | 78 (TDD n78), 20 MHz BW |
| SCS | 30 kHz |
| Handover | N/A (single cell) |

### USRP Parameters (edit `config.sh`)

```bash
# Serial number (run 'uhd_find_devices' to discover; leave empty for auto-detect)
export USRP_SERIAL=""

# RF gains (B210 range: 0–89.8 dB)
export USRP_TX_GAIN=50
export USRP_RX_GAIN=60
```

## Quick Start

```bash
# Ensure B210 is connected to a USB 3.0 port
# Edit config.sh if needed (serial number, gains)
sudo ./start_all.sh

# Connect a COTS UE (PLMN 00101) or srsUE with another USRP

./start_traffic.sh              # After UE attaches
./start_traffic.sh --server-only  # For COTS UE (iperf3 server only)

sudo ./stop_all.sh
```

## Key Differences from Scenario 7 (2-Cell USRP N320)

| Aspect | Scenario 7 | Scenario 8 |
|---|---|---|
| SDR | USRP N320 (10GbE) | **USRP B210 (USB 3.0)** |
| Cells | 2 (PCI 1 + PCI 2) | **1 (PCI 1 only)** |
| Connection | Ethernet (IP address) | **USB 3.0 (serial number)** |
| Clock/Sync | Configurable (internal/external/gpsdo) | **Internal only** |
| CU-CP E2 | Enabled (RC handover) | Not needed |
| Handover | RIC-driven E2SM-RC | **N/A** |

## Key Files

| File | Description |
|---|---|
| `config.sh` | RIC choice + USRP B210 parameters (serial, gains) |
| `gnb_usrp.yaml` | gNB config (UHD driver, 1-cell, B210) |
| `start_all.sh` | Full deployment |
| `stop_all.sh` | Full teardown |
| `start_traffic.sh` | Traffic (supports `--server-only` for COTS UE) |

## Prerequisites

- USRP B210 connected to a **USB 3.0** port (USB 2.0 will not work reliably)
- UHD drivers installed (`uhd_find_devices` should find your B210)
- COTS UE with test SIM (PLMN 00101, matching K/OPC) or srsUE + another USRP
