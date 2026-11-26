#!/usr/bin/env bash
set -uo pipefail

usage() {
	cat <<'EOF'
Usage: tests/with_weston.sh command [args ...]

Runs a command inside a headless Weston compositor, the Wayland counterpart of
xvfb-run. The command sees only the Wayland display: DISPLAY is unset so Godot
cannot fall back to X11. Set WESTON_SIZE (default 1280x720) to change the output
size. The compositor log is written to weston.log in a temporary folder and
printed if Weston fails to start.

  tests/with_weston.sh env GODOT_ARGS="--display-driver wayland" tests/run_tests.sh
EOF
}

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
	usage
	exit 0
fi

size="${WESTON_SIZE:-1280x720}"
runtime="$(mktemp -d)"
chmod 700 "${runtime}"
socket="wayland-orrery-$$"

XDG_RUNTIME_DIR="${runtime}" weston \
	--backend=headless \
	--renderer=pixman \
	--socket="${socket}" \
	--width="${size%x*}" \
	--height="${size#*x}" \
	--idle-time=0 \
	> "${runtime}/weston.log" 2>&1 &
weston_pid=$!

stop() {
	kill "${weston_pid}" 2> /dev/null
	wait "${weston_pid}" 2> /dev/null
	rm -rf "${runtime}"
}
trap stop EXIT

for _ in $(seq 100); do
	[[ -S "${runtime}/${socket}" ]] && break
	if ! kill -0 "${weston_pid}" 2> /dev/null; then
		break
	fi
	sleep 0.1
done
if [[ ! -S "${runtime}/${socket}" ]]; then
	echo "Weston did not start:" >&2
	cat "${runtime}/weston.log" >&2
	exit 1
fi

env -u DISPLAY XDG_RUNTIME_DIR="${runtime}" WAYLAND_DISPLAY="${socket}" "$@"
