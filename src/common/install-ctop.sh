#!/bin/sh

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/version.sh"
. "${COMMON_LIB_DIR}/arch.sh"
. "${COMMON_LIB_DIR}/tmpfile.sh"
. "${COMMON_LIB_DIR}/exec.sh"
. "${COMMON_LIB_DIR}/github_release.sh"

CTOP_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64' 'armv7l|armv6l=arm' 'ppc64le=ppc64le')" || exit 1

# ---

CTOP_VERSION="$(github_resolve_version "${CTOP_VERSION_INPUT}" 'ctop' 'bcicen/ctop')"
require_resolved_version "${CTOP_VERSION}" 'ctop' "${CTOP_VERSION_INPUT}" || exit 1

install_github_raw_binary 'ctop' \
	"https://github.com/bcicen/ctop/releases/download/v${CTOP_VERSION}/ctop-${CTOP_VERSION}-linux-${ARCH_PLATFORM}" \
	/usr/local/bin/ctop || exit 1

echo "Installed ctop version ${CTOP_VERSION} to /usr/local/bin/ctop."
