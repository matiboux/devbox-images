#!/bin/sh

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/version.sh"
. "${COMMON_LIB_DIR}/arch.sh"
. "${COMMON_LIB_DIR}/tmpfile.sh"
. "${COMMON_LIB_DIR}/exec.sh"
. "${COMMON_LIB_DIR}/github_release.sh"

GLAB_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64' 'i386|i686|x86=386' 'armv7l|armv6l=armv6' 's390x=s390x' 'ppc64le=ppc64le' 'ppc64=ppc64')" || exit 1

# ---

GLAB_VERSION="$(gitlab_resolve_version "${GLAB_VERSION_INPUT}" 'gitlab-org%2Fcli')"
require_resolved_version "${GLAB_VERSION}" 'glab' "${GLAB_VERSION_INPUT}" || exit 1

install_github_tarball_binary 'glab' \
	"https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
	'bin/glab' \
	/usr/local/bin/glab || exit 1

echo "Installed glab version ${GLAB_VERSION} to /usr/local/bin/glab."
