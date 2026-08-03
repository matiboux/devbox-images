#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/exec.sh"

LAZYGIT_VERSION_INPUT="${1:-latest}"

# ---

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=x86_64' 'aarch64|arm64=arm64' 'i386|i686|x86=32-bit' 'armv7l=armv7' 'armv6l=armv6')" || exit 1

# ---

LAZYGIT_VERSION="$(github_resolve_version "${LAZYGIT_VERSION_INPUT}" 'lazygit' 'jesseduffield/lazygit')"
if [ -z "${LAZYGIT_VERSION}" ]; then
	echo "Failed to find a valid lazygit version for '${LAZYGIT_VERSION_INPUT}'." >&2
	exit 1
fi

LAZYGIT_BINARY_ARCHIVE="$(mktemp)"
register_cleanup_path "${LAZYGIT_BINARY_ARCHIVE}"
run_or_fail "Failed to download lazygit binary archive for version ${LAZYGIT_VERSION}." \
	curl -sSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
	-o "${LAZYGIT_BINARY_ARCHIVE}" || exit 1

LAZYGIT_EXTRACT_DIR="$(mktemp -d)"
register_cleanup_path "${LAZYGIT_EXTRACT_DIR}"
run_or_fail 'Failed to extract lazygit binary from archive.' \
	tar -xzf "${LAZYGIT_BINARY_ARCHIVE}" -C "${LAZYGIT_EXTRACT_DIR}" || exit 1

run_or_fail 'Failed to install lazygit binary in /usr/local/bin.' \
	mv "${LAZYGIT_EXTRACT_DIR}/lazygit" /usr/local/bin/lazygit || exit 1

echo "Installed lazygit version ${LAZYGIT_VERSION} to /usr/local/bin/lazygit."
