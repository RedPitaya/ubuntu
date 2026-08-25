if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi

install -v -m 664 -o root -D $OVERLAY/etc/systemd/system/wifi-powersave@.service $ROOT_DIR/etc/systemd/system/wifi-powersave@.service
install -v -m 664 -o root -D $OVERLAY/etc/systemd/system/wpa_supplicant_wext@.service $ROOT_DIR/etc/systemd/system/wpa_supplicant_wext@.service
install -v -m 755 -o root -D $OVERLAY/usr/local/sbin/rp-wireless-driver $ROOT_DIR/usr/local/sbin/rp-wireless-driver
install -v -m 644 -o root -D $OVERLAY/etc/modprobe.d/rtw88.conf $ROOT_DIR/etc/modprobe.d/rtw88.conf

chroot $ROOT_DIR <<- EOF_CHROOT

export DEBIAN_FRONTEND=noninteractive
apt -y install wireless-tools
apt -y install wireless-regdb

# Connecting at boot is owned by the wpa_supplicant units, not by the
# network_manager web app's shell scripts. wpa_supplicant@wlan0.service is
# enabled in network.sh; enable the wext companion for legacy adapters here,
# next to the wireless-tools install it depends on. Both stay enabled - their
# ExecCondition= picks whichever matches the adapter actually plugged in.
systemctl enable wpa_supplicant_wext@wlan0.service

# 802.11 station power save is on by default and resets on every interface
# bring-up, so this is bound to the device unit rather than to a target.
systemctl enable wifi-powersave@wlan0.service

EOF_CHROOT
