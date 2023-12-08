if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi

echo "################################################################################"
echo "# Up to 2.03"
echo "################################################################################"

chroot $ROOT_DIR <<- EOF_CHROOT

export DEBIAN_FRONTEND=noninteractive

pip3 install --upgrade pip
pip3 install --upgrade notebook
pip3 install --upgrade bokeh
pip3 install --upgrade jupyterlab
pip3 install --upgrade jupyterlab_server
pip3 install --upgrade jupyterlab-widgets
pip3 install --upgrade jupyterlab-pygments
pip3 install --upgrade jupyter_core
pip3 install --upgrade jupyter_client

echo 2.03 > /root/.version

EOF_CHROOT

install -v -m 664 -o root -D $OVERLAY/usr/local/share/jupyter/kernels/python3/kernel.json      $ROOT_DIR/usr/local/share/jupyter/kernels/python3/kernel.json
