#!/usr/bin/env bash
set -e

echo "=========================================="
echo "Initializing Musee Flutter Development Env"
echo "=========================================="

WORKSPACE_DIR="${CODESPACE_VSCODE_FOLDER:-/workspaces/Musee-client}"

# Configure git safe directory
git config --global --add safe.directory "${WORKSPACE_DIR}" || true

# Verify Flutter and Android toolchain
echo "[1/3] Verifying Flutter and Android SDK..."
flutter doctor -v

# Fetch Flutter dependencies and generate android/local.properties
echo "[2/3] Fetching Flutter dependencies and generating local.properties..."
cd "${WORKSPACE_DIR}"
flutter pub get

# Check if Mason bricks need to be fetched
if [ -f "mason.yaml" ] && command -v mason &> /dev/null; then
    echo "[3/3] Getting Mason bricks..."
    mason get || true
else
    echo "[3/3] Mason check complete."
fi

echo "=========================================="
echo "Dev Container setup complete! Ready to build."
echo "=========================================="
