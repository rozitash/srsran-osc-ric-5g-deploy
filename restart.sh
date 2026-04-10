#!/bin/bash
# =============================================================================
# restart.sh — Restart the full stack
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Restarting stack..."
docker compose down
docker compose up -d

echo ""
echo "Waiting 10s for services to settle..."
sleep 10

./check.sh
