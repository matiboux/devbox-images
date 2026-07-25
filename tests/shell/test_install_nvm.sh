#!/bin/sh
# Tests for src/common/install-nvm.sh
#
# IMPORTANT SAFETY NOTE: on a successful version resolution, this script
# goes on to `touch /etc/bash_env` and append to /etc/bash.bashrc --
# hardcoded, real, absolute system paths with no override. That is not
# safe to exercise on a real host/container filesystem from a test suite.
# So this suite deliberately only covers the branches that exit *before*
# that point: unresolvable/invalid versions, GitHub API errors, and the
# Alpine-unsupported check. The success path is intentionally left
# untested here (verified only through the actual Docker image build).

. "$(dirname "$0")/harness.sh"

SCRIPT="${COMMON_DIR}/install-nvm.sh"

setup_stub_bin
use_stub curl

# Defense in depth: even though every test case below is chosen so version
# resolution FAILS before the script ever reaches `mkdir "${NVM_DIR}"`,
# point NVM_DIR at a throwaway directory anyway, in case a future edit to
# this suite accidentally introduces a case that resolves successfully.
NVM_DIR="$(mktemp -d)"
export NVM_DIR

test_case 'Alpine Linux is rejected outright'
if [ -f /etc/os-release ] && grep -qi '^ID=alpine' /etc/os-release 2>/dev/null; then
	output=$(sh "${SCRIPT}" 2>&1)
	code=$?
	assert_exit_code "${code}" 1
	assert_contains "${output}" 'Alpine Linux is not supported'
else
	skip_case 'host is not Alpine; cannot exercise this branch without faking /etc/os-release'
fi

test_case "'latest' (default) fails cleanly when the GitHub API is unreachable"
output=$(CURL_STUB_EXIT_CODE=1 sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to connect to GitHub API.'
assert_contains "${output}" "Failed to find a valid nvm version for 'latest'."

test_case 'a rate-limited (429) response is reported clearly'
output=$(CURL_STUB_HTTP_CODE=429 sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'GitHub API rate limit exceeded'

test_case 'an empty releases/latest response is reported clearly'
output=$(CURL_STUB_API_BODY='' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Empty response from GitHub API.'

test_case 'a 404 on a specific version is reported as version-not-found'
# NOTE: must be a *partial* version (not X.Y.Z) -- a fully-qualified
# version bypasses the GitHub API lookup entirely via the fast-path regex
# and would otherwise sail through to the unsafe mkdir/touch section.
output=$(CURL_STUB_HTTP_CODE=404 CURL_STUB_API_BODY='[]' sh "${SCRIPT}" '99.99' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Version '99.99' not found in nvm repository."

test_case 'an unparseable API response is reported clearly'
output=$(CURL_STUB_API_BODY='{"unexpected":"shape"}' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to parse version from GitHub API response.'

summary
