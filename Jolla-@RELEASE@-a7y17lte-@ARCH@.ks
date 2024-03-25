# DisplayName: Jolla a7y17lte/@ARCH@ (release) 1
# KickstartType: release
# DeviceModel: a7y17lte
# DeviceVariant: a7y17lte
# Brand: Jolla
# SuggestedImageType: fs
# SuggestedArchitecture: aarch64

timezone --utc UTC

### Commands from /tmp/sandbox/usr/share/ssu/kickstart/part/default
part / --size 500 --ondisk sda --fstype=ext4

## No suitable configuration found in /tmp/sandbox/usr/share/ssu/kickstart/bootloader

repo --name=adaptation-common-a7y17lte-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/jolla-hw/adaptation-common/@ARCH@/
repo --name=adaptation-community-a7y17lte-@RELEASE@ --baseurl=https://exynos7880-linux.github.io/repo/@RELEASE@/
repo --name=adaptation-community-common-a7y17lte-@RELEASE@ --baseurl=https://repo.sailfishos.org/obs/nemo:/devel:/hw:/common/sailfish_latest_@ARCH@/
repo --name=apps-@RELEASE@ --baseurl=https://releases.jolla.com/jolla-apps/@RELEASE@/@ARCH@/
repo --name=customer-jolla-@RELEASE@ --baseurl=https://releases.jolla.com/features/@RELEASE@/customers/jolla/@ARCH@/
repo --name=hotfixes-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/hotfixes/@ARCH@/
repo --name=jolla-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/jolla/@ARCH@/

%packages
patterns-sailfish-device-configuration-a7y17lte
%end

%attachment
### Commands from /tmp/sandbox/usr/share/ssu/kickstart/attachment/a7y17lte
/boot/hybris-boot.img
/boot/hybris-updater-script
/boot/hybris-updater-unpack.sh
/boot/update-binary

%end

%pre --erroronfail
export SSU_RELEASE_TYPE=release
### begin 01_init
touch $INSTALL_ROOT/.bootstrap
### end 01_init
%end

%post --erroronfail
export SSU_RELEASE_TYPE=release
### begin 01_arch-hack
if [ "@ARCH@" == armv7hl ] || [ "@ARCH@" == armv7tnhl ] || [ "@ARCH@" == aarch64 ]; then
    # Without this line the rpm does not get the architecture right.
    echo -n "@ARCH@-meego-linux" > /etc/rpm/platform

    # Also libzypp has problems in autodetecting the architecture so we force tha as well.
    # https://bugs.meego.com/show_bug.cgi?id=11484
    echo "arch = @ARCH@" >> /etc/zypp/zypp.conf
fi
### end 01_arch-hack
### begin 01_rpm-rebuilddb
# Rebuild db using target's rpm
echo -n "Rebuilding db using target rpm.."
rm -f /var/lib/rpm/__db*
rpm --rebuilddb
echo "done"
### end 01_rpm-rebuilddb
### begin 50_oneshot
# exit boostrap mode
rm -f /.bootstrap

# export some important variables until there's a better solution
export LANG=en_US.UTF-8
export LC_COLLATE=en_US.UTF-8

# run the oneshot triggers for root and first user uid
UID_MIN=$(grep "^UID_MIN" /etc/login.defs |  tr -s " " | cut -d " " -f2)
DEVICEUSER=`getent passwd $UID_MIN | sed 's/:.*//'`

if [ -x /usr/bin/oneshot ]; then
   /usr/bin/oneshot --mic
   su -c "/usr/bin/oneshot --mic" $DEVICEUSER
fi
### end 50_oneshot
### begin 60_ssu
if [ "$SSU_RELEASE_TYPE" = "rnd" ]; then
    [ -n "@RNDRELEASE@" ] && ssu release -r @RNDRELEASE@
    [ -n "@RNDFLAVOUR@" ] && ssu flavour @RNDFLAVOUR@
    # RELEASE is reused in RND setups with parallel release structures
    # this makes sure that an image created from such a structure updates from there
    [ -n "@RELEASE@" ] && ssu set update-version @RELEASE@
    ssu mode 2
else
    [ -n "@RELEASE@" ] && ssu release @RELEASE@
    ssu mode 4
fi
### end 60_ssu
### begin 70_sdk-domain

export SSU_DOMAIN=@RNDFLAVOUR@

if [ "$SSU_RELEASE_TYPE" = "release" ] && [[ "$SSU_DOMAIN" = "public-sdk" ]];
then
    ssu domain sailfish
