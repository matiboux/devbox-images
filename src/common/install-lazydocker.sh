#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"

LAZYDOCKER_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=x86_64' 'aarch64|arm64=arm64' 'i386|i686|x86=x86' 'armv7l=armv7' 'armv6l=armv6')" || exit 1

# ---

LAZYDOCKER_VERSION="$(github_resolve_version "${LAZYDOCKER_VERSION_INPUT}" 'lazydocker' 'jesseduffield/lazydocker')"
if [ -z "${LAZYDOCKER_VERSION}" ]; then
	echo "Failed to find a valid lazydocker version for '${LAZYDOCKER_VERSION_INPUT}'." >&2
	exit 1
fi

LAZYDOCKER_BINARY_ARCHIVE="$(mktemp)"
register_cleanup_path "${LAZYDOCKER_BINARY_ARCHIVE}"
curl -sSL "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_${ARCH_PLATFORM}.tar.gz" \
    -o "${LAZYDOCKER_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download lazydocker binary archive for version ${LAZYDOCKER_VERSION}." >&2
	exit 1
fi

LAZYDOCKER_EXTRACT_DIR="$(mktemp -d)"
register_cleanup_path "${LAZYDOCKER_EXTRACT_DIR}"
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
