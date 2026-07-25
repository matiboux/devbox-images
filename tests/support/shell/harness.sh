#!/bin/sh
# Minimal POSIX-ish test harness for the shell scripts in src/common and
# src/python. No external dependencies (bats, shunit2, ...) required.
#
# Usage (from a test file under tests/common/ or tests/python/):
#   . "$(dirname "$0")/../support/shell/harness.sh"
#   test_case "description of the test"
#   ... run script, capture output ...
#   assert_equal "$actual" "$expected"
#   ...
#   summary   # at the end of the file

# $0 here is the *sourcing* test script's own path (POSIX/bash don't change
# $0 across `.`), which lives in tests/common/ or tests/python/ -- two
# levels below the repo root.
REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
COMMON_DIR="${REPO_ROOT}/src/common"
PYTHON_DIR="${REPO_ROOT}/src/python"
STUBS_DIR="${REPO_ROOT}/tests/support/shell/stubs"

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_TEST=''
STUB_BIN_DIR=''
ORIGINAL_PATH="${PATH}"

# --- stub command management ---

setup_stub_bin() {
	STUB_BIN_DIR="$(mktemp -d)"
	PATH="${STUB_BIN_DIR}:${ORIGINAL_PATH}"
	export PATH
}

teardown_stub_bin() {
	if [ -n "${STUB_BIN_DIR}" ] && [ -d "${STUB_BIN_DIR}" ]; then
		rm -rf "${STUB_BIN_DIR}"
	fi
	STUB_BIN_DIR=''
	PATH="${ORIGINAL_PATH}"
	export PATH
}

# stub_cmd <name> <heredoc body via stdin>
# Creates an executable stub in STUB_BIN_DIR that shadows a real command.
stub_cmd() {
	name="$1"
	body="$2"
	printf '#!/bin/sh\n%s\n' "${body}" > "${STUB_BIN_DIR}/${name}"
	chmod +x "${STUB_BIN_DIR}/${name}"
}

# Records every invocation (command name + args) of a stub to a log file,
# then exits with the given code (default 0). Useful to assert on how a
# script called an external command.
stub_cmd_logging() {
	name="$1"
	exit_code="${2:-0}"
	log_file="${3:-${STUB_BIN_DIR}/${name}.log}"
	stub_cmd "${name}" "echo \"${name} \$*\" >> '${log_file}'; exit ${exit_code}"
}

# use_stub <name> — installs one of the pre-written, configurable stubs
# from tests/shell/stubs/ (e.g. curl, pip) into STUB_BIN_DIR.
use_stub() {
	name="$1"
	cp "${STUBS_DIR}/${name}" "${STUB_BIN_DIR}/${name}"
	chmod +x "${STUB_BIN_DIR}/${name}"
}

# --- assertions ---

test_case() {
	CURRENT_TEST="$1"
	TESTS_RUN=$((TESTS_RUN + 1))
}

fail() {
	TESTS_FAILED=$((TESTS_FAILED + 1))
	echo "FAIL: ${CURRENT_TEST}: $1" >&2
}

TESTS_SKIPPED=0

# skip_case <reason> — marks the current test_case as skipped instead of run.
# Use this instead of asserting when the environment can't safely or
# reliably exercise a branch (e.g. it would require mutating real system
# files like /etc/sudoers outside of our control).
skip_case() {
	TESTS_RUN=$((TESTS_RUN - 1))
	TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
	echo "SKIP: ${CURRENT_TEST}: $1" >&2
}

assert_equal() {
	if [ "$1" != "$2" ]; then
		fail "expected '$2', got '$1'${3:+ ($3)}"
	fi
}

assert_not_equal() {
	if [ "$1" = "$2" ]; then
		fail "expected value to differ from '$2'${3:+ ($3)}"
	fi
}

assert_contains() {
	case "$1" in
		*"$2"*) ;;
		*) fail "expected output to contain '$2', got: $1" ;;
	esac
}

assert_not_contains() {
	case "$1" in
		*"$2"*) fail "expected output to NOT contain '$2', got: $1" ;;
		*) ;;
	esac
}

assert_exit_code() {
	if [ "$1" != "$2" ]; then
		fail "expected exit code $2, got $1${3:+ ($3)}"
	fi
}

summary() {
	teardown_stub_bin
	echo ''
	echo "$(basename "$0"): ${TESTS_RUN} tests run, ${TESTS_FAILED} failed, ${TESTS_SKIPPED} skipped."
	if [ "${TESTS_FAILED}" -gt 0 ]; then
		exit 1
	fi
	exit 0
}
