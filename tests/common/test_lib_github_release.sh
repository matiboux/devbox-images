#!/bin/sh
# Direct unit tests for src/common/lib/github_release.sh
# (install_github_tarball_binary, install_github_raw_binary), independent of
# any install-*.sh script that uses them.

. "$(dirname "$0")/../support/shell/harness.sh"

. "${COMMON_DIR}/lib/tmpfile.sh"
. "${COMMON_DIR}/lib/exec.sh"
. "${COMMON_DIR}/lib/github_release.sh"

setup_stub_bin
use_stub curl
stub_cmd_logging tar
stub_cmd_logging mv
stub_cmd_logging install

# --- install_github_tarball_binary ---

test_case 'a successful download/extract/move reports no error'
output=$(install_github_tarball_binary 'sometool' 'https://example.test/sometool.tar.gz' 'sometool' /usr/local/bin/sometool 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"

test_case 'a curl download failure is reported and stops before any tar/mv'
: > "${STUB_BIN_DIR}/tar.log"
: > "${STUB_BIN_DIR}/mv.log"
output=$(CURL_STUB_EXIT_CODE=1 install_github_tarball_binary 'sometool' 'https://example.test/sometool.tar.gz' 'sometool' /usr/local/bin/sometool 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to download sometool binary archive.'
assert_equal "$(cat "${STUB_BIN_DIR}/tar.log")" ''
assert_equal "$(cat "${STUB_BIN_DIR}/mv.log")" ''

test_case 'a tar extraction failure is reported and stops before any mv'
stub_cmd_logging tar 1
: > "${STUB_BIN_DIR}/mv.log"
output=$(install_github_tarball_binary 'sometool' 'https://example.test/sometool.tar.gz' 'sometool' /usr/local/bin/sometool 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to extract sometool binary from archive.'
assert_equal "$(cat "${STUB_BIN_DIR}/mv.log")" ''
stub_cmd_logging tar

test_case 'an mv failure into the destination directory is reported'
stub_cmd_logging mv 1
output=$(install_github_tarball_binary 'sometool' 'https://example.test/sometool.tar.gz' 'sometool' /usr/local/bin/sometool 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install sometool binary in /usr/local/bin.'
stub_cmd_logging mv

test_case 'the path in the archive and destination path are passed through to mv'
: > "${STUB_BIN_DIR}/mv.log"
output=$(install_github_tarball_binary 'sometool' 'https://example.test/sometool.tar.gz' 'nested/dir/sometool' /usr/local/bin/sometool 2>&1)
assert_contains "$(cat "${STUB_BIN_DIR}/mv.log")" 'nested/dir/sometool'
assert_contains "$(cat "${STUB_BIN_DIR}/mv.log")" '/usr/local/bin/sometool'

# --- install_github_raw_binary ---

test_case 'a successful download/install reports no error'
output=$(install_github_raw_binary 'sometool' 'https://example.test/sometool' /usr/local/bin/sometool 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"

test_case 'a curl download failure is reported and stops before any install'
: > "${STUB_BIN_DIR}/install.log"
output=$(CURL_STUB_EXIT_CODE=1 install_github_raw_binary 'sometool' 'https://example.test/sometool' /usr/local/bin/sometool 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to download sometool binary.'
assert_equal "$(cat "${STUB_BIN_DIR}/install.log")" ''

test_case 'an install failure into the destination directory is reported'
stub_cmd_logging install 1
output=$(install_github_raw_binary 'sometool' 'https://example.test/sometool' /usr/local/bin/sometool 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install sometool binary in /usr/local/bin.'
stub_cmd_logging install

test_case 'the default mode (0755) is passed through to install'
: > "${STUB_BIN_DIR}/install.log"
output=$(install_github_raw_binary 'sometool' 'https://example.test/sometool' /usr/local/bin/sometool 2>&1)
assert_contains "$(cat "${STUB_BIN_DIR}/install.log")" '0755'

test_case 'a custom mode is passed through to install'
: > "${STUB_BIN_DIR}/install.log"
output=$(install_github_raw_binary 'sometool' 'https://example.test/sometool' /usr/local/bin/sometool '0700' 2>&1)
assert_contains "$(cat "${STUB_BIN_DIR}/install.log")" '0700'

summary
