#!/bin/bash

################################################################################
# License:
# https://raw.githubusercontent.com/RedPitaya/RedPitaya/master/COPYING
################################################################################

# Added by DM; 2017/10/17 to check ROOT_DIR setting
if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi

# Install Ubuntu base system to the root file system
UBUNTU_BASE_VER=24.04.2
UBUNTU_BASE_TAR=ubuntu-base-${UBUNTU_BASE_VER}-base-armhf.tar.gz
UBUNTU_BASE_URL=http://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_BASE_VER}/release/${UBUNTU_BASE_TAR}
test -f $UBUNTU_BASE_TAR || curl -L $UBUNTU_BASE_URL -o $UBUNTU_BASE_TAR
tar -zxf $UBUNTU_BASE_TAR --directory=$ROOT_DIR

export OVERLAY=debian/overlay

# enable chroot access with native execution
cp /etc/resolv.conf         $ROOT_DIR/etc/
cp /usr/bin/qemu-arm-static $ROOT_DIR/usr/bin/

sudo mount -o bind /dev/ "${ROOT_DIR}/dev/"
sudo mount -o bind /dev/pts "${ROOT_DIR}/dev/pts"
sudo mount -t proc proc "${ROOT_DIR}/proc/"
sudo mount -t sysfs sys "${ROOT_DIR}/sys/"
sudo mount -o bind /run "${ROOT_DIR}/run"


SETUP_PYTHON=1
SETUP_KEYBOARD=1
SETUP_TZ=1
SETUP_HWE=1

export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8


echo "################################################################################"
echo "# Locale settings"
echo "################################################################################"


install -v -m 664 -o root -D $OVERLAY/etc/apt/apt.conf.d/99norecommends $ROOT_DIR/etc/apt/apt.conf.d/99norecommends

chroot $ROOT_DIR <<- EOF_CHROOT
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install locales
echo "LC_ALL=en_US.UTF-8" >> /etc/environment
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen en_US.UTF-8

EOF_CHROOT

echo "################################################################################"
echo "# APT settings"
echo "################################################################################"


install -v -m 664 -o root -D $OVERLAY/etc/apt/apt.conf.d/99norecommends $ROOT_DIR/etc/apt/apt.conf.d/99norecommends

chroot $ROOT_DIR <<- EOF_CHROOT
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y systemd
apt-get install -y apt-utils
apt-get -y upgrade
# Set systemd as main service
ln -s /lib/systemd/systemd /sbin/init
# Disable GUI
systemctl set-default multi-user
apt-get purge ubuntu-desktop
# Enable root user
echo 'root:root' | chpasswd

EOF_CHROOT

if [[ $SETUP_PYTHON == 1 ]]
then
echo "################################################################################"
echo "# python3.12-full settings"
echo "################################################################################"

chroot $ROOT_DIR <<- EOF_CHROOT
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

apt-get -y install python3-full
apt-get -y install python3-pip
apt-get -y install python-is-python3
apt-get -y install python3-dev

pip install --upgrade pip setuptools wheel packaging --break-system-packages

# need for build DTC
apt-get -y install swig

EOF_CHROOT
fi

if [[ $SETUP_KEYBOARD == 1 ]]
then
echo "################################################################################"
echo "# locale and keyboard"
echo "# setting LC_ALL overides values for all LC_* variables, this avids complaints"
echo "# about missing locales if some of this variables are inherited over SSH"
echo "################################################################################"

chroot $ROOT_DIR <<- EOF_CHROOT

export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

# this is needed by systemd services 'keyboard-setup.service' and 'console-setup.service'
DEBIAN_FRONTEND=noninteractive \
apt-get -y install console-setup

# setup locale
apt-get -y install locales
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LANGUAGE=en_US LC_ALL=en_US.UTF-8

# localectl set-locale LANG=en_US.UTF-8 LANGUAGE=en_US LC_ALL=en_US.UTF-8
# localectl set-keymap us

# Debug log
locale -a
locale
cat /etc/default/locale
cat /etc/default/keyboard
EOF_CHROOT
fi


echo "################################################################################"
echo "# hostname"
echo "# NOTE: redpitaya.py enables a systemd service"
echo "# which changes the hostname on boot, to an unique value"
echo "################################################################################"

#chroot $ROOT_DIR <<- EOF_CHROOT
# TODO seems sytemd is not running without /proc/cmdline or something
#hostnamectl set-hostname redpitaya
#EOF_CHROOT

install -v -m 664 -o root -D $OVERLAY/etc/hostname  $ROOT_DIR/etc/hostname

