#!/bin/sh
# Tests for src/common/install-python-tools.sh
#
# python3/python are stubbed as logging no-ops: this script's only action is
# `${PYTHON_COMMAND} -m pip install ...` against real package names, so we
# must never let it actually run un-intercepted.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-python-tools.sh"

setup_stub_bin

test_case 'installs the expected package list via python3, with expected pip flags'
stub_cmd_logging python3
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
calls="$(cat "${STUB_BIN_DIR}/python3.log")"
assert_contains "${calls}" '-m pip install'
assert_contains "${calls}" '--no-cache-dir'
assert_contains "${calls}" '--root-user-action ignore'
for package in black ipython mypy pip-tools pipx pre-commit pytest ruff ty; do
	assert_contains "${calls}" "${package}"
done

test_case 'falls back to python when python3 is not available'
rm -f "${STUB_BIN_DIR}/python3"
stub_cmd_logging python
output=$(PATH="${STUB_BIN_DIR}" /bin/sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/python.log")" '-m pip install'
stub_cmd_logging python3

test_case 'a failing pip install propagates its exit code'
stub_cmd_logging python3 7
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 7
stub_cmd_logging python3

summary
