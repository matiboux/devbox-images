#!/bin/sh

DOCKER_SOCK="${DOCKER_SOCK:-/var/run/docker.sock}"

# Start an isolated Docker Engine (dockerd) for Docker-in-Docker use, if one
# is installed and no external Docker daemon is already wired up (a
# host-mounted socket, or an explicit DOCKER_HOST)
# (requires sudo; otherwise skipped with a warning)
if [ ! -S "${DOCKER_SOCK}" ] && [ -z "${DOCKER_HOST}" ] && command -v dockerd > /dev/null 2>&1; then
	if command -v sudo > /dev/null 2>&1; then
		sudo -n dockerd > /tmp/dockerd.log 2>&1 &
		DOCKERD_WAIT=0
		while [ ! -S "${DOCKER_SOCK}" ] && [ "${DOCKERD_WAIT}" -lt 30 ]; do
			sleep 0.5
			DOCKERD_WAIT=$((DOCKERD_WAIT + 1))
		done
		if [ ! -S "${DOCKER_SOCK}" ]; then
			echo "Warning: Docker Engine did not start in time; see /tmp/dockerd.log." >&2
		fi
	else
		echo "Warning: Could not start Docker Engine (dockerd); sudo is not available." >&2
	fi
fi

# Align Docker group GID with host-mounted Docker socket GID
# (requires sudo; otherwise skipped with a warning)
REEXEC=''
if [ -S "${DOCKER_SOCK}" ] && command -v docker > /dev/null 2>&1; then
	export DOCKER_HOST="unix://${DOCKER_SOCK}"
	SOCK_GID="$(stat -c '%g' "${DOCKER_SOCK}" 2>/dev/null)"
	DOCKER_GROUP_GID="$(getent group docker 2>/dev/null | cut -d: -f3)"
	if [ -n "${SOCK_GID}" ] && [ -n "${DOCKER_GROUP_GID}" ] && [ "${SOCK_GID}" != "${DOCKER_GROUP_GID}" ]; then
		if \
			command -v sudo > /dev/null 2>&1 \
			&& sudo -n sh -c '
				set -e
				sock_gid="$1"
				sed -i "s/^docker:\([^:]*\):[0-9]*:/docker:\1:${sock_gid}:/" /etc/group
			' sh "${SOCK_GID}" 2>/dev/null
		then
			# Re-exec as ourselves to refresh supplementary groups
			REEXEC="sudo -n -u $(id -un)"
		else
			echo "Warning: Could not align Docker group GID with Docker socket GID; Docker access may not work for non-root users." >&2
		fi
	fi
fi

if [ -z "${SHELL}" ]; then
	SHELL="$(command -v bash || command -v sh)"
fi

if [ $# -gt 0 ] && [ "$1" = "${1#-}" ]; then
	exec ${REEXEC} "$@"
else
	exec ${REEXEC} "${SHELL}" "$@"
fi
