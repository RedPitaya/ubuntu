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

rm -rf /tmp/kernel

git clone https://github.com/RedPitaya/linux-xlnx --depth 1 --branch branch-redpitaya-v2026.1 /tmp/kernel
cd /tmp/kernel
rm -rf .git .github
touch .scmversion

make -C /tmp/kernel mrproper
make -C /tmp/kernel KCFLAGS="-O2 -march=armv7-a -mtune=cortex-a9" ARCH=arm redpitaya_zynq_defconfig  -j$(nproc)
make -C /tmp/kernel KCFLAGS="-O2 -march=armv7-a -mtune=cortex-a9" ARCH=arm modules -j$(nproc)
make -C /tmp/kernel ARCH=arm modules_install INSTALL_MOD_PATH= -j$(nproc)

rm -rf /tmp/kernel

# Update modules
depmod -a 6.12.0-redpitaya


EOF_CHROOT
