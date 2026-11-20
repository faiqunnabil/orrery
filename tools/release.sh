#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/godot/project.godot"
PRESETS="$ROOT/godot/export_presets.cfg"

usage() {
	cat <<'USAGE'
Usage:
  tools/release.sh bump <version>   On dev: set the version and commit "chore: release <version>"
  tools/release.sh tag <version>    On main after the release PR is merged: tag v<version> and push it

Releasing takes three steps:
  1. tools/release.sh bump 1.1.0, then push dev and merge it into main through a pull request
  2. git checkout main && git pull
  3. tools/release.sh tag 1.1.0, which pushes the tag after you confirm

Pushing the tag starts the Release workflow, which exports both builds and publishes them.
USAGE
}

fail() {
	echo "Error: $1" >&2
	exit 1
}

project_version() {
	sed -n 's/^config\/version="\(.*\)"$/\1/p' "$PROJECT"
}

require_clean_tree() {
	[[ -z "$(git -C "$ROOT" status --porcelain)" ]] || fail "the working tree has uncommitted changes"
}

bump() {
	local version="$1"
	[[ "$(git -C "$ROOT" branch --show-current)" == "dev" ]] || fail "bump runs on the dev branch"
	require_clean_tree
	[[ "$(project_version)" != "$version" ]] || fail "the project is already at version $version"
	sed -i "s/^config\/version=\".*\"$/config\/version=\"$version\"/" "$PROJECT"
	sed -i "s/^application\/file_version=\".*\"$/application\/file_version=\"$version.0\"/" "$PRESETS"
	sed -i "s/^application\/product_version=\".*\"$/application\/product_version=\"$version.0\"/" "$PRESETS"
	[[ "$(project_version)" == "$version" ]] || fail "could not update $PROJECT"
	git -C "$ROOT" add "$PROJECT" "$PRESETS"
	git -C "$ROOT" commit -q -m "chore: release $version"
	echo "Committed version $version on dev. Push dev and merge it into main, then run: tools/release.sh tag $version"
}

tag() {
	local version="$1"
	local name="v$version"
	[[ "$(git -C "$ROOT" branch --show-current)" == "main" ]] || fail "tag runs on the main branch"
	require_clean_tree
	git -C "$ROOT" fetch -q origin main --tags
	[[ "$(git -C "$ROOT" rev-parse HEAD)" == "$(git -C "$ROOT" rev-parse origin/main)" ]] || fail "main is not in sync with origin/main"
	[[ "$(project_version)" == "$version" ]] || fail "main is at version $(project_version), not $version"
	! git -C "$ROOT" rev-parse -q --verify "refs/tags/$name" > /dev/null || fail "tag $name already exists"
	git -C "$ROOT" tag -a "$name" -m "Orrery $version"
	read -r -p "Push tag $name to origin and start the Release workflow? [y/N] " answer
	if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
		git -C "$ROOT" tag -d "$name" > /dev/null
		echo "Cancelled. The tag was removed."
		exit 1
	fi
	git -C "$ROOT" push origin "$name"
	echo "Pushed $name. Follow the build at https://github.com/Ablebil/orrery/actions"
}

if [[ $# -ne 2 ]]; then
	usage
	[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && exit 0
	exit 1
fi
[[ "$2" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "the version must look like 1.2.3"

case "$1" in
	bump) bump "$2" ;;
	tag) tag "$2" ;;
	*) usage; exit 1 ;;
esac
