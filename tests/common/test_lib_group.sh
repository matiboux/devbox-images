#!/bin/sh
# Direct unit tests for src/common/lib/group.sh (add_user_to_group),
# independent of create-user.sh.
#
# Testing this directly (rather than only through create-user.sh's
# full-script tests) is what lets us reach the required=1 error branches
# (missing group, no usermod/adduser) -- those are only exercised in
# create-user.sh on a recognized alpine/debian/ubuntu distro, which isn't
# reachable on every dev host (see tests/common/test_create_user.sh).

. "$(dirname "$0")/../support/shell/harness.sh"

. "${COMMON_DIR}/lib/group.sh"

setup_stub_bin

test_case 'adds the user to an existing group via usermod'
stub_cmd getent 'exit 0'
stub_cmd_logging usermod
output=$(add_user_to_group user docker 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/usermod.log")" '-aG docker user'
rm -f "${STUB_BIN_DIR}"/*.log "${STUB_BIN_DIR}/getent" "${STUB_BIN_DIR}/usermod"

test_case 'falls back to adduser when usermod is unavailable'
stub_cmd getent 'exit 0'
stub_cmd_logging adduser
output=$(add_user_to_group user docker 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/adduser.log")" 'user docker'
rm -f "${STUB_BIN_DIR}"/*.log "${STUB_BIN_DIR}/getent" "${STUB_BIN_DIR}/adduser"

test_case 'a missing group is silently ignored by default (required unset)'
stub_cmd getent 'exit 1'
output=$(add_user_to_group user sudo 2>&1)
code=$?
assert_exit_code "${code}" 0
assert_equal "${output}" ''
rm -f "${STUB_BIN_DIR}/getent"

test_case 'a missing group errors out when required=1'
stub_cmd getent 'exit 1'
output=$(add_user_to_group user sudo 1 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Group 'sudo' does not exist"
rm -f "${STUB_BIN_DIR}/getent"

test_case 'neither usermod nor adduser available is silently ignored by default (required unset)'
stub_cmd getent 'exit 0'
output=$(add_user_to_group user docker 2>&1)
code=$?
assert_exit_code "${code}" 0
assert_equal "${output}" ''
rm -f "${STUB_BIN_DIR}/getent"

test_case 'neither usermod nor adduser available errors out when required=1'
stub_cmd getent 'exit 0'
output=$(add_user_to_group user sudo 1 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'No suitable command found to add user to sudo group'
rm -f "${STUB_BIN_DIR}/getent"

summary
