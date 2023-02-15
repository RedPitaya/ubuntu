################################################################################
# Authors:
# - Pavel Demin <pavel.demin@uclouvain.be>
# - Iztok Jeras <iztok.jeras@redpitaya.com>
# License:
# https://raw.githubusercontent.com/RedPitaya/RedPitaya/master/COPYING
################################################################################

echo '################################################################################'
echo '# install various packages'
echo '################################################################################'

# Added by DM; 2017/10/17 to check ROOT_DIR setting
if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi

# SETUP after build baazar
chroot $ROOT_DIR <<- EOF_CHROOT
# applications used by Bazaar

# libraries used by Bazaar

apt-get -y install libcrypto++-dev
apt-get -y install libboost-dev
apt-get -y install libluajit
apt-get -y install libluajit-5.1-dev
apt-get -y install libpcre3-dev
apt-get -y install libcurl4-openssl-dev
apt-get -y install libboost-all-dev
apt-get -y install lua-cjson

# JSON libraries
#
apt-get -y install libjson-c-dev rapidjson-dev
# Websockets++ library
#apt-get -y install libwebsocketpp-dev

EOF_CHROOT

echo '################################################################################'
echo '# systemd services'
echo '################################################################################'

install -v -m 664 -o root -d                                                         $ROOT_DIR/var/log/redpitaya_nginx
install -v -m 664 -o root -D $OVERLAY/etc/systemd/system/redpitaya_nginx.service     $ROOT_DIR/etc/systemd/system/redpitaya_nginx.service
install -v -m 664 -o root -D $OVERLAY/etc/systemd/system/sockproc.service            $ROOT_DIR/etc/systemd/system/sockproc.service
install -v -m 664 -o root -D $OVERLAY/etc/systemd/system/redpitaya_scpi.service      $ROOT_DIR/etc/systemd/system/redpitaya_scpi.service
install -v -m 664 -o root -D $OVERLAY/etc/systemd/system/redpitaya_startup.service   $ROOT_DIR/etc/systemd/system/redpitaya_startup.service
install -v -m 664 -o root -D $OVERLAY/etc/systemd/system/scpi.service                $ROOT_DIR/etc/systemd/system/scpi.service
install -v -m 664 -o root -D $OVERLAY/etc/sysconfig/redpitaya                        $ROOT_DIR/etc/sysconfig/redpitaya

chroot $ROOT_DIR <<- EOF_CHROOT
systemctl enable redpitaya_nginx
systemctl enable redpitaya_startup
systemctl enable sockproc
#systemctl enable redpitaya_scpi
EOF_CHROOT

echo '################################################################################'
echo '# create users and groups'
echo '################################################################################'

# NEED RUN SCRIPT zynq.sh

chroot $ROOT_DIR <<- EOF_CHROOT
# add system groups for running daemons
# for running bazar (Nginx), sockproc
useradd --system redpitaya_nginx
useradd --system scpi

# add HW access rights to Nginx user "redpitaya_nginx"
usermod -a -G xdevcfg,uio,xadc,led,gpio,spi,i2c,eeprom,dialout,dma redpitaya_nginx

# add HW access rights to users "scpi"
usermod -a -G uio,xadc,led,gpio,spi,i2c,eeprom,dialout,dma scpi

# TODO: Bazaar code should be moved from /dev/mem to /dev/uio/*
usermod -a -G kmem redpitaya
usermod -a -G kmem redpitaya_nginx
usermod -a -G kmem scpi
EOF_CHROOT
