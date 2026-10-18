# a5y17lte-ci

Sailfish OS image builds for Samsung Galaxy A5 2017 (a5y17lte) and A7 2017 (a7y17lte).
Current target: Sailfish OS 5.1.0.11. See [UPGRADING.md](UPGRADING.md).

Local build inside a Platform SDK: `RELEASE=5.1.0.11 ./run-mic.sh a5y17lte`
With Android app support (Waydroid): `WAYDROID=1 RELEASE=5.1.0.11 ./run-mic.sh a5y17lte`

Images register the community repo (`https://exynos7880-linux.github.io/repo/<release>/<device>/`)
in ssu, so phones get device updates from it. `ADAPTATION_REPO=<url>` builds from another
repo and also points the phone at it; `DEVICE_REPO=<url>` sets only the phone's repo.
On a5y17lte, Android App Support is installed from that repo with
`devel-su pkcon install a5y17lte-android-support` (then open **Android**).
