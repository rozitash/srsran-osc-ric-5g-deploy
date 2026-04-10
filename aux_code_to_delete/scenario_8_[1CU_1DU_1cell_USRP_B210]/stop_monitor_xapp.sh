#!/bin/bash
# =============================================================================
# stop_monitor_xapp.sh — Stop the KPM xApp CSV monitor
# =============================================================================

echo "Stopping xApp CSV monitor..."
pkill -f xapp_csv_writer.py 2>/dev/null || true
pkill -f xapp_oran_moni 2>/dev/null || true
echo "Monitor stopped."
