#!/bin/sh
# Tests for src/common/install-yarn.sh

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-yarn.sh"

setup_stub_bin
use_stub curl
stub_cmd_logging node
stub_cmd_logging corepack

test_case 'errors out early when a required system dependency (curl) is missing'
rm -f "${STUB_BIN_DIR}/curl"
output=$(PATH="${STUB_BIN_DIR}" /bin/sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Required command 'curl' not found"
use_stub curl

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

test_case 'a partial version resolves via matching-refs ("@yarnpkg/cli/" prefix stripping)'
output=$(CURL_STUB_API_BODY='[{"ref":"refs/tags/@yarnpkg/cli/4.5.0"},{"ref":"refs/tags/@yarnpkg/cli/4.5.10"}]' sh "${SCRIPT}" '4.5' 2>&1)
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
stub_cmd_logging corepack

test_case 'errors out when node is missing and nvm.sh cannot be found'
rm -f "${STUB_BIN_DIR}/node"
empty_dir="$(mktemp -d)"
output=$(NVM_DIR="${empty_dir}" sh "${SCRIPT}" '4.5.0' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to find Node and nvm. Please install Node before installing Yarn.'
rm -rf "${empty_dir}"

test_case 'defaults NVM_DIR to /opt/nvm when unset'
if [ -s /opt/nvm/nvm.sh ]; then
	skip_case 'host has a real /opt/nvm/nvm.sh; cannot exercise the "not found" branch here'
else
	output=$(sh "${SCRIPT}" '4.5.0' 2>&1)
	code=$?
	assert_exit_code "${code}" 1
	assert_contains "${output}" 'Failed to find Node and nvm. Please install Node before installing Yarn.'
fi
stub_cmd_logging node

test_case 'sources nvm and switches to the default Node version to find node and corepack on PATH'
rm -f "${STUB_BIN_DIR}/node" "${STUB_BIN_DIR}/corepack"
nvm_dir="$(mktemp -d)"
nvm_bin_dir="$(mktemp -d)"
stub_cmd_logging node 0 "${nvm_bin_dir}/node.log"
mv "${STUB_BIN_DIR}/node" "${nvm_bin_dir}/node"
stub_cmd_logging corepack 0 "${nvm_bin_dir}/corepack.log"
mv "${STUB_BIN_DIR}/corepack" "${nvm_bin_dir}/corepack"
cat > "${nvm_dir}/nvm.sh" <<EOF
nvm() {
	if [ "\$1" = 'use' ]; then
		PATH="${nvm_bin_dir}:\${PATH}"
	fi
}
EOF
output=$(NVM_DIR="${nvm_dir}" sh "${SCRIPT}" '4.5.0' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${nvm_bin_dir}/corepack.log")" 'install -g yarn@4.5.0'
rm -rf "${nvm_dir}" "${nvm_bin_dir}"
stub_cmd_logging node
stub_cmd_logging corepack

test_case "errors out when node is still missing after activating nvm"
rm -f "${STUB_BIN_DIR}/node"
nvm_dir="$(mktemp -d)"
cat > "${nvm_dir}/nvm.sh" <<'EOF'
nvm() { :; }
EOF
output=$(NVM_DIR="${nvm_dir}" sh "${SCRIPT}" '4.5.0' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to find Node after activating nvm. Please install Node before installing Yarn.'
rm -rf "${nvm_dir}"
stub_cmd_logging node

test_case 'falls back to installing corepack via npm, and succeeds once npm makes it available'
rm -f "${STUB_BIN_DIR}/corepack"
stub_cmd "npm" "echo \"npm \$*\" >> '${STUB_BIN_DIR}/npm.log'; if [ \"\$1\" = 'install' ]; then printf '#!/bin/sh\necho corepack \$*\n' > '${STUB_BIN_DIR}/corepack'; chmod +x '${STUB_BIN_DIR}/corepack'; fi"
output=$(sh "${SCRIPT}" '4.5.0' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${STUB_BIN_DIR}/npm.log")" 'install -g corepack'
assert_contains "${output}" 'Successfully installed Yarn version 4.5.0.'
rm -f "${STUB_BIN_DIR}/npm" "${STUB_BIN_DIR}/npm.log"
stub_cmd_logging corepack

test_case 'errors out when corepack is missing and npm is also missing'
rm -f "${STUB_BIN_DIR}/corepack" "${STUB_BIN_DIR}/npm"
output=$(sh "${SCRIPT}" '4.5.0' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to find corepack and npm. Please install Corepack or npm before installing Yarn.'
stub_cmd_logging corepack

test_case 'errors out when npm fails to make corepack available'
rm -f "${STUB_BIN_DIR}/corepack"
stub_cmd_logging npm
output=$(sh "${SCRIPT}" '4.5.0' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "$(cat "${STUB_BIN_DIR}/npm.log")" 'install -g corepack'
assert_contains "${output}" 'Failed to install corepack via npm. Please install Corepack before installing Yarn.'
rm -f "${STUB_BIN_DIR}/npm" "${STUB_BIN_DIR}/npm.log"
stub_cmd_logging corepack

summary
