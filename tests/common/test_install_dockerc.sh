#!/bin/sh
# Tests for src/common/install-dockerc.sh
#
# `install` is stubbed as a safe no-op: this script's final step is an
# unconditional `install ... /usr/local/bin/dockerc`, a real hardcoded
# system path with no override, so we must never let it actually run
# un-intercepted.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-dockerc.sh"

setup_stub_bin
use_stub curl
stub_cmd_logging install
stub_cmd docker 'exit 0'

CURL_LOG="${STUB_BIN_DIR}/curl-calls.log"

test_case 'docker not installed errors out before any network call'
stub_cmd docker 'exit 1'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Docker is not installed.'
assert_equal "$(cat "${CURL_LOG}")" ''
stub_cmd docker 'exit 0'

test_case 'docker compose not installed errors out before any network call'
stub_cmd docker '[ "$1" = "compose" ] && exit 1; exit 0'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Docker compose is not installed.'
assert_equal "$(cat "${CURL_LOG}")" ''
stub_cmd docker 'exit 0'

test_case 'a fully-qualified X.Y.Z version skips the GitHub API lookup'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '2.2.0' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_not_contains "$(cat "${CURL_LOG}")" 'api.github.com'
assert_contains "$(cat "${CURL_LOG}")" 'raw.githubusercontent.com/matiboux/dockerc/v2.2.0/dockerc'
assert_contains "${output}" 'Installed dockerc version 2.2.0 to /usr/local/bin/dockerc.'

test_case "'latest' (default) resolves the tag_name from the GitHub releases API"
output=$(CURL_STUB_API_BODY='{"tag_name":"v2.2.0"}' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'Installed dockerc version 2.2.0 to /usr/local/bin/dockerc.'

test_case 'a partial version resolves via matching-refs and picks the highest match'
output=$(CURL_STUB_API_BODY='[{"ref":"refs/tags/v2.2.0"},{"ref":"refs/tags/v2.2.9"}]' sh "${SCRIPT}" '2.2' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'Installed dockerc version 2.2.9 to /usr/local/bin/dockerc.'

test_case 'a 404 from matching-refs is reported as version-not-found'
output=$(CURL_STUB_HTTP_CODE=404 CURL_STUB_API_BODY='[]' sh "${SCRIPT}" '99.99' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Version '99.99' not found in dockerc repository."

test_case 'an install failure into /usr/local/bin is reported'
stub_cmd_logging install 1
output=$(sh "${SCRIPT}" '2.2.0' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install dockerc script in /usr/local/bin.'
stub_cmd_logging install

summary
