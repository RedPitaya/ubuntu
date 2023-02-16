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
apt-get -y install zip unzip

# Miscelaneous tools
apt-get -y install bc

# Disk utility
apt-get -y install fdisk

# shutdown and reboot tool
apt-get -y install systemd-sysv

# uboot tools (fw_printenv)
apt install -y libubootenv-tool

# install ntp

apt-get install ntp

# install shellinabox

apt-get install openssl shellinabox

# disable https

sed -i 's/--no-beep/--no-beep --disable-ssl/' /etc/default/shellinabox

EOF_CHROOT

# config for fw_printenv
install -v -m 664 -o root -D $OVERLAY/etc/fw_env.config  $ROOT_DIR/etc/fw_env.config