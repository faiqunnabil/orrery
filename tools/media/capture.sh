#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: tools/media/capture.sh

Captures the README screenshots that show the newer features into .github/media.
Set GODOT to the Godot 4.7 executable when it is not on PATH. The run opens a
window, and your saved settings are backed up first and restored afterwards.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-godot}"
MEDIA_DIR="${ROOT}/.github/media"

case "$(uname -s)" in
	MINGW*|MSYS*|CYGWIN*) USER_DIR="${APPDATA}/Godot/app_userdata/Orrery" ;;
	Darwin) USER_DIR="${HOME}/Library/Application Support/Godot/app_userdata/Orrery" ;;
	*) USER_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/godot/app_userdata/Orrery" ;;
esac

BACKUP="$(mktemp -d)"
restore() {
	if [[ -f "${BACKUP}/settings.cfg" ]]; then
		cp "${BACKUP}/settings.cfg" "${USER_DIR}/settings.cfg"
	else
		rm -f "${USER_DIR}/settings.cfg"
	fi
	rm -rf "${BACKUP}"
}
if [[ -f "${USER_DIR}/settings.cfg" ]]; then
	cp "${USER_DIR}/settings.cfg" "${BACKUP}/settings.cfg"
fi
trap restore EXIT

mkdir -p "${MEDIA_DIR}"
MEDIA_DIR="${MEDIA_DIR}" "${GODOT}" ${GODOT_ARGS:-} --path "${ROOT}/godot" --script "${ROOT}/tools/media/capture_media.gd"
