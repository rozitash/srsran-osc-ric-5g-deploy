#!/bin/bash
# =============================================================================
# build_gnb.sh — Build the srsRAN gNB Docker image from source
#
# The gNB image (srsran/gnb) is large and takes ~30 min to compile.
# This script clones only the necessary srsRAN source into srsran/src/
# and builds the Docker image.
#
# You only need to run this:
#   - On a fresh machine where the image hasn't been built
#   - When you want to rebuild after a code change
#
# On the current machine, the image is already built. Just run ./start.sh.
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SRSRAN_SRC="$SCRIPT_DIR/srsran/src"
SRSRAN_REPO="https://github.com/srsran/srsRAN_Project.git"
SRSRAN_COMMIT="1483bda3091420cf7270eacdf31de932865c6294"   # release_24_04 (tutorial-tested, E2AP v03.00)

echo "================================================================="
echo " Building srsRAN gNB Docker image"
echo "================================================================="

# Clone source if not already present
if [ ! -d "$SRSRAN_SRC/.git" ]; then
    echo "Cloning srsRAN_Project source..."
    git clone "$SRSRAN_REPO" "$SRSRAN_SRC"
    cd "$SRSRAN_SRC"
    git checkout "$SRSRAN_COMMIT"
    cd "$SCRIPT_DIR"
else
    echo "Source already cloned at $SRSRAN_SRC"
fi

echo ""
echo "Building Docker image (this takes ~20-30 minutes)..."
docker build \
    --build-arg OS_VERSION=24.04 \
    -t srsran/gnb \
    -f "$SRSRAN_SRC/docker/Dockerfile" \
    "$SRSRAN_SRC"

echo ""
echo "✅ srsran/gnb image built successfully."
echo "   You can now run: ./start.sh"
