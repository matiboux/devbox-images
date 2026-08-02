#!/bin/sh
# Direct unit tests for src/common/lib/distro.sh (detect_distro,
# detect_package_manager), independent of any install-*.sh script that uses
# them.
#
# detect_distro reads the fixed path /etc/os-release with no override, so
# (like test_install_sudo.sh/test_install_docker.sh) we can't safely
# simulate its absence without mutating the real filesystem -- that branch
# is skipped rather than asserted on a host where the file exists.

. "$(dirname "$0")/../support/shell/harness.sh"

. "${COMMON_DIR}/lib/distro.sh"

setup_stub_bin

test_case 'detect_distro reads the ID field out of a real /etc/os-release'
if [ -f /etc/os-release ]; then
	expected="$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')"
	output=$(detect_distro)
	assert_equal "${output}" "${expected}"
else
	skip_case 'host has no /etc/os-release to read'
fi

test_case 'detect_distro falls back to "unknown" when /etc/os-release is absent'
if [ -f /etc/os-release ]; then
	skip_case '/etc/os-release is a fixed path; cannot simulate its absence without mutating the real filesystem'
else
	output=$(detect_distro)
	assert_equal "${output}" 'unknown'
fi

test_case 'detect_package_manager resolves apk for alpine'
stub_cmd apk 'exit 0'
output=$(detect_package_manager alpine)
assert_equal "${output}" "${STUB_BIN_DIR}/apk"
rm -f "${STUB_BIN_DIR}/apk"

test_case 'detect_package_manager resolves apt-get for debian and ubuntu'
stub_cmd apt-get 'exit 0'
output=$(detect_package_manager debian)
assert_equal "${output}" "${STUB_BIN_DIR}/apt-get"
output=$(detect_package_manager ubuntu)
assert_equal "${output}" "${STUB_BIN_DIR}/apt-get"
rm -f "${STUB_BIN_DIR}/apt-get"

test_case 'detect_package_manager prints nothing for an unrecognized distro'
output=$(detect_package_manager fedora)
assert_equal "${output}" ''

test_case 'detect_package_manager prints nothing for alpine if apk is not on PATH'
output=$(detect_package_manager alpine)
assert_equal "${output}" ''

summary
