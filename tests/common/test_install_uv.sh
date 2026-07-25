#!/bin/sh
# Tests for src/common/install-uv.sh
# curl and pip are stubbed (tests/shell/stubs/) so no real network/PyPI
# access happens, and the "downloaded" installer is a script we control.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-uv.sh"

setup_stub_bin
use_stub curl
use_stub pip

CURL_LOG="${STUB_BIN_DIR}/curl-calls.log"

test_case 'a fully-qualified X.Y.Z version skips PyPI lookup entirely'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '0.8.13' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${CURL_LOG}")" 'astral.sh/uv/0.8.13/install.sh'

test_case "'latest' (default) resolves via 'pip index versions' and picks the first entry"
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" PIP_STUB_VERSIONS='0.9.2, 0.9.1, 0.8.0' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${CURL_LOG}")" 'astral.sh/uv/0.9.2/install.sh'

test_case 'a partial version (X.Y) resolves to the newest matching patch release'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" PIP_STUB_VERSIONS='0.9.0, 0.8.5, 0.8.1' sh "${SCRIPT}" '0.8' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${CURL_LOG}")" 'astral.sh/uv/0.8.5/install.sh'

test_case 'no matching version available errors out clearly'
output=$(PIP_STUB_VERSIONS='0.9.0, 0.8.5' sh "${SCRIPT}" '0.5' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Failed to find a valid uv version for '0.5'"

test_case 'a curl failure while downloading the installer errors out'
output=$(CURL_STUB_EXIT_CODE=1 sh "${SCRIPT}" '0.8.13' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install uv version 0.8.13'

test_case 'a failing installer script propagates its exit code and prints an error'
output=$(CURL_STUB_INSTALLER='#!/bin/sh
exit 7' sh "${SCRIPT}" '0.8.13' 2>&1)
code=$?
assert_exit_code "${code}" 7
assert_contains "${output}" 'Failed to install uv.'

test_case 'the installer is invoked with UV_NO_MODIFY_PATH and UV_UNMANAGED_INSTALL exported'
output=$(CURL_STUB_INSTALLER='#!/bin/sh
echo "modify=${UV_NO_MODIFY_PATH} install=${UV_UNMANAGED_INSTALL}"' sh "${SCRIPT}" '0.8.13' 2>&1)
assert_contains "${output}" 'modify=1 install=/usr/local/bin'

summary
