#!/bin/sh
# Tests for src/common/install-node.sh

. "$(dirname "$0")/harness.sh"

SCRIPT="${COMMON_DIR}/install-node.sh"

setup_stub_bin

# Creates a fake $NVM_DIR/nvm.sh that defines an `nvm` shell function
# logging its invocation, and returns the fresh NVM_DIR via stdout.
make_fake_nvm_dir() {
	log_file="$1"
	dir="$(mktemp -d)"
	cat > "${dir}/nvm.sh" <<EOF
nvm() {
	echo "nvm \$*" >> '${log_file}'
}
EOF
	echo "${dir}"
}

test_case 'errors out when nvm.sh cannot be found'
empty_dir="$(mktemp -d)"
output=$(NVM_DIR="${empty_dir}" sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Cannot find nvm'
rmdir "${empty_dir}"

test_case 'no argument defaults to installing the latest LTS release'
log_file="$(mktemp)"
nvm_dir="$(make_fake_nvm_dir "${log_file}")"
NVM_DIR="${nvm_dir}" sh "${SCRIPT}" > /dev/null 2>&1
assert_equal "$(cat "${log_file}")" 'nvm install --lts --latest-npm --default'
rm -rf "${nvm_dir}" "${log_file}"

test_case "'lts' argument installs the latest LTS release"
log_file="$(mktemp)"
nvm_dir="$(make_fake_nvm_dir "${log_file}")"
NVM_DIR="${nvm_dir}" sh "${SCRIPT}" 'lts' > /dev/null 2>&1
assert_equal "$(cat "${log_file}")" 'nvm install --lts --latest-npm --default'
rm -rf "${nvm_dir}" "${log_file}"

test_case "'latest' argument installs the latest Node.js release"
log_file="$(mktemp)"
nvm_dir="$(make_fake_nvm_dir "${log_file}")"
NVM_DIR="${nvm_dir}" sh "${SCRIPT}" 'latest' > /dev/null 2>&1
assert_equal "$(cat "${log_file}")" 'nvm install node --latest-npm --default'
rm -rf "${nvm_dir}" "${log_file}"

test_case 'a specific version string is passed straight through to nvm install'
log_file="$(mktemp)"
nvm_dir="$(make_fake_nvm_dir "${log_file}")"
NVM_DIR="${nvm_dir}" sh "${SCRIPT}" '20.11.0' > /dev/null 2>&1
assert_equal "$(cat "${log_file}")" 'nvm install 20.11.0 --latest-npm --default'
rm -rf "${nvm_dir}" "${log_file}"

test_case 'defaults NVM_DIR to /opt/nvm when unset'
if [ -s /opt/nvm/nvm.sh ]; then
	skip_case 'host has a real /opt/nvm/nvm.sh; running the script unstubbed here would trigger a real nvm install'
else
	output=$(env -u NVM_DIR sh "${SCRIPT}" 2>&1)
	code=$?
	assert_exit_code "${code}" 1
	assert_contains "${output}" 'Cannot find nvm'
fi

summary
