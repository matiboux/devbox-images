#!/bin/sh
# Tests for src/common/install-delta.sh
#
# `dpkg` is stubbed as a safe no-op: this script's final step is an
# unconditional `dpkg -i .../git-delta_..._<arch>.deb`, a real system-wide
# package install with no override, so we must never let it actually run
# un-intercepted.
#
# Unlike the other GitHub-release installers in this repo, delta's release
# tags have no "v" prefix (e.g. "0.19.2", not "v0.19.2").

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-delta.sh"

setup_stub_bin
use_stub curl
stub_cmd_logging dpkg

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
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '0.19.2' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
rm -f "${STUB_BIN_DIR}/uname"

test_case 'the resolved architecture selects the matching release asset'
stub_cmd uname 'echo aarch64'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '0.19.2' 2>&1)
assert_contains "$(cat "${CURL_LOG}")" 'git-delta_0.19.2_arm64.deb'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a fully-qualified X.Y.Z version skips the GitHub API lookup'
stub_cmd uname 'echo x86_64'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '0.19.2' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_not_contains "$(cat "${CURL_LOG}")" 'api.github.com'
assert_contains "${output}" 'Installed delta version 0.19.2 to /usr/local/bin/delta.'
rm -f "${STUB_BIN_DIR}/uname"

test_case "'latest' (default) resolves the tag_name from the GitHub releases API"
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_API_BODY='{"tag_name":"0.19.2"}' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'Installed delta version 0.19.2 to /usr/local/bin/delta.'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a partial version resolves via matching-refs and picks the highest match'
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_API_BODY='[{"ref":"refs/tags/0.19.2"},{"ref":"refs/tags/0.19.10"}]' sh "${SCRIPT}" '0.19' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'Installed delta version 0.19.10 to /usr/local/bin/delta.'
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a 404 from matching-refs is reported as version-not-found'
stub_cmd uname 'echo x86_64'
output=$(CURL_STUB_HTTP_CODE=404 CURL_STUB_API_BODY='[]' sh "${SCRIPT}" '99.99' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Version '99.99' not found in delta repository."
rm -f "${STUB_BIN_DIR}/uname"

test_case 'a dpkg install failure is reported'
stub_cmd uname 'echo x86_64'
stub_cmd_logging dpkg 1
output=$(sh "${SCRIPT}" '0.19.2' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install delta package.'
stub_cmd_logging dpkg
rm -f "${STUB_BIN_DIR}/uname"

summary
