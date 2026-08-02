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
stub_cmd_logging getent 1
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/groupadd.log")" '-g 1000 user'
assert_contains "$(cat "${STUB_BIN_DIR}/useradd.log")" '-u 1000 -g 1000 -s /usr/bin/bash user'
rm -f "${STUB_BIN_DIR}"/*.log

# --- custom args ---

test_case 'custom args are passed through to groupadd/useradd'
stub_cmd_logging groupadd
stub_cmd_logging useradd
stub_cmd_logging getent 1
output=$(sh "${SCRIPT}" 'dev' '2000' '2001' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/groupadd.log")" '-g 2001 dev'
assert_contains "$(cat "${STUB_BIN_DIR}/useradd.log")" '-u 2000 -g 2001 -s /usr/bin/bash dev'
rm -f "${STUB_BIN_DIR}"/*.log

# --- group creation fallback ---

test_case 'falls back to addgroup when groupadd is unavailable'
rm -f "${STUB_BIN_DIR}/groupadd"
stub_cmd_logging addgroup
stub_cmd_logging useradd
stub_cmd_logging getent 1
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
stub_cmd_logging getent 1
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/adduser.log")" '-D -u 1000 -G user -s /usr/bin/bash user'
rm -f "${STUB_BIN_DIR}"/*.log

test_case 'errors out when neither useradd nor adduser are available'
stub_cmd_logging groupadd
rm -f "${STUB_BIN_DIR}/useradd" "${STUB_BIN_DIR}/adduser"
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'No suitable command found to create user'

# --- docker group membership (socat execute access) ---

test_case 'user is added to an existing docker group via usermod'
stub_cmd_logging groupadd
stub_cmd_logging useradd
stub_cmd_logging getent 0
stub_cmd_logging usermod
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/usermod.log")" '-aG docker user'
rm -f "${STUB_BIN_DIR}"/*.log

test_case 'falls back to adduser for docker group membership when usermod is unavailable'
stub_cmd_logging groupadd
stub_cmd_logging useradd
stub_cmd_logging getent 0
rm -f "${STUB_BIN_DIR}/usermod"
stub_cmd_logging adduser
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/adduser.log")" 'user docker'
rm -f "${STUB_BIN_DIR}"/*.log

test_case 'no docker group present leaves group membership untouched'
stub_cmd_logging groupadd
stub_cmd_logging useradd
stub_cmd_logging getent 1
stub_cmd_logging usermod
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
if [ -f "${STUB_BIN_DIR}/usermod.log" ]; then
	fail 'expected usermod to not run when docker group is absent'
fi
rm -f "${STUB_BIN_DIR}"/*.log

# --- pre-existing UID/GID collision (e.g. the official node image's "node" user) ---

test_case 'a pre-existing user occupying the target UID is removed via userdel first'
stub_cmd getent 'case "$1" in
	passwd) echo "node:x:1000:1000::/home/node:/bin/sh" ;;
	group) ;;
esac
exit 0'
stub_cmd_logging userdel
stub_cmd_logging groupadd
stub_cmd_logging useradd
stub_cmd_logging usermod
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/userdel.log")" 'userdel node'
rm -f "${STUB_BIN_DIR}"/*.log "${STUB_BIN_DIR}/getent"

test_case 'a pre-existing group occupying the target GID is removed via groupdel first'
stub_cmd getent 'case "$1" in
	passwd) ;;
	group) echo "node:x:1000:" ;;
esac
exit 0'
stub_cmd_logging groupdel
stub_cmd_logging groupadd
stub_cmd_logging useradd
stub_cmd_logging usermod
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/groupdel.log")" 'groupdel node'
rm -f "${STUB_BIN_DIR}"/*.log "${STUB_BIN_DIR}/getent"

test_case 'no removal happens when the existing entry already matches the target username'
stub_cmd getent 'case "$1" in
	passwd) echo "user:x:1000:1000::/home/user:/bin/sh" ;;
	group) echo "user:x:1000:" ;;
esac
exit 0'
stub_cmd_logging userdel
stub_cmd_logging groupdel
stub_cmd_logging groupadd
stub_cmd_logging useradd
stub_cmd_logging usermod
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
if [ -f "${STUB_BIN_DIR}/userdel.log" ]; then
	fail 'expected userdel to not run when the existing user already matches'
fi
if [ -f "${STUB_BIN_DIR}/groupdel.log" ]; then
	fail 'expected groupdel to not run when the existing group already matches'
fi
rm -f "${STUB_BIN_DIR}"/*.log "${STUB_BIN_DIR}/getent"

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
