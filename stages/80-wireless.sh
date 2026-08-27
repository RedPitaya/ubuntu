#!/usr/bin/env bash
# Wireless helper tools and the units bound to the WiFi device.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

install_overlay etc/modprobe.d/rtw88.conf
install_overlay etc/systemd/system/wifi-powersave@.service
install_overlay etc/systemd/system/wpa_supplicant_wext@.service
install_overlay etc/systemd/system/wpa_supplicant_wext@.path
install_overlay usr/local/sbin/rp-wireless-driver '' 0755

chroot_run <<'EOF'
apt-get install -y wireless-tools wireless-regdb
EOF

# Both wpa_supplicant variants stay enabled; ExecCondition picks the one
# matching the adapter that is plugged in.
enable_units \
    wpa_supplicant_wext@wlan0.service \
    wifi-powersave@wlan0.service
