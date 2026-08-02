#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"

DIVE_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64' 'ppc64le=ppc64le')" || exit 1

# ---

DIVE_VERSION="$(github_resolve_version "${DIVE_VERSION_INPUT}" 'dive' 'wagoodman/dive')"
if [ -z "${DIVE_VERSION}" ]; then
	echo "Failed to find a valid dive version for '${DIVE_VERSION_INPUT}'." >&2
	exit 1
fi

DIVE_BINARY_ARCHIVE="$(mktemp)"
register_cleanup_path "${DIVE_BINARY_ARCHIVE}"
curl -sSL "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
    -o "${DIVE_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download dive binary archive for version ${DIVE_VERSION}." >&2
	exit 1
fi

DIVE_EXTRACT_DIR="$(mktemp -d)"
register_cleanup_path "${DIVE_EXTRACT_DIR}"
tar -xzf "${DIVE_BINARY_ARCHIVE}" -C "${DIVE_EXTRACT_DIR}"
if [ $? -ne 0 ]; then
    echo "Failed to extract dive binary from archive." >&2
    exit 1
fi

mv "${DIVE_EXTRACT_DIR}/dive" /usr/local/bin/dive
if [ $? -ne 0 ]; then
    echo "Failed to install dive binary in /usr/local/bin." >&2
    exit 1
fi

echo "Installed dive version ${DIVE_VERSION} to /usr/local/bin/dive."
