#!/bin/bash
# =============================================================================
# logs.sh — Tail live logs from gNB, E2 Manager, and E2 Termination
#
# Press Ctrl+C to stop.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Tailing gNB, E2 Manager, and E2 Term logs... (Ctrl+C to stop)"
docker compose --project-name srsran-ric-deploy logs -f gnb ric_e2mgr ric_e2term
