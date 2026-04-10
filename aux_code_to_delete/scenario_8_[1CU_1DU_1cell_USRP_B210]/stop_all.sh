#!/bin/bash
# =============================================================================
# stop_all.sh — Stop everything for Scenario 8 (1 cell, USRP B210)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================================"
echo "Stopping all components (Scenario 8, USRP B210)..."
echo "========================================================"

echo ">>> Stopping dashboard..."
"$SCRIPT_DIR/stop_grafana.sh"
echo ""

echo ">>> Stopping monitor..."
"$SCRIPT_DIR/stop_monitor_xapp.sh"
echo ""

echo ">>> Stopping traffic..."
"$SCRIPT_DIR/stop_traffic.sh"
echo ""

echo ">>> Stopping network..."
"$SCRIPT_DIR/stop_network.sh"

echo ""
echo "========================================================"
echo "All components stopped."
echo "========================================================"
