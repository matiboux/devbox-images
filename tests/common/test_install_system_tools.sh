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

. "$(dirname "$0")/../support/shell/harness.sh"

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
# apt-get is stubbed to fail installing git-delta/lazygit when the
# corresponding APT_GET_FAIL_* env var is set, to simulate Debian releases
# (e.g. bookworm) that don't package them -- unlike Alpine, which always has
# both, and newer Debian/Ubuntu releases (trixie, 24.04), which may have one
# or both. Any other apt-get invocation (the bulk install, `update`, ...)
# always succeeds.
stub_cmd apt-get '
echo "apt-get $*" >> "'"${STUB_BIN_DIR}"'/apt-get.log"
case "$*" in
	*git-delta*) [ "${APT_GET_FAIL_DELTA}" = "1" ] && exit 1 ;;
esac
case "$*" in
	*lazygit*) [ "${APT_GET_FAIL_LAZYGIT}" = "1" ] && exit 1 ;;
esac
exit 0
'
# apt-get is stubbed (no real package install happens), so `fdfind` is
# never actually installed; stub it as the `ln` target. `ln` itself is
# also stubbed since the Debian branch's final step is an unconditional
# `ln -sf ... /usr/local/bin/fd`, a real hardcoded system path with no
# override, which must never actually run un-intercepted.
stub_cmd fdfind 'exit 0'
stub_cmd_logging ln
# When apt-get lacks git-delta/lazygit, the Debian branch falls back to
# install-delta.sh/install-lazygit.sh, which hit the network and (for delta)
# run dpkg -- stub their externals too.
use_stub curl
stub_cmd_logging dpkg
stub_cmd_logging tar
stub_cmd_logging mv

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

if [ "${DISTRO}" = 'debian' ] || [ "${DISTRO}" = 'ubuntu' ]; then

	test_case 'falls back to GitHub releases when apt lacks git-delta/lazygit (e.g. Debian bookworm)'
	: > "${STUB_BIN_DIR}/apt-get.log"
	: > "${STUB_BIN_DIR}/dpkg.log"
	: > "${STUB_BIN_DIR}/tar.log"
	: > "${STUB_BIN_DIR}/mv.log"
	output=$(
		APT_GET_FAIL_DELTA=1 APT_GET_FAIL_LAZYGIT=1 \
		CURL_STUB_API_BODY='{"tag_name":"v1.0.0"}' \
		sh "${SCRIPT}" 2>&1
	)
	code=$?
	assert_exit_code "${code}" 0 "${output}"
	assert_contains "$(cat "${STUB_BIN_DIR}/dpkg.log")" 'dpkg'
	assert_contains "$(cat "${STUB_BIN_DIR}/mv.log")" '/usr/local/bin/lazygit'

	test_case 'skips the GitHub releases fallback when apt already has git-delta/lazygit (e.g. Debian trixie)'
	: > "${STUB_BIN_DIR}/apt-get.log"
	: > "${STUB_BIN_DIR}/dpkg.log"
	: > "${STUB_BIN_DIR}/mv.log"
	output=$(sh "${SCRIPT}" 2>&1)
	code=$?
	assert_exit_code "${code}" 0 "${output}"
	assert_contains "$(cat "${STUB_BIN_DIR}/apt-get.log")" 'git-delta'
	assert_contains "$(cat "${STUB_BIN_DIR}/apt-get.log")" 'lazygit'
	assert_equal "$(cat "${STUB_BIN_DIR}/dpkg.log")" ''
	assert_equal "$(cat "${STUB_BIN_DIR}/mv.log")" ''

fi

summary
