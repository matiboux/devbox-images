#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"

LAZYGIT_VERSION_INPUT="${1:-latest}"

# ---

LAZYGIT_BINARY_ARCHIVE=''
LAZYGIT_EXTRACT_DIR=''

cleanup() {
	if [ -n "${LAZYGIT_BINARY_ARCHIVE}" ]; then
		rm -f "${LAZYGIT_BINARY_ARCHIVE}"
	fi
	if [ -n "${LAZYGIT_EXTRACT_DIR}" ]; then
		rm -rf "${LAZYGIT_EXTRACT_DIR}"
	fi
}

trap 'cleanup' EXIT

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=x86_64' 'aarch64|arm64=arm64' 'i386|i686|x86=32-bit' 'armv7l=armv7' 'armv6l=armv6')" || exit 1

# ---

LAZYGIT_VERSION="$(github_resolve_version "${LAZYGIT_VERSION_INPUT}" 'lazygit' 'jesseduffield/lazygit')"
if [ -z "${LAZYGIT_VERSION}" ]; then
	echo "Failed to find a valid lazygit version for '${LAZYGIT_VERSION_INPUT}'." >&2
	exit 1
fi

LAZYGIT_BINARY_ARCHIVE="$(mktemp)"
curl -sSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
    -o "${LAZYGIT_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download lazygit binary archive for version ${LAZYGIT_VERSION}." >&2
	exit 1
fi

LAZYGIT_EXTRACT_DIR="$(mktemp -d)"
tar -xzf "${LAZYGIT_BINARY_ARCHIVE}" -C "${LAZYGIT_EXTRACT_DIR}"
if [ $? -ne 0 ]; then
	echo "Failed to extract lazygit binary from archive." >&2
	exit 1
fi

mv "${LAZYGIT_EXTRACT_DIR}/lazygit" /usr/local/bin/lazygit
if [ $? -ne 0 ]; then
	echo "Failed to install lazygit binary in /usr/local/bin." >&2
	exit 1
fi

echo "Installed lazygit version ${LAZYGIT_VERSION} to /usr/local/bin/lazygit."
