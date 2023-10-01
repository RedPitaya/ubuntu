export ROOT_DIR=$(realpath ./root)

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

curl -L https://github.com/RedPitaya/linux-xlnx/archive/branch-redpitaya-v2022.3.tar.gz -o /tmp/kernel.tar.gz
mkdir -p /usr/kernel
tar -zxf /tmp/kernel.tar.gz --strip-components=1 --directory=/usr/kernel
rm /tmp/kernel.tar.gz
make -C /usr/kernel mrproper
make -C /usr/kernel KCFLAGS="-O2 -march=armv7-a -mtune=cortex-a9" ARCH=arm redpitaya_zynq_defconfig
make -C /usr/kernel KCFLAGS="-O2 -march=armv7-a -mtune=cortex-a9" ARCH=arm modules -j$(nproc)
make -C /usr/kernel ARCH=arm modules_install -j$(nproc)


EOF_CHROOT
