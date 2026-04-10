#!/bin/bash
# =============================================================================
# stop.sh — Stop and remove all containers cleanly
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping all containers..."
# Use --project-name to ensure we always stop containers from THIS compose file,
# regardless of which directory docker compose was originally invoked from.
docker compose --project-name srsran-ric-deploy down

echo ""
echo "All containers removed."
