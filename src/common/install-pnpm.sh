#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib"
. "${COMMON_LIB_DIR}/version.sh"
. "${COMMON_LIB_DIR}/tmpfile.sh"
. "${COMMON_LIB_DIR}/exec.sh"

PNPM_VERSION_INPUT="${1:-latest}"

PNPM_HOME="${PNPM_HOME:-/opt/pnpm}"
PNPM_BIN_DIR="${PNPM_BIN_DIR:-/usr/local/bin}"

# ---

PNPM_VERSION="$(github_resolve_version "${PNPM_VERSION_INPUT}" 'pnpm' 'pnpm/pnpm')"
require_resolved_version "${PNPM_VERSION}" 'pnpm' "${PNPM_VERSION_INPUT}" || exit 1

mkdir -p "${PNPM_HOME}"

PNPM_INSTALLER_FILE="$(mktemp)"
register_cleanup_path "${PNPM_INSTALLER_FILE}"
run_or_fail 'Failed to download pnpm installer.' \
	curl -fsSL 'https://get.pnpm.io/install.sh' -o "${PNPM_INSTALLER_FILE}" || exit 1

# Avoid relying on shell env files for binary discovery
PNPM_SHRC_FILE="$(mktemp)"
register_cleanup_path "${PNPM_SHRC_FILE}"

run_or_fail "Failed to install pnpm version ${PNPM_VERSION}." \
	env \
	PNPM_VERSION="${PNPM_VERSION}" \
	PNPM_HOME="${PNPM_HOME}" \
	ENV="${PNPM_SHRC_FILE}" \
	SHELL='/bin/sh' \
	sh "${PNPM_INSTALLER_FILE}" || exit 1

# Allow all users to access pnpm binaries and cache store
chmod -R 777 "${PNPM_HOME}"

# Create shims for pnpm, pnpx, pn, and pnx
# Shims preserve original paths for pnpm to resolve its sibling files correctly
for name in pnpm pnpx pn pnx; do
	target=''
	if [ -x "${PNPM_HOME}/bin/${name}" ]; then
		target="${PNPM_HOME}/bin/${name}"
	elif [ -x "${PNPM_HOME}/${name}" ]; then
		target="${PNPM_HOME}/${name}"
	fi
	if [ -n "${target}" ]; then
		printf '#!/bin/sh\nexec "%s" "$@"\n' "${target}" > "${PNPM_BIN_DIR}/${name}"
		chmod 755 "${PNPM_BIN_DIR}/${name}"
	fi
done

echo "Installed pnpm version ${PNPM_VERSION} to ${PNPM_HOME}."
