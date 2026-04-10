#!/bin/bash
# =============================================================================
# stop_grafana.sh — Stop Grafana and CSV HTTP server
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Stopping Grafana..."
cd "$WORKSPACE_DIR/libs/grafana_monitoring" && sudo docker compose down 2>/dev/null || true

echo "Stopping CSV HTTP server..."
pkill -f csv_http_server.py 2>/dev/null || true

echo "Dashboard stopped."
