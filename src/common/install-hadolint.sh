#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"

HADOLINT_VERSION_INPUT="${1:-latest}"

# ---

HADOLINT_BINARY=''

cleanup() {
	if [ -n "${HADOLINT_BINARY}" ]; then
		rm -f "${HADOLINT_BINARY}"
	fi
}

trap 'cleanup' EXIT

# Detect CPU platform
ARCH_PLATFORM="$(detect_arch 'x86_64=x86_64' 'aarch64|arm64=arm64')" || exit 1

# ---

HADOLINT_VERSION="$(github_resolve_version "${HADOLINT_VERSION_INPUT}" 'hadolint' 'hadolint/hadolint')"
if [ -z "${HADOLINT_VERSION}" ]; then
	echo "Failed to find a valid hadolint version for '${HADOLINT_VERSION_INPUT}'." >&2
	exit 1
fi

HADOLINT_BINARY="$(mktemp)"
curl -sSL "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-linux-${ARCH_PLATFORM}" \
    -o "${HADOLINT_BINARY}"
if [ $? -ne 0 ]; then
	echo "Failed to download hadolint binary for version ${HADOLINT_VERSION}." >&2
	exit 1
fi

install -m 0755 "${HADOLINT_BINARY}" /usr/local/bin/hadolint
if [ $? -ne 0 ]; then
	echo "Failed to install hadolint binary in /usr/local/bin." >&2
	exit 1
fi

echo "Installed hadolint version ${HADOLINT_VERSION} to /usr/local/bin/hadolint."
