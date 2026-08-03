#!/bin/sh
set -e

# Script to install Docker CLI tools (docker, buildx, compose plugins).

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/distro.sh"

DISTRO="$(detect_distro)"
PACKAGE_MANAGER_NAME="$(require_package_manager "${DISTRO}")" || exit 1

if [ "${PACKAGE_MANAGER_NAME}" = 'apk' ]; then

	# Install for Alpine Linux
	apk add --no-cache \
		docker-cli \
		docker-cli-buildx \
		docker-cli-compose

elif [ "${PACKAGE_MANAGER_NAME}" = 'apt-get' ]; then

	# Install for Debian/Ubuntu
	apt-get update
	apt-get install -y --no-install-recommends \
		ca-certificates \
		curl

	# Add Docker's official apt repository
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL "https://download.docker.com/linux/${DISTRO}/gpg" -o /etc/apt/keyrings/docker.asc
	chmod a+r /etc/apt/keyrings/docker.asc

	CODENAME="$(awk -F= '/^VERSION_CODENAME=/{print $2}' /etc/os-release | tr -d '"')"
	ARCH="$(dpkg --print-architecture)"
	echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DISTRO} ${CODENAME} stable" \
		> /etc/apt/sources.list.d/docker.list

	apt-get update
	apt-get install -y --no-install-recommends \
		docker-ce-cli \
		docker-buildx-plugin \
		docker-compose-plugin

else

	echo "Unsupported package manager: ${PACKAGE_MANAGER_NAME}" >&2
	exit 1

fi

# Create a Docker group for non-root users
if ! getent group docker > /dev/null 2>&1; then
	if command -v groupadd > /dev/null 2>&1; then
		groupadd --system docker
	elif command -v addgroup > /dev/null 2>&1; then
		addgroup -S docker
	fi
fi
