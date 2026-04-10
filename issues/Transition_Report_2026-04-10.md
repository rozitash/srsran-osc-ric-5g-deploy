# Transition Report: srsRAN & OSC RIC Integration Status

## 1. Project Overview
This project aims to establish a stable E2 interface and KPM metric streaming between a **srsRAN gNB (25.10.0)** and the **OSC Near-RT RIC**.

## 2. Current Status (as of 2026-04-10)

### Infrastructure State
- **Docker Deployment**: Functional and highly organized.
- **srsRAN gNB**: Pinned to version 25.10.0 (commit `d2f4b70dde...`). It is stable and establishes SCTP connectivity with the RIC.
- **Open5GS Core**: Fully functional. Modified AMF security to allow `NIA0` integrity, resolving UE registration rejections.
- **UE Connection**: COTS UEs can successfully register and generate traffic (~15kbps).

### RIC Platform Migration (NIST Alignment)
A migration from the legacy "i-release" RIC to the **L/M-release** (consistent with NIST's `O-RAN-Testbed-Automation`) is currently in progress:
- **Successfully Pulled Images**:
  - `ric-plt-e2mgr:6.0.8`
  - `ric-plt-appmgr:0.5.10`
  - `ric-plt-dbaas:0.6.5`
- **Pending/Tag Issues**:
  - `ric-plt-submgr`: Tag `0.14.0` was not found in the nexus registry.
  - `ric-plt-e2`: Tag `9.0.1` was not found.
  - *Note*: These tags need to be adjusted in the `.env` file once the exact M-release registry tags are verified.

### xApp Logic
- Resolved a critical `NULL pointer access` in `xAppBase.py` (lib/xAppBase.py) related to RMR timeouts.
- Adjusted xApp health-check port to `8093` to prevent binding conflicts.
- Verified that the xApp correctly identifies the node ID (`0x19B0`).

---

## 3. Recommended Steps for Resumption

### Step A: Finalize RIC Image Tags
1. Find the correct Docker image tags for `submgr` and `e2term` corresponding to the **m-release** branch on `nexus3.o-ran-sc.org`.
2. Update the `SUBMGR_VER` and `E2TERM_VER` variables in the `.env` file.
3. Run `docker compose up -d` to pull and start the updated RIC stack.

### Step B: Configuration Alignment
1. Check if the newer `submgr` requires different field casing in `ric/configs/submgr.yaml` (e.g., `e2tSubReqTimeout_ms` vs `E2TSubReqTimeout_ms`).
2. Ensure `ric/configs/routes.rtg` remains consistent with the updated IPs.

### Step C: Verification
1. Verify E2 Setup by checking `srsran_gnb` logs for `E2 Setup Request Successful`.
2. Monitor `ric_submgr` logs to ensure the protocol "unpack" errors (msginfo mismatch) are resolved by the version upgrade.
3. Run the xApp and check for `RIC_INDICATION` messages in the console or logs.

---

## 4. Key Files
- **Configurations**: `gnb/gnb_b210_single_cell.yml`, `.env`
- **Logs**: `logs/gnb.log`, `logs/ric_submgr.log`
- **Automation References**: `O-RAN-Testbed-Automation/` (Freshly cloned NIST repo)
