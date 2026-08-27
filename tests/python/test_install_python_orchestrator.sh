#!/bin/sh
# Tests for src/python/install-python.sh
#
# COMMON_SCRIPTS_DIR is derived from "$0"'s own location
# ("$(dirname "$(dirname "$0")")/common"), not overridable via env var. So
# to test the orchestration logic (which sub-scripts get invoked, with what
# args, under which env vars) without ever touching the real, potentially
# unsafe install-*.sh scripts, we copy install-python.sh into a throwaway
# "src/python/" directory next to a fake "src/common/" full of logging
# stubs, and run it from there.

. "$(dirname "$0")/../support/shell/harness.sh"

REAL_SCRIPT="${PYTHON_DIR}/install-python.sh"

FAKE_ROOT="$(mktemp -d)"
mkdir -p "${FAKE_ROOT}/src/python" "${FAKE_ROOT}/src/common"
cp "${REAL_SCRIPT}" "${FAKE_ROOT}/src/python/install-python.sh"

CALL_LOG="${FAKE_ROOT}/calls.log"

for name in install-system-tools.sh install-yq.sh install-gh.sh install-glab.sh \
	install-python-tools.sh install-poetry.sh install-uv.sh install-nvm.sh \
	install-node.sh install-yarn.sh install-pnpm.sh install-docker-tools.sh \
	install-sudo.sh create-user.sh; do
	cat > "${FAKE_ROOT}/src/common/${name}" <<EOF
#!/bin/sh
echo "${name} \$*" >> '${CALL_LOG}'
EOF
	chmod +x "${FAKE_ROOT}/src/common/${name}"
done

run_orchestrator() {
	: > "${CALL_LOG}"
	sh "${FAKE_ROOT}/src/python/install-python.sh"
}

test_case 'with no optional env vars set, only the mandatory base scripts run'
: > "${CALL_LOG}"
sh "${FAKE_ROOT}/src/python/install-python.sh"
calls="$(cat "${CALL_LOG}")"
assert_contains "${calls}" 'install-system-tools.sh'
assert_contains "${calls}" 'install-yq.sh'
assert_contains "${calls}" 'install-python-tools.sh'
assert_not_contains "${calls}" 'install-poetry.sh'
assert_not_contains "${calls}" 'install-uv.sh'
assert_not_contains "${calls}" 'install-nvm.sh'
assert_not_contains "${calls}" 'install-node.sh'
assert_not_contains "${calls}" 'install-yarn.sh'
assert_not_contains "${calls}" 'install-pnpm.sh'
assert_not_contains "${calls}" 'install-docker-tools.sh'
assert_not_contains "${calls}" 'install-sudo.sh'
assert_not_contains "${calls}" 'create-user.sh'

test_case 'POETRY_VERSION triggers install-poetry.sh with that version'
: > "${CALL_LOG}"
POETRY_VERSION='2.1.5' sh "${FAKE_ROOT}/src/python/install-python.sh"
assert_contains "$(cat "${CALL_LOG}")" 'install-poetry.sh 2.1.5'

test_case 'NODE_VERSION triggers install-node.sh with that version'
: > "${CALL_LOG}"
NODE_VERSION='22' sh "${FAKE_ROOT}/src/python/install-python.sh"
calls="$(cat "${CALL_LOG}")"
assert_contains "${calls}" 'install-node.sh 22'
assert_not_contains "${calls}" 'install-nvm.sh'

test_case 'YARN_VERSION/PNPM_VERSION alone (without NODE_VERSION) do not trigger any install'
: > "${CALL_LOG}"
YARN_VERSION='4.5.0' PNPM_VERSION='9.12.0' sh "${FAKE_ROOT}/src/python/install-python.sh"
calls="$(cat "${CALL_LOG}")"
assert_not_contains "${calls}" 'install-node.sh'
assert_not_contains "${calls}" 'install-yarn.sh'
assert_not_contains "${calls}" 'install-pnpm.sh'

test_case 'NODE_VERSION with YARN_VERSION/PNPM_VERSION set forwards each version'
: > "${CALL_LOG}"
NODE_VERSION='22' YARN_VERSION='4.5.0' PNPM_VERSION='9.12.0' sh "${FAKE_ROOT}/src/python/install-python.sh"
calls="$(cat "${CALL_LOG}")"
assert_contains "${calls}" 'install-node.sh 22'
assert_contains "${calls}" 'install-yarn.sh 4.5.0'
assert_contains "${calls}" 'install-pnpm.sh 9.12.0'

test_case 'DOCKER_VERSION triggers install-docker-tools.sh'
: > "${CALL_LOG}"
DOCKER_VERSION='docker' sh "${FAKE_ROOT}/src/python/install-python.sh"
assert_contains "$(cat "${CALL_LOG}")" 'install-docker-tools.sh'

test_case 'LAZYDOCKER_VERSION/HADOLINT_VERSION/CTOP_VERSION/DIVE_VERSION/DOCKERC_VERSION/DOCKERX_VERSION alone (without DOCKER_VERSION) do not trigger install-docker-tools.sh'
: > "${CALL_LOG}"
LAZYDOCKER_VERSION='0.23.3' HADOLINT_VERSION='2.12.0' CTOP_VERSION='0.7.7' \
	DIVE_VERSION='0.13.1' DOCKERC_VERSION='2.2.0' DOCKERX_VERSION='0.1.0' \
	sh "${FAKE_ROOT}/src/python/install-python.sh"
assert_not_contains "$(cat "${CALL_LOG}")" 'install-docker-tools.sh'

test_case 'USER_SUDO=true triggers install-sudo.sh'
: > "${CALL_LOG}"
USER_SUDO='true' sh "${FAKE_ROOT}/src/python/install-python.sh"
assert_contains "$(cat "${CALL_LOG}")" 'install-sudo.sh'

test_case 'USER_SUDO set to anything other than "true" does not trigger install-sudo.sh'
: > "${CALL_LOG}"
USER_SUDO='yes' sh "${FAKE_ROOT}/src/python/install-python.sh"
assert_not_contains "$(cat "${CALL_LOG}")" 'install-sudo.sh'

test_case 'USERNAME alone triggers create-user.sh with all four positional args'
: > "${CALL_LOG}"
USERNAME='dev' USER_SUDO='true' sh "${FAKE_ROOT}/src/python/install-python.sh"
assert_contains "$(cat "${CALL_LOG}")" 'create-user.sh dev   true'

test_case 'none of USERNAME/USER_ID/GROUP_ID set does not trigger create-user.sh'
: > "${CALL_LOG}"
sh "${FAKE_ROOT}/src/python/install-python.sh"
assert_not_contains "$(cat "${CALL_LOG}")" 'create-user.sh'

rm -rf "${FAKE_ROOT}"

summary
