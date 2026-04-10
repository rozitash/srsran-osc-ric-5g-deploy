#!/bin/bash
# =============================================================================
# check.sh — Verify that all services are running and RIC/gNB are connected
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Container Status ==="
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "=== RIC E2 Termination ==="
if docker logs ric_e2term 2>&1 | grep -q "SI95"; then
    echo "✅ E2 Termination is listening on port 36421."
else
    echo "❌ E2 Termination not initialized."
fi

echo ""
echo "=== gNB -> RIC Connection (REST API) ==="
E2_NODES=$(docker exec ric_e2mgr curl -s http://localhost:3800/v1/nodeb/states 2>/dev/null || echo "[]")

if echo "$E2_NODES" | grep -q "CONNECTED"; then
    echo "✅ RIC E2 Manager — connected nodes:"
    echo "$E2_NODES" | python3 -c "
import sys, json
try:
    nodes = json.load(sys.stdin)
    for n in nodes:
        print(f\"  - {n.get('inventoryName','?')}: {n.get('connectionStatus','?')}\")
except Exception:
    print('  Unable to parse node list.')
"
else
    echo "⏳ No CONNECTED nodes yet. (Response: $E2_NODES)"
fi

echo ""
echo "=== gNB E2 Agent ==="
if docker logs srsran_gnb 2>&1 | grep -q "E2AP: Connection to Near-RT-RIC"; then
    echo "✅ gNB E2 Agent connected to RIC."
    docker logs srsran_gnb | grep "E2AP" | tail -n 2
else
    echo "❌ gNB E2 Agent has not confirmed RIC connection."
fi
