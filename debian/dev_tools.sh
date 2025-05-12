echo "################################################################################"
echo "# Dev tools"
echo "################################################################################"

# Added by DM; 2017/10/17 to check ROOT_DIR setting
if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi


chroot $ROOT_DIR <<- EOF_CHROOT
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

# Git can be used to share notebook examples
apt-get -y install git

# GCC

apt-get -y install build-essential gcc

# Meson+ninja build system
apt-get -y install ninja-build meson

# pkg-config
apt-get -y install pkg-config

# bison, flex
apt-get -y install bison flex

# DSP library for C language
apt-get -y install libliquid-dev

#  Install libs
apt-get -y install libaio-dev libusb-dev libusb-1.0-0-dev libserialport-dev libxml2-dev libavahi-client-dev

# Debug tools

apt-get -y install gdb cgdb libcunit1-ncurses-dev

# openssl

apt-get -y install libssl-dev

EOF_CHROOT


echo "################################################################################"
echo "# Install cmake"
echo "################################################################################"


chroot $ROOT_DIR <<- EOF_CHROOT

export DEBIAN_FRONTEND=noninteractive

apt install -y cmake

EOF_CHROOT