#!/usr/bin/env bash
# Zynq specific tools, hardware access groups and the default user.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

install_overlay etc/udev/rules.d/10-redpitaya.rules
install_overlay etc/profile.d/redpitaya.sh

log "installing zynq packages"
chroot_run <<'EOF'
apt-get install -y \
    device-tree-compiler \
    i2c-tools \
    libi2c-dev \
    libiio-dev \
    libiio-utils \
    libudev-dev \
    python3-libiio \
    u-boot-tools
EOF

log "building gpio-utils"
chroot_run <<'EOF'
rm -rf /tmp/gpio-utils
git clone --depth 1 https://github.com/RedPitaya/gpio-utils.git /tmp/gpio-utils
cd /tmp/gpio-utils
meson builddir --buildtype release --prefix /usr
ninja -C builddir install
rm -rf /tmp/gpio-utils
EOF

log "creating hardware access groups and default user"
chroot_run <<'EOF'
for group in xdevcfg uio led gpio spi eeprom xadc dma i2c; do
    getent group "$group" >/dev/null || groupadd --system "$group"
done

id redpitaya >/dev/null 2>&1 || useradd -m -c "Red Pitaya" -s /bin/bash \
    -G sudo,xdevcfg,uio,xadc,led,gpio,spi,i2c,eeprom,dialout,dma redpitaya
EOF

# MOTD is a link to the Red Pitaya version file created by the ecosystem.
ln -sfn /opt/redpitaya/version.txt "$ROOT_DIR/etc/motd"
