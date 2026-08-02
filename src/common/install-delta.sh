#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"

DELTA_VERSION_INPUT="${1:-latest}"

# ---

DELTA_BINARY_ARCHIVE=''

cleanup() {
	if [ -n "${DELTA_BINARY_ARCHIVE}" ]; then
		rm -f "${DELTA_BINARY_ARCHIVE}"
	fi
}

trap 'cleanup' EXIT

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64' 'armv7l=armhf' 'i386|i686|x86=i386')" || exit 1

# ---

DELTA_VERSION="$(github_resolve_version "${DELTA_VERSION_INPUT}" 'delta' 'dandavison/delta' '' 0)"
if [ -z "${DELTA_VERSION}" ]; then
	echo "Failed to find a valid delta version for '${DELTA_VERSION_INPUT}'." >&2
	exit 1
fi

DELTA_BINARY_ARCHIVE="$(mktemp)"
curl -sSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${ARCH_PLATFORM}.deb" \
    -o "${DELTA_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download delta package for version ${DELTA_VERSION}." >&2
	exit 1
fi

dpkg -i "${DELTA_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to install delta package." >&2
	exit 1
fi

echo "Installed delta version ${DELTA_VERSION} to /usr/local/bin/delta."
