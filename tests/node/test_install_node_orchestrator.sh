#!/bin/sh
# Tests for src/node/install-node.sh
#
# COMMON_SCRIPTS_DIR is derived from "$0"'s own location
# ("$(dirname "$(dirname "$0")")/common"), not overridable via env var. So
# to test the orchestration logic (which sub-scripts get invoked, with what
# args, under which env vars) without ever touching the real, potentially
# unsafe install-*.sh scripts, we copy install-node.sh into a throwaway
# "src/node/" directory next to a fake "src/common/" full of logging
# stubs, and run it from there.

. "$(dirname "$0")/../support/shell/harness.sh"

REAL_SCRIPT="${NODE_DIR}/install-node.sh"

FAKE_ROOT="$(mktemp -d)"
mkdir -p "${FAKE_ROOT}/src/node" "${FAKE_ROOT}/src/common"
cp "${REAL_SCRIPT}" "${FAKE_ROOT}/src/node/install-node.sh"

CALL_LOG="${FAKE_ROOT}/calls.log"

for name in install-system-tools.sh install-yq.sh install-gh.sh install-glab.sh \
	install-yarn.sh install-pnpm.sh install-docker-tools.sh \
	install-sudo.sh create-user.sh; do
	cat > "${FAKE_ROOT}/src/common/${name}" <<EOF
#!/bin/sh
echo "${name} \$*" >> '${CALL_LOG}'
EOF
	chmod +x "${FAKE_ROOT}/src/common/${name}"
done

test_case 'with no optional env vars set, only the mandatory base scripts run'
: > "${CALL_LOG}"
sh "${FAKE_ROOT}/src/node/install-node.sh"
calls="$(cat "${CALL_LOG}")"
assert_contains "${calls}" 'install-system-tools.sh'
assert_contains "${calls}" 'install-yq.sh'
assert_not_contains "${calls}" 'install-yarn.sh'
assert_not_contains "${calls}" 'install-pnpm.sh'
assert_not_contains "${calls}" 'install-docker-tools.sh'
assert_not_contains "${calls}" 'install-sudo.sh'
assert_not_contains "${calls}" 'create-user.sh'

test_case 'YARN_VERSION triggers install-yarn.sh with that version'
: > "${CALL_LOG}"
YARN_VERSION='4.5.0' sh "${FAKE_ROOT}/src/node/install-node.sh"
assert_contains "$(cat "${CALL_LOG}")" 'install-yarn.sh 4.5.0'

test_case 'PNPM_VERSION triggers install-pnpm.sh with that version'
: > "${CALL_LOG}"
PNPM_VERSION='10.5.0' sh "${FAKE_ROOT}/src/node/install-node.sh"
assert_contains "$(cat "${CALL_LOG}")" 'install-pnpm.sh 10.5.0'

test_case 'DOCKER_VERSION triggers install-docker-tools.sh'
: > "${CALL_LOG}"
DOCKER_VERSION='docker' sh "${FAKE_ROOT}/src/node/install-node.sh"
assert_contains "$(cat "${CALL_LOG}")" 'install-docker-tools.sh'

test_case 'LAZYDOCKER_VERSION/HADOLINT_VERSION/CTOP_VERSION/DIVE_VERSION/DOCKERC_VERSION/DOCKERX_VERSION alone (without DOCKER_VERSION) do not trigger install-docker-tools.sh'
: > "${CALL_LOG}"
LAZYDOCKER_VERSION='0.23.3' HADOLINT_VERSION='2.12.0' CTOP_VERSION='0.7.7' \
	DIVE_VERSION='0.13.1' DOCKERC_VERSION='2.2.0' DOCKERX_VERSION='0.1.0' \
	sh "${FAKE_ROOT}/src/node/install-node.sh"
assert_not_contains "$(cat "${CALL_LOG}")" 'install-docker-tools.sh'

test_case 'USER_SUDO=true triggers install-sudo.sh'
: > "${CALL_LOG}"
USER_SUDO='true' sh "${FAKE_ROOT}/src/node/install-node.sh"
assert_contains "$(cat "${CALL_LOG}")" 'install-sudo.sh'

test_case 'USER_SUDO set to anything other than "true" does not trigger install-sudo.sh'
: > "${CALL_LOG}"
USER_SUDO='yes' sh "${FAKE_ROOT}/src/node/install-node.sh"
assert_not_contains "$(cat "${CALL_LOG}")" 'install-sudo.sh'

test_case 'USERNAME alone triggers create-user.sh with all four positional args'
: > "${CALL_LOG}"
USERNAME='dev' USER_SUDO='true' sh "${FAKE_ROOT}/src/node/install-node.sh"
assert_contains "$(cat "${CALL_LOG}")" 'create-user.sh dev   true'

test_case 'none of USERNAME/USER_ID/GROUP_ID set does not trigger create-user.sh'
: > "${CALL_LOG}"
sh "${FAKE_ROOT}/src/node/install-node.sh"
assert_not_contains "$(cat "${CALL_LOG}")" 'create-user.sh'

rm -rf "${FAKE_ROOT}"

summary
