#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/arch.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/exec.sh"

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

HADOLINT_BINARY="$(mktemp)"
register_cleanup_path "${HADOLINT_BINARY}"
run_or_fail "Failed to download hadolint binary for version ${HADOLINT_VERSION}." \
	curl -sSL "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-linux-${ARCH_PLATFORM}" \
	-o "${HADOLINT_BINARY}" || exit 1

run_or_fail 'Failed to install hadolint binary in /usr/local/bin.' \
	install -m 0755 "${HADOLINT_BINARY}" /usr/local/bin/hadolint || exit 1

echo "Installed hadolint version ${HADOLINT_VERSION} to /usr/local/bin/hadolint."
