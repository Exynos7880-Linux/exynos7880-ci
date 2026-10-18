#!/bin/sh
# Build a Sailfish OS image for one Exynos7880 device.
# Usage: ./run-mic.sh [a5y17lte|a7y17lte]   (default: a5y17lte)
# RELEASE can be overridden from the environment, e.g. RELEASE=5.1.0.11
# WAYDROID=1 adds Android app support (Waydroid) to the image.
set -e

WAYDROID="${WAYDROID:-0}"
WAYDROID_PKGS="waydroid waydroid-gbinder-config-hybris waydroid-runner waydroid-sensors waydroid-settings python3-gbinder"


DEVICE_ARG="${1:-a5y17lte}"
WORKDIR="$(cd "$(dirname "$0")" && pwd)"
. "$WORKDIR/$DEVICE_ARG.env"

echo "Device:  $DEVICE"
echo "Release: $RELEASE"
echo "Waydroid: $WAYDROID"

# Fail early if the community adaptation repo has no packages for this release.
ADAPT_URL="https://exynos7880-linux.github.io/repo/$RELEASE/$DEVICE/repodata/repomd.xml"
if command -v curl >/dev/null 2>&1; then
    if ! curl -sfI "$ADAPT_URL" >/dev/null; then
        echo "ERROR: no adaptation repo for $RELEASE at $ADAPT_URL"
        echo "Rebuild and publish the $DEVICE adaptation for $RELEASE first (see UPGRADING.md)."
        exit 1
    fi
    if [ "$WAYDROID" = "1" ]; then
        WD_URL="https://exynos7880-linux.github.io/repo/$RELEASE/waydroid/repodata/repomd.xml"
        if ! curl -sfI "$WD_URL" >/dev/null; then
            echo "ERROR: WAYDROID=1 but no Waydroid repo for $RELEASE at $WD_URL"
            echo "Rebuild the Waydroid packages for $RELEASE first (see UPGRADING.md)."
            exit 1
        fi
    fi
fi

sudo zypper -n in kmod lvm2

echo "Creating loop devices..."
for i in 0 1 2; do
    [ -e /dev/loop$i ] || sudo mknod /dev/loop$i -m0660 b 7 $i
done
ls -lh /dev/loop*

echo "Building Sailfish $RELEASE for $DEVICE"
cd "$WORKDIR"

KS="Jolla-@RELEASE@-$DEVICE-@ARCH@.ks"
if [ "$WAYDROID" = "1" ]; then
    # Make a Waydroid variant of the kickstart: extra repo + extra packages.
    WD_KS="Jolla-@RELEASE@-$DEVICE-waydroid-@ARCH@.ks"
    awk -v pkgs="$WAYDROID_PKGS" '
        { print }
        /^repo --name=jolla-@RELEASE@ / {
            print "repo --name=waydroid-@RELEASE@ --baseurl=https://exynos7880-linux.github.io/repo/@RELEASE@/waydroid/"
        }
        /^%packages/ { n = split(pkgs, a, " "); for (i = 1; i <= n; i++) print a[i] }
    ' "$KS" > "$WD_KS"
    KS="$WD_KS"
    EXTRA_NAME="$EXTRA_NAME-waydroid"
fi

sudo mic create fs --arch="$PORT_ARCH" \
    --tokenmap=ARCH:$PORT_ARCH,RELEASE:$RELEASE,EXTRA_NAME:$EXTRA_NAME \
    --record-pkgs=name,url \
    --outdir="sfe-$DEVICE-$RELEASE$EXTRA_NAME" \
    --pack-to="sfe-$DEVICE-$RELEASE$EXTRA_NAME.tar.bz2" \
    "$KS"
