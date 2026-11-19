#!/usr/bin/env bash
set -euo pipefail

version=${1:?ImmortalWrt release required}
source=${2:?N1 configuration directory required}
output=${3:?OpenWrt filesystem overlay required}
repair=${4:?Migration script destination required}

[[ $version =~ ^25\.12\.[0-9]+$ ]]
[[ $GITHUB_REPOSITORY =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]
feeds="$output/etc/apk/repositories.d"
mkdir -p "$feeds"
sed "s/@VERSION@/$version/g" "$source/distfeeds.list.in" > "$feeds/distfeeds.list"
printf '%s\n' "https://raw.githubusercontent.com/$GITHUB_REPOSITORY/honk-feed/aarch64_generic/packages.adb" \
	> "$feeds/n1-honk.list"

# Render a standalone migration script with the same URLs and public key as the image.
sed "s/@VERSION@/$version/g" "$source/repair-apk-sources.sh.in" |
	sed -e "/^@DISTFEEDS@$/ {r $feeds/distfeeds.list" -e 'd;}' \
	    -e "/^@HONK_FEED@$/ {r $feeds/n1-honk.list" -e 'd;}' \
	    -e "/^@PUBLIC_KEY@$/ {r $output/etc/apk/keys/n1-honk.pem" -e 'd;}' > "$repair"
sh -n "$repair"
