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

POETRY_HOME_DIR="$(mktemp -d)"
POETRY_BIN_DIR="$(mktemp -d)"

test_case 'a fully-qualified X.Y.Z version skips the pip lookup entirely'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" POETRY_HOME="${POETRY_HOME_DIR}" POETRY_BIN_DIR="${POETRY_BIN_DIR}" sh "${SCRIPT}" '2.1.5' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${CURL_LOG}")" 'install.python-poetry.org'
rm -rf "${POETRY_HOME_DIR}"; POETRY_HOME_DIR="$(mktemp -d)"

test_case "'latest' (default) resolves via 'pip index versions' and picks the first entry"
output=$(PIP_STUB_VERSIONS='2.1.5, 2.1.4, 1.8.5' POETRY_HOME="${POETRY_HOME_DIR}" POETRY_BIN_DIR="${POETRY_BIN_DIR}" sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
rm -rf "${POETRY_HOME_DIR}"; POETRY_HOME_DIR="$(mktemp -d)"

test_case 'a partial version (X.Y) resolves to the newest matching patch release'
output=$(PIP_STUB_VERSIONS='2.1.5, 1.8.5, 1.8.4' POETRY_HOME="${POETRY_HOME_DIR}" POETRY_BIN_DIR="${POETRY_BIN_DIR}" sh "${SCRIPT}" '1.8' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
rm -rf "${POETRY_HOME_DIR}"; POETRY_HOME_DIR="$(mktemp -d)"

test_case 'no matching version available errors out clearly'
output=$(PIP_STUB_VERSIONS='2.1.5, 1.8.5' POETRY_HOME="${POETRY_HOME_DIR}" POETRY_BIN_DIR="${POETRY_BIN_DIR}" sh "${SCRIPT}" '1.5' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Failed to find a valid Poetry version for '1.5'"

test_case 'POETRY_HOME is exported to the configured directory before installing'
output=$(CURL_STUB_INSTALLER='print("POETRY_HOME", __import__("os").environ.get("POETRY_HOME"))' POETRY_HOME="${POETRY_HOME_DIR}" POETRY_BIN_DIR="${POETRY_BIN_DIR}" sh "${SCRIPT}" '2.1.5' 2>&1)
assert_contains "${output}" "POETRY_HOME ${POETRY_HOME_DIR}"

test_case 'a curl failure while downloading the installer errors out'
output=$(CURL_STUB_EXIT_CODE=1 POETRY_HOME="${POETRY_HOME_DIR}" POETRY_BIN_DIR="${POETRY_BIN_DIR}" sh "${SCRIPT}" '2.1.5' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install Poetry version 2.1.5'

test_case 'a failing installer script propagates its exit code and prints an error'
output=$(CURL_STUB_INSTALLER='import sys; sys.exit(3)' POETRY_HOME="${POETRY_HOME_DIR}" POETRY_BIN_DIR="${POETRY_BIN_DIR}" sh "${SCRIPT}" '2.1.5' 2>&1)
code=$?
assert_exit_code "${code}" 3
assert_contains "${output}" 'Failed to install Poetry.'

test_case 'installed poetry binary gets a symlink in POETRY_BIN_DIR and POETRY_HOME is world-accessible'
rm -rf "${POETRY_HOME_DIR}" "${POETRY_BIN_DIR}"
POETRY_HOME_DIR="$(mktemp -d)"; POETRY_BIN_DIR="$(mktemp -d)"
output=$(CURL_STUB_INSTALLER="import os
os.makedirs(os.path.join(os.environ['POETRY_HOME'], 'bin'), exist_ok=True)
with open(os.path.join(os.environ['POETRY_HOME'], 'bin', 'poetry'), 'w') as f:
    f.write('#!/bin/sh\n')
os.chmod(os.path.join(os.environ['POETRY_HOME'], 'bin', 'poetry'), 0o755)
" POETRY_HOME="${POETRY_HOME_DIR}" POETRY_BIN_DIR="${POETRY_BIN_DIR}" sh "${SCRIPT}" '2.1.5' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_equal "$(readlink "${POETRY_BIN_DIR}/poetry")" "${POETRY_HOME_DIR}/bin/poetry"
perms="$(stat -c '%a' "${POETRY_HOME_DIR}")"
assert_equal "${perms}" '777'
rm -rf "${POETRY_HOME_DIR}" "${POETRY_BIN_DIR}"
POETRY_HOME_DIR="$(mktemp -d)"; POETRY_BIN_DIR="$(mktemp -d)"

test_case 'defaults POETRY_HOME to /opt/poetry when unset'
skip_case 'mkdir/chmod are not stubbed; exercising the real default would write to /opt/poetry on this host'

rm -rf "${POETRY_HOME_DIR}" "${POETRY_BIN_DIR}"

summary
