#!/bin/bash

################################################################################
# License:
# https://raw.githubusercontent.com/RedPitaya/RedPitaya/master/COPYING
################################################################################

# Optional system variables:
# TIMEZONE - it is written into /etc/timezone


################################################################################
# prepating image
################################################################################

export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

apt install -y qemu-user-static curl

# current time and date are used to create the image name
export DATE=`date +"%H-%M-%S_%d-%b-%Y"`

# default image size if 3GB, which is appropriate for all 4BG SD cards
SIZE=7500

#IMAGE=$1
IMAGE=redpitaya_OS_${DATE}.img

sudo dd if=/dev/zero of=$IMAGE bs=1M count=$SIZE

DEVICE=$(losetup -f)

sudo losetup -P $DEVICE $IMAGE

echo $DEVICE

export BOOT_DIR=$(realpath ./boot)
export ROOT_DIR=$(realpath ./root)

echo "Boot dir $BOOT_DIR"
echo "Root dir $ROOT_DIR"

# Create partitions
parted -s $DEVICE mklabel msdos
parted -s $DEVICE mkpart primary fat16   4MB 512MB
parted -s $DEVICE mkpart primary ext4  512MB 100%

partprobe $DEVICE

BOOT_DEV=/dev/$(lsblk -lno NAME -x NAME $DEVICE | sed '2!d')
ROOT_DEV=/dev/$(lsblk -lno NAME -x NAME $DEVICE | sed '3!d')

# Create file systems
mkfs.vfat -v    $BOOT_DEV
mkfs.ext4 -F -j $ROOT_DEV


################################################################################
# mount image
################################################################################

# Mount file systems
mkdir -p $BOOT_DIR $ROOT_DIR
sudo mount $BOOT_DEV $BOOT_DIR
sudo mount $ROOT_DEV $ROOT_DIR




################################################################################
# install OS
################################################################################

debian/ubuntu.sh 2>&1 | tee $ROOT_DIR/buildlog.txt
# not fixed
# debian/debian.sh 2>&1 | tee $ROOT_DIR/buildlog.txt

################################################################################
# umount image
################################################################################

# kill -k file users and list them -m before Unmount file systems

sudo fuser -km $BOOT_DIR
sudo fuser -km $ROOT_DIR


# Unmount file systems
sudo umount $BOOT_DIR $ROOT_DIR
sudo rm -rf $BOOT_DIR $ROOT_DIR

losetup -d $DEVICE

zip $IMAGE.zip *.img
