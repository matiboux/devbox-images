#!/bin/sh
# Direct unit tests for src/common/lib/version.sh (github_resolve_version,
# pip_resolve_version), independent of any install-*.sh script that uses
# them.
#
# curl and pip are stubbed (tests/support/shell/stubs/) so no real network
# access happens. The lib is sourced directly into this shell; each function
# call below runs through a command substitution, which is its own subshell,
# so nothing a call does (local vars, etc.) leaks between test cases.

. "$(dirname "$0")/../support/shell/harness.sh"

. "${COMMON_DIR}/lib/version.sh"

setup_stub_bin
use_stub curl
use_stub pip

CURL_LOG="${STUB_BIN_DIR}/curl-calls.log"

# --- github_resolve_version ---

test_case 'a fully-qualified X.Y.Z version is returned as-is, with no API call'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" github_resolve_version '1.2.3' 'sometool' 'someorg/sometool')
code=$?
assert_exit_code "${code}" 0
assert_equal "${output}" '1.2.3'
assert_equal "$(cat "${CURL_LOG}")" ''

test_case "'latest' (default) resolves the tag_name from the releases/latest endpoint"
output=$(CURL_STUB_API_BODY='{"tag_name":"v1.2.3"}' github_resolve_version 'latest' 'sometool' 'someorg/sometool')
assert_equal "${output}" '1.2.3'

test_case 'an empty version_input behaves the same as "latest"'
output=$(CURL_STUB_API_BODY='{"tag_name":"v1.2.3"}' github_resolve_version '' 'sometool' 'someorg/sometool')
assert_equal "${output}" '1.2.3'

test_case 'a partial version resolves via matching-refs and picks the highest match'
output=$(CURL_STUB_API_BODY='[{"ref":"refs/tags/v1.2.3"},{"ref":"refs/tags/v1.2.10"}]' github_resolve_version '1.2' 'sometool' 'someorg/sometool')
assert_equal "${output}" '1.2.10'

test_case 'a 404 from matching-refs is reported as version-not-found, using the given tool_name'
output=$(CURL_STUB_HTTP_CODE=404 CURL_STUB_API_BODY='[]' github_resolve_version '9.9.9-rc' 'sometool' 'someorg/sometool' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Version '9.9.9-rc' not found in sometool repository."

test_case 'a 403/429 response is reported as a rate-limit error'
output=$(CURL_STUB_HTTP_CODE=403 CURL_STUB_API_BODY='{}' github_resolve_version 'latest' 'sometool' 'someorg/sometool' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'GitHub API rate limit exceeded.'

test_case 'an empty response for "latest" is reported clearly'
output=$(CURL_STUB_API_BODY='' github_resolve_version 'latest' 'sometool' 'someorg/sometool' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Empty response from GitHub API.'

test_case 'GITHUB_TOKEN, when set, is forwarded as an Authorization header'
: > "${CURL_LOG}"
output=$(GITHUB_TOKEN='s3cr3t' CURL_STUB_LOG="${CURL_LOG}" CURL_STUB_API_BODY='{"tag_name":"v1.2.3"}' github_resolve_version 'latest' 'sometool' 'someorg/sometool')
assert_contains "$(cat "${CURL_LOG}")" 'Authorization: token s3cr3t'

test_case 'strip_tag_v=0 preserves a tag_name with no leading v (e.g. delta-style repos)'
output=$(CURL_STUB_API_BODY='{"tag_name":"1.2.3"}' github_resolve_version 'latest' 'sometool' 'someorg/sometool' '' 0)
assert_equal "${output}" '1.2.3'

test_case 'a custom version_prefix is used both in the matching-refs URL and the ref prefix strip'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" CURL_STUB_API_BODY='[{"ref":"refs/tags/@scope/cli/4.5.0"}]' github_resolve_version '4.5' 'sometool' 'someorg/sometool' '@scope/cli/')
assert_contains "$(cat "${CURL_LOG}")" 'matching-refs/tags/@scope/cli/4.5'
assert_equal "${output}" '4.5.0'

# --- pip_resolve_version ---

PIP_LOG="${STUB_BIN_DIR}/pip-calls.log"
stub_cmd_logging pip

test_case 'a fully-qualified X.Y.Z version is returned as-is, with no pip call'
: > "${PIP_LOG}"
output=$(pip_resolve_version '1.2.3' 'sometool')
assert_equal "${output}" '1.2.3'
assert_equal "$(cat "${PIP_LOG}")" ''
use_stub pip

test_case "'latest' (default) resolves via 'pip index versions' and picks the first entry"
output=$(PIP_STUB_VERSIONS='1.3.0, 1.2.9, 1.2.0' pip_resolve_version 'latest' 'sometool')
assert_equal "${output}" '1.3.0'

test_case 'a partial version (X.Y) resolves to the newest matching patch release'
output=$(PIP_STUB_VERSIONS='1.3.0, 1.2.9, 1.2.0' pip_resolve_version '1.2' 'sometool')
assert_equal "${output}" '1.2.9'

test_case 'no matching version available resolves to an empty string'
output=$(PIP_STUB_VERSIONS='1.3.0, 1.2.9' pip_resolve_version '1.5' 'sometool')
assert_equal "${output}" ''

summary
