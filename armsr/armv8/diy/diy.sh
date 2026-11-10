#!/bin/bash
set -euo pipefail

# Keep the Honk package and its pinned core/toolchain together.
git clone https://github.com/QiuSimons/luci-app-honk clone/honk
git -C clone/honk checkout 9936045ac52ca46a48f57f86fae1af8fa0e9134b
git clone https://github.com/ophub/luci-app-amlogic --single-branch --depth=1 clone/amlogic
git clone https://github.com/daeuniverse/openwrt-packages --single-branch --depth=1 clone/daepkg
mkdir -p package/custom
cp -a clone/honk/honk clone/honk/luci-app-honk package/custom/
cp -a clone/amlogic/luci-app-amlogic feeds/luci/applications/
cp -a clone/daepkg/vmlinux-btf-builtin feeds/packages/net/
sed -i '/luci-app-attendedsysupgrade/d' feeds/luci/collections/luci/Makefile
rm -rf clone
