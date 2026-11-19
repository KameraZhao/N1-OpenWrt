#!/usr/bin/env bash
set -euo pipefail

image=${1:?N1 image required}
overlay=${2:?OpenWrt overlay required}
apk=${3:?Path to the OpenWrt host apk required}
working=$(mktemp -d)
loop=
cleanup() {
	if mountpoint -q "$working/root"; then
		sudo umount "$working/root"
	fi
	if [[ -n $loop ]]; then
		sudo losetup -d "$loop"
	fi
	sudo rm -rf "$working"
}
trap cleanup EXIT

mkdir "$working/root" "$working/apk-root"
gzip -dc "$image" > "$working/n1.img"
loop=$(sudo losetup --find --show --partscan --read-only "$working/n1.img")
sudo mount -o ro "${loop}p2" "$working/root"

for file in etc/config/network etc/config/dhcp etc/config/firewall \
	etc/apk/repositories.d/distfeeds.list etc/apk/repositories.d/n1-honk.list \
	etc/apk/keys/n1-honk.pem; do
	sudo diff -u "$overlay/$file" "$working/root/$file"
done

# Use the final image's package database and trust keys, leaving the image read-only.
sudo cp -a "$working/root/." "$working/apk-root/"
official="$working/apk-root/etc/apk/repositories.d/distfeeds.list"
sudo "$apk" --root "$working/apk-root" --repositories-file "$official" update
sudo "$apk" --root "$working/apk-root" --repositories-file "$official" --no-scripts add tree
sudo "$apk" --root "$working/apk-root" info --installed tree
