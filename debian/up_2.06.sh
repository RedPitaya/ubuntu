if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi

echo "################################################################################"
echo "# Up to 2.06"
echo "################################################################################"

install -v -m 664 -o root -D $OVERLAY/etc/systemd/system/redpitaya_e3_controller.service   $ROOT_DIR/etc/systemd/system/redpitaya_e3_controller.service

chroot $ROOT_DIR <<- EOF_CHROOT

export DEBIAN_FRONTEND=noninteractive

systemctl enable redpitaya_e3_controller.service

echo 2.06 > /root/.version

EOF_CHROOT
