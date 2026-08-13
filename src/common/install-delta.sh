#!/bin/sh

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/version.sh"
. "${COMMON_LIB_DIR}/arch.sh"
. "${COMMON_LIB_DIR}/tmpfile.sh"
. "${COMMON_LIB_DIR}/exec.sh"

DELTA_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64' 'armv7l=armhf' 'i386|i686|x86=i386')" || exit 1

# ---

DELTA_VERSION="$(github_resolve_version "${DELTA_VERSION_INPUT}" 'delta' 'dandavison/delta' '' 0)"
require_resolved_version "${DELTA_VERSION}" 'delta' "${DELTA_VERSION_INPUT}" || exit 1

DELTA_BINARY_ARCHIVE="$(mktemp)"
register_cleanup_path "${DELTA_BINARY_ARCHIVE}"
run_or_fail "Failed to download delta package for version ${DELTA_VERSION}." \
	curl -fsSL --retry 3 --retry-connrefused "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${ARCH_PLATFORM}.deb" \
	-o "${DELTA_BINARY_ARCHIVE}" || exit 1

run_or_fail 'Failed to install delta package.' \
	dpkg -i "${DELTA_BINARY_ARCHIVE}" || exit 1

echo "Installed delta version ${DELTA_VERSION} to /usr/local/bin/delta."
