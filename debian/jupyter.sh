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

# OWFS 1-wire library
# NOTE: for now do not install OWFS, and avoid another http/ftp server from running by default
# apt-get -y install owfs python-ow

# Python package manager, Jupyter dependencies
# apt-get -y install python3-dev python3-cffi python3-wheel python3-setuptools python3-pip python3-zmq python3-jinja2 python3-pygments python3-six python3-html5lib python3-terminado python3-decorator python3-ptyprocess python3-pexpect python3-simplegeneric python3-wcwidth python3-pickleshare python3-bleach python3-mistune python3-jsonschema

# Python numerical processing and plotting
apt-get -y install gfortran libopenblas-dev liblapack-dev
# APT
apt-get -y install python3-numpy python3-scipy python3-pandas
apt-get -y install python3-matplotlib

#----------------

# Jupyterlab and ipywidgets
pip3 install --upgrade pip --break-system-packages
pip3 install meson meson-python pybind11 cython --break-system-packages
pip3 install contourpy -U --no-build-isolation --break-system-packages
pip3 install notebook jupyterlab --break-system-packages
pip3 install ipywidgets qtconsole --break-system-packages

# Jupyter declarative widgets
pip3 install jupyter_declarativewidgets --break-system-packages

## Not work with jupyterlab
##jupyter declarativewidgets quick-setup --sys-prefix
## jupyter contrib nbextension enable --system --py widgetsnbextension
## jupyter declarativewidgets install
## jupyter contrib nbextension enable --sys-prefix --py --system declarativewidgets


pip3 install jupyter_bokeh --break-system-packages

# additional Python support for GPIO, LED, PWM, SPI, I2C, MMIO, Serial
# https://pypi.python.org/pypi/python-periphery
pip3 install python-periphery --break-system-packages
pip3 install smbus2 --break-system-packages
pip3 install i2cdev --break-system-packages

# support for VCD files
pip3 install pyvcd --break-system-packages

# UDEV support can be used to search for peripherals loaded using DT overlays
# https://pypi.python.org/pypi/pyudev
# https://pypi.python.org/pypi/pyfdt
pip3 install pyudev pyfdt --break-system-packages


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
git clone https://github.com/redpitaya/jupyter.git -b master $ROOT_DIR/home/jupyter/RedPitaya

chroot $ROOT_DIR <<- EOF_CHROOT
pip3 install -e /home/jupyter/RedPitaya --break-system-packages
EOF_CHROOT

#mkdir $ROOT_DIR/home/jupyter/WhirlwindTourOfPython
git clone https://github.com/jakevdp/WhirlwindTourOfPython.git $ROOT_DIR/home/jupyter/WhirlwindTourOfPython
