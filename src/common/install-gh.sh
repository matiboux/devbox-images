#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/exec.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/github_release.sh"

GH_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64' 'i386|i686|x86=386' 'armv7l|armv6l=armv6' 's390x=s390x' 'ppc64le=ppc64le' 'ppc64=ppc64')" || exit 1

# ---

GH_VERSION="$(github_resolve_version "${GH_VERSION_INPUT}" 'gh' 'cli/cli')"
if [ -z "${GH_VERSION}" ]; then
	echo "Failed to find a valid gh version for '${GH_VERSION_INPUT}'." >&2
	exit 1
fi

install_github_tarball_binary 'gh' \
	"https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
	"gh_${GH_VERSION}_linux_${ARCH_PLATFORM}/bin/gh" \
	/usr/local/bin/gh || exit 1

echo "Installed gh version ${GH_VERSION} to /usr/local/bin/gh."
