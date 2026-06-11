if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi

install -v -m 664 -o root -D $OVERLAY/etc/systemd/system/netstart.service $ROOT_DIR/etc/systemd/system/netstart.service

chroot $ROOT_DIR <<- EOF_CHROOT

export DEBIAN_FRONTEND=noninteractive
apt -y install wireless-tools

systemctl enable netstart.service
systemctl disable wpa_supplicant@wlan0.service
rm -f /etc/systemd/system/wpa_supplicant@.service

EOF_CHROOT
