export ROOT_DIR=$(realpath ./root)

chroot $ROOT_DIR <<- EOF_CHROOT
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive
export CROSS_COMPILE=arm-linux-gnueabihf-
export ARCH=arm

echo CROSS_COMPILE
cd /tmp/

git clone https://github.com/lwfinger/rtl8188eu.git  rtl8188eu
cd rtl8188eu
make KCFLAGS="-O2 -march=armv7-a -mtune=cortex-a9" KERNELRELEASE=5.15.0-xilinx
make install KERNELRELEASE=5.15.0-xilinx

EOF_CHROOT
