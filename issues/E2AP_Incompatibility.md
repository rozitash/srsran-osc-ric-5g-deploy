# E2 Connectivity Issue: RIC xApp Subscription Failure (503 / Timeout)

## Summary
The current deployment of the OSC Near-RT RIC (i-release) and srsRAN gNB (24.04) is experiencing a protocol-level incompatibility during the E2 subscription handshake. While the individual components are healthy and properly networked, they cannot successfully exchange KPM measurement reports.

---

## Technical Findings

### 1. Root Cause: E2AP Unpacking Error
The RIC's Subscription Manager (`ric_submgr`) successfully receives the REST subscription request from the xApp but fails to process the E2AP response from the gNB.
*   **Error Message**: `err(unpack e2ap logbuffer() pduinfo(msginfo(3:2)) expinfo(msginfo(3:1)))`
*   **Interpretation**: The E2 Termination (`e2term`) receives a **Successful Outcome (3:2)** from the gNB but the parsing library in the i-release RIC expects a different binary format or E2AP version (likely v2.0 vs v3.0).

### 2. Stabilization Achieved
Before identifying the protocol mismatch, several infrastructure-level issues were resolved:
*   **gNB Stability**: Disabled `e2sm_rc_enabled` which was causing gNB crashes every 50 seconds.
*   **UE Connectivity**: Updated Open5GS AMF security settings to allow `NIA0` (null integrity), enabling the UE to register and generate live throughput data (~15kbps verified).
*   **RMR Loop Fix**: Resolved a `NULL pointer access` in the xApp's Python RMR library (`xAppBase.py`) which caused the monitoring script to exit prematurely.
*   **ID Alignment**: Synchronized `gnb_id` (0x19B0) and Node IDs in the RIC's DBAAS to ensure the xApp targets the correct DU agent.

### 3. Historical Data
Logs from the reference code (`aux_code_to_delete/scenario_8`) showed similar stability issues, including `PermissionError` and `Operation not permitted` during xApp execution, suggesting this environment/build combination has historical limitations regarding OSC RIC integration.

---

## Recommended Next Steps

### Option A: Upgrade the RIC Platform (Recommended)
Migrate the RIC components from the **i-release** to the **ORAN-SC K-Release** or later. The K-release has significantly better support for E2AP v2.03 and v3.0, which matches modern srsRAN releases.

### Option B: Downgrade srsRAN gNB
Build an older version of srsRAN gNB (specifically matching the commit used in previous working scenarios if available, e.g., `commit 4bf1543936` found in the auxiliary folder). This version likely uses an E2AP profile compatible with the older RIC binaries.

### Option C: Use FlexRIC
If the goal is specifically KPM monitoring and not the OSC RIC architecture itself, switching to **FlexRIC** (by OAI) is often more stable for srsRAN deployments as it has dedicated service model alignment scripts.

---

## Current Configuration State
*   **gNB Node ID**: `gnbd_999_070_000019b0_0` (DU)
*   **gNB Status**: UP and Stable
*   **UE Status**: Registered and generating data
*   **xApp Status**: RUNNING (Listening for indications)
