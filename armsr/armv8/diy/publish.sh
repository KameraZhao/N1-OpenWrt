#!/usr/bin/env bash
set -euo pipefail

openwrt=$(realpath "${1:?OpenWrt source directory required}")
output=${2:?Packaged output directory required}
repair=${3:?Migration script required}
apk="$openwrt/staging_dir/host/bin/apk"
tag="OpenWrt_$(date +%Y%m%d)_${GITHUB_RUN_NUMBER}_${GITHUB_RUN_ATTEMPT}"

working=$(mktemp -d)
trap 'rm -rf "$working"' EXIT
mkdir "$working/assets" "$working/keys" "$working/downloaded"
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
# apk 3.0.5 adbsign does not load the old trust directory before reading.
"$apk" --keys-dir "$openwrt" verify "${apks[@]}"
"$apk" --allow-untrusted --sign "$key" adbsign --reset-signatures "${apks[@]}"
"$apk" --keys-dir "$working/keys" verify "${apks[@]}"

# Each index points at complete, versioned release assets. Only the small index
# is kept on the honk-feed branch.
download_url="https://github.com/$GITHUB_REPOSITORY/releases/download/$tag"
index="$working/packages.adb"
"$apk" --keys-dir "$working/keys" --sign "$key" mkndx --output "$index" \
	--pkgname-spec "$download_url/"'${name}.apk' "${apks[@]}"
rm -f "$key"
"$apk" --keys-dir "$working/keys" verify "$index"

cat > "$working/release-notes" <<NOTES
ImmortalWrt ${IMMORTAL_VERSION} · Flippy ${FLIPPY_KERNEL} · ${HONK_TAG}

管理地址 192.168.123.99，IPv4 上游网关 192.168.123.11。
N1 强制提供 DHCPv4。同一网段接入前，请关闭主路由上的 DHCPv4。

旧版 N1 可在设备上运行本 Release 的 repair-apk-sources.sh 接入签名的软件源。
随后可在 LuCI 的系统 → 软件包中更新 Honk，或运行 apk upgrade honk luci-app-honk luci-i18n-honk-zh-cn。
NOTES

gh release create "$tag" "$output"/*.img.gz "$repair" "${apks[@]}" \
	--target "$GITHUB_SHA" --title "$tag" --notes-file "$working/release-notes" --repo "$GITHUB_REPOSITORY"

printf '%s\n' "$index" > "$working/repositories.list"
"$apk" --arch aarch64_generic --keys-dir "$working/keys" --no-cache \
	--repositories-file "$working/repositories.list" fetch --output "$working/downloaded" "${packages[@]}"
"$apk" --keys-dir "$working/keys" verify "$working/downloaded/"*.apk

feed="$working/feed"
git init -q "$feed"
git -C "$feed" remote add origin "https://github.com/$GITHUB_REPOSITORY.git"
if git -C "$feed" ls-remote --exit-code origin refs/heads/honk-feed >/dev/null; then
	git -C "$feed" fetch --depth=1 origin refs/heads/honk-feed
	git -C "$feed" switch -c honk-feed FETCH_HEAD
elif [[ $? == 2 ]]; then
	git -C "$feed" switch --orphan honk-feed
else
	exit 1
fi
mkdir -p "$feed/aarch64_generic"
cp "$index" "$feed/aarch64_generic/packages.adb"
git -C "$feed" add aarch64_generic/packages.adb
git -C "$feed" -c user.name=github-actions -c 'user.email=41898282+github-actions[bot]@users.noreply.github.com' \
	commit -qm "Publish Honk APK index for $tag"
git -C "$feed" -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
	push origin HEAD:refs/heads/honk-feed
