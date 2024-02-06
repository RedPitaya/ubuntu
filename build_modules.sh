#!/bin/bash
export ROOT_DIR=$(realpath ./root)
RP_UBUNTU=redpitaya_OS_16-03-48_03-Nov-2022.tar.gz
SCHROOT_CONF_PATH=/etc/schroot/chroot.d/red-pitaya-ubuntu.conf


function print_ok(){
    echo -e "\033[92m[OK]\e[0m"
}

function print_fail(){
    echo -e "\033[91m[FAIL]\e[0m"
}

# secure chroot
sudo apt-get install schroot -y
# QEMU
sudo apt-get install qemu qemu-user qemu-user-static -y


BD=./modules-build
rm -rf $BD 2> /dev/null
mkdir -p $BD

if [ -z "$1" ]
then
    echo -n "Download redpitaya ubuntu OS. "
    wget -N http://downloads.redpitaya.com/downloads/LinuxOS/$RP_UBUNTU
else
    echo "Set ubuntu OS from parameter $1"
    RP_UBUNTU=$1
fi

RP_UBUNTU=$(pwd)/$RP_UBUNTU

echo -n "Check redpitaya ubuntu OS. "
if [[ -f "$RP_UBUNTU" ]]
        chown root:root $RP_UBUNTU
        chmod 664 $RP_UBUNTU
then
print_ok
else
print_fail
exit 1
fi

cd $BD


if [[ -f "$SCHROOT_CONF_PATH" ]]
then
echo "File $SCHROOT_CONF_PATH is exists"
sudo rm -f $SCHROOT_CONF_PATH
echo "File $SCHROOT_CONF_PATH is deleted"
fi

sleep 1
echo  "Write new configuration"
echo
echo  "[red-pitaya-ubuntu]"      | sudo tee -a $SCHROOT_CONF_PATH
echo  "description=Red pitaya"   | sudo tee -a $SCHROOT_CONF_PATH
echo  "type=file"                | sudo tee -a $SCHROOT_CONF_PATH
echo  "file=$RP_UBUNTU"          | sudo tee -a $SCHROOT_CONF_PATH
echo  "users=root"               | sudo tee -a $SCHROOT_CONF_PATH
echo  "root-users=root"          | sudo tee -a $SCHROOT_CONF_PATH
echo  "root-groups=root"         | sudo tee -a $SCHROOT_CONF_PATH
echo  "personality=linux"        | sudo tee -a $SCHROOT_CONF_PATH
echo  "preserve-environment=true"| sudo tee -a $SCHROOT_CONF_PATH
if [[ $? = 0 ]]
then
echo
echo -n "Complete write new configuration "
print_ok
echo
else
echo -n "Complete write new configuration "
print_fail
exit 1
fi

schroot -c red-pitaya-ubuntu <<- EOL_CHROOT

curl -L https://github.com/RedPitaya/linux-xlnx/archive/branch-redpitaya-v2024.1.tar.gz -o ./kernel.tar.gz
tar -zxf ./kernel.tar.gz --strip-components=1 --directory=./
rm ./kernel.tar.gz
make KCFLAGS="-O2 -march=armv7-a -mtune=cortex-a9" ARCH=arm redpitaya_zynq_defconfig
make KCFLAGS="-O2 -march=armv7-a -mtune=cortex-a9" ARCH=arm modules  -j$(nproc)
cd ..
zip -r ./modules.zip $BD -x *.c *.o

EOL_CHROOT
