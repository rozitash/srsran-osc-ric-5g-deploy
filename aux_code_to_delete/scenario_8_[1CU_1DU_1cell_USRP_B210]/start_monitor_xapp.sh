#!/bin/bash
# =============================================================================
# start_monitor_xapp.sh — Run the KPM xApp and write metrics to CSV
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source config (forces RIC_CHOICE)
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

echo "=========================================="
echo "Starting KPM xApp → CSV Monitor ($RIC_CHOICE)"
echo "=========================================="

export XAPP_LOGS_DIR="$SCRIPT_DIR/logs"
export XAPP_CONF_FILE="$SCRIPT_DIR/xapp_mon_e2sm_kpm.conf"
export PYTHONUNBUFFERED=1

exec stdbuf -oL python3 -u "$WORKSPACE_DIR/libs/grafana_monitoring/xapp_csv_writer.py" --ric "$RIC_CHOICE"
