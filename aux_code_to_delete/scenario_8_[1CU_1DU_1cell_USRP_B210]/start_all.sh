#!/bin/bash
# =============================================================================
# start_all.sh — Start everything for Scenario 8 (1 cell, USRP B210)
#
# Launches: network (1 cell via USRP B210) + xApp monitor + Grafana
# Traffic must be started manually after a UE attaches.
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SCRIPT_DIR/logs"

# Source config (USRP params + RIC_CHOICE)
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

cleanup() {
    echo ""
    echo "========================================"
    echo "Ctrl+C detected! Stopping all components..."
    echo "========================================"
    "$SCRIPT_DIR/stop_all.sh"
    exit 0
}
trap cleanup SIGINT SIGTERM

# 0. Clean up any previous deployment
echo ">>> Pre-cleanup: stopping any conflicting processes..."
"$SCRIPT_DIR/stop_all.sh" 2>/dev/null || true
sleep 2

# 1. Deploy the single-cell network (USRP B210)
echo ">>> Step 1/3: Deploying single-cell network (USRP B210)..."
"$SCRIPT_DIR/start_network.sh"
echo ""

# 2. Start xApp monitor in background
echo ">>> Step 2/3: Starting xApp monitor (background)..."
nohup "$SCRIPT_DIR/start_monitor_xapp.sh" > "$SCRIPT_DIR/logs/monitor_console.log" 2>&1 &
sleep 3
echo "  Monitor PID: $!"
echo ""

# 3. Start Grafana dashboard in background
echo ">>> Step 3/3: Starting Grafana dashboard (background)..."
nohup "$SCRIPT_DIR/start_grafana.sh" > "$SCRIPT_DIR/logs/dashboard_console.log" 2>&1 &
sleep 12
echo "  Dashboard PID: $!"
echo ""

echo "============================================================"
echo "ALL COMPONENTS RUNNING (Scenario 8 — 1 Cell, USRP B210)"
echo "============================================================"
echo "  Network:     Core + OSC RIC + gNB (1 cell, USRP B210)"
echo "  USRP:        B210 via USB 3.0"
echo "  Cell:        PCI 1 (0x19B0)"
echo "  Monitor:     xApp → logs/KPI_Metrics.csv"
echo "  Dashboard:   http://localhost:3300 (admin/admin)"
echo ""
echo "  UE:          Connect a COTS UE or srsUE with another USRP"
echo "  Traffic:     ./start_traffic.sh  (after UE attaches)"
echo ""
echo "  Logs: logs/"
echo "  Stop all: ./stop_all.sh"
echo "============================================================"
