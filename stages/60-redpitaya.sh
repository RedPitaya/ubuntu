#!/usr/bin/env bash
# Bazaar/SCPI runtime dependencies, service units and daemon users.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

install_overlay etc/sysconfig/redpitaya
install_overlay etc/systemd/system/redpitaya_nginx.service
install_overlay etc/systemd/system/redpitaya_scpi.service
install_overlay etc/systemd/system/redpitaya_startup.service
install_overlay etc/systemd/system/redpitaya_e3_controller.service
install_overlay etc/systemd/system/sockproc.service
copy_overlay_dir etc/systemd/system/serial-getty@ttyPS0.service.d

install -d -m 0755 -o root -g root "$ROOT_DIR/var/log/redpitaya_nginx"

log "installing ecosystem dependencies"
chroot_run <<'EOF'
apt-get install -y \
    libboost-all-dev \
    libboost-dev \
    libcrypto++-dev \
    libcurl4-openssl-dev \
    libjson-c-dev \
    libluajit-5.1-dev \
    libpcre3-dev \
    lua-cjson \
    luajit \
    openssl \
    rapidjson-dev \
    shellinabox
EOF

# Bazaar is served over plain HTTP by nginx.
patch_rootfs_file 's/--no-beep/--no-beep --disable-ssl/' \
    etc/default/shellinabox '\-\-disable-ssl'

log "creating daemon users"
chroot_run <<'EOF'
id redpitaya_nginx >/dev/null 2>&1 || useradd --system redpitaya_nginx
id scpi >/dev/null 2>&1 || useradd --system scpi

usermod -a -G xdevcfg,uio,xadc,led,gpio,spi,i2c,eeprom,dialout,dma,kmem redpitaya_nginx
usermod -a -G uio,xadc,led,gpio,spi,i2c,eeprom,dialout,dma,kmem scpi
usermod -a -G kmem redpitaya
EOF

enable_units \
    redpitaya_nginx.service \
    redpitaya_startup.service \
    redpitaya_e3_controller.service \
    sockproc.service
