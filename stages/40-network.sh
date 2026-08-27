#!/usr/bin/env bash
# Configures systemd-networkd, SSH, WiFi (client and AP) and mDNS.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

install_overlay etc/iptables/iptables.rules
install_overlay etc/sysctl.d/99-ip-forwarding.conf
install_overlay etc/systemd/network/25-wireless.link
install_overlay etc/systemd/network/wired.network
install_overlay etc/systemd/network/wireless.network.client
install_overlay etc/systemd/network/wireless.network.ap
install_overlay etc/systemd/system/ssh-reconfigure.service
install_overlay etc/systemd/system/wireless_adapter_up@.service
install_overlay etc/systemd/system/wireless-mode-client.service
install_overlay etc/systemd/system/wireless-mode-ap.service
install_overlay etc/systemd/system/wpa_supplicant@.service
install_overlay etc/systemd/system/wpa_supplicant@.path
install_overlay etc/systemd/system/hostapd@.service
install_overlay etc/systemd/system/hostapd@.path
install_overlay etc/systemd/system/iptables.service
install_overlay etc/systemd/system/hostname-mac.service
install_overlay etc/avahi/services/ssh.service
install_overlay etc/avahi/services/bazaar.service

# ExecStop of iptables.service expects the script in this location.
install_overlay etc/systemd/system/iptables-flush usr/lib/systemd/scripts/iptables-flush 0755

log "installing network packages"
chroot_run <<'EOF'
apt-get install -y \
    avahi-daemon \
    ca-certificates \
    curl \
    hostapd \
    iproute2 \
    iptables \
    iputils-ping \
    iw \
    libnss-mdns \
    openssh-server \
    sshpass \
    systemd-resolved \
    wpasupplicant

mkdir -p /etc/hostapd /etc/wpa_supplicant
ln -sf /opt/redpitaya/hostapd.conf /etc/hostapd/hostapd.conf
ln -sf /opt/redpitaya/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf

# Keep USB WiFi adapters named wlan0 instead of wlx[MAC].
ln -sf /dev/null /etc/udev/rules.d/73-usb-net-by-mac.rules

# Host keys are regenerated on first boot by ssh-reconfigure.service.
rm -f /etc/ssh/ssh_host_*

systemctl disable hostapd.service
EOF

write_rootfs_file etc/ssh/sshd_config.d/10-redpitaya.conf <<'EOF'
PermitRootLogin yes
EOF

write_rootfs_file etc/systemd/resolved.conf.d/mdns.conf <<'EOF'
[Resolve]
MulticastDNS=yes
EOF

write_rootfs_file etc/systemd/system/avahi-daemon.service.d/ad.conf <<'EOF'
[Unit]
After=systemd-resolved.service
EOF

write_rootfs_file etc/mdns.allow <<'EOF'
.local.
.local
EOF

patch_rootfs_file 's/mdns4_minimal/mdns/' etc/nsswitch.conf '^hosts:.*\bmdns\b'
patch_rootfs_file 's|^(ExecStart=.*systemd-networkd-wait-online)$|\1 --any|' \
    lib/systemd/system/systemd-networkd-wait-online.service \
    'systemd-networkd-wait-online .*--any'

enable_units \
    systemd-networkd.service \
    systemd-resolved.service \
    avahi-daemon.service \
    hostname-mac.service \
    ssh-reconfigure.service \
    iptables.service \
    wireless_adapter_up@wlan0.service \
    wpa_supplicant@wlan0.service \
    hostapd@wlan0.service \
    wireless-mode-client.service \
    wireless-mode-ap.service
