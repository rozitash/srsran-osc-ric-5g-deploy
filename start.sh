#!/bin/bash
# =============================================================================
# start.sh — Start the full srsRAN + OSC RIC + Open5GS + Monitoring stack
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "================================================================="
echo " Starting Scenario 8: 1 CU, 1 DU, 1 Cell, USRP B210 + OSC RIC"
echo "================================================================="

# Verify USRP B210 is reachable
if command -v uhd_find_devices &>/dev/null; then
    echo "Checking for USRP B210..."
    UHD_RESULT=$(uhd_find_devices --args "type=b200" 2>&1 || true)
    if echo "$UHD_RESULT" | grep -qi "no uhd devices found\|no devices found"; then
        echo "WARNING: No USRP B210 detected on USB. Continuing anyway..."
    else
        echo "  ✅ USRP B210 found."
    fi
fi

echo ""
echo "Starting containers (detached)..."
# Pin project name so stop.sh / restart.sh always find the right containers
docker compose --project-name srsran-ric-deploy up -d

echo ""
echo "Waiting 10s for all services to settle..."
sleep 10

echo ""
./check.sh

echo ""
echo "================================================================="
echo " Stack is up. Useful commands:"
echo "   ./check.sh         — verify RIC/gNB connection status"
echo "   ./logs.sh          — tail key service logs"
echo "   ./stop.sh          — stop everything cleanly"
echo "   Grafana:           http://localhost:3300"
echo "================================================================="
