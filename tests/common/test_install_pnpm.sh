#!/bin/sh
# Tests for src/common/install-pnpm.sh

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-pnpm.sh"

setup_stub_bin
use_stub curl

CURL_LOG="${STUB_BIN_DIR}/curl-calls.log"

test_case 'a fully-qualified X.Y.Z version skips the GitHub API lookup'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '10.5.2' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
log="$(cat "${CURL_LOG}")"
assert_not_contains "${log}" 'api.github.com'
assert_contains "${output}" 'Installed pnpm version 10.5.2.'

test_case "'latest' (default) resolves the tag_name from the GitHub releases API"
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" CURL_STUB_API_BODY='{"tag_name":"v10.5.2"}' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'Installed pnpm version 10.5.2.'

test_case 'a partial version resolves via matching-refs and picks the highest match'
output=$(CURL_STUB_API_BODY='[{"ref":"refs/tags/v10.5.2"},{"ref":"refs/tags/v10.5.10"}]' sh "${SCRIPT}" '10.5' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'Installed pnpm version 10.5.10.'

test_case 'a 404 from the matching-refs endpoint reports the version was not found'
output=$(CURL_STUB_HTTP_CODE=404 CURL_STUB_API_BODY='[]' sh "${SCRIPT}" '99.99' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Version '99.99' not found in pnpm repository."

test_case 'a rate-limited (429) response is reported clearly'
output=$(CURL_STUB_HTTP_CODE=429 sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'GitHub API rate limit exceeded'

test_case 'an empty release-list response for latest fails with a clear message'
output=$(CURL_STUB_API_BODY='' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Empty response from GitHub API.'

test_case 'a failure downloading the pnpm installer itself is reported'
output=$(CURL_STUB_EXIT_CODE=1 sh "${SCRIPT}" '10.5.2' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to download pnpm installer.'

summary
