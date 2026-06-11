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
export DATE=`date +"%Y-%b-%d_%H-%M-%S"`
export VERSION='3.00'

# default image size if 3GB, which is appropriate for all 4BG SD cards
SIZE=7400

# Build image name with optional build number and version
if [ -n "${BUILD_NUM}" ] && [ "${BUILD_NUM}" != "local" ]; then
    export IMAGE_NAME="redpitaya_OS_${VERSION}.${BUILD_NUM}_${DATE}"
else
    export IMAGE_NAME="redpitaya_OS_${VERSION}_${DATE}"
fi
export IMAGE="${IMAGE_NAME}.img"

# Create the empty image file
dd if=/dev/zero of=$IMAGE bs=1M count=$SIZE

################################################################################
# format image using loop device (temporary)
################################################################################

# Attach loop device only for partitioning and formatting
DEVICE=$(losetup -f)
losetup -P $DEVICE $IMAGE

echo "Loop device: $DEVICE"

# Create partitions
parted -s $DEVICE mklabel msdos
parted -s $DEVICE mkpart primary fat16   4MB 1024MB
parted -s $DEVICE mkpart primary ext4  1024MB 100%

# Force kernel to re-read partition table
partprobe $DEVICE
sleep 2  # Give kernel time to create partition devices

# Check if partition devices exist
if [ ! -e "${DEVICE}p1" ] || [ ! -e "${DEVICE}p2" ]; then
    echo "Error: Partition devices not created"
    echo "Available devices:"
    ls -la ${DEVICE}*
    losetup -d $DEVICE
    exit 1
fi

BOOT_DEV="${DEVICE}p1"
ROOT_DEV="${DEVICE}p2"

echo "Boot device: $BOOT_DEV"
echo "Root device: $ROOT_DEV"

# Create file systems
mkfs.vfat -v $BOOT_DEV
mkfs.ext4 -F -j $ROOT_DEV

# Detach loop device immediately after formatting
losetup -d $DEVICE

################################################################################
# mount image using direct offset mounting
################################################################################

# Get partition information from the image file
SECTOR_SIZE=$(fdisk -l $IMAGE | grep "Sector size" | awk '{print $4}')
BOOT_START=$(fdisk -l $IMAGE | grep "^${IMAGE}1" | awk '{print $2}')
BOOT_END=$(fdisk -l $IMAGE | grep "^${IMAGE}1" | awk '{print $3}')
ROOT_START=$(fdisk -l $IMAGE | grep "^${IMAGE}2" | awk '{print $2}')

# Calculate byte offsets and size limits
BOOT_OFFSET=$((BOOT_START * SECTOR_SIZE))
BOOT_SIZE=$(((BOOT_END - BOOT_START + 1) * SECTOR_SIZE))
ROOT_OFFSET=$((ROOT_START * SECTOR_SIZE))

echo "Sector size: $SECTOR_SIZE"
echo "Boot partition starts at sector: $BOOT_START (offset: $BOOT_OFFSET bytes, size: $BOOT_SIZE bytes)"
echo "Root partition starts at sector: $ROOT_START (offset: $ROOT_OFFSET bytes)"

export BOOT_DIR=$(realpath ./boot)
export ROOT_DIR=$(realpath ./root)

echo "Boot dir $BOOT_DIR"
echo "Root dir $ROOT_DIR"

# Mount file systems directly using offset and sizelimit
mkdir -p $BOOT_DIR $ROOT_DIR
mount -o loop,offset=$BOOT_OFFSET,sizelimit=$BOOT_SIZE $IMAGE $BOOT_DIR
mount -o loop,offset=$ROOT_OFFSET $IMAGE $ROOT_DIR


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
fuser -km $BOOT_DIR
fuser -km $ROOT_DIR

# Unmount file systems
umount $BOOT_DIR $ROOT_DIR
rm -rf $BOOT_DIR $ROOT_DIR

zip $IMAGE.zip $IMAGE