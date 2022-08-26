echo "################################################################################"
echo "# miscelaneous tools"
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

apt-get -y install dbus udev curl wget gawk

# development tools
apt-get -y install less vim nano sudo usbutils psmisc lsof 
apt-get -y install parted dosfstools

# install file system tools
apt-get -y install mtd-utils

# Install Midnight commander
apt-get -y install mc

# Tools used to compile applications
apt-get -y install zip

# Miscelaneous tools
apt-get -y install bc

# shutdown and reboot tool
apt-get -y install systemd-sysv

EOF_CHROOT
