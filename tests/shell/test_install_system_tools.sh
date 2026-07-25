#!/bin/sh
# Tests for src/common/install-system-tools.sh
#
# Unlike install-sudo.sh, this script only ever shells out to apk/apt-get
# (no direct writes to hardcoded system files), so both package managers
# can be safely stubbed via PATH on any host -- the real apk/apt-get are
# never invoked. The expected branch is derived from the host's actual
# /etc/os-release (when present), so this suite behaves correctly whether
# run on a plain dev machine (no os-release -> "unsupported") or inside an
# Alpine/Debian/Ubuntu container (-> the matching package-manager branch).

. "$(dirname "$0")/harness.sh"

SCRIPT="${COMMON_DIR}/install-system-tools.sh"

host_distro() {
	if [ -f /etc/os-release ]; then
		awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"'
	else
		echo 'unknown'
	fi
}

DISTRO="$(host_distro)"

setup_stub_bin
stub_cmd_logging apk
stub_cmd_logging apt-get

test_case 'installs the expected package set for the host distribution (or errors on unsupported ones)'
output=$(sh "${SCRIPT}" 2>&1)
code=$?

case "${DISTRO}" in
	alpine)
		assert_exit_code "${code}" 0 "${output}"
		assert_contains "$(cat "${STUB_BIN_DIR}/apk.log")" 'add --no-cache'
		assert_contains "$(cat "${STUB_BIN_DIR}/apk.log")" 'build-base'
		assert_contains "$(cat "${STUB_BIN_DIR}/apk.log")" 'musl-dev'
		;;
	debian|ubuntu)
		assert_exit_code "${code}" 0 "${output}"
		assert_contains "$(cat "${STUB_BIN_DIR}/apt-get.log")" 'update'
		assert_contains "$(cat "${STUB_BIN_DIR}/apt-get.log")" 'build-essential'
		;;
	*)
		assert_exit_code "${code}" 1
		assert_contains "${output}" "Unsupported distribution: ${DISTRO}"
		;;
esac

summary
