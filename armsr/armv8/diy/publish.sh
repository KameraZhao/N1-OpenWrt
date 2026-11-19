#!/usr/bin/env bash
set -euo pipefail

openwrt=$(realpath "${1:?OpenWrt source directory required}")
output=${2:?Packaged output directory required}
repair=${3:?Migration script required}
apk="$openwrt/staging_dir/host/bin/apk"
tag="OpenWrt_$(date +%Y%m%d)_${GITHUB_RUN_NUMBER}_${GITHUB_RUN_ATTEMPT}"

working=$(mktemp -d)
trap 'rm -rf "$working"' EXIT
mkdir "$working/assets" "$working/keys"
public_key="$openwrt/files/etc/apk/keys/n1-honk.pem"
cp "$public_key" "$working/keys/"
key="$working/key.pem"
(umask 077; printf '%s\n' "${HONK_APK_SIGNING_KEY:?Configure the Honk APK signing secret}" > "$key")
unset HONK_APK_SIGNING_KEY
openssl pkey -in "$key" -pubout | diff - "$public_key"

packages=(honk luci-app-honk luci-i18n-honk-zh-cn)
apks=()
for package in "${packages[@]}"; do
	mapfile -t matches < <(find "$openwrt/bin/targets/armsr/armv8/packages" \
		"$openwrt/bin/packages/aarch64_generic" -type f -name "$package-[0-9]*.apk")
	if (( ${#matches[@]} != 1 )); then
		echo "Expected exactly one build of $package, found ${#matches[@]}" >&2
		exit 1
	fi
	apk_file="$working/assets/$package.apk"
	cp "${matches[0]}" "$apk_file"
	apks+=("$apk_file")
done
# OpenWrt build output APKs use the build index for integrity. Sign these local
# build outputs for download and use one adbsign invocation per APK on 3.0.5.
for apk_file in "${apks[@]}"; do
	"$apk" --allow-untrusted --sign "$key" adbsign --reset-signatures "$apk_file"
done
"$apk" --keys-dir "$working/keys" verify "${apks[@]}"
"$apk" --keys-dir "$working/keys" adbdump --format json "$working/assets/luci-i18n-honk-zh-cn.apk" |
	jq -e '.info.version != null and .info.version != "0"' >/dev/null

cat > "$working/release-notes" <<NOTES
ImmortalWrt ${IMMORTAL_VERSION} · Flippy ${FLIPPY_KERNEL} · ${HONK_TAG}

管理地址 192.168.123.99，IPv4 上游网关 192.168.123.11。
N1 强制提供 DHCPv4。同一网段接入前，请关闭主路由上的 DHCPv4。

旧版 N1 可在设备上运行本 Release 的 repair-apk-sources.sh 接入签名的软件源。
随后可在 LuCI 的系统 → 软件包中更新 Honk，或运行 apk upgrade honk luci-app-honk luci-i18n-honk-zh-cn。
NOTES

gh release create "$tag" "$output"/*.img.gz "$repair" "${apks[@]}" \
	--target "$GITHUB_SHA" --title "$tag" --notes-file "$working/release-notes" --repo "$GITHUB_REPOSITORY"

bash "$(dirname "$0")/publish-honk-feed.sh" "$apk" "$working/assets" "$key" "$tag"
