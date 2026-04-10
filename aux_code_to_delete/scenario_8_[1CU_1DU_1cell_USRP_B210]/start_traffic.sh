#!/bin/bash
# =============================================================================
# start_traffic.sh — Start the traffic pattern for Scenario 8 (USRP B210)
#
# With real RF, the UE is a COTS phone or srsUE on another USRP.
# This script detects the UE's PDN IP and runs iperf3 from the 5GC container.
#
# For COTS UE: the iperf3 server runs in the Open5GS container and the
# phone runs an iperf3 client app. Use --server-only for this mode.
#
# For srsUE: traffic goes through the UE's tun device in a netns.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="${1:-server}"

echo "========================================="
echo "Traffic Generator (Scenario 8, USRP B210)"
echo "========================================="

# --- Clean up any existing iperf3 in the container, then start fresh ---
echo "Setting up iperf3 server in Open5GS container..."
sudo docker exec open5gs_5gc bash -c 'for pid in $(pgrep iperf3); do kill -9 $pid 2>/dev/null; done' 2>/dev/null
sleep 1
sudo docker exec open5gs_5gc bash -c "iperf3 -s -D 2>/dev/null" 2>/dev/null
sleep 2

if [ "$MODE" == "--server-only" ]; then
    echo ""
    echo "iperf3 server running in Open5GS container."
    echo "Connect your UE's iperf3 client to the gateway IP."
    echo ""
    echo "From the UE, run:"
    echo "  iperf3 -c <gateway_ip> -u -b 2M -t 60"
    echo ""
    echo "Press Ctrl+C to stop..."
    trap "echo 'Stopping...'; sudo docker exec open5gs_5gc pkill iperf3 2>/dev/null; exit 0" SIGINT SIGTERM
    while true; do sleep 10; done
    exit 0
fi

# --- Auto-detect UE: COTS UE (via ogstun in Open5GS) or srsUE (via netns) ---
# Try COTS UE first: find any allocated UE IP on the UPF ogstun interface
UE_IP=$(sudo docker exec open5gs_5gc bash -c \
    "ip -4 addr show ogstun 2>/dev/null | grep -oP 'inet \\K[\\d.]+' | grep -v '^10\.45\.0\.1$' | head -1" 2>/dev/null)
UE_MODE="cots"

# Fall back to srsUE netns
if [ -z "$UE_IP" ]; then
    UE_IP=$(sudo ip netns exec ue1 ip -4 addr show tun_srsue 2>/dev/null | grep -oP 'inet \K[\d.]+')
    UE_MODE="srsue"
fi

if [ -z "$UE_IP" ]; then
    echo ""
    echo "ERROR: No UE detected (neither COTS UE nor srsUE is attached)."
    echo "  → Make sure your UE/dongle has registered and got a PDU session."
    echo "  → To just start the iperf3 server and test manually:"
    echo "      $0 --server-only"
    exit 1
fi

GW_IP=$(sudo docker exec open5gs_5gc bash -c \
    "ip -4 addr show ogstun 2>/dev/null | grep -oP 'inet \\K[\\d.]+' | head -1" 2>/dev/null)
[ -z "$GW_IP" ] && GW_IP=$(echo "$UE_IP" | sed 's/\.[0-9]*$/.1/')
echo "Detected UE IP : $UE_IP  (mode: $UE_MODE)"
echo "Gateway (UPF)  : $GW_IP"

# --- Stepped traffic pattern (repeating) ---
STEP_DURATION=40
STEPS_KBPS=(1000 2000)

if [ "$UE_MODE" == "cots" ]; then
    echo "  Mode:    COTS UE (iperf3 server running in 5GC)"
    echo "  UE IP:   $UE_IP"
    echo "  GW/UPF:  $GW_IP"
    echo "  Pattern: 1→2 Mbps steps (${STEP_DURATION}s each)"
    echo "  → On your UE/dongle, run:"
    echo "      iperf3 -c $GW_IP -u -b 2M -t 60"
    echo "  Ctrl+C to stop server"
    echo "========================================="
    cleanup() {
        echo ""
        echo "Stopping traffic..."
        sudo docker exec open5gs_5gc pkill iperf3 2>/dev/null || true
        exit 0
    }
    trap cleanup SIGINT SIGTERM
    # Keep alive — UE drives the traffic from its side
    while true; do sleep 10; done
else
    echo "  Mode:    srsUE (netns ue1 → $GW_IP)"
    echo "  Pattern: 1→2 Mbps, ${STEP_DURATION}s each"
    echo "  Ctrl+C to stop"
    echo "========================================="
    cleanup() {
        echo ""
        echo "Stopping traffic..."
        sudo ip netns exec ue1 pkill -f iperf3 2>/dev/null || true
        exit 0
    }
    trap cleanup SIGINT SIGTERM

    IDX=0
    LAST_BW=""
    while true; do
        BW=${STEPS_KBPS[$IDX]}
        if [ "$BW" != "$LAST_BW" ]; then
            echo "[$(date +%H:%M:%S)] Bandwidth: ${BW} kbps for ${STEP_DURATION}s"
            LAST_BW="$BW"
        fi
        START_TIME=$(date +%s)
        sudo ip netns exec ue1 iperf3 -c "$GW_IP" -u -b "${BW}k" -t "$STEP_DURATION" -R > /dev/null 2>&1
        IPERF_EXIT=$?
        if [ "$IPERF_EXIT" -ne 0 ]; then
            echo "[$(date +%H:%M:%S)] WARNING: iperf3 exited with code $IPERF_EXIT"
        fi
        ELAPSED=$(( $(date +%s) - START_TIME ))
        if [ "$ELAPSED" -lt "$STEP_DURATION" ]; then
            sleep $(( STEP_DURATION - ELAPSED ))
        fi
        IDX=$(( (IDX + 1) % ${#STEPS_KBPS[@]} ))
    done
fi
