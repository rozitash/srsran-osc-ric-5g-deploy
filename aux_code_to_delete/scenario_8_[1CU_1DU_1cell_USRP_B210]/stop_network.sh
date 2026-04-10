#!/bin/bash
# =============================================================================
# stop_network.sh — Stop the single-cell 5G network (USRP B210)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "================================================================="
echo "Stopping Single-Cell Network (Scenario 8, USRP B210)"
echo "================================================================="

echo "Stopping traffic..."
"$SCRIPT_DIR/stop_traffic.sh" 2>/dev/null || true

echo "Stopping gNB..."
sudo pkill -9 -f "srsRAN_Project/build/apps/gnb/gnb" 2>/dev/null || true
sudo pkill -9 -f "gnb.*gnb_usrp" 2>/dev/null || true
sleep 2

echo "Stopping OSC NearRT-RIC Docker containers..."
cd "$WORKSPACE_DIR/libs/oran-sc-ric" 2>/dev/null && sudo docker compose down 2>/dev/null || true
cd "$SCRIPT_DIR"
# Explicitly remove RIC network to prevent 'Pool overlaps' error on next start
sudo docker network rm oran-sc-ric_ric_network docker_ric_network 2>/dev/null || true

echo "Stopping Open5GS Docker containers..."
cd "$WORKSPACE_DIR/libs/srsRAN_Project/docker" && sudo docker compose down 2>/dev/null || true
cd "$SCRIPT_DIR"
# Explicitly remove Open5GS RAN network to prevent stale pool on next start
sudo docker network rm docker_ran 2>/dev/null || true

echo "Stopping background log collectors..."
sudo pkill -f "docker logs -f open5gs_5gc" 2>/dev/null || true
sudo pkill -f "docker logs -f ric_" 2>/dev/null || true

echo "================================================================="
echo "Network stopped."
echo "================================================================="
