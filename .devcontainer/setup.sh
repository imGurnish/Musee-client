#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Initializing Musee Flutter Development Env"
echo "=========================================="

WORKSPACE_DIR="${CODESPACE_VSCODE_FOLDER:-/workspaces/Musee-client}"
ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME}}"
FLUTTER_HOME="${FLUTTER_HOME:-/opt/flutter}"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.2}"
ANDROID_CMDLINE_TOOLS_URL="${ANDROID_CMDLINE_TOOLS_URL:-https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip}"

export ANDROID_HOME ANDROID_SDK_ROOT FLUTTER_HOME
export PATH="${PATH}:${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

ensure_android_sdk() {
    if [ -x "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" ]; then
        echo "Android SDK command-line tools already installed."
        return
    fi

    echo "Installing Android SDK command-line tools..."
    mkdir -p "${ANDROID_HOME}/cmdline-tools"
    curl -fsSL -o /tmp/cmdline-tools.zip "${ANDROID_CMDLINE_TOOLS_URL}"
    unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-unzip
    mv /tmp/cmdline-tools-unzip/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest"
    rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools-unzip
}

ensure_flutter() {
    if [ -x "${FLUTTER_HOME}/bin/flutter" ]; then
        echo "Flutter SDK already installed."
        return
    fi

    echo "Installing Flutter SDK ${FLUTTER_VERSION}..."
    curl -fsSL -o /tmp/flutter.tar.xz "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    tar -xf /tmp/flutter.tar.xz --no-same-owner -C /opt
    rm -f /tmp/flutter.tar.xz
}

# Configure git safe directory
git config --global --add safe.directory "${WORKSPACE_DIR}" || true

# Ensure Android SDK and Flutter are installed
echo "[1/4] Ensuring Android SDK is installed..."
ensure_android_sdk

echo "[2/4] Ensuring Flutter SDK is installed..."
ensure_flutter

echo "[3/4] Configuring Flutter and Android SDK..."
yes | "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" --licenses || true
"${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" \
    --sdk_root="${ANDROID_HOME}" \
    "platform-tools" \
    "platforms;android-35" \
    "build-tools;35.0.0"
"${FLUTTER_HOME}/bin/flutter" config --no-analytics
"${FLUTTER_HOME}/bin/flutter" config --android-sdk "${ANDROID_HOME}"
"${FLUTTER_HOME}/bin/flutter" precache --android --linux --web || true

echo "[4/4] Verifying Flutter and Android SDK..."
"${FLUTTER_HOME}/bin/flutter" doctor -v || true

# Fetch Flutter dependencies and generate android/local.properties
echo "Fetching Flutter dependencies and generating local.properties..."
cd "${WORKSPACE_DIR}"
"${FLUTTER_HOME}/bin/flutter" pub get

# Check if Mason bricks need to be fetched
if [ -f "mason.yaml" ] && command -v mason &> /dev/null; then
    echo "Getting Mason bricks..."
    mason get || true
else
    echo "Mason check complete."
fi

echo "=========================================="
echo "Dev Container setup complete! Ready to build."
echo "=========================================="
