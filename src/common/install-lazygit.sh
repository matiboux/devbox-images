#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib"
for lib in version arch tmpfile exec github_release; do . "${COMMON_LIB_DIR}/${lib}.sh"; done

LAZYGIT_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=x86_64' 'aarch64|arm64=arm64' 'i386|i686|x86=32-bit' 'armv7l=armv7' 'armv6l=armv6')" || exit 1

# ---

LAZYGIT_VERSION="$(github_resolve_version "${LAZYGIT_VERSION_INPUT}" 'lazygit' 'jesseduffield/lazygit')"
if [ -z "${LAZYGIT_VERSION}" ]; then
	echo "Failed to find a valid lazygit version for '${LAZYGIT_VERSION_INPUT}'." >&2
	exit 1
fi

install_github_tarball_binary 'lazygit' \
	"https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
	'lazygit' \
	/usr/local/bin/lazygit || exit 1

echo "Installed lazygit version ${LAZYGIT_VERSION} to /usr/local/bin/lazygit."
