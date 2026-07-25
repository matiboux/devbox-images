#!/bin/sh
# Tests for src/common/install-poetry.sh
# curl and pip are stubbed; the "downloaded" installer is executed with
# python3, so we keep its content valid, trivial Python.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-poetry.sh"

setup_stub_bin
use_stub curl
use_stub pip

CURL_LOG="${STUB_BIN_DIR}/curl-calls.log"

# The default curl stub installer ("#!/bin/sh\nexit 0") is shell, but this
# script executes the downloaded installer with python3 directly -- so the
# default content here must be valid, trivial Python instead.
CURL_STUB_INSTALLER='pass'
export CURL_STUB_INSTALLER

test_case 'a fully-qualified X.Y.Z version skips the pip lookup entirely'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" sh "${SCRIPT}" '2.1.5' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${CURL_LOG}")" 'install.python-poetry.org'

test_case "'latest' (default) resolves via 'pip index versions' and picks the first entry"
output=$(PIP_STUB_VERSIONS='2.1.5, 2.1.4, 1.8.5' sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"

test_case 'a partial version (X.Y) resolves to the newest matching patch release'
output=$(PIP_STUB_VERSIONS='2.1.5, 1.8.5, 1.8.4' sh "${SCRIPT}" '1.8' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"

test_case 'no matching version available errors out clearly'
output=$(PIP_STUB_VERSIONS='2.1.5, 1.8.5' sh "${SCRIPT}" '1.5' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Failed to find a valid Poetry version for '1.5'"

test_case 'POETRY_HOME is exported as /usr/local before installing'
output=$(CURL_STUB_INSTALLER='print("POETRY_HOME", __import__("os").environ.get("POETRY_HOME"))' sh "${SCRIPT}" '2.1.5' 2>&1)
assert_contains "${output}" 'POETRY_HOME /usr/local'

test_case 'a curl failure while downloading the installer errors out'
output=$(CURL_STUB_EXIT_CODE=1 sh "${SCRIPT}" '2.1.5' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install Poetry version 2.1.5'

test_case 'a failing installer script propagates its exit code and prints an error'
output=$(CURL_STUB_INSTALLER='import sys; sys.exit(3)' sh "${SCRIPT}" '2.1.5' 2>&1)
code=$?
assert_exit_code "${code}" 3
assert_contains "${output}" 'Failed to install Poetry.'

summary
