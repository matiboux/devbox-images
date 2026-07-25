#!/bin/sh
# Tests for src/common/create-user.sh
#
# NOTE: create-user.sh reads the fixed path /etc/os-release to detect the
# Linux distribution when SUDO_USER=true. That path can't be overridden by
# environment/stubs, so on a non-Linux dev machine (no /etc/os-release) the
# script always falls into DISTRO='unknown'. The alpine/debian-specific
# sudo-group branches are exercised in practice inside the actual Docker
# images (see src/python/Dockerfile) and are out of reach for this harness.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/create-user.sh"

setup_stub_bin

# --- defaults ---

test_case 'defaults: no args uses username=user, uid=1000, gid=1000'
stub_cmd_logging groupadd
stub_cmd_logging useradd
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/groupadd.log")" '-g 1000 user'
assert_contains "$(cat "${STUB_BIN_DIR}/useradd.log")" '-u 1000 -g 1000 user'
rm -f "${STUB_BIN_DIR}"/*.log

# --- custom args ---

test_case 'custom args are passed through to groupadd/useradd'
stub_cmd_logging groupadd
stub_cmd_logging useradd
output=$(sh "${SCRIPT}" 'dev' '2000' '2001' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/groupadd.log")" '-g 2001 dev'
assert_contains "$(cat "${STUB_BIN_DIR}/useradd.log")" '-u 2000 -g 2001 dev'
rm -f "${STUB_BIN_DIR}"/*.log

# --- group creation fallback ---

test_case 'falls back to addgroup when groupadd is unavailable'
rm -f "${STUB_BIN_DIR}/groupadd"
stub_cmd_logging addgroup
stub_cmd_logging useradd
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/addgroup.log")" '-g 1000 user'
rm -f "${STUB_BIN_DIR}"/*.log

test_case 'errors out when neither groupadd nor addgroup are available'
rm -f "${STUB_BIN_DIR}/groupadd" "${STUB_BIN_DIR}/addgroup"
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'No suitable command found to create group'

# --- user creation fallback ---

test_case 'falls back to adduser when useradd is unavailable'
stub_cmd_logging groupadd
rm -f "${STUB_BIN_DIR}/useradd"
stub_cmd_logging adduser
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/adduser.log")" '-D -u 1000 -G user user'
rm -f "${STUB_BIN_DIR}"/*.log

test_case 'errors out when neither useradd nor adduser are available'
stub_cmd_logging groupadd
rm -f "${STUB_BIN_DIR}/useradd" "${STUB_BIN_DIR}/adduser"
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'No suitable command found to create user'

# --- sudo user, unknown distro (this machine has no /etc/os-release) ---

test_case 'sudo user requested on an unrecognized distribution errors out'
stub_cmd_logging groupadd
stub_cmd_logging useradd
# Also stub the group-membership commands the script *could* reach on a
# recognized distribution, so this test can never mutate real system
# group/sudoers state regardless of what distro the host actually is.
stub_cmd_logging getent 1
stub_cmd_logging usermod
stub_cmd_logging adduser
output=$(sh "${SCRIPT}" 'user' '1000' '1000' 'true' 2>&1)
code=$?
if [ -f /etc/os-release ]; then
	skip_case 'host has a real /etc/os-release; skipping to avoid depending on its specific distro/package-manager branch'
else
	assert_exit_code "${code}" 1
	assert_contains "${output}" 'Unsupported distribution: unknown'
fi

summary
