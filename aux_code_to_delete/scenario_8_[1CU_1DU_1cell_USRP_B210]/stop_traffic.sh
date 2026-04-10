#!/bin/bash
# =============================================================================
# stop_traffic.sh — Stop the traffic pattern for Scenario 8
# =============================================================================

echo "Stopping traffic pattern and iperf3..."
sudo ip netns exec ue1 pkill -f iperf3 2>/dev/null || true
sudo docker exec open5gs_5gc pkill -f iperf3 2>/dev/null || true
sudo pkill -f "start_traffic" 2>/dev/null || true
echo "Traffic stopped."
