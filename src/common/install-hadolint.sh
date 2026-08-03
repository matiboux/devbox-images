#!/bin/sh

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/version.sh"
. "${COMMON_LIB_DIR}/arch.sh"
. "${COMMON_LIB_DIR}/tmpfile.sh"
. "${COMMON_LIB_DIR}/exec.sh"
. "${COMMON_LIB_DIR}/github_release.sh"

HADOLINT_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=x86_64' 'aarch64|arm64=arm64')" || exit 1

# ---

HADOLINT_VERSION="$(github_resolve_version "${HADOLINT_VERSION_INPUT}" 'hadolint' 'hadolint/hadolint')"
require_resolved_version "${HADOLINT_VERSION}" 'hadolint' "${HADOLINT_VERSION_INPUT}" || exit 1

install_github_raw_binary 'hadolint' \
	"https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-linux-${ARCH_PLATFORM}" \
	/usr/local/bin/hadolint || exit 1

echo "Installed hadolint version ${HADOLINT_VERSION} to /usr/local/bin/hadolint."
