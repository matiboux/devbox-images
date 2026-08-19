#!/bin/sh

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/version.sh"
. "${COMMON_LIB_DIR}/arch.sh"
. "${COMMON_LIB_DIR}/tmpfile.sh"
. "${COMMON_LIB_DIR}/exec.sh"
. "${COMMON_LIB_DIR}/github_release.sh"

JQ_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64' 'i386|i686|x86=i386')" || exit 1

# ---

JQ_VERSION="$(github_resolve_version "${JQ_VERSION_INPUT}" 'jq' 'jqlang/jq' 'jq-' 0)"
JQ_VERSION="${JQ_VERSION#jq-}"
require_resolved_version "${JQ_VERSION}" 'jq' "${JQ_VERSION_INPUT}" || exit 1

install_github_raw_binary 'jq' \
	"https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${ARCH_PLATFORM}" \
	/usr/local/bin/jq || exit 1

echo "Installed jq version ${JQ_VERSION} to /usr/local/bin/jq."
