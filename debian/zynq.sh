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
echo '# install dtc'
echo '################################################################################'

# NOTE: we have to compile a custom device tree compiler with overlay support
chroot $ROOT_DIR <<- EOF_CHROOT
export LANG='C' LC_ALL='C' LANGUAGE='C'
export DEBIAN_FRONTEND=noninteractive

apt-get -y install device-tree-compiler
EOF_CHROOT


echo '################################################################################'
echo '# build IIO library'
echo '################################################################################'

# IIO library, the version provided in debian is old, missing Python 3 bindings
chroot $ROOT_DIR <<- EOF_CHROOT

export LANG='C' LC_ALL='C' LANGUAGE='C'
export DEBIAN_FRONTEND=noninteractive

apt-get -y install libiio-utils libiio-dev
apt-get -y install python3-libiio

EOF_CHROOT


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
