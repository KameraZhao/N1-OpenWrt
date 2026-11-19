#!/usr/bin/env bash
set -euo pipefail

apk=$(realpath "${1:?APK executable required}")
assets=$(realpath "${2:?Signed APK directory required}")
key=$(realpath "${3:?APK signing key required}")
release=${4:?Release tag required}
public_key="$(dirname "$0")/../N1/files/etc/apk/keys/n1-honk.pem"
working=$(mktemp -d)
trap 'rm -rf "$working"' EXIT
mkdir "$working/keys" "$working/downloaded"
cp "$public_key" "$working/keys/"
openssl pkey -in "$key" -pubout | diff - "$public_key"

packages=(honk luci-app-honk luci-i18n-honk-zh-cn)
apk_files=()
for package in "${packages[@]}"; do
	apk_files+=("$assets/$package.apk")
done
"$apk" --keys-dir "$working/keys" verify "${apk_files[@]}"

feed="$working/feed"
git init -q "$feed"
git -C "$feed" remote add origin "https://github.com/$GITHUB_REPOSITORY.git"
git -C "$feed" config user.name github-actions
git -C "$feed" config user.email '41898282+github-actions[bot]@users.noreply.github.com'
if git -C "$feed" ls-remote --exit-code origin refs/heads/honk-feed >/dev/null; then
	git -C "$feed" fetch --depth=1 origin refs/heads/honk-feed
	git -C "$feed" switch -c honk-feed FETCH_HEAD
elif [[ $? == 2 ]]; then
	git -C "$feed" switch --orphan honk-feed
else
	exit 1
fi

publish() {
	git -C "$feed" -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
		push origin HEAD:refs/heads/honk-feed
}

# Publish complete files before changing the index. An older cached index can
# still fetch its exact packages because the URLs include the commit SHA.
mkdir -p "$feed/aarch64_generic"
cp "${apk_files[@]}" "$feed/aarch64_generic/"
git -C "$feed" add aarch64_generic/*.apk
if ! git -C "$feed" diff --cached --quiet; then
	git -C "$feed" commit -qm "Stage signed Honk APKs from $release"
	publish
fi
revision=$(git -C "$feed" rev-parse HEAD)
package_url="https://raw.githubusercontent.com/$GITHUB_REPOSITORY/$revision/aarch64_generic"
index="$working/packages.adb"
"$apk" --keys-dir "$working/keys" --sign "$key" mkndx --output "$index" \
	--pkgname-spec "$package_url/"'${name}.apk' "${apk_files[@]}"
"$apk" --keys-dir "$working/keys" verify "$index"

printf '%s\n' "$index" > "$working/repositories.list"
"$apk" --arch aarch64_generic --keys-dir "$working/keys" --no-cache \
	--repositories-file "$working/repositories.list" fetch --output "$working/downloaded" "${packages[@]}"
"$apk" --keys-dir "$working/keys" verify "$working/downloaded/"*.apk

cp "$index" "$feed/aarch64_generic/packages.adb"
git -C "$feed" add aarch64_generic/packages.adb
git -C "$feed" commit -qm "Publish Honk APK index for $release"
publish
