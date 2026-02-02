echo '###############################################################################'
echo '# install packages for Jyputer'
echo '###############################################################################'

# Added by DM; 2017/10/17 to check ROOT_DIR setting
if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi

chroot $ROOT_DIR <<- EOF_CHROOT
export DEBIAN_FRONTEND=noninteractive

# Sigrok
apt-get -y install libsigrok4t64 libsigrokdecode4 sigrok-cli
apt-get -y install libffi8 libffi-dev

# Python numerical processing and plotting
apt-get -y install gfortran libopenblas-dev liblapack-dev

# Need for pillow
apt-get -y  install libjpeg-dev zlib1g-dev libpng-dev

#----------------

# Jupyterlab and ipywidgets
pip3 install meson==1.6.1 --break-system-packages
pip3 install meson-python==0.17.1 --break-system-packages
pip3 install pybind11==2.13.6 --break-system-packages
pip3 install cython==3.0.11 --break-system-packages

pip3 install contourpy==1.3.1 -U --no-build-isolation --break-system-packages

pip3 install notebook==7.3.2 --break-system-packages
pip3 install jupyterlab==4.3.4 --break-system-packages
pip3 install ipywidgets==8.1.8 --break-system-packages
pip3 install qtconsole==5.6.1 --break-system-packages
pip3 install bokeh==3.8.2 --break-system-packages
pip3 install jupyterlab_server==2.27.3 --break-system-packages
pip3 install jupyterlab-widgets==3.0.14 --break-system-packages
pip3 install jupyterlab-pygments==0.3.0 --break-system-packages
pip3 install jupyter_core==5.9.1 --break-system-packages
pip3 install jupyter_client==8.8.0 --break-system-packages

pip3 install numpy==2.4.1 --break-system-packages
pip3 install scipy==1.17.0 --break-system-packages
pip3 install pandas==3.0.0 --break-system-packages
pip3 install matplotlib==3.10.0 --break-system-packages


pip3 install jupyter_bokeh==4.0.5 --break-system-packages

# additional Python support for GPIO, LED, PWM, SPI, I2C, MMIO, Serial
# https://pypi.python.org/pypi/python-periphery
pip3 install python-periphery==2.4.1 --break-system-packages
pip3 install smbus2==0.5.0 --break-system-packages
pip3 install i2cdev==0.0.6 --break-system-packages

# support for VCD files
pip3 install pyvcd==0.4.1 --break-system-packages

# UDEV support can be used to search for peripherals loaded using DT overlays
pip3 install pyudev==0.24.3 --break-system-packages
pip3 install pyfdt==0.3 --break-system-packages


EOF_CHROOT

###############################################################################
# create user and add it into groups for HW access rights
###############################################################################

chroot $ROOT_DIR <<- EOF_CHROOT
useradd -m -c "Jupyter notebook user" -s /bin/bash -G xdevcfg,uio,xadc,led,gpio,spi,i2c,eeprom,dialout,dma jupyter
EOF_CHROOT

###############################################################################
# systemd service
###############################################################################

# copy systemd service
install -v -m 664 -o root -D  $OVERLAY/etc/systemd/system/jupyter.service \
                             $ROOT_DIR/etc/systemd/system/jupyter.service

# create configuration directory for users root and jupyter
install -v -m 664 -o root -D  $OVERLAY/home/jupyter/.jupyter/jupyter_notebook_config.py \
                             $ROOT_DIR/root/.jupyter/jupyter_notebook_config.py
# let the owner be root, since the user should not change it easily
install -v -m 664 -o root -D  $OVERLAY/home/jupyter/.jupyter/jupyter_notebook_config.py \
                             $ROOT_DIR/home/jupyter/.jupyter/jupyter_notebook_config.py

chroot $ROOT_DIR <<- EOF_CHROOT
chown -v -R jupyter:jupyter /home/jupyter/.jupyter
systemctl enable jupyter
EOF_CHROOT

###############################################################################
# copy/link notebook examples
###############################################################################

#mkdir $ROOT_DIR/home/jupyter/RedPitaya
git clone https://github.com/redpitaya/jupyter.git -b Release-2026.1 $ROOT_DIR/home/jupyter/RedPitaya

chroot $ROOT_DIR <<- EOF_CHROOT
export PIP_BREAK_SYSTEM_PACKAGES=1
pip3 install -e /home/jupyter/RedPitaya --no-build-isolation
EOF_CHROOT

#mkdir $ROOT_DIR/home/jupyter/WhirlwindTourOfPython
git clone https://github.com/jakevdp/WhirlwindTourOfPython.git $ROOT_DIR/home/jupyter/WhirlwindTourOfPython
