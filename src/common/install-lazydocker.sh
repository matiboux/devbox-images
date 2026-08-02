#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"

LAZYDOCKER_VERSION_INPUT="${1:-latest}"

# ---

LAZYDOCKER_BINARY_ARCHIVE=''
LAZYDOCKER_EXTRACT_DIR=''

cleanup() {
	if [ -n "${LAZYDOCKER_BINARY_ARCHIVE}" ]; then
		rm -f "${LAZYDOCKER_BINARY_ARCHIVE}"
	fi
	if [ -n "${LAZYDOCKER_EXTRACT_DIR}" ]; then
		rm -rf "${LAZYDOCKER_EXTRACT_DIR}"
	fi
}

trap 'cleanup' EXIT

# Detect CPU platform
ARCH_INPUT="$(uname -m)"
case "${ARCH_INPUT}" in
    x86_64)
        ARCH_PLATFORM='x86_64'
        ;;
    aarch64|arm64)
        ARCH_PLATFORM='arm64'
        ;;
    i386|i686|x86)
        ARCH_PLATFORM='x86'
        ;;
    armv7l)
        ARCH_PLATFORM='armv7'
        ;;
    armv6l)
        ARCH_PLATFORM='armv6'
        ;;
    *)
        echo "Unsupported architecture: ${ARCH_INPUT}" >&2
        exit 1
        ;;
esac

# ---

LAZYDOCKER_VERSION="$(github_resolve_version "${LAZYDOCKER_VERSION_INPUT}" 'lazydocker' 'jesseduffield/lazydocker')"
if [ -z "${LAZYDOCKER_VERSION}" ]; then
	echo "Failed to find a valid lazydocker version for '${LAZYDOCKER_VERSION_INPUT}'." >&2
	exit 1
fi

LAZYDOCKER_BINARY_ARCHIVE="$(mktemp)"
curl -sSL "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_${ARCH_PLATFORM}.tar.gz" \
    -o "${LAZYDOCKER_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download lazydocker binary archive for version ${LAZYDOCKER_VERSION}." >&2
	exit 1
fi

LAZYDOCKER_EXTRACT_DIR="$(mktemp -d)"
tar -xzf "${LAZYDOCKER_BINARY_ARCHIVE}" -C "${LAZYDOCKER_EXTRACT_DIR}"
if [ $? -ne 0 ]; then
    echo "Failed to extract lazydocker binary from archive." >&2
    exit 1
fi

mv "${LAZYDOCKER_EXTRACT_DIR}/lazydocker" /usr/local/bin/lazydocker
if [ $? -ne 0 ]; then
    echo "Failed to install lazydocker binary in /usr/local/bin." >&2
    exit 1
fi

echo "Installed lazydocker version ${LAZYDOCKER_VERSION} to /usr/local/bin/lazydocker."
