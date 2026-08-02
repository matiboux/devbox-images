#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"

PNPM_VERSION_INPUT="${1:-latest}"

PNPM_HOME="${PNPM_HOME:-/opt/pnpm}"
PNPM_BIN_DIR="${PNPM_BIN_DIR:-/usr/local/bin}"

# ---

PNPM_VERSION="$(github_resolve_version "${PNPM_VERSION_INPUT}" 'pnpm' 'pnpm/pnpm')" || exit 1
if [ -z "${PNPM_VERSION}" ]; then
	echo "Failed to find a valid pnpm version for '${PNPM_VERSION_INPUT}'." >&2
	exit 1
fi

mkdir -p "${PNPM_HOME}"

PNPM_INSTALLER_FILE="$(mktemp)"
register_cleanup_path "${PNPM_INSTALLER_FILE}"
curl -fsSL 'https://get.pnpm.io/install.sh' -o "${PNPM_INSTALLER_FILE}"
if [ $? -ne 0 ]; then
    echo 'Failed to download pnpm installer.' >&2
    exit 1
fi

# Avoid relying on shell env files for binary discovery
PNPM_SHRC_FILE="$(mktemp)"
register_cleanup_path "${PNPM_SHRC_FILE}"

PNPM_VERSION="${PNPM_VERSION}" \
PNPM_HOME="${PNPM_HOME}" \
ENV="${PNPM_SHRC_FILE}" \
SHELL='/bin/sh' \
sh "${PNPM_INSTALLER_FILE}"
if [ $? -ne 0 ]; then
    echo "Failed to install pnpm version ${PNPM_VERSION}." >&2
    exit 1
fi

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
