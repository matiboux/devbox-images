#!/bin/sh
# Direct unit tests for src/common/lib/arch.sh (detect_arch), independent of
# any install-*.sh script that uses it.

. "$(dirname "$0")/../support/shell/harness.sh"

. "${COMMON_DIR}/lib/arch.sh"

setup_stub_bin

test_case 'a single-value pattern matches its exact uname -m value'
stub_cmd uname 'echo x86_64'
output=$(detect_arch 'x86_64=amd64')
code=$?
assert_exit_code "${code}" 0
assert_equal "${output}" 'amd64'

test_case 'a "|"-combined pattern matches any of its alternatives'
stub_cmd uname 'echo arm64'
output=$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64')
assert_equal "${output}" 'arm64'
stub_cmd uname 'echo aarch64'
output=$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64')
assert_equal "${output}" 'arm64'

test_case 'patterns are checked in order, first match wins'
stub_cmd uname 'echo x86_64'
output=$(detect_arch 'x86_64=first' 'x86_64=second')
assert_equal "${output}" 'first'

test_case 'an unrecognized uname -m value errors out clearly and returns non-zero'
stub_cmd uname 'echo sparc'
output=$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Unsupported architecture: sparc'

test_case 'called with no patterns at all always errors out'
stub_cmd uname 'echo x86_64'
output=$(detect_arch 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Unsupported architecture: x86_64'

rm -f "${STUB_BIN_DIR}/uname"

summary
