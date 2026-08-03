#!/bin/sh

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/version.sh"
. "${COMMON_LIB_DIR}/arch.sh"
. "${COMMON_LIB_DIR}/tmpfile.sh"
. "${COMMON_LIB_DIR}/exec.sh"
. "${COMMON_LIB_DIR}/github_release.sh"

YQ_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch \
	'x86_64=linux_amd64' \
	'aarch64|arm64=linux_arm64' \
	'i386|i686|x86=linux_386' \
	'armv7l|armv6l|armv5l|armv5b=linux_arm' \
	'loongarch64=linux_loong64' \
	'mips=linux_mips' \
	'mips64=linux_mips64' \
	'mips64el=linux_mips64le' \
	'mipsel=linux_mipsle' \
	'ppc64=linux_ppc64' \
	'ppc64le=linux_ppc64le' \
	'riscv64=linux_riscv64' \
	's390x=linux_s390x' \
)" || exit 1

# ---

YQ_VERSION="$(github_resolve_version "${YQ_VERSION_INPUT}" 'yq' 'mikefarah/yq')"
require_resolved_version "${YQ_VERSION}" 'yq' "${YQ_VERSION_INPUT}" || exit 1

install_github_tarball_binary 'yq' \
	"https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${ARCH_PLATFORM}.tar.gz" \
	"yq_${ARCH_PLATFORM}" \
	/usr/local/bin/yq || exit 1

echo "Installed yq version ${YQ_VERSION} to /usr/local/bin/yq."
