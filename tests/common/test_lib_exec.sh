#!/bin/sh
# Direct unit tests for src/common/lib/exec.sh (run_or_fail), independent of
# any install-*.sh script that uses it.

. "$(dirname "$0")/../support/shell/harness.sh"

. "${COMMON_DIR}/lib/exec.sh"

setup_stub_bin

test_case 'a successful command returns 0 and prints nothing extra'
output=$(run_or_fail 'should not be printed' echo 'hello')
code=$?
assert_exit_code "${code}" 0
assert_equal "${output}" 'hello'

test_case 'a failing command prints the given error message to stderr and returns 1'
output=$(run_or_fail 'custom failure message' false 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'custom failure message'

test_case "the wrapped command's own stdout is not swallowed on failure"
stub_cmd_logging noisy-failure 1
output=$(run_or_fail 'wrapper error' sh -c 'echo "from the command"; exit 1' 2>&1)
assert_contains "${output}" 'from the command'
assert_contains "${output}" 'wrapper error'

test_case 'arguments are passed through to the wrapped command unmodified'
output=$(run_or_fail 'unused' printf '%s-%s\n' 'one' 'two words')
assert_equal "${output}" 'one-two words'

test_case '|| exit 1 propagates the failure out of the calling script'
result=$(sh -c '. "'"${COMMON_DIR}"'/lib/exec.sh"; run_or_fail "boom" false || exit 1; echo unreachable' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${result}" 'boom'
assert_not_contains "${result}" 'unreachable'

summary
