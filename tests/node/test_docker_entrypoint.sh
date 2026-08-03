#!/bin/sh
# Tests for src/node/docker-entrypoint.sh's Docker socket GID alignment:
# docker/stat/getent/sudo are stubbed and DOCKER_SOCK points at a throwaway
# path, so no real system group state is touched.
#
# NOTE: the actual /etc/group edit (the docker GID rewrite) runs inside a
# `sudo sh -c '...'` invocation. Here that invocation is replaced by a stub,
# so this suite only verifies the entrypoint's own control flow (when it
# calls sudo, how it re-execs, what it warns about) -- not the embedded sed
# logic itself, which requires real root to exercise safely.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${NODE_DIR}/docker-entrypoint.sh"

setup_stub_bin

WORKDIR="$(mktemp -d)"
FAKE_SOCK="${WORKDIR}/docker.sock"

# Creates a real AF_UNIX socket file, so `[ -S ... ]` checks in the script
# see an actual socket rather than a plain file.
make_fake_socket() {
	python3 -c '
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.bind(sys.argv[1])
' "$1"
}

# Stubs sudo so `sudo sh -c ...` (the group fixup) reports success/failure
# per $1, and `sudo -u <user> <cmd...>` actually execs the command (so the
# entrypoint's final exec still runs and its output can be asserted on).
stub_sudo() {
	fixup_exit_code="$1"
	log_file="${STUB_BIN_DIR}/sudo.log"
	stub_cmd sudo "
echo \"sudo \$*\" >> '${log_file}'
if [ \"\$1\" = '-n' ] && [ \"\$2\" = '-u' ]; then
	shift 3
	exec \"\$@\"
fi
exit ${fixup_exit_code}
"
}

test_case 'docker socket present, docker group GID already matches socket GID: DOCKER_HOST exported, sudo not invoked'
make_fake_socket "${FAKE_SOCK}"
stub_cmd docker 'exit 0'
stub_cmd stat 'echo 1000'
stub_cmd getent 'echo "docker:x:1000:user"'
output=$(DOCKER_SOCK="${FAKE_SOCK}" sh "${SCRIPT}" env 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" "DOCKER_HOST=unix://${FAKE_SOCK}"
if [ -f "${STUB_BIN_DIR}/sudo.log" ]; then
	fail 'expected sudo to not run when the docker group GID already matches'
fi
rm -f "${FAKE_SOCK}"

test_case 'docker socket present, GID differs and sudo fixup succeeds: re-execs via sudo -u to refresh groups'
make_fake_socket "${FAKE_SOCK}"
stub_cmd docker 'exit 0'
stub_cmd stat 'echo 2000'
stub_cmd getent 'echo "docker:x:1000:user"'
stub_sudo 0
output=$(DOCKER_SOCK="${FAKE_SOCK}" sh "${SCRIPT}" env 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" "DOCKER_HOST=unix://${FAKE_SOCK}"
sudo_log="$(cat "${STUB_BIN_DIR}/sudo.log")"
assert_contains "${sudo_log}" 'sudo -n sh -c'
assert_contains "${sudo_log}" "-n -u $(id -un) env"
rm -f "${FAKE_SOCK}" "${STUB_BIN_DIR}/sudo.log"

test_case 'docker socket present, GID differs and sudo fixup fails: warns, does not re-exec'
make_fake_socket "${FAKE_SOCK}"
stub_cmd docker 'exit 0'
stub_cmd stat 'echo 2000'
stub_cmd getent 'echo "docker:x:1000:user"'
stub_sudo 1
output=$(DOCKER_SOCK="${FAKE_SOCK}" sh "${SCRIPT}" env 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" "Warning: Could not align Docker group GID with Docker socket GID"
assert_contains "${output}" "DOCKER_HOST=unix://${FAKE_SOCK}"
sudo_log="$(cat "${STUB_BIN_DIR}/sudo.log")"
assert_not_contains "${sudo_log}" '-u'
rm -f "${FAKE_SOCK}" "${STUB_BIN_DIR}/sudo.log"

test_case 'docker socket present, GID differs and sudo unavailable: warns and continues without a fixup'
make_fake_socket "${FAKE_SOCK}"
stub_cmd docker 'exit 0'
stub_cmd stat 'echo 2000'
stub_cmd getent 'echo "docker:x:1000:user"'
rm -f "${STUB_BIN_DIR}/sudo"
if command -v sudo > /dev/null 2>&1; then
	skip_case 'host has a real sudo binary on PATH outside the stub dir; cannot safely simulate "sudo not installed" here'
else
	output=$(DOCKER_SOCK="${FAKE_SOCK}" sh "${SCRIPT}" env 2>&1)
	code=$?
	assert_exit_code "${code}" 0 "${output}"
	assert_contains "${output}" "Warning: Could not align Docker group GID with Docker socket GID"
	assert_contains "${output}" "DOCKER_HOST=unix://${FAKE_SOCK}"
fi
rm -f "${FAKE_SOCK}"

test_case 'no docker socket mounted: DOCKER_HOST is left unset, no GID alignment attempted'
stub_cmd docker 'exit 0'
output=$(DOCKER_SOCK="${WORKDIR}/missing.sock" sh "${SCRIPT}" env 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_not_contains "${output}" 'DOCKER_HOST'

test_case 'docker CLI not installed: GID alignment is skipped even if the socket exists'
rm -f "${STUB_BIN_DIR}/docker"
if command -v docker > /dev/null 2>&1; then
	skip_case 'host has a real docker binary on PATH outside the stub dir; cannot safely simulate "docker not installed" here'
else
	make_fake_socket "${FAKE_SOCK}"
	output=$(DOCKER_SOCK="${FAKE_SOCK}" sh "${SCRIPT}" env 2>&1)
	code=$?
	assert_exit_code "${code}" 0 "${output}"
	assert_not_contains "${output}" 'DOCKER_HOST'
	rm -f "${FAKE_SOCK}"
fi

rm -rf "${WORKDIR}"

summary
