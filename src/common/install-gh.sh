#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"

GH_VERSION_INPUT="${1:-latest}"

# ---

GH_BINARY_ARCHIVE=''

cleanup() {
	if [ -n "${GH_BINARY_ARCHIVE}" ]; then
		rm -f "${GH_BINARY_ARCHIVE}"
	fi
}

trap 'cleanup' EXIT

# Detect CPU platform
ARCH_INPUT="$(uname -m)"
case "${ARCH_INPUT}" in
    x86_64)
        ARCH_PLATFORM='amd64'
        ;;
    aarch64|arm64)
        ARCH_PLATFORM='arm64'
        ;;
    i386|i686|x86)
        ARCH_PLATFORM='386'
        ;;
    armv7l|armv6l)
        ARCH_PLATFORM='armv6'
        ;;
    s390x)
        ARCH_PLATFORM='s390x'
        ;;
    ppc64le)
        ARCH_PLATFORM='ppc64le'
        ;;
    ppc64)
        ARCH_PLATFORM='ppc64'
        ;;
    *)
        echo "Unsupported architecture: ${ARCH_INPUT}" >&2
        exit 1
        ;;
esac

# ---

GH_VERSION="$(github_resolve_version "${GH_VERSION_INPUT}" 'gh' 'cli/cli')"
if [ -z "${GH_VERSION}" ]; then
	echo "Failed to find a valid gh version for '${GH_VERSION_INPUT}'." >&2
	exit 1
fi

GH_BINARY_ARCHIVE="$(mktemp)"
curl -sSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
    -o "${GH_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download gh binary archive for version ${GH_VERSION}." >&2
	exit 1
fi

GH_EXTRACT_DIR="$(mktemp -d)"
tar -xzf "${GH_BINARY_ARCHIVE}" -C "${GH_EXTRACT_DIR}"
if [ $? -ne 0 ]; then
    echo "Failed to extract gh binary from archive." >&2
    exit 1
fi

mv "${GH_EXTRACT_DIR}/gh_${GH_VERSION}_linux_${ARCH_PLATFORM}/bin/gh" /usr/local/bin/gh
if [ $? -ne 0 ]; then
    echo "Failed to install gh binary in /usr/local/bin." >&2
    exit 1
fi

rm -rf "${GH_EXTRACT_DIR}"

echo "Installed gh version ${GH_VERSION} to /usr/local/bin/gh."
