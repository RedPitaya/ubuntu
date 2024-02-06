if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi

echo "################################################################################"
echo "# Up to 2.04"
echo "################################################################################"

chroot $ROOT_DIR <<- EOF_CHROOT

export DEBIAN_FRONTEND=noninteractive

echo 2.04 > /root/.version

apt-get install lshw ethtool

# Removed scripts for wifi and old drvier
# check this commit 'https://github.com/RedPitaya/ubuntu/commit/b69855941ea32b9b6d354ef7e190f91be2579d12'

EOF_CHROOT