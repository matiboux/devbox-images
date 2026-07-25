#!/bin/sh

NVM_DIR="${NVM_DIR:-/opt/nvm}"
if [ -s "${NVM_DIR}/nvm.sh" ]; then
    \. "${NVM_DIR}/nvm.sh"
fi

# Relay host-mounted Docker socket through a container-owned socket
DOCKER_SOCK="${DOCKER_SOCK:-/var/run/docker.sock}"
DOCKER_PROXY_SOCK="${DOCKER_PROXY_SOCK:-/var/run/docker-proxy.sock}"
if [ -S "${DOCKER_SOCK}" ] && command -v docker > /dev/null 2>&1 && command -v socat > /dev/null 2>&1; then
	rm -f "${DOCKER_PROXY_SOCK}"
	socat "UNIX-LISTEN:${DOCKER_PROXY_SOCK},fork,mode=660,group=docker" "UNIX-CONNECT:${DOCKER_SOCK}" 2>/dev/null &
	export DOCKER_HOST="unix://${DOCKER_PROXY_SOCK}"
fi

if [ $# -gt 0 ] && [ "$1" = "${1#-}" ]; then
	exec "$@"
else
	exec "${SHELL:-/bin/sh}" "$@"
fi
