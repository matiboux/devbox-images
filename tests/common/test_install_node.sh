#!/bin/sh
# Tests for src/common/install-node.sh

. "$(dirname "$0")/../support/shell/harness.sh"

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

# install-node.sh derives its own "install-nvm.sh" sibling path from "$0",
# not overridable via env var. So to test the self-install trigger without
# ever touching the real install-nvm.sh, we copy install-node.sh into a
# throwaway "src/common/" directory next to a fake install-nvm.sh stub that
# logs its invocation and materializes a fake nvm.sh, then run it from there.
FAKE_ROOT="$(mktemp -d)"
mkdir -p "${FAKE_ROOT}/src/common"
cp "${SCRIPT}" "${FAKE_ROOT}/src/common/install-node.sh"

test_case 'installs nvm automatically when nvm.sh cannot be found'
empty_dir="$(mktemp -d)"
CALL_LOG="$(mktemp)"
cat > "${FAKE_ROOT}/src/common/install-nvm.sh" <<EOF
#!/bin/sh
echo "install-nvm.sh \$*" >> '${CALL_LOG}'
mkdir -p "\${NVM_DIR}"
cat > "\${NVM_DIR}/nvm.sh" <<'INNER'
nvm() { :; }
INNER
EOF
chmod +x "${FAKE_ROOT}/src/common/install-nvm.sh"
NVM_DIR="${empty_dir}" NVM_VERSION_INPUT='0.40.3' sh "${FAKE_ROOT}/src/common/install-node.sh" > /dev/null 2>&1
code=$?
assert_exit_code "${code}" 0
assert_contains "$(cat "${CALL_LOG}")" 'install-nvm.sh 0.40.3'
rm -rf "${empty_dir}"
rm -f "${CALL_LOG}"

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
	skip_case 'unstubbed default NVM_DIR (/opt/nvm) would trigger a real nvm install via install-nvm.sh; not safe to exercise here'
fi

rm -rf "${FAKE_ROOT}"

summary
