#!/bin/sh
set -e

# Script to install system development tools and dependencies.

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
        bat \
        build-base \
        ca-certificates \
        curl \
        delta \
        fd \
        fzf \
        git \
        gnupg \
        htop \
        jq \
        less \
        make \
        musl-dev \
        nano \
        openssh \
        ripgrep \
        tar \
        tmux \
        tree \
        unzip \
        vim \
        wget

elif [ "${PACKAGE_MANAGER_NAME}" = 'apt-get' ]; then

    # Install for Debian/Ubuntu
    apt-get update
    apt-get install -y --no-install-recommends \
        bat \
        build-essential \
        ca-certificates \
        curl \
        fd-find \
        fzf \
        git \
        git-delta \
        gnupg \
        htop \
        jq \
        less \
        make \
        nano \
        openssh-client \
        ripgrep \
        tar \
        tmux \
        tree \
        unzip \
        vim \
        wget

    # Debian/Ubuntu package ships the binary as `fdfind` to avoid a name clash
    ln -sf "$(command -v fdfind)" /usr/local/bin/fd

else

    echo "Unsupported package manager: ${PACKAGE_MANAGER_NAME}" >&2
    exit 1

fi
