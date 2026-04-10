#!/bin/bash
# =============================================================================
# stop.sh — Stop and remove all containers cleanly
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping all containers..."
docker compose down

echo ""
echo "All containers removed."