fi
### end 70_sdk-domain
### begin 90_accept_unsigned_packages
sed -i /etc/zypp/zypp.conf \
    -e '/^# pkg_gpgcheck =/ c \
# Modified by kickstart. See sdk-configs sources\
pkg_gpgcheck = off
'
### end 90_accept_unsigned_packages
### begin 90_zypper_skip_check_access_deleted
sed -i /etc/zypp/zypper.conf \
    -e '/^# *psCheckAccessDeleted =/ c \
# Modified by kickstart. See sdk-configs sources\
psCheckAccessDeleted = no
'
### end 90_zypper_skip_check_access_deleted
%end

%post --nochroot --erroronfail
export SSU_RELEASE_TYPE=release
### begin 50_os-release
(
CUSTOMERS=$(find $INSTALL_ROOT/usr/share/ssu/features.d -name 'customer-*.ini' \
    |xargs --no-run-if-empty sed -n 's/^name[[:space:]]*=[[:space:]]*//p')

cat $INSTALL_ROOT/etc/os-release
echo "SAILFISH_CUSTOMER=\"${CUSTOMERS//$'\n'/ }\""
) > $IMG_OUT_DIR/os-release
### end 50_os-release
### begin 99_check_shadow
IS_BAD=0

echo "Checking that no user has password set in /etc/shadow."
# This grep prints users that have password set, normally nothing
if grep -vE '^[^:]+:[*!]{1,2}:' $INSTALL_ROOT/etc/shadow
then
    echo "A USER HAS PASSWORD SET! THE IMAGE IS NOT SAFE!"
    IS_BAD=1
fi

# Checking that all users use shadow in passwd,
# if they weren't the check above would be useless
if grep -vE '^[^:]+:x:' $INSTALL_ROOT/etc/passwd
then
    echo "BAD PASSWORD IN /etc/passwd! THE IMAGE IS NOT SAFE!"
    IS_BAD=1
fi

# Fail image build if checks fail
[ $IS_BAD -eq 0 ] && echo "No passwords set, good." || exit 1
### end 99_check_shadow
%end

%pack --erroronfail
export SSU_RELEASE_TYPE=release
### begin hybris
pushd $IMG_OUT_DIR

DEVICE=a7y17lte

VERSION_FILE=./os-release
source $VERSION_FILE

# Locate rootfs tar.bz2 archive.
for filename in *.tar.bz2; do
    GEN_IMG_BASE=$(basename $filename .tar.bz2)
done

if [ ! -e "$GEN_IMG_BASE.tar.bz2" ]; then
    echo "No rootfs archive found, exiting ..."
    exit 1
fi

# Output filenames
DST_IMG_BASE=$ID-$DEVICE-$SAILFISH_FLAVOUR-$VERSION_ID@EXTRA_NAME@
DST_IMG=$DST_IMG_BASE.tar.bz2


# extracting $GEN_IMG_BASE.tar.bz2 to rootfs.img
mkdir data
mkdir rootfs

truncate -s3G data/rootfs.img
/sbin/mke2fs -t ext4 data/rootfs.img
mount -o loop data/rootfs.img rootfs
tar --numeric-owner -xjf "$GEN_IMG_BASE.tar.bz2" -C rootfs
umount rootfs
rm -rf rootfs
rm $GEN_IMG_BASE.tar.bz2

DST_IMG=data/rootfs.img

IMG_SIZE=$(du -h $DST_IMG | cut -f1)

# Copy boot image, updater scripts and updater binary into updater .zip tree.
mkdir -p updater/META-INF/com/google/android
mkdir -p updater/data

mv update-binary updater/META-INF/com/google/android/update-binary
mv hybris-updater-script updater/META-INF/com/google/android/updater-script

cat <<'EOF' >> updater/updater-unpack.sh
#! /sbin/sh

IMG_DIR="/data/.stowaways/images"

rm -rf $IMG_DIR
rm -rf /data/.stowaways
mkdir -p $IMG_DIR
mkdir -p /data/.stowaways/sailfishos

mv /data/rootfs.img $IMG_DIR/rootfs.img
e2fsck -fy $IMG_DIR/rootfs.img
resize2fs $IMG_DIR/rootfs.img 8G

EXIT=$?

exit $EXIT
EOF

mv hybris-boot.img updater/hybris-boot.img
mv data/rootfs.img updater/data/rootfs.img

# Update updater-script with image details.
sed -i -e "s %VERSION% $VERSION_ID g" -e "s %IMAGE_FILE% $DST_IMG g" -e "s %IMAGE_SIZE% $IMG_SIZE g" updater/META-INF/com/google/android/updater-script

# pack updater .zip
pushd updater
zip -r ../$DST_IMG_BASE.zip META-INF/com/google/android/update-binary META-INF/com/google/android/updater-script updater-unpack.sh hybris-boot.img $DST_IMG_BASE.ks data/rootfs.img
popd # updater

# Clean up updater .zip working directory.
rm -rf updater
rm -rf data

popd # $IMG_OUT_DIR
### end hybris
%end

