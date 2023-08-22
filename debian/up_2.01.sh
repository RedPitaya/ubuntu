if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi

chroot $ROOT_DIR <<- EOF_CHROOT

export DEBIAN_FRONTEND=noninteractive
echo 2.01 > /root/.version

rm /usr/lib/binfmt.d/python3.10.conf

EOF_CHROOT
