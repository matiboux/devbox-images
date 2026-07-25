#!/bin/sh
# Tests for src/common/install-yarn.sh

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-yarn.sh"

setup_stub_bin
use_stub curl
stub_cmd_logging corepack

test_case 'errors out early when a required dependency (corepack) is missing'
rm -f "${STUB_BIN_DIR}/corepack"
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Required command 'corepack' not found"
stub_cmd_logging corepack

test_case 'a fully-qualified X.Y.Z version skips the GitHub API lookup and installs via corepack'
output=$(sh "${SCRIPT}" '4.5.0' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/corepack.log")" 'install -g yarn@4.5.0'
assert_contains "${output}" 'Successfully installed Yarn version 4.5.0.'
rm -f "${STUB_BIN_DIR}/corepack.log"

test_case "'latest' (default) resolves the tag_name from the GitHub releases API"
output=$(CURL_STUB_API_BODY='{"tag_name":"v4.5.0"}' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/corepack.log")" 'install -g yarn@4.5.0'
rm -f "${STUB_BIN_DIR}/corepack.log"

# NOTE: locks in actual current behavior. Yarn tags are really published as
# "@yarnpkg/cli/X.Y.Z", but the matching-refs branch below queries and
# strips a hardcoded "refs/tags/v" prefix (copied from the uv/pnpm/nvm
# template), not the real yarn tag format. So a ref shaped like the real
# yarn convention would NOT be stripped correctly (see the ref format used
# here, which is what the sed pattern actually expects).
test_case 'a partial version resolves via matching-refs (hardcoded "v" prefix stripping)'
output=$(CURL_STUB_API_BODY='[{"ref":"refs/tags/v4.5.0"},{"ref":"refs/tags/v4.5.10"}]' sh "${SCRIPT}" '4.5' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/corepack.log")" 'install -g yarn@4.5.10'
rm -f "${STUB_BIN_DIR}/corepack.log"

test_case 'a 404 from matching-refs is reported as version-not-found'
output=$(CURL_STUB_HTTP_CODE=404 CURL_STUB_API_BODY='[]' sh "${SCRIPT}" '99.99' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Version '99.99' not found in Yarn repository."

test_case 'a corepack install failure is reported and exits non-zero'
stub_cmd_logging corepack 1
output=$(sh "${SCRIPT}" '4.5.0' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install Yarn version 4.5.0.'

summary
