#!/bin/sh
source /a5y17lte/a5y17lte.env

sudo zypper in -y kmod
sudo zypper -n in lvm2

echo "Creating loop devices..."
sudo mknod /dev/loop0 -m0660 b 7 0
sudo mknod /dev/loop1 -m0660 b 7 1
sudo mknod /dev/loop2 -m0660 b 7 2
echo $?
ls -lh /dev/loop*

echo "Building Sailfish $RELEASE"

sudo zypper in -y kmod 
sudo mic create fs --arch=$PORT_ARCH \
--tokenmap=ARCH:$PORT_ARCH,RELEASE:$RELEASE,EXTRA_NAME:$EXTRA_NAME \
--record-pkgs=name,url \
--outdir=sfe-$DEVICE-$RELEASE$EXTRA_NAME \
--pack-to=sfe-$DEVICE-$RELEASE$EXTRA_NAME.tar.bz2 \
Jolla-@RELEASE@-$DEVICE-@ARCH@.ks
