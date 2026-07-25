#!/bin/sh
# Tests for src/common/entrypoint-shell.sh

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/entrypoint-shell.sh"

setup_stub_bin

test_case 'sources nvm.sh when present in NVM_DIR'
NVM_DIR="$(mktemp -d)"
cat > "${NVM_DIR}/nvm.sh" <<'EOF'
echo "nvm sourced" >&2
EOF
output=$(NVM_DIR="${NVM_DIR}" sh "${SCRIPT}" -c 'echo hi' 2>&1)
assert_contains "${output}" 'nvm sourced'
rm -rf "${NVM_DIR}"

test_case 'does not fail when nvm.sh is absent'
NVM_DIR="$(mktemp -d)"
output=$(NVM_DIR="${NVM_DIR}" sh "${SCRIPT}" -c 'echo hi' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
rmdir "${NVM_DIR}"

test_case 'command starting with an option is run via $SHELL wrapper (not exec-ed directly)'
# "-c 'echo hi'" starts with "-", so it takes the "exec ${SHELL:-/bin/sh} $@" path.
output=$(SHELL=/bin/sh sh "${SCRIPT}" -c 'echo hello-from-dash-arg' 2>&1)
assert_contains "${output}" 'hello-from-dash-arg'

test_case 'command not starting with a dash is exec-ed directly as argv'
output=$(sh "${SCRIPT}" echo 'direct-exec' 2>&1)
assert_equal "${output}" 'direct-exec'

test_case 'no arguments falls back to an interactive-less $SHELL invocation without hanging'
# With no args, "$1" is unset, "${1#-}" is also empty/unset -> "$1" = "${1#-}"
# is true (both empty), so it goes into the exec "$@" branch with an empty
# argument list, i.e. `exec` with no command -- which is a no-op success.
sh "${SCRIPT}" < /dev/null > /tmp/entrypoint_noargs.out 2>&1
code=$?
assert_exit_code "${code}" 0
rm -f /tmp/entrypoint_noargs.out

summary