if [[ $SETUP_TZ == 1 ]]
then
echo "################################################################################"
echo "# timezone and fake HW time"
echo "################################################################################"

chroot $ROOT_DIR <<- EOF_CHROOT

export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

# install fake hardware clock
apt-get -y install fake-hwclock

ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime
apt-get install -y tzdata
dpkg-reconfigure --frontend noninteractive tzdata
EOF_CHROOT
fi

# the fake HW clock will be UTC, so an adjust file is not needed
#echo $MYADJTIME > $ROOT_DIR/etc/adjtime
# fake HW time is set to the image build time
DATETIME=`date -u +"%F %T"`
echo date/time = $DATETIME
echo $DATETIME > $ROOT_DIR/etc/fake-hwclock.data

echo "################################################################################"
echo "# File System table"
echo "################################################################################"

install -v -m 664 -o root -D $OVERLAY/etc/fstab  $ROOT_DIR/etc/fstab


echo "################################################################################"
echo "# run other scripts"
echo "################################################################################"

debian/tools.sh
debian/dev_tools.sh
debian/network.sh
debian/zynq.sh


debian/redpitaya.sh

debian/jupyter.sh


debian/watchdog.sh

# Up to version version 1.05
debian/up_1.05.sh

# Installed CA sertificates -> up to version 1.06

# Up to version version 1.07
debian/wireless_tool.sh

# Up to version version 1.08
debian/up_1.08.sh

# Up to version 2.0 (new ubuntu 22.04)

debian/up_2.0.sh

# Added new kernel modules from external repository
debian/up_2.01.sh

# Added libsocketcan library
debian/up_2.02.sh

# Added path to python rp api
debian/up_2.03.sh

# All wifi drivers loading from modules
debian/up_2.04.sh

# Update jupyter code
debian/up_2.05.sh

# Added service for e3_led_controller
debian/up_2.06.sh

# Added libzip-dev package
debian/up_2.07.sh

# Set version 3.00 for ubuntu 24.04
debian/up_3.00.sh

if [[ $SETUP_HWE == 1 ]]
then
echo "################################################################################"
echo "# install HWE kernel modules"
echo "################################################################################"

chroot $ROOT_DIR <<- EOF_CHROOT
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive
export CROSS_COMPILE=arm-linux-gnueabihf-
export ARCH=arm

apt-get -y install kmod

cd /tmp/

curl -L https://github.com/RedPitaya/linux-xlnx/archive/branch-redpitaya-v2025-dev.tar.gz -o /tmp/kernel.tar.gz
mkdir -p /usr/kernel
tar -zxf /tmp/kernel.tar.gz --strip-components=1 --directory=/usr/kernel
rm /tmp/kernel.tar.gz
make -C /usr/kernel mrproper
make -C /usr/kernel KCFLAGS="-O2 -march=armv7-a -mtune=cortex-a9" ARCH=arm redpitaya_zynq_defconfig  -j$(nproc)
make -C /usr/kernel KCFLAGS="-O2 -march=armv7-a -mtune=cortex-a9" ARCH=arm modules -j$(nproc)
make -C /usr/kernel ARCH=arm modules_install -j$(nproc)

EOF_CHROOT
fi

# OS/debian/tft.sh

###############################################################################
# handle users
###############################################################################


install -v -m 664 -o root -D $OVERLAY/etc/securetty $ROOT_DIR/etc/securetty



################################################################################
# cleanup
################################################################################

chroot $ROOT_DIR <<- EOF_CHROOT
apt-get clean
history -c
EOF_CHROOT


# file system cleanup for better compression
cat /dev/zero > $ROOT_DIR/zero.file
sync -f $ROOT_DIR/zero.file
rm -f $ROOT_DIR/zero.file

# remove ARM emulation
rm $ROOT_DIR/usr/bin/qemu-arm-static

################################################################################
# archiving image
################################################################################

# create a tarball (without resolv.conf link, since it causes schroot issues)
rm $ROOT_DIR/etc/resolv.conf
tar -cpzf redpitaya_OS_${DATE}.tar.gz --one-file-system -C $ROOT_DIR .
ln -sf /run/systemd/resolve/resolv.conf $ROOT_DIR/etc/resolv.conf

# one final sync to be sure
sync
sudo umount -l "${ROOT_DIR}/run/"
sudo umount -l "${ROOT_DIR}/sys/"
sudo umount -l "${ROOT_DIR}/proc/"
sudo umount -l "${ROOT_DIR}/dev/pts"
sudo umount -l "${ROOT_DIR}/dev/"
