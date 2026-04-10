# E2AP Protocol Incompatibility Report (Updated)

## Current Status
The deployment has been updated to align with the **O-RAN-Testbed-Automation** versions from NIST. This involves a transition from the legacy "i-release" RIC components to newer, more compatible versions that support modern srsRAN Project (25.10) E2AP structures.

---

## NIST Alignment & Upgrades
The following RIC components have been upgraded to stable L/M-release equivalents:
- **E2 Termination (E2Term)**: `9.0.1` (Supports modern E2AP unpacking)
- **Subscription Manager (SubMgr)**: `0.14.0`
- **E2 Manager (E2Mgr)**: `6.0.8`
- **App Manager (AppMgr)**: `0.5.10`
- **DBAAS**: `0.6.5`

These versions are specifically chosen to match the protocol profiles mentioned in the NIST automation scripts for the **OCUDU (srsRAN)** scenario.

---

## Stabilization Log
- **srsRAN gNB**: Pinned to commit `d2f4b70dda8e2c557d5b05a0ac5f92dbddda19bc` (from NIST L-release).
- **UE Connectivity**: Optimized Open5GS security settings verify NIA0 support.
- **xApp**: Fixed internal RMR pointer bugs and aligned health-check ports to 8093.

## Roadmap
1. [x] Upgrade RIC to L/M releases.
2. [ ] Verify E2 Setup completion without "unpack" errors.
3. [ ] Confirm KPM Indications (RICINDICATION) flow to Grafana.

## Current Configuration State
*   **gNB Node ID**: `0x19B0`
*   **srsRAN Release**: `25.10.0`
*   **RIC Release**: `L-release/M-release stable mix`
