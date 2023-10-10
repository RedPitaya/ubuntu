if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi

echo "################################################################################"
echo "# Up to 2.0"
echo "################################################################################"

chroot $ROOT_DIR <<- EOF_CHROOT

export DEBIAN_FRONTEND=noninteractive
echo 2.0 > /root/.version

EOF_CHROOT
