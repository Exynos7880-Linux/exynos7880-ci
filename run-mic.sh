#!/bin/sh
# Build a Sailfish OS image for one Exynos7880 device.
# Usage: ./run-mic.sh [a5y17lte|a7y17lte]   (default: a5y17lte)
# RELEASE can be overridden from the environment, e.g. RELEASE=5.1.0.11
# WAYDROID=1 adds Android app support (Waydroid) to the image.
# ADAPTATION_REPO overrides the community adaptation repo, e.g. a local build:
#   ADAPTATION_REPO=file://$HOME/sfos/repo/5.1.0.11/a5y17lte/ ./run-mic.sh a5y17lte
# WAYDROID_REPO likewise overrides the Waydroid repo (used with WAYDROID=1).
# DEVICE_REPO is the repo the installed phone gets updates from (ssu). It defaults to
# ADAPTATION_REPO, or to the community repo when ADAPTATION_REPO is a local file:// one.
set -e

WAYDROID="${WAYDROID:-0}"
WAYDROID_PKGS="waydroid waydroid-gbinder-config-hybris waydroid-runner waydroid-sensors waydroid-settings python3-gbinder"


DEVICE_ARG="${1:-a5y17lte}"
WORKDIR="$(cd "$(dirname "$0")" && pwd)"
. "$WORKDIR/$DEVICE_ARG.env"

echo "Device:  $DEVICE"
echo "Release: $RELEASE"
echo "Waydroid: $WAYDROID"

ADAPTATION_REPO="${ADAPTATION_REPO:-https://exynos7880-linux.github.io/repo/$RELEASE/$DEVICE/}"
echo "Adaptation repo: $ADAPTATION_REPO"
DEFAULT_DEVICE_REPO="https://exynos7880-linux.github.io/repo/$RELEASE/$DEVICE/"
case "$ADAPTATION_REPO" in
file://*) DEVICE_REPO="${DEVICE_REPO:-$DEFAULT_DEVICE_REPO}" ;;
*)        DEVICE_REPO="${DEVICE_REPO:-$ADAPTATION_REPO}" ;;
esac
echo "Device repo on the phone: $DEVICE_REPO"
WAYDROID_REPO="${WAYDROID_REPO:-https://exynos7880-linux.github.io/repo/$RELEASE/waydroid/}"
[ "$WAYDROID" = "1" ] && echo "Waydroid repo: $WAYDROID_REPO"

# Fail early if the community adaptation repo has no packages for this release.
ADAPT_URL="${ADAPTATION_REPO%/}/repodata/repomd.xml"
case "$ADAPT_URL" in
file://*)
    if [ ! -f "${ADAPT_URL#file://}" ]; then
        echo "ERROR: no repodata at ${ADAPT_URL#file://} (run createrepo_c there first)"
        exit 1
    fi
    ;;
esac
if command -v curl >/dev/null 2>&1; then
    if [ "${ADAPT_URL#file://}" = "$ADAPT_URL" ] && ! curl -sfI "$ADAPT_URL" >/dev/null; then
        echo "ERROR: no adaptation repo for $RELEASE at $ADAPT_URL"
        echo "Rebuild and publish the $DEVICE adaptation for $RELEASE first (see UPGRADING.md)."
        exit 1
    fi
    if [ "$WAYDROID" = "1" ]; then
        WD_URL="${WAYDROID_REPO%/}/repodata/repomd.xml"
        if [ "${WD_URL#file://}" != "$WD_URL" ]; then
            [ -f "${WD_URL#file://}" ] || { echo "ERROR: no repodata at ${WD_URL#file://}"; exit 1; }
        elif ! curl -sfI "$WD_URL" >/dev/null; then
            echo "ERROR: WAYDROID=1 but no Waydroid repo for $RELEASE at $WD_URL"
            echo "Rebuild the Waydroid packages for $RELEASE first (see UPGRADING.md)."
            exit 1
        fi
    fi
fi

# 106 = some repos skipped (e.g. an unreadable ssu adaptation repo in the Platform SDK)
sudo zypper -n in kmod lvm2 || [ $? -eq 106 ]

echo "Creating loop devices..."
for i in 0 1 2; do
    [ -e /dev/loop$i ] || sudo mknod /dev/loop$i -m0660 b 7 $i
done
ls -lh /dev/loop*

echo "Building Sailfish $RELEASE for $DEVICE"
cd "$WORKDIR"

KS="Jolla-@RELEASE@-$DEVICE-@ARCH@.ks"
if [ "$ADAPTATION_REPO" != "$DEFAULT_DEVICE_REPO" ] || [ "$DEVICE_REPO" != "$DEFAULT_DEVICE_REPO" ]; then
    # Build from ADAPTATION_REPO and point the phone's ssu repo at DEVICE_REPO.
    LOCAL_KS="Jolla-@RELEASE@-$DEVICE-local-@ARCH@.ks"
    sed -e "s#^\(repo --name=adaptation-community-$DEVICE-@RELEASE@ --baseurl=\).*#\1$ADAPTATION_REPO#" \
        -e "s#^\(ssu ar adaptation-community-$DEVICE \).*#\1$DEVICE_REPO#" "$KS" > "$LOCAL_KS"
    grep -q "baseurl=$ADAPTATION_REPO" "$LOCAL_KS" || { echo "ERROR: could not set adaptation repo in $LOCAL_KS"; exit 1; }
    grep -q "^ssu ar adaptation-community-$DEVICE $DEVICE_REPO\$" "$LOCAL_KS" || { echo "ERROR: could not set device repo in $LOCAL_KS"; exit 1; }
    KS="$LOCAL_KS"
fi
if [ "$WAYDROID" = "1" ]; then
    # Make a Waydroid variant of the kickstart: extra repo + extra packages.
    WD_KS="Jolla-@RELEASE@-$DEVICE-waydroid-@ARCH@.ks"
    awk -v pkgs="$WAYDROID_PKGS" -v wdrepo="$WAYDROID_REPO" '
        { print }
        /^repo --name=jolla-@RELEASE@ / {
            print "repo --name=waydroid-@RELEASE@ --baseurl=" wdrepo
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
