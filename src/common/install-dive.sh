#!/bin/sh

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/version.sh"
. "${COMMON_LIB_DIR}/arch.sh"
. "${COMMON_LIB_DIR}/tmpfile.sh"
. "${COMMON_LIB_DIR}/exec.sh"
. "${COMMON_LIB_DIR}/github_release.sh"

DIVE_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64' 'ppc64le=ppc64le')" || exit 1

# ---

DIVE_VERSION="$(github_resolve_version "${DIVE_VERSION_INPUT}" 'dive' 'wagoodman/dive')"
require_resolved_version "${DIVE_VERSION}" 'dive' "${DIVE_VERSION_INPUT}" || exit 1

install_github_tarball_binary 'dive' \
	"https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
	'dive' \
	/usr/local/bin/dive || exit 1

echo "Installed dive version ${DIVE_VERSION} to /usr/local/bin/dive."
