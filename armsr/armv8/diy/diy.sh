#!/bin/bash
set -euo pipefail

# Use the matching core, LuCI app and toolchain pins from a published Honk release.
honk_tag=${1:?Honk release tag required}
git clone --branch "$honk_tag" --single-branch --depth=1 https://github.com/QiuSimons/luci-app-honk clone/honk
git clone https://github.com/ophub/luci-app-amlogic --single-branch --depth=1 clone/amlogic
git clone https://github.com/daeuniverse/openwrt-packages --single-branch --depth=1 clone/daepkg
mkdir -p package/custom
cp -a clone/honk/honk clone/honk/luci-app-honk package/custom/
cp -a clone/amlogic/luci-app-amlogic clone/daepkg/vmlinux-btf-builtin package/custom/
sed -i '/luci-app-attendedsysupgrade/d' feeds/luci/collections/luci/Makefile

# The N1 feed list already points at the release used for this build.
sed -i '/^apk_mirror=/,$d' package/emortal/default-settings/files/99-default-settings-chinese
printf '\nexit 0\n' >> package/emortal/default-settings/files/99-default-settings-chinese
rm -rf clone
