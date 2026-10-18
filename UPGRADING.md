# Upgrading the a5y17lte / a7y17lte port to Sailfish OS 5.1.0.11

Target: **Sailfish OS 5.1.0.11 "Pispala"**, the current stable release for all
Jolla-supported devices (released to all on 2026-06-16).
Previous build: **4.5.0.24** (last CI release: 2024.03.27).

Note: 5.2.x ("Finlayson") exists but is currently Jolla Phone only, so it is not
a stable target for community ports yet.

## Why bumping RELEASE alone is not enough

The kickstart pulls device packages from
`https://exynos7880-linux.github.io/repo/@RELEASE@/<device>/`.
That repo only has `4.5.0.16`, `4.5.0.18`, `4.5.0.21` and `4.5.0.24` for these
devices. A 5.1.0.11 image build will fail until `repo/5.1.0.11/a5y17lte` (and
`a7y17lte`) exist. The CI now checks this up front and stops with a clear error.

5.1 also changes the base system a lot (from the 5.1.0.11 release notes):
gcc 10 → 13, glibc 2.30 → 2.41, python 3.8 → 3.11, openssl 1.1 → 3.5
(1.1 kept for compatibility), pulseaudio 14 → 17, systemd-resolved for DNS.
The 2022-era middleware in the 4.5.0.24 repo was built against the old base and
must be rebuilt.

## What to do with each package in repo/4.5.0.24/<device>

| Package group | Action for 5.1.0.11 |
|---|---|
| droid-hal-<device>* (kernel, boot/recovery img, modules, tools) | Reuse. Android-side, not tied to the SFOS version. |
| droid-system-<device>, droid-system-vendor-<device> | Reuse. |
| droid-config-<device>* , droid-hal-version-<device>, patterns-* | Rebuild in a 5.1.0.11 target (`rpm/dhd/helpers/build_packages.sh -c` then `-v`). |
| libhybris*, qt5-qpa-hwcomposer-plugin, mce-plugin-libhybris | Drop the local copies; let them come from `nemo:devel:hw:common` (already in the kickstart), or rebuild in a 5.1 target. Stale local copies would shadow newer ones. |
| pulseaudio-modules-droid*, pulseaudio-modules-droid-hidl | Must rebuild (pulseaudio 17 ABI). |
| droidmedia, gst-droid | Rebuild (`build_packages.sh -g` / droidmedia from the Android tree). |
| sailfish-device-encryption-community*, sailfish-fpd-community, droid-biometry-fp, droid-hwcrypt, droid-fake-crypt, yamuisplash, libsfosdevenc, libargon2, systemd-ask-password-gui | Rebuild in a 5.1 target (openssl 3 / new glibc). |
| community-adaptation-localbuild(-ota) | Rebuild against 5.1.0.11. |

## Steps

1. Install a Platform SDK and add 5.1.0.11 tooling + target:
   `sdk-assistant create SailfishOS-5.1.0.11 <tooling url>` and
   `sdk-assistant create a5y17lte-aarch64 <aarch64 target url>`
   (URLs from releases.sailfishos.org/sdk/targets/).
2. In the HADK tree (`$ANDROID_ROOT`), point `rpm/dhd` and `hybris/droid-configs`
   submodules at current upstream mer-hybris HEAD, then run
   `rpm/dhd/helpers/build_packages.sh` for configs, version, middleware and gst-droid.
3. Copy the resulting RPMs plus the reused droid-hal RPMs into
   `repo/5.1.0.11/a5y17lte/`, run `createrepo_c` there, and push the `repo` Pages site.
   Repeat for a7y17lte.
4. Run the "Build sailfishos Images" workflow (Actions → Run workflow).
   Defaults: release `5.1.0.11`, SDK image `coderus/sailfishos-platform-sdk-base:5.1.0.11`.
   If that image tag does not exist, set `sdk_image` to any Platform SDK image at
   5.1.0.11 or newer.
5. Flash the zip from TWRP and test calls, audio, camera, Wi-Fi, BT, sensors, encryption.

## Existing 4.5 installs (OTA instead of reflashing)

Jolla requires stop releases in order:
4.5.0.25 → 4.6.0.15 → 5.0.0.71 → 5.0.0.78 (hotfix) → 5.1.0.11.
Each step needs an adaptation repo for that version, so a clean reflash of the
5.1.0.11 image is much simpler. Builds are marked as prerelease until tested.

## Android app support (Waydroid)

Jolla's AppSupport (used on Xperia and Jolla devices) is closed and licensed only
for official devices, so community ports use **Waydroid** instead: a full Android
container running on the port's own kernel and hybris stack.

The old repo already has 2022 Waydroid builds in `repo/custom-repo/`
(waydroid 1.3.3, waydroid-gbinder-config-hybris, waydroid-runner,
waydroid-sensors, waydroid-settings, python3-gbinder). They were built for 4.5
(python 3.8) and will not work on 5.1 (python 3.11), so they must be rebuilt.

### 1. Kernel options

Add these to the a5y17lte/a7y17lte defconfig, then rebuild
`droid-hal-<device>-kernel` (`build_packages.sh -d`) and reflash the boot image:

```
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder,anbox-binder,anbox-hwbinder,anbox-vndbinder"
CONFIG_ASHMEM=y
CONFIG_MEMFD_CREATE=y          # may need a backport on an old 3.x kernel
CONFIG_NAMESPACES=y
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y
CONFIG_PID_NS=y
CONFIG_NET_NS=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_FREEZER=y
CONFIG_VETH=y
CONFIG_BRIDGE=y
CONFIG_NETFILTER_XT_TARGET_MASQUERADE=y
CONFIG_NF_NAT_MASQUERADE_IPV4=y
```

The `anbox-*` binder nodes give Waydroid its own binder devices so it does not
fight with the hybris side over `/dev/binder`. If the kernel is older than 4.14,
expect to backport binder fixes. This is the riskiest step; check
`zcat /proc/config.gz | grep -E "BINDER|ASHMEM|_NS="` on the phone after flashing.

### 2. Rebuild the packages for 5.1.0.11

In the 5.1.0.11 aarch64 SDK target, build from their sources (sailfishos-open /
waydroid-sailfish forks) in this order: `libgbinder` (if not already in the
target), `python3-gbinder`, `waydroid`, `waydroid-gbinder-config-hybris`,
`waydroid-runner`, `waydroid-sensors`, `waydroid-settings`. Copy the RPMs to
`repo/5.1.0.11/waydroid/`, run `createrepo_c` there and push the Pages repo.

### 3. Build the image

Local: `WAYDROID=1 RELEASE=5.1.0.11 ./run-mic.sh a5y17lte`
CI: Actions → Build sailfishos Images → Run workflow → tick **waydroid**.
CI then builds both a normal image and a `-waydroid` image per device, so a
broken Waydroid repo never blocks the normal build.

### 4. First boot

```
devel-su
waydroid init            # downloads the LineageOS-based Android image
systemctl enable --now waydroid-container
```
Then start "Waydroid" from the app grid. Expect light apps to run fine; heavy
games will be slow on Exynos 7880 with 3 GB RAM.
