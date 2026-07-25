#!/bin/sh
# Tests for src/python/docker-entrypoint.sh's Docker socket relay:
# docker/socat are stubbed and DOCKER_SOCK/DOCKER_PROXY_SOCK point at
# throwaway paths, so no real socket proxying or system state is touched.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${PYTHON_DIR}/docker-entrypoint.sh"

setup_stub_bin

WORKDIR="$(mktemp -d)"
FAKE_SOCK="${WORKDIR}/docker.sock"
PROXY_SOCK="${WORKDIR}/proxy.sock"

# Creates a real AF_UNIX socket file, so `[ -S ... ]` checks in the script
# see an actual socket rather than a plain file.
make_fake_socket() {
	python3 -c '
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.bind(sys.argv[1])
' "$1"
}

# socat is started in the background (`&`), so give it a brief, bounded
# window to write its log before asserting on it.
wait_for_log() {
	i=0
	while [ ! -s "$1" ] && [ "${i}" -lt 20 ]; do
		i=$((i + 1))
		sleep 0.05
	done
}

test_case 'docker socket present with docker+socat available: starts a relay and exports DOCKER_HOST'
make_fake_socket "${FAKE_SOCK}"
stub_cmd docker 'exit 0'
stub_cmd_logging socat
output=$(DOCKER_SOCK="${FAKE_SOCK}" DOCKER_PROXY_SOCK="${PROXY_SOCK}" sh "${SCRIPT}" env 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "${output}" "DOCKER_HOST=unix://${PROXY_SOCK}"
wait_for_log "${STUB_BIN_DIR}/socat.log"
assert_contains "$(cat "${STUB_BIN_DIR}/socat.log")" "UNIX-LISTEN:${PROXY_SOCK}"
assert_contains "$(cat "${STUB_BIN_DIR}/socat.log")" "UNIX-CONNECT:${FAKE_SOCK}"
rm -f "${FAKE_SOCK}" "${PROXY_SOCK}" "${STUB_BIN_DIR}/socat.log"

test_case 'no docker socket mounted: DOCKER_HOST is left unset, socat is not started'
output=$(DOCKER_SOCK="${WORKDIR}/missing.sock" DOCKER_PROXY_SOCK="${PROXY_SOCK}" sh "${SCRIPT}" env 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_not_contains "${output}" 'DOCKER_HOST'
if [ -f "${STUB_BIN_DIR}/socat.log" ]; then
	fail 'expected socat to not run when no docker socket is mounted'
fi

test_case 'docker CLI not installed: relay is skipped even if the socket exists'
rm -f "${STUB_BIN_DIR}/docker"
if command -v docker > /dev/null 2>&1; then
	skip_case 'host has a real docker binary on PATH outside the stub dir; cannot safely simulate "docker not installed" here'
else
	make_fake_socket "${FAKE_SOCK}"
	output=$(DOCKER_SOCK="${FAKE_SOCK}" DOCKER_PROXY_SOCK="${PROXY_SOCK}" sh "${SCRIPT}" env 2>&1)
	code=$?
	assert_exit_code "${code}" 0 "${output}"
	assert_not_contains "${output}" 'DOCKER_HOST'
	rm -f "${FAKE_SOCK}"
fi

test_case 'socat not installed: relay is skipped even if the socket exists and docker is present'
stub_cmd docker 'exit 0'
rm -f "${STUB_BIN_DIR}/socat"
if command -v socat > /dev/null 2>&1; then
	skip_case 'host has a real socat binary on PATH outside the stub dir; cannot safely simulate "socat not installed" here'
else
	make_fake_socket "${FAKE_SOCK}"
	output=$(DOCKER_SOCK="${FAKE_SOCK}" DOCKER_PROXY_SOCK="${PROXY_SOCK}" sh "${SCRIPT}" env 2>&1)
	code=$?
	assert_exit_code "${code}" 0 "${output}"
	assert_not_contains "${output}" 'DOCKER_HOST'
	rm -f "${FAKE_SOCK}"
fi

rm -rf "${WORKDIR}"

summary
