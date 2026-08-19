#!/bin/sh
# Tests for src/python/docker-entrypoint.sh's Docker socket GID alignment:
# docker/stat/getent/sudo are stubbed and DOCKER_SOCK points at a throwaway
# path, so no real system group state is touched.
#
# NOTE: the actual /etc/group edit (the docker GID rewrite) runs inside a
# `sudo sh -c '...'` invocation. Here that invocation is replaced by a stub,
# so this suite only verifies the entrypoint's own control flow (when it
# calls sudo, how it re-execs, what it warns about) -- not the embedded sed
# logic itself, which requires real root to exercise safely.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${PYTHON_DIR}/docker-entrypoint.sh"

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

# --- Docker-in-Docker (dockerd auto-start) ---

# Stubs sudo so `sudo -n dockerd ...` creates a real AF_UNIX socket at
# DOCKER_SOCK (simulating dockerd coming up), and everything else behaves
# like a no-op success.
stub_sudo_dockerd() {
	log_file="${STUB_BIN_DIR}/sudo.log"
	stub_cmd sudo "
echo \"sudo \$*\" >> '${log_file}'
if [ \"\$1\" = '-n' ] && [ \"\$2\" = 'dockerd' ]; then
	python3 -c '
import socket, os
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.bind(os.environ[\"DOCKER_SOCK\"])
'
	exit 0
fi
if [ \"\$1\" = '-n' ] && [ \"\$2\" = '-u' ]; then
	shift 3
	exec \"\$@\"
fi
exit 0
"
}

test_case 'no external Docker wired up, dockerd installed: it is started via sudo and DOCKER_HOST is exported once its socket appears'
stub_cmd docker 'exit 0'
stub_cmd dockerd 'exit 0'
stub_cmd stat 'echo 1000'
stub_cmd getent 'echo "docker:x:1000:user"'
stub_sudo_dockerd
output=$(DOCKER_SOCK="${FAKE_SOCK}" sh "${SCRIPT}" env 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" "DOCKER_HOST=unix://${FAKE_SOCK}"
sudo_log="$(cat "${STUB_BIN_DIR}/sudo.log")"
assert_contains "${sudo_log}" 'sudo -n dockerd'
rm -f "${FAKE_SOCK}" "${STUB_BIN_DIR}/sudo.log"

test_case 'DOCKER_HOST already set: dockerd is not auto-started even if installed'
stub_cmd docker 'exit 0'
stub_cmd dockerd 'exit 0'
stub_sudo_dockerd
output=$(DOCKER_HOST='tcp://dind:2375' DOCKER_SOCK="${WORKDIR}/missing.sock" sh "${SCRIPT}" env 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'DOCKER_HOST=tcp://dind:2375'
if [ -f "${STUB_BIN_DIR}/sudo.log" ]; then
	fail 'expected sudo to not run when DOCKER_HOST is already set'
fi
rm -f "${STUB_BIN_DIR}/sudo.log"

test_case 'dockerd installed but sudo unavailable: warns and continues without starting it'
stub_cmd docker 'exit 0'
stub_cmd dockerd 'exit 0'
rm -f "${STUB_BIN_DIR}/sudo"
if command -v sudo > /dev/null 2>&1; then
	skip_case 'host has a real sudo binary on PATH outside the stub dir; cannot safely simulate "sudo not installed" here'
else
	output=$(DOCKER_SOCK="${WORKDIR}/missing.sock" sh "${SCRIPT}" env 2>&1)
	code=$?
	assert_exit_code "${code}" 0 "${output}"
	assert_contains "${output}" 'Warning: Could not start Docker Engine (dockerd); sudo is not available.'
	assert_not_contains "${output}" 'DOCKER_HOST'
fi

test_case 'dockerd not installed: no attempt is made to start it'
stub_cmd docker 'exit 0'
rm -f "${STUB_BIN_DIR}/dockerd"
stub_sudo_dockerd
output=$(DOCKER_SOCK="${WORKDIR}/missing.sock" sh "${SCRIPT}" env 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_not_contains "${output}" 'DOCKER_HOST'
if [ -f "${STUB_BIN_DIR}/sudo.log" ]; then
	fail 'expected sudo to not run when dockerd is not installed'
fi
rm -f "${STUB_BIN_DIR}/sudo.log"

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

# --- NVM_DIR/nvm.sh sourcing (python's entrypoint only) ---

test_case 'an existing NVM_DIR/nvm.sh is sourced into the entrypoint shell before the final exec'
FAKE_NVM_DIR="${WORKDIR}/nvm"
mkdir -p "${FAKE_NVM_DIR}"
printf 'export NVM_SH_WAS_SOURCED=1\n' > "${FAKE_NVM_DIR}/nvm.sh"
stub_cmd docker 'exit 0'
output=$(NVM_DIR="${FAKE_NVM_DIR}" DOCKER_SOCK="${WORKDIR}/missing.sock" sh "${SCRIPT}" env 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" 'NVM_SH_WAS_SOURCED=1'
rm -rf "${FAKE_NVM_DIR}"

test_case 'no NVM_DIR/nvm.sh present: sourcing is skipped, the rest of the entrypoint still runs'
stub_cmd docker 'exit 0'
output=$(NVM_DIR="${WORKDIR}/missing-nvm" DOCKER_SOCK="${WORKDIR}/missing.sock" sh "${SCRIPT}" env 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"

rm -rf "${WORKDIR}"

summary
