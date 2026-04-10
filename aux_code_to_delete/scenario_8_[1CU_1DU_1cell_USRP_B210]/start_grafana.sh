#!/bin/bash
# =============================================================================
# start_grafana.sh — Start Grafana dashboard to visualize KPM metrics
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MONITORING_DIR="$WORKSPACE_DIR/libs/grafana_monitoring"

echo "========================================="
echo "Starting Grafana Dashboard"
echo "========================================="

export XAPP_LOGS_DIR="$SCRIPT_DIR/logs"
python3 "$MONITORING_DIR/csv_http_server.py" &
HTTP_PID=$!
sleep 1

echo "Starting Grafana on port 3300..."
cd "$MONITORING_DIR"
sudo docker compose up -d
cd "$SCRIPT_DIR"
echo "Waiting 10s for Grafana to initialize..."
sleep 10

echo ""
echo "========================================="
echo "Grafana is ready at: http://localhost:3300"
echo "  Login: admin / admin"
echo "========================================="

echo "Press Ctrl+C to stop..."
wait $HTTP_PID
