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
