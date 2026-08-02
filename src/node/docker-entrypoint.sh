#!/bin/sh

# Align Docker group GID with host-mounted Docker socket GID
# (requires sudo; otherwise skipped with a warning)
DOCKER_SOCK="${DOCKER_SOCK:-/var/run/docker.sock}"
REEXEC=''
if [ -S "${DOCKER_SOCK}" ] && command -v docker > /dev/null 2>&1; then
	export DOCKER_HOST="unix://${DOCKER_SOCK}"
	SOCK_GID="$(stat -c '%g' "${DOCKER_SOCK}" 2>/dev/null)"
	DOCKER_GROUP_GID="$(getent group docker 2>/dev/null | cut -d: -f3)"
	if [ -n "${SOCK_GID}" ] && [ -n "${DOCKER_GROUP_GID}" ] && [ "${SOCK_GID}" != "${DOCKER_GROUP_GID}" ]; then
		if \
			command -v sudo > /dev/null 2>&1 \
			&& sudo sh -c '
				set -e
				sock_gid="$1"
				sed -i "s/^docker:\([^:]*\):[0-9]*:/docker:\1:${sock_gid}:/" /etc/group
			' sh "${SOCK_GID}" 2>/dev/null
		then
			# Re-exec as ourselves to refresh supplementary groups
			REEXEC="sudo -u $(id -un)"
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
