#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/exec.sh"

GLAB_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64' 'i386|i686|x86=386' 'armv7l|armv6l=armv6' 's390x=s390x' 'ppc64le=ppc64le' 'ppc64=ppc64')" || exit 1

# ---

GLAB_VERSION="$(gitlab_resolve_version "${GLAB_VERSION_INPUT}" 'gitlab-org%2Fcli')"
if [ -z "${GLAB_VERSION}" ]; then
	echo "Failed to find a valid glab version for '${GLAB_VERSION_INPUT}'." >&2
	exit 1
fi

GLAB_BINARY_ARCHIVE="$(mktemp)"
register_cleanup_path "${GLAB_BINARY_ARCHIVE}"
run_or_fail "Failed to download glab binary archive for version ${GLAB_VERSION}." \
	curl -sSL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
	-o "${GLAB_BINARY_ARCHIVE}" || exit 1

GLAB_EXTRACT_DIR="$(mktemp -d)"
register_cleanup_path "${GLAB_EXTRACT_DIR}"
run_or_fail 'Failed to extract glab binary from archive.' \
	tar -xzf "${GLAB_BINARY_ARCHIVE}" -C "${GLAB_EXTRACT_DIR}" || exit 1

run_or_fail 'Failed to install glab binary in /usr/local/bin.' \
	mv "${GLAB_EXTRACT_DIR}/bin/glab" /usr/local/bin/glab || exit 1

echo "Installed glab version ${GLAB_VERSION} to /usr/local/bin/glab."
