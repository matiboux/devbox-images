#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/exec.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/github_release.sh"

CTOP_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64' 'armv7l|armv6l=arm' 'ppc64le=ppc64le')" || exit 1

# ---

CTOP_VERSION="$(github_resolve_version "${CTOP_VERSION_INPUT}" 'ctop' 'bcicen/ctop')"
if [ -z "${CTOP_VERSION}" ]; then
	echo "Failed to find a valid ctop version for '${CTOP_VERSION_INPUT}'." >&2
	exit 1
fi

install_github_raw_binary 'ctop' \
	"https://github.com/bcicen/ctop/releases/download/v${CTOP_VERSION}/ctop-${CTOP_VERSION}-linux-${ARCH_PLATFORM}" \
	/usr/local/bin/ctop || exit 1

echo "Installed ctop version ${CTOP_VERSION} to /usr/local/bin/ctop."
