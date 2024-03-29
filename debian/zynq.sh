################################################################################
# Authors:
# - Pavel Demin <pavel.demin@uclouvain.be>
# - Iztok Jeras <iztok.jeras@redpitaya.com>
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

# Copy files to the boot file system
# unzip ecosystem*.zip -d $BOOT_DIR

echo '################################################################################'
echo '# U-Boot environment EEPROM memory map'
echo '################################################################################'

chroot $ROOT_DIR <<- EOF_CHROOT
export LANG='C' LC_ALL='C' LANGUAGE='C'
export DEBIAN_FRONTEND=noninteractive

# development tools

apt-get -y install u-boot-tools
EOF_CHROOT

# copy U-Boot environment tools
install -v -m 664 -o root -D patches/fw_env.config  $ROOT_DIR/etc/fw_env.config

echo '################################################################################'
echo '# install various packages'
echo '################################################################################'

chroot $ROOT_DIR <<- EOF_CHROOT
export LANG='C' LC_ALL='C' LANGUAGE='C'
export DEBIAN_FRONTEND=noninteractive

# I2C libraries
apt-get install -y libi2c-dev i2c-tools

# Device tree compiler can be used to compile custom overlays
apt-get -y install libudev-dev
EOF_CHROOT

echo '################################################################################'
echo '# build dtc'
echo '################################################################################'

# NOTE: we have to compile a custom device tree compiler with overlay support
chroot $ROOT_DIR <<- EOF_CHROOT
export LANG='C' LC_ALL='C' LANGUAGE='C'
export DEBIAN_FRONTEND=noninteractive

#curl -L https://github.com/pantoniou/dtc/archive/overlays.tar.gz -o dtc.tar.gz
#curl -L https://github.com/RedPitaya/dtc/archive/overlays_python3.tar.gz -o dtc.tar.gz
curl -L https://git.kernel.org/pub/scm/utils/dtc/dtc.git/snapshot/dtc-1.6.1.tar.gz  -o dtc.tar.gz
tar zxf dtc.tar.gz
cd dtc-1.6.1
make -j$(grep processor /proc/cpuinfo | wc -l)
make install PREFIX=/usr
cd ../
rm -rf dtc-1.6.1 dtc.tar.gz
EOF_CHROOT


echo '################################################################################'
echo '# build IIO library'
echo '################################################################################'

# IIO library, the version provided in debian is old, missing Python 3 bindings
chroot $ROOT_DIR <<- EOF_CHROOT

export LANG='C' LC_ALL='C' LANGUAGE='C'
export DEBIAN_FRONTEND=noninteractive

# https://wiki.analog.com/resources/eval/user-guides/ad-fmcdaq2-ebz/software/linux/applications/libiio#how_to_build_it
apt-get -y install libxml2 libxml2-dev bison flex libcdk5-dev

#git clone --branch v0.10 --depth 1 https://github.com/analogdevicesinc/libiio.git
curl -L https://github.com/analogdevicesinc/libiio/archive/refs/tags/v0.23.tar.gz -o libiio.tar.gz
tar zxvf libiio.tar.gz
cd libiio-0.23/
cmake ./ -DPYTHON_BINDINGS=ON
make all -j$(grep processor /proc/cpuinfo | wc -l)
make install
pip3 install bindings/python/
# cleanup
cd ../
rm -rf libiio-0.23 libiio.tar.gz
EOF_CHROOT


## Ne10 library, the version in launchpad fails to build
# TODO: 'make install' is not working yet
#chroot $ROOT_DIR <<- EOF_CHROOT
#sudo apt-get install cmake
#git clone --depth 1 https://github.com/projectNe10/Ne10.git
#cd Ne10
#mkdir build && cd build             # Create the `build` directory and navigate into it
#export NE10_LINUX_TARGET_ARCH=armv7 # Set the target architecture (can also be "aarch64")
#cmake -DGNULINUX_PLATFORM=ON ..     # Run CMake to generate the build files
#make                                # Build the project
## cleanup
#cd ../../
#rm -rf Ne10
#EOF_CHROOT

# GPIO utilities
chroot $ROOT_DIR <<- EOF_CHROOT
git clone --depth 1 https://github.com/RedPitaya/gpio-utils.git
cd gpio-utils
meson builddir --buildtype release --prefix /usr
cd builddir
ninja install
cd ../../
rm -rf gpio-utils
EOF_CHROOT

################################################################################
# create users and groups
################################################################################

# UDEV rules setting hardware access group rights
install -v -m 664 -o root -D $OVERLAY/etc/udev/rules.d/10-redpitaya.rules            $ROOT_DIR/etc/udev/rules.d/10-redpitaya.rules

chroot $ROOT_DIR <<- EOF_CHROOT
# add system groups for HW access
groupadd --system xdevcfg
groupadd --system uio
groupadd --system led
groupadd --system gpio
groupadd --system spi
groupadd --system eeprom
groupadd --system xadc
groupadd --system dma

# add a default user
useradd -m -c "Red Pitaya" -s /bin/bash -G sudo,xdevcfg,uio,xadc,led,gpio,spi,i2c,eeprom,dialout,dma redpitaya
EOF_CHROOT

###############################################################################
# configuring shell
###############################################################################

# profile for PATH variables, ...
install -v -m 664 -o root -D $OVERLAY/etc/profile.d/redpitaya.sh $ROOT_DIR/etc/profile.d/redpitaya.sh

# MOTD (the static part) is a link to Red Pitaya version.txt
ln -s /opt/redpitaya/version.txt $ROOT_DIR/etc/motd
