#!/bin/sh

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/version.sh"
. "${COMMON_LIB_DIR}/arch.sh"
. "${COMMON_LIB_DIR}/tmpfile.sh"
. "${COMMON_LIB_DIR}/exec.sh"
. "${COMMON_LIB_DIR}/github_release.sh"

LAZYDOCKER_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=x86_64' 'aarch64|arm64=arm64' 'i386|i686|x86=x86' 'armv7l=armv7' 'armv6l=armv6')" || exit 1

# ---

LAZYDOCKER_VERSION="$(github_resolve_version "${LAZYDOCKER_VERSION_INPUT}" 'lazydocker' 'jesseduffield/lazydocker')"
require_resolved_version "${LAZYDOCKER_VERSION}" 'lazydocker' "${LAZYDOCKER_VERSION_INPUT}" || exit 1

install_github_tarball_binary 'lazydocker' \
	"https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_${ARCH_PLATFORM}.tar.gz" \
	'lazydocker' \
	/usr/local/bin/lazydocker || exit 1

echo "Installed lazydocker version ${LAZYDOCKER_VERSION} to /usr/local/bin/lazydocker."
