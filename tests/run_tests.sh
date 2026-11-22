#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
TIMEOUT_FRAMES=20000
ALL_TESTS=(simulation_test ux_test language_test eclipse_test star_test gravity_well_test comet_test challenge_test input_test shell_test quiz_test panel_test binding_test a11y_test pointer_test graphics_test texture_test timezone_test settings_test keyboard_test session_test)

usage() {
	cat <<'EOF'
Usage: tests/run_tests.sh [test_name ...]

Runs the Orrery UI, input, and rendering tests in a real window. With no
arguments every test runs. Set GODOT to the Godot 4.7.2 executable when it is
not on PATH, and GODOT_ARGS to pass extra engine options such as
--display-driver x11. Set SHOT_DIR to also save the screenshots some tests take,
and FAILURE_DIR to save a screenshot of the window at every failed check.

The user settings and sandbox snapshot are backed up before the run and
restored afterwards, so the tests never change your saved preferences.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

user_dir() {
	case "$(uname -s)" in
		MINGW* | MSYS* | CYGWIN*) echo "${APPDATA}/Godot/app_userdata/Orrery" ;;
		Darwin*) echo "${HOME}/Library/Application Support/Godot/app_userdata/Orrery" ;;
		*) echo "${XDG_DATA_HOME:-${HOME}/.local/share}/godot/app_userdata/Orrery" ;;
	esac
}

native_path() {
	if command -v cygpath > /dev/null 2>&1; then
		cygpath -m "$1"
	else
		echo "$1"
	fi
}

USER_DIR="$(user_dir)"
BACKUP="$(mktemp -d)"
for file in settings.cfg sandbox_snapshot.json; do
	[[ -f "${USER_DIR}/${file}" ]] && cp "${USER_DIR}/${file}" "${BACKUP}/${file}"
done

restore() {
	for file in settings.cfg sandbox_snapshot.json; do
		if [[ -f "${BACKUP}/${file}" ]]; then
			cp "${BACKUP}/${file}" "${USER_DIR}/${file}"
		else
			rm -f "${USER_DIR}/${file}"
		fi
	done
	rm -rf "${BACKUP}"
}
trap restore EXIT

TESTS=("$@")
if [[ ${#TESTS[@]} -eq 0 ]]; then
	TESTS=("${ALL_TESTS[@]}")
fi

PROJECT="$(native_path "${ROOT}/godot")"
failed=0
for test in "${TESTS[@]}"; do
	script="$(native_path "${ROOT}/tests/${test}.gd")"
	output="$("${GODOT}" ${GODOT_ARGS:-} --path "${PROJECT}" --script "${script}" --quit-after "${TIMEOUT_FRAMES}" 2>&1)"
	passes="$(grep -c '^PASS' <<< "${output}")"
	summary="$(grep -m1 '^FAILURES:' <<< "${output}")"
	if [[ "${summary}" == "FAILURES: 0" ]]; then
		echo "ok    ${test} (${passes} checks)"
	else
		failed=1
		echo "FAIL  ${test}"
		grep -E '^FAIL|SCRIPT ERROR' <<< "${output}" | sed 's/^/      /'
		[[ -z "${summary}" ]] && echo "      the test did not finish"
	fi
	for file in settings.cfg sandbox_snapshot.json; do
		if [[ -f "${BACKUP}/${file}" ]]; then
			cp "${BACKUP}/${file}" "${USER_DIR}/${file}"
		else
			rm -f "${USER_DIR}/${file}"
		fi
	done
done
exit "${failed}"
