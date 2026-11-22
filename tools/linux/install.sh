#!/usr/bin/env bash
set -euo pipefail

APP_ID="orrery"
APP_NAME="Orrery"
BINARY="Orrery.x86_64"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
	cat <<'USAGE'
Usage: ./install.sh [--system] [--uninstall]

Installs Orrery from this folder so it appears in the application menu of any
desktop environment and can be started with the `orrery` command.

  (no option)   Install for the current user, without root:
                ~/.local/share/orrery, ~/.local/bin/orrery, and the menu entry
  --system      Install for every user into /opt/orrery and /usr/local (run as root)
  --uninstall   Remove an installation made with the same scope
  -h, --help    Show this help
USAGE
}

SYSTEM=false
UNINSTALL=false
for argument in "$@"; do
	case "$argument" in
		--system) SYSTEM=true ;;
		--uninstall) UNINSTALL=true ;;
		-h|--help) usage; exit 0 ;;
		*) echo "Unknown option: $argument" >&2; usage >&2; exit 1 ;;
	esac
done

if $SYSTEM; then
	if [[ "$(id -u)" -ne 0 ]]; then
		echo "Error: --system needs root. Run: sudo ./install.sh --system" >&2
		exit 1
	fi
	APP_DIR="/opt/$APP_ID"
	BIN_DIR="/usr/local/bin"
	DATA_DIR="/usr/local/share"
else
	DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
	APP_DIR="$DATA_DIR/$APP_ID"
	BIN_DIR="$HOME/.local/bin"
fi
DESKTOP_FILE="$DATA_DIR/applications/$APP_ID.desktop"
ICON_FILE="$DATA_DIR/icons/hicolor/512x512/apps/$APP_ID.png"
LAUNCHER="$BIN_DIR/$APP_ID"

refresh_caches() {
	if command -v update-desktop-database > /dev/null 2>&1; then
		update-desktop-database "$DATA_DIR/applications" > /dev/null 2>&1 || true
	fi
	if command -v gtk-update-icon-cache > /dev/null 2>&1 && [[ -f "$DATA_DIR/icons/hicolor/index.theme" ]]; then
		gtk-update-icon-cache -q -t "$DATA_DIR/icons/hicolor" > /dev/null 2>&1 || true
	fi
}

if $UNINSTALL; then
	rm -rf "$APP_DIR"
	rm -f "$LAUNCHER" "$DESKTOP_FILE" "$ICON_FILE"
	refresh_caches
	echo "$APP_NAME was removed. Your settings stay in ~/.local/share/godot/app_userdata/$APP_NAME."
	exit 0
fi

if [[ ! -f "$HERE/$BINARY" ]]; then
	echo "Error: $BINARY was not found next to install.sh." >&2
	exit 1
fi

mkdir -p "$APP_DIR" "$BIN_DIR" "$(dirname "$DESKTOP_FILE")" "$(dirname "$ICON_FILE")"
install -m 755 "$HERE/$BINARY" "$APP_DIR/$BINARY"
for document in LICENSE THIRD_PARTY_LICENSES.md; do
	if [[ -f "$HERE/$document" ]]; then
		install -m 644 "$HERE/$document" "$APP_DIR/$document"
	fi
done
if [[ -f "$HERE/$APP_ID.png" ]]; then
	install -m 644 "$HERE/$APP_ID.png" "$ICON_FILE"
fi
ln -sf "$APP_DIR/$BINARY" "$LAUNCHER"

cat > "$DESKTOP_FILE" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$APP_NAME
GenericName=Solar System Simulator
Comment=Explore an interactive 3D solar system and experiment with gravity
Exec="$APP_DIR/$BINARY"
Icon=$APP_ID
Terminal=false
Categories=Education;Science;Astronomy;
Keywords=solar system;planets;astronomy;orbit;gravity;
DESKTOP
chmod 644 "$DESKTOP_FILE"
refresh_caches

echo "$APP_NAME was installed to $APP_DIR."
echo "Start it from the application menu or with the '$APP_ID' command."
if ! $SYSTEM && [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
	echo "Note: $BIN_DIR is not on your PATH, so the '$APP_ID' command needs a new login or a PATH update."
fi
