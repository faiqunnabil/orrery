#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"

usage() {
	cat <<'USAGE'
Usage: tools/package_release.sh <version>

Packages builds/windows/Orrery.exe and builds/linux/Orrery.x86_64, exported by
build.sh, into dist/ as a Windows zip and a Linux tar.gz. Both archives include
the project license and the third-party license register. SHA256SUMS.txt lists
the checksums of both archives. Requires zip, tar, and sha256sum.
USAGE
}

if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
	usage
	[[ $# -eq 1 ]] && exit 0
	exit 1
fi

VERSION="$1"
for tool in zip tar sha256sum; do
	if ! command -v "$tool" > /dev/null 2>&1; then
		echo "Error: '$tool' not found in PATH." >&2
		exit 1
	fi
done
for build in "$ROOT/builds/windows/Orrery.exe" "$ROOT/builds/linux/Orrery.x86_64"; do
	if [[ ! -f "$build" ]]; then
		echo "Error: $build is missing. Run ./build.sh first." >&2
		exit 1
	fi
done

rm -rf "$DIST"
mkdir -p "$DIST"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

stage() {
	local name="$1"
	local binary="$2"
	mkdir -p "$STAGE/$name"
	cp "$binary" "$STAGE/$name/"
	cp "$ROOT/LICENSE" "$STAGE/$name/LICENSE"
	cp "$ROOT/assets/LICENSES.md" "$STAGE/$name/THIRD_PARTY_LICENSES.md"
}

WINDOWS="Orrery-$VERSION-windows-x86_64"
stage "$WINDOWS" "$ROOT/builds/windows/Orrery.exe"
(cd "$STAGE" && zip -q -9 -r "$DIST/$WINDOWS.zip" "$WINDOWS")

LINUX="Orrery-$VERSION-linux-x86_64"
stage "$LINUX" "$ROOT/builds/linux/Orrery.x86_64"
chmod 755 "$STAGE/$LINUX/Orrery.x86_64"
chmod 644 "$STAGE/$LINUX/LICENSE" "$STAGE/$LINUX/THIRD_PARTY_LICENSES.md"
tar -C "$STAGE" --owner=0 --group=0 --numeric-owner -czf "$DIST/$LINUX.tar.gz" "$LINUX"

(cd "$DIST" && sha256sum "$WINDOWS.zip" "$LINUX.tar.gz" > SHA256SUMS.txt)
ls -l "$DIST"
