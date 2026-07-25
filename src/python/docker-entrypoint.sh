#!/bin/sh

NVM_DIR="${NVM_DIR:-/opt/nvm}"
if [ -s "${NVM_DIR}/nvm.sh" ]; then
    \. "${NVM_DIR}/nvm.sh"
fi

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
				conflict="$(getent group "${sock_gid}" | cut -d: -f1)"
				if [ -n "${conflict}" ] && [ "${conflict}" != "docker" ]; then
					free_gid=59999
					while getent group "${free_gid}" > /dev/null 2>&1; do
						free_gid=$((free_gid - 1))
					done
					sed -i "s/^${conflict}:\([^:]*\):[0-9]*:/${conflict}:\1:${free_gid}:/" /etc/group
				fi
				sed -i "s/^docker:\([^:]*\):[0-9]*:/docker:\1:${sock_gid}:/" /etc/group
			' sh "${SOCK_GID}" 2>/dev/null
		then
			# Re-exec as ourselves through sudo so supplementary groups are
			# re-resolved against the just-updated /etc/group; a plain root
			# edit doesn't retroactively update this process's own groups.
			REEXEC="sudo -u $(id -un)"
		else
			echo "Warning: Could not align Docker group GID with Docker socket GID; Docker access may not work for non-root users." >&2
		fi
	fi
fi

if [ $# -gt 0 ] && [ "$1" = "${1#-}" ]; then
	exec ${REEXEC} "$@"
else
	exec ${REEXEC} "${SHELL:-/bin/sh}" "$@"
fi
