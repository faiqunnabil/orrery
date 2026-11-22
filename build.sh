#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_VERSION="4.7.2.stable"
TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
GODOT="${GODOT:-godot}"

usage() {
	cat <<'EOF'
Usage: ./build.sh [linux|windows|all] [--install-templates]

Exports standalone release builds of Orrery into builds/.

Options:
  linux                Export Linux x86_64 binary (builds/linux/Orrery.x86_64)
  windows              Export Windows x86_64 binary (builds/windows/Orrery.exe)
  all                  Export both platforms (default)
  --install-templates  Download and install Godot 4.7.2 export templates if missing
  -h, --help           Show this help message

Environment:
  GODOT                Godot 4.7.2 executable (default: godot on PATH)
  GODOT_TEMPLATES      Export template folder, when it is not found automatically

On Windows, run it from Git Bash, for example:
  GODOT=/d/Godot/Godot_v4.7.2-stable_win64_console.exe ./build.sh windows
EOF
}

templates_dir() {
	if [[ -n "${GODOT_TEMPLATES:-}" ]]; then
		echo "$GODOT_TEMPLATES"
		return
	fi
	local editor_dir
	editor_dir="$(dirname "$GODOT_PATH")"
	if [[ -f "$editor_dir/._sc_" || -f "$editor_dir/_sc_" ]]; then
		echo "$editor_dir/editor_data/export_templates/$GODOT_VERSION"
		return
	fi
	case "$(uname -s)" in
		MINGW*|MSYS*|CYGWIN*) echo "${APPDATA}/Godot/export_templates/$GODOT_VERSION" ;;
		Darwin) echo "$HOME/Library/Application Support/Godot/export_templates/$GODOT_VERSION" ;;
		*) echo "${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GODOT_VERSION" ;;
	esac
}

templates_installed() {
	local platform
	for platform in "$@"; do
		case "$platform" in
			linux) [[ -f "$TEMPLATES_DIR/linux_release.x86_64" ]] || return 1 ;;
			windows) [[ -f "$TEMPLATES_DIR/windows_release_x86_64.exe" ]] || return 1 ;;
		esac
	done
}

install_templates() {
	local tmp_dir
	tmp_dir="$(mktemp -d)"
	trap 'rm -rf "$tmp_dir"' RETURN
	echo "Downloading Godot $GODOT_VERSION export templates..."
	curl -fL -o "$tmp_dir/templates.tpz" "$TEMPLATES_URL"
	echo "Extracting export templates to $TEMPLATES_DIR..."
	unzip -q "$tmp_dir/templates.tpz" -d "$tmp_dir"
	mkdir -p "$TEMPLATES_DIR"
	cp -r "$tmp_dir/templates/"* "$TEMPLATES_DIR/"
	echo "Export templates installed."
}

export_linux() {
	mkdir -p "$DIR/builds/linux"
	echo "Exporting Linux release..."
	"$GODOT_PATH" --headless --path "$DIR/godot" --export-release "Linux" "../builds/linux/Orrery.x86_64"
	chmod +x "$DIR/builds/linux/Orrery.x86_64"
	echo "Built: builds/linux/Orrery.x86_64"
}

export_windows() {
	mkdir -p "$DIR/builds/windows"
	echo "Exporting Windows release..."
	"$GODOT_PATH" --headless --path "$DIR/godot" --export-release "Windows" "../builds/windows/Orrery.exe"
	echo "Built: builds/windows/Orrery.exe"
}

target="all"
want_install=false

for arg in "$@"; do
	case "$arg" in
		linux|windows|all)
			target="$arg"
			;;
		--install-templates)
			want_install=true
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $arg" >&2
			usage >&2
			exit 1
			;;
	esac
done

if ! GODOT_PATH="$(command -v "$GODOT")"; then
	echo "Error: Godot was not found at '$GODOT'. Put godot on PATH or set GODOT to the executable." >&2
	exit 1
fi
TEMPLATES_DIR="$(templates_dir)"

case "$target" in
	all) platforms=(linux windows) ;;
	*) platforms=("$target") ;;
esac

if ! templates_installed "${platforms[@]}"; then
	if [[ "$want_install" == true ]]; then
		install_templates
	else
		cat >&2 <<EOF
Error: Godot $GODOT_VERSION export templates not found at:
  $TEMPLATES_DIR

Install them automatically with:
  ./build.sh $target --install-templates
EOF
		exit 1
	fi
fi

case "$target" in
	linux)
		export_linux
		;;
	windows)
		export_windows
		;;
	all)
		export_linux
		export_windows
		;;
esac
