#!/bin/sh
# Tests for src/common/install-pnpm.sh

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-pnpm.sh"

setup_stub_bin
use_stub curl

CURL_LOG="${STUB_BIN_DIR}/curl-calls.log"

PNPM_HOME_DIR="$(mktemp -d)"
PNPM_BIN_DIR="$(mktemp -d)"

test_case 'a fully-qualified X.Y.Z version skips the GitHub API lookup'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" PNPM_HOME="${PNPM_HOME_DIR}" PNPM_BIN_DIR="${PNPM_BIN_DIR}" sh "${SCRIPT}" '10.5.2' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
log="$(cat "${CURL_LOG}")"
assert_not_contains "${log}" 'api.github.com'
assert_contains "${output}" "Installed pnpm version 10.5.2 to ${PNPM_HOME_DIR}."
rm -rf "${PNPM_HOME_DIR}"; PNPM_HOME_DIR="$(mktemp -d)"

test_case "'latest' (default) resolves the tag_name from the GitHub releases API"
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" CURL_STUB_API_BODY='{"tag_name":"v10.5.2"}' PNPM_HOME="${PNPM_HOME_DIR}" PNPM_BIN_DIR="${PNPM_BIN_DIR}" sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" "Installed pnpm version 10.5.2 to ${PNPM_HOME_DIR}."
rm -rf "${PNPM_HOME_DIR}"; PNPM_HOME_DIR="$(mktemp -d)"

test_case 'a partial version resolves via matching-refs and picks the highest match'
output=$(CURL_STUB_API_BODY='[{"ref":"refs/tags/v10.5.2"},{"ref":"refs/tags/v10.5.10"}]' PNPM_HOME="${PNPM_HOME_DIR}" PNPM_BIN_DIR="${PNPM_BIN_DIR}" sh "${SCRIPT}" '10.5' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" "Installed pnpm version 10.5.10 to ${PNPM_HOME_DIR}."
rm -rf "${PNPM_HOME_DIR}"; PNPM_HOME_DIR="$(mktemp -d)"

test_case 'a 404 from the matching-refs endpoint reports the version was not found'
output=$(CURL_STUB_HTTP_CODE=404 CURL_STUB_API_BODY='[]' PNPM_HOME="${PNPM_HOME_DIR}" PNPM_BIN_DIR="${PNPM_BIN_DIR}" sh "${SCRIPT}" '99.99' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Version '99.99' not found in pnpm repository."

test_case 'a rate-limited (429) response is reported clearly'
output=$(CURL_STUB_HTTP_CODE=429 PNPM_HOME="${PNPM_HOME_DIR}" PNPM_BIN_DIR="${PNPM_BIN_DIR}" sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'GitHub API rate limit exceeded'

test_case 'an empty release-list response for latest fails with a clear message'
output=$(CURL_STUB_API_BODY='' PNPM_HOME="${PNPM_HOME_DIR}" PNPM_BIN_DIR="${PNPM_BIN_DIR}" sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Empty response from GitHub API.'

test_case 'a failure downloading the pnpm installer itself is reported'
output=$(CURL_STUB_EXIT_CODE=1 PNPM_HOME="${PNPM_HOME_DIR}" PNPM_BIN_DIR="${PNPM_BIN_DIR}" sh "${SCRIPT}" '10.5.2' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to download pnpm installer.'

test_case 'a failing installer script is reported as a failed install'
output=$(CURL_STUB_INSTALLER='#!/bin/sh
exit 1' PNPM_HOME="${PNPM_HOME_DIR}" PNPM_BIN_DIR="${PNPM_BIN_DIR}" sh "${SCRIPT}" '10.5.2' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install pnpm version 10.5.2.'

test_case 'a pre-11 (single-binary) layout gets a shim in PNPM_BIN_DIR that execs the real binary by absolute path'
: > "${CURL_LOG}"
mkdir -p "${PNPM_HOME_DIR}"
printf '#!/bin/sh\ntouch "%s/pnpm"; touch "%s/pnpx"; chmod +x "%s/pnpm" "%s/pnpx"\n' \
	"${PNPM_HOME_DIR}" "${PNPM_HOME_DIR}" "${PNPM_HOME_DIR}" "${PNPM_HOME_DIR}" > "${STUB_BIN_DIR}/fake-installer.sh"
output=$(CURL_STUB_INSTALLER="$(cat "${STUB_BIN_DIR}/fake-installer.sh")" PNPM_HOME="${PNPM_HOME_DIR}" PNPM_BIN_DIR="${PNPM_BIN_DIR}" sh "${SCRIPT}" '10.5.2' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${PNPM_BIN_DIR}/pnpm")" "exec \"${PNPM_HOME_DIR}/pnpm\" \"\$@\""
assert_contains "$(cat "${PNPM_BIN_DIR}/pnpx")" "exec \"${PNPM_HOME_DIR}/pnpx\" \"\$@\""
rm -rf "${PNPM_HOME_DIR}" "${PNPM_BIN_DIR}"
PNPM_HOME_DIR="$(mktemp -d)"; PNPM_BIN_DIR="$(mktemp -d)"

test_case 'an 11+ (bin/ subdirectory) layout gets a shim pointing at PNPM_HOME/bin, not PNPM_HOME'
mkdir -p "${PNPM_HOME_DIR}/bin"
printf '#!/bin/sh\ntouch "%s/bin/pnpm"; touch "%s/bin/pnpx"; chmod +x "%s/bin/pnpm" "%s/bin/pnpx"\n' \
	"${PNPM_HOME_DIR}" "${PNPM_HOME_DIR}" "${PNPM_HOME_DIR}" "${PNPM_HOME_DIR}" > "${STUB_BIN_DIR}/fake-installer.sh"
output=$(CURL_STUB_INSTALLER="$(cat "${STUB_BIN_DIR}/fake-installer.sh")" PNPM_HOME="${PNPM_HOME_DIR}" PNPM_BIN_DIR="${PNPM_BIN_DIR}" sh "${SCRIPT}" '11.0.0' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${PNPM_BIN_DIR}/pnpm")" "exec \"${PNPM_HOME_DIR}/bin/pnpm\" \"\$@\""
rm -rf "${PNPM_HOME_DIR}" "${PNPM_BIN_DIR}"
PNPM_HOME_DIR="$(mktemp -d)"; PNPM_BIN_DIR="$(mktemp -d)"

test_case 'defaults PNPM_HOME to /opt/pnpm when unset'
skip_case 'mkdir/chmod are not stubbed; exercising the real default would write to /opt/pnpm on this host'

rm -rf "${PNPM_HOME_DIR}" "${PNPM_BIN_DIR}"

summary
