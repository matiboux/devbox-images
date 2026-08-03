#!/bin/sh

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/version.sh"
. "${COMMON_LIB_DIR}/arch.sh"
. "${COMMON_LIB_DIR}/tmpfile.sh"
. "${COMMON_LIB_DIR}/exec.sh"
. "${COMMON_LIB_DIR}/github_release.sh"

LAZYGIT_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=x86_64' 'aarch64|arm64=arm64' 'i386|i686|x86=32-bit' 'armv7l=armv7' 'armv6l=armv6')" || exit 1

# ---

LAZYGIT_VERSION="$(github_resolve_version "${LAZYGIT_VERSION_INPUT}" 'lazygit' 'jesseduffield/lazygit')"
require_resolved_version "${LAZYGIT_VERSION}" 'lazygit' "${LAZYGIT_VERSION_INPUT}" || exit 1

install_github_tarball_binary 'lazygit' \
	"https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
	'lazygit' \
	/usr/local/bin/lazygit || exit 1

echo "Installed lazygit version ${LAZYGIT_VERSION} to /usr/local/bin/lazygit."
