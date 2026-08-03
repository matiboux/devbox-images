#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/exec.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/github_release.sh"

HADOLINT_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=x86_64' 'aarch64|arm64=arm64')" || exit 1

# ---

HADOLINT_VERSION="$(github_resolve_version "${HADOLINT_VERSION_INPUT}" 'hadolint' 'hadolint/hadolint')"
if [ -z "${HADOLINT_VERSION}" ]; then
	echo "Failed to find a valid hadolint version for '${HADOLINT_VERSION_INPUT}'." >&2
	exit 1
fi

install_github_raw_binary 'hadolint' \
	"https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-linux-${ARCH_PLATFORM}" \
	/usr/local/bin/hadolint || exit 1

echo "Installed hadolint version ${HADOLINT_VERSION} to /usr/local/bin/hadolint."
