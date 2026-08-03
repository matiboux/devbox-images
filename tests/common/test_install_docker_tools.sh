#!/bin/sh
# Tests for src/common/install-docker-tools.sh
#
# Like tests/node/test_install_node_orchestrator.sh and
# tests/python/test_install_python_orchestrator.sh, this copies the real
# script into a throwaway "src/common/" directory full of logging stubs for
# the sub-scripts it shells out to, so we never touch the real (unsafe)
# install-docker.sh/install-lazydocker.sh/etc.

. "$(dirname "$0")/../support/shell/harness.sh"

REAL_SCRIPT="${COMMON_DIR}/install-docker-tools.sh"

FAKE_ROOT="$(mktemp -d)"
mkdir -p "${FAKE_ROOT}/src/common"
cp "${REAL_SCRIPT}" "${FAKE_ROOT}/src/common/install-docker-tools.sh"

CALL_LOG="${FAKE_ROOT}/calls.log"

for name in install-docker.sh install-lazydocker.sh install-hadolint.sh \
	install-ctop.sh install-dive.sh install-dockerc.sh install-dockerx.sh; do
	cat > "${FAKE_ROOT}/src/common/${name}" <<EOF
#!/bin/sh
echo "${name} \$*" >> '${CALL_LOG}'
EOF
	chmod +x "${FAKE_ROOT}/src/common/${name}"
done

SCRIPT="${FAKE_ROOT}/src/common/install-docker-tools.sh"

test_case 'installs Docker CLI tools and every companion dev tool, defaulting their versions to empty'
: > "${CALL_LOG}"
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
calls="$(cat "${CALL_LOG}")"
assert_contains "${calls}" 'install-docker.sh'
assert_contains "${calls}" 'install-lazydocker.sh'
assert_contains "${calls}" 'install-hadolint.sh'
assert_contains "${calls}" 'install-ctop.sh'
assert_contains "${calls}" 'install-dive.sh'
assert_contains "${calls}" 'install-dockerc.sh'
assert_contains "${calls}" 'install-dockerx.sh'

test_case 'each companion tool version env var is forwarded to its own script'
: > "${CALL_LOG}"
LAZYDOCKER_VERSION='0.23.3' HADOLINT_VERSION='2.12.0' CTOP_VERSION='0.7.7' \
	DIVE_VERSION='0.13.1' DOCKERC_VERSION='2.2.0' DOCKERX_VERSION='0.1.0' \
	sh "${SCRIPT}" 2>&1
calls="$(cat "${CALL_LOG}")"
assert_contains "${calls}" 'install-lazydocker.sh 0.23.3'
assert_contains "${calls}" 'install-hadolint.sh 2.12.0'
assert_contains "${calls}" 'install-ctop.sh 0.7.7'
assert_contains "${calls}" 'install-dive.sh 0.13.1'
assert_contains "${calls}" 'install-dockerc.sh 2.2.0'
assert_contains "${calls}" 'install-dockerx.sh 0.1.0'

test_case 'a failing sub-script aborts the rest of the sequence'
: > "${CALL_LOG}"
cat > "${FAKE_ROOT}/src/common/install-docker.sh" <<EOF
#!/bin/sh
echo "install-docker.sh \$*" >> '${CALL_LOG}'
exit 1
EOF
chmod +x "${FAKE_ROOT}/src/common/install-docker.sh"
output=$(sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_not_contains "$(cat "${CALL_LOG}")" 'install-lazydocker.sh'

rm -rf "${FAKE_ROOT}"

summary
