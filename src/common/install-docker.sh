#!/bin/sh
set -e

# Script to install Docker CLI tools (docker, buildx, compose plugins) and socat.
# Socat allows relaying a host-mounted Docker socket to a container-owned socket.

# Detect Linux distribution
if [ -f /etc/os-release ]; then
    DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
else
    DISTRO='unknown'
fi

# Detect package manager based on distribution
PACKAGE_MANAGER=''
case "${DISTRO}" in
    alpine)
        PACKAGE_MANAGER="$(command -v apk)"
        ;;
    debian|ubuntu)
        PACKAGE_MANAGER="$(command -v apt-get)"
        ;;
esac

if [ -z "${PACKAGE_MANAGER}" ]; then
    echo "Unsupported distribution: ${DISTRO}" >&2
    exit 1
fi


PACKAGE_MANAGER_NAME="$(basename "${PACKAGE_MANAGER}")"

if [ "${PACKAGE_MANAGER_NAME}" = 'apk' ]; then

    # Install for Alpine Linux
    apk add --no-cache \
        docker-cli \
        docker-cli-buildx \
        docker-cli-compose \
        socat \
        libcap-utils

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
        docker-compose-plugin \
        socat \
        libcap2-bin

else

    echo "Unsupported package manager: ${PACKAGE_MANAGER_NAME}" >&2
    exit 1

fi

# Grant CAP_DAC_OVERRIDE capability to socat binary
# (relies on container having this capability, which Docker grants by default)
SOCAT_BIN="$(command -v socat)"
if command -v setcap > /dev/null 2>&1; then
    setcap cap_dac_override+ep "${SOCAT_BIN}" \
        || echo "Warning: Failed to set capabilities on ${SOCAT_BIN}; Docker socket proxying may not work for non-root users." >&2
else
    echo "Warning: Command 'setcap' not available; Docker socket proxying may not work for non-root users." >&2
fi

# Create a Docker group for non-root users
DOCKER_GID='998'
if ! getent group docker > /dev/null 2>&1; then
    if command -v groupadd > /dev/null 2>&1; then
        groupadd -g "${DOCKER_GID}" docker
    elif command -v addgroup > /dev/null 2>&1; then
        addgroup -g "${DOCKER_GID}" docker
    fi
fi

# Restrict access to the socat binary to Docker group members
chgrp docker "${SOCAT_BIN}" 2>/dev/null \
    || echo "Warning: failed to set 'docker' group ownership on ${SOCAT_BIN}." >&2
chmod 750 "${SOCAT_BIN}" 2>/dev/null \
    || echo "Warning: failed to restrict execute permission on ${SOCAT_BIN}." >&2
