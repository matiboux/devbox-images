#!/bin/sh
# Tests for src/common/install-yq.sh
#
# `tar` and `mv` are stubbed as safe no-ops: this script's final step is an
# unconditional `mv .../yq_<arch> /usr/local/bin/yq`, a real hardcoded
# system path with no override, so we must never let it actually run
# un-intercepted.

. "$(dirname "$0")/harness.sh"

SCRIPT="${COMMON_DIR}/install-yq.sh"

setup_stub_bin
use_stub curl
stub_cmd_logging tar
stub_cmd_logging mv

CURL_LOG="${STUB_BIN_DIR}/curl-calls.log"

test_case 'an unsupported host architecture errors out before any network call'
stub_cmd uname 'echo sparc'
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Unsupported architecture: sparc'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a recognized architecture (x86_64) is accepted'
stub_cmd uname 'echo x86_64'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '4.53.3' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
rm -f "${STUB_BIN_DIR}/uname"

test_case 'the resolved architecture selects the matching release asset'
stub_cmd uname 'echo aarch64'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '4.53.3' 2>&1)
assert_contains "$(cat "${CURL_LOG}")" 'yq_linux_arm64.tar.gz'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a fully-qualified X.Y.Z version skips the GitHub API lookup'
stub_cmd uname 'echo x86_64'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '4.53.3' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_not_contains "$(cat "${CURL_LOG}")" 'api.github.com'
assert_contains "${output}" 'Installed yq version 4.53.3 to /usr/local/bin/yq.'
rm -f "${STUB_BIN_DIR}/uname"

test_case "'latest' (default) resolves the tag_name from the GitHub releases API"
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_API_BODY='{"tag_name":"v4.53.3"}' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'Installed yq version 4.53.3 to /usr/local/bin/yq.'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a partial version resolves via matching-refs and picks the highest match'
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_API_BODY='[{"ref":"refs/tags/v4.53.3"},{"ref":"refs/tags/v4.53.10"}]' sh "${SCRIPT}" '4.53' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'Installed yq version 4.53.10 to /usr/local/bin/yq.'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a 404 from matching-refs is reported as version-not-found'
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_HTTP_CODE=404 CURL_STUB_API_BODY='[]' sh "${SCRIPT}" '99.99' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Version '99.99' not found in yq repository."
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a tar extraction failure is reported and stops before any mv'
stub_cmd uname 'echo x86_64'
stub_cmd_logging tar 1
: > "${STUB_BIN_DIR}/mv.log"
output=$(sh "${SCRIPT}" '4.53.3' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to extract yq binary from archive.'
assert_equal "$(cat "${STUB_BIN_DIR}/mv.log")" ''
stub_cmd_logging tar
rm -f "${STUB_BIN_DIR}/uname"

test_case 'an mv failure into /usr/local/bin is reported'
stub_cmd uname 'echo x86_64'
stub_cmd_logging mv 1
output=$(sh "${SCRIPT}" '4.53.3' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install yq binary in /usr/local/bin.'
stub_cmd_logging mv
rm -f "${STUB_BIN_DIR}/uname"

summary
