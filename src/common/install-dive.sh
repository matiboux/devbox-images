#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib"
for lib in version arch tmpfile exec github_release; do . "${COMMON_LIB_DIR}/${lib}.sh"; done

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

install_github_tarball_binary 'dive' \
	"https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
	'dive' \
	/usr/local/bin/dive || exit 1

echo "Installed dive version ${DIVE_VERSION} to /usr/local/bin/dive."
