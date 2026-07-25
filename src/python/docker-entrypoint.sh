#!/bin/sh

NVM_DIR="${NVM_DIR:-/opt/nvm}"
if [ -s "${NVM_DIR}/nvm.sh" ]; then
    \. "${NVM_DIR}/nvm.sh"
fi

# If a Docker socket is bind-mounted (Docker-outside-of-Docker) and its
# group doesn't match ours, align the 'docker' group's GID to the
# socket's GID, then re-exec once (via sudo) to pick up the refreshed
# group membership. Requires passwordless sudo (SUDO_USER=true).
DOCKER_SOCK="${DOCKER_SOCK:-/var/run/docker.sock}"
if [ -z "${_DEVBOX_DOCKER_SOCK_FIXED}" ] && [ -S "${DOCKER_SOCK}" ] \
	&& command -v docker > /dev/null 2>&1 && command -v sudo > /dev/null 2>&1
then
	SOCK_GID="$(stat -c '%g' "${DOCKER_SOCK}" 2>/dev/null || true)"
	CURRENT_USER="$(id -un)"
	if [ -n "${SOCK_GID}" ] && ! id -G "${CURRENT_USER}" | tr ' ' '\n' | grep -qx "${SOCK_GID}"; then
		if getent group docker > /dev/null 2>&1; then
			sudo -n groupmod -g "${SOCK_GID}" docker 2>/dev/null || true
		else
			sudo -n groupadd -g "${SOCK_GID}" docker 2>/dev/null || true
			sudo -n usermod -aG docker "${CURRENT_USER}" 2>/dev/null || true
		fi
		export _DEVBOX_DOCKER_SOCK_FIXED=1
		exec sudo \
			-n -u "${CURRENT_USER}" \
			--preserve-env=_DEVBOX_DOCKER_SOCK_FIXED \
			"$0" "$@"
	fi
fi

if [ $# -gt 0 ] && [ "$1" = "${1#-}" ]; then
	exec "$@"
else
	exec "${SHELL:-/bin/sh}" "$@"
fi
