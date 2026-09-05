FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ARG FLUTTER_VERSION="3.47.2"
ARG ANDROID_CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

# Environment variables for SDKs, Java, and Gradle
ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    FLUTTER_HOME=/opt/flutter \
    FLUTTER_ROOT=/opt/flutter \
    FLUTTER_VERSION=${FLUTTER_VERSION} \
    ANDROID_CMDLINE_TOOLS_URL=${ANDROID_CMDLINE_TOOLS_URL} \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    GRADLE_USER_HOME=/home/vscode/.gradle \
    PUB_CACHE=/home/vscode/.pub-cache \
    CHROME_EXECUTABLE=/usr/bin/google-chrome-stable

ENV PATH=${PATH}:${JAVA_HOME}/bin:${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/cmdline-tools/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools/35.0.0:${PUB_CACHE}/bin

# 1. Install system dependencies as root
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    git \
    gnupg \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-17-jdk-headless \
    build-essential \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    libmpv-dev \
    mpv \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Install Google Chrome for Flutter web testing and headless driver
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-chrome-stable \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Create target directories and grant ownership to vscode BEFORE downloading
RUN mkdir -p ${ANDROID_HOME} ${FLUTTER_HOME} /home/vscode/.gradle /home/vscode/.pub-cache \
    && chown -R vscode:vscode ${ANDROID_HOME} ${FLUTTER_HOME} /home/vscode/.gradle /home/vscode/.pub-cache \
    && git config --system --add safe.directory "*"

# Switch to non-root user vscode for all SDK installations and caches
USER vscode

# 4. Download and setup Android SDK as vscode user
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && curl -fsSL -o /tmp/cmdline-tools.zip "${ANDROID_CMDLINE_TOOLS_URL}" \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-unzip \
    && mv /tmp/cmdline-tools-unzip/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools-unzip \
    && yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses \
    && ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_HOME} \
       "platform-tools" \
       "platforms;android-35" \
       "platforms;android-34" \
       "build-tools;35.0.0" \
       "build-tools;34.0.0"

# 5. Download and setup Flutter SDK as vscode user
RUN curl -fsSL -o /tmp/flutter.tar.xz "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar -xf /tmp/flutter.tar.xz --no-same-owner -C /opt \
    && rm -f /tmp/flutter.tar.xz \
    && ${FLUTTER_HOME}/bin/flutter config --no-analytics \
    && ${FLUTTER_HOME}/bin/flutter config --android-sdk ${ANDROID_HOME} \
    && ${FLUTTER_HOME}/bin/flutter precache --android --universal --linux --web \
    && yes | ${FLUTTER_HOME}/bin/flutter doctor --android-licenses || true

# 6. Pre-cache Gradle 8.14 wrapper distribution as vscode user
RUN mkdir -p /home/vscode/.gradle/wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj \
    && curl -fsSL -o /home/vscode/.gradle/wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj/gradle-8.14-all.zip "https://services.gradle.org/distributions/gradle-8.14-all.zip" \
    && unzip -q /home/vscode/.gradle/wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj/gradle-8.14-all.zip -d /home/vscode/.gradle/wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj \
    && touch /home/vscode/.gradle/wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj/gradle-8.14-all.zip.ok \
    && touch /home/vscode/.gradle/wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj/gradle-8.14-all.zip.lck \
    && printf "org.gradle.daemon=true\norg.gradle.parallel=true\norg.gradle.caching=true\norg.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m -XX:+HeapDumpOnOutOfMemoryError\n" > /home/vscode/.gradle/gradle.properties

# 7. Pre-warm AGP 8.11.1 and Kotlin Gradle plugin 2.2.20 in Gradle cache as vscode user
RUN mkdir -p /tmp/gradle-warmup \
    && printf "buildscript {\n    repositories {\n        google()\n        mavenCentral()\n    }\n    dependencies {\n        classpath 'com.android.tools.build:gradle:8.11.1'\n        classpath 'org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20'\n    }\n}\n" > /tmp/gradle-warmup/build.gradle \
    && touch /tmp/gradle-warmup/settings.gradle \
    && /home/vscode/.gradle/wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj/gradle-8.14/bin/gradle -b /tmp/gradle-warmup/build.gradle help --no-daemon \
    && rm -rf /tmp/gradle-warmup

WORKDIR /workspaces/Musee-client

# 8. Verify toolchain with flutter doctor
RUN flutter doctor -v
