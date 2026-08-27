#!/usr/bin/env bash
# Installs the general purpose user space tools.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

chroot_run <<'EOF'
apt-get install -y \
    bc \
    curl \
    dbus \
    dosfstools \
    ethtool \
    fdisk \
    ftp \
    gawk \
    kmod \
    less \
    lshw \
    lsof \
    libubootenv-tool \
    mc \
    memtester \
    mtd-utils \
    nano \
    ntp \
    parted \
    psmisc \
    sudo \
    tree \
    udev \
    unzip \
    usbutils \
    vim \
    wget \
    zip
EOF

install_overlay etc/fw_env.config
