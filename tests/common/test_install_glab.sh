#!/bin/sh
# Tests for src/common/install-glab.sh
#
# `tar` and `mv` are stubbed as safe no-ops: this script's final step is an
# unconditional `mv .../glab /usr/local/bin/glab`, a real hardcoded system
# path with no override, so we must never let it actually run
# un-intercepted.
#
# Unlike the GitHub-based install-*.sh scripts, install-glab.sh only ever
# calls the GitLab API to resolve 'latest' (via the releases/permalink/latest
# endpoint) -- a partial version like '2.63' has no matching-refs equivalent
# here and is used as-is, with no API call and no validation that it exists.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-glab.sh"

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
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '1.51.0' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
rm -f "${STUB_BIN_DIR}/uname"

test_case 'the resolved architecture selects the matching release asset'
stub_cmd uname 'echo aarch64'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '1.51.0' 2>&1)
assert_contains "$(cat "${CURL_LOG}")" 'glab_1.51.0_linux_arm64.tar.gz'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a fully-qualified X.Y.Z version skips the GitLab API lookup'
stub_cmd uname 'echo x86_64'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '1.51.0' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_not_contains "$(cat "${CURL_LOG}")" 'gitlab.com/api'
assert_contains "${output}" 'Installed glab version 1.51.0 to /usr/local/bin/glab.'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a partial version is used as-is, with no GitLab API lookup or validation'
stub_cmd uname 'echo x86_64'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '1.51' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_not_contains "$(cat "${CURL_LOG}")" 'gitlab.com/api'
assert_contains "$(cat "${CURL_LOG}")" 'v1.51/downloads/glab_1.51_linux_amd64.tar.gz'
assert_contains "${output}" 'Installed glab version 1.51 to /usr/local/bin/glab.'
rm -f "${STUB_BIN_DIR}/uname"

test_case "'latest' (default) resolves the tag_name from the GitLab releases permalink API"
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_API_BODY='{"tag_name":"v1.51.0"}' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'Installed glab version 1.51.0 to /usr/local/bin/glab.'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a non-200 response for "latest" is reported as a GitLab API error'
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_HTTP_CODE=500 CURL_STUB_API_BODY='' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'GitLab API error (HTTP 500).'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a 403 response for "latest" is reported as a rate-limit error'
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_HTTP_CODE=403 CURL_STUB_API_BODY='' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'GitLab API rate limit exceeded.'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'an empty response for "latest" is reported clearly'
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_API_BODY='' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Empty response from GitLab API.'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a tar extraction failure is reported and stops before any mv'
stub_cmd uname 'echo x86_64'
stub_cmd_logging tar 1
: > "${STUB_BIN_DIR}/mv.log"
output=$(sh "${SCRIPT}" '1.51.0' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to extract glab binary from archive.'
assert_equal "$(cat "${STUB_BIN_DIR}/mv.log")" ''
stub_cmd_logging tar
rm -f "${STUB_BIN_DIR}/uname"

test_case 'an mv failure into /usr/local/bin is reported'
stub_cmd uname 'echo x86_64'
stub_cmd_logging mv 1
output=$(sh "${SCRIPT}" '1.51.0' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install glab binary in /usr/local/bin.'
stub_cmd_logging mv
rm -f "${STUB_BIN_DIR}/uname"

summary
