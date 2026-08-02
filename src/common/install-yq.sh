#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"

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
if [ -z "${YQ_VERSION}" ]; then
	echo "Failed to find a valid yq version for '${YQ_VERSION_INPUT}'." >&2
	exit 1
fi

YQ_BINARY_ARCHIVE="$(mktemp)"
register_cleanup_path "${YQ_BINARY_ARCHIVE}"
curl -sSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${ARCH_PLATFORM}.tar.gz" \
    -o "${YQ_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download yq binary archive for version ${YQ_VERSION}." >&2
	exit 1
fi

YQ_EXTRACT_DIR="$(mktemp -d)"
register_cleanup_path "${YQ_EXTRACT_DIR}"
tar -xzf "${YQ_BINARY_ARCHIVE}" -C "${YQ_EXTRACT_DIR}"
if [ $? -ne 0 ]; then
    echo "Failed to extract yq binary from archive." >&2
    exit 1
fi

mv "${YQ_EXTRACT_DIR}/yq_${ARCH_PLATFORM}" /usr/local/bin/yq
if [ $? -ne 0 ]; then
    echo "Failed to install yq binary in /usr/local/bin." >&2
    exit 1
fi

echo "Installed yq version ${YQ_VERSION} to /usr/local/bin/yq."
