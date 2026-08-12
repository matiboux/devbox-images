#!/bin/sh
set -e

# Script to install system development tools and dependencies.

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_SCRIPT_DIR="$(CDPATH= cd -- "${CURRENT_DIR}" && pwd)"
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/distro.sh"
. "${COMMON_LIB_DIR}/apt.sh"

DISTRO="$(detect_distro)"
PACKAGE_MANAGER_NAME="$(require_package_manager "${DISTRO}")" || exit 1

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
		lazygit \
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
		wget \
		xz \
		zstd

elif [ "${PACKAGE_MANAGER_NAME}" = 'apt-get' ]; then

	# Install for Debian/Ubuntu
	apt_get_update_install \
		bat \
		build-essential \
		ca-certificates \
		curl \
		fd-find \
		fzf \
		git \
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
		wget \
		xz-utils \
		zstd

	if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
		# Create a symlink to `fd` for consistency with other distributions
		ln -sf "$(command -v fdfind)" /usr/local/bin/fd
	fi

	# Try to install community packages via apt-get first
	# Fall back to install scripts if not available via apt-get
	if ! apt-get install -y --no-install-recommends git-delta; then
		sh "${COMMON_SCRIPT_DIR}/install-delta.sh"
	fi
	if ! apt-get install -y --no-install-recommends lazygit; then
		sh "${COMMON_SCRIPT_DIR}/install-lazygit.sh"
	fi

else

	echo "Unsupported package manager: ${PACKAGE_MANAGER_NAME}" >&2
	exit 1

fi
