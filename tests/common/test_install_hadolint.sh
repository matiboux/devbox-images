#!/bin/sh
# Tests for src/common/install-hadolint.sh
#
# `install` is stubbed as a safe no-op: this script's final step is an
# unconditional `install ... /usr/local/bin/hadolint`, a real hardcoded
# system path with no override, so we must never let it actually run
# un-intercepted.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-hadolint.sh"

setup_stub_bin
use_stub curl
stub_cmd_logging install

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
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '2.12.0' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
rm -f "${STUB_BIN_DIR}/uname"

test_case 'the resolved architecture selects the matching release asset'
stub_cmd uname 'echo aarch64'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '2.12.0' 2>&1)
assert_contains "$(cat "${CURL_LOG}")" 'hadolint-linux-arm64'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a fully-qualified X.Y.Z version skips the GitHub API lookup'
stub_cmd uname 'echo x86_64'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '2.12.0' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_not_contains "$(cat "${CURL_LOG}")" 'api.github.com'
assert_contains "${output}" 'Installed hadolint version 2.12.0 to /usr/local/bin/hadolint.'
rm -f "${STUB_BIN_DIR}/uname"

test_case "'latest' (default) resolves the tag_name from the GitHub releases API"
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_API_BODY='{"tag_name":"v2.12.0"}' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'Installed hadolint version 2.12.0 to /usr/local/bin/hadolint.'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a partial version resolves via matching-refs and picks the highest match'
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_API_BODY='[{"ref":"refs/tags/v2.12.0"},{"ref":"refs/tags/v2.12.9"}]' sh "${SCRIPT}" '2.12' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'Installed hadolint version 2.12.9 to /usr/local/bin/hadolint.'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a 404 from matching-refs is reported as version-not-found'
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_HTTP_CODE=404 CURL_STUB_API_BODY='[]' sh "${SCRIPT}" '99.99' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Version '99.99' not found in hadolint repository."
rm -f "${STUB_BIN_DIR}/uname"

test_case 'an install failure into /usr/local/bin is reported'
stub_cmd uname 'echo x86_64'
stub_cmd_logging install 1
output=$(sh "${SCRIPT}" '2.12.0' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install hadolint binary in /usr/local/bin.'
stub_cmd_logging install
rm -f "${STUB_BIN_DIR}/uname"

summary
