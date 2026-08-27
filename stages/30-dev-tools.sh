#!/usr/bin/env bash
# Installs Python and the native build toolchain used by the ecosystem.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

log "installing python"
chroot_run <<'EOF'
apt-get install -y python3-full python3-pip python3-dev python-is-python3 swig
pip3 install --upgrade pip setuptools wheel packaging
EOF

log "installing build toolchain"
chroot_run <<'EOF'
apt-get install -y \
    bison \
    build-essential \
    cgdb \
    cmake \
    flex \
    gcc \
    gdb \
    git \
    gpiod \
    libaio-dev \
    libavahi-client-dev \
    libcunit1-ncurses-dev \
    libgpiod-dev \
    libliquid-dev \
    libpugixml-dev \
    libserialport-dev \
    libsocketcan-dev \
    libssl-dev \
    libusb-1.0-0-dev \
    libusb-dev \
    libxml2-dev \
    libzip-dev \
    meson \
    ninja-build \
    pkg-config
EOF
