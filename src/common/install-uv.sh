#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib"
for lib in version tmpfile exec; do . "${COMMON_LIB_DIR}/${lib}.sh"; done

UV_VERSION_INPUT=${1:-latest}

UV_HOME="${UV_HOME:-/opt/uv}"
UV_BIN_DIR="${UV_BIN_DIR:-/usr/local/bin}"

# ---

UV_VERSION="$(pip_resolve_version "${UV_VERSION_INPUT}" 'uv')"
if [ -z "${UV_VERSION}" ]; then
	echo "Failed to find a valid uv version for '${UV_VERSION_INPUT}'." >&2
	exit 1
fi

mkdir -p "${UV_HOME}"

# Set uv install parameters
export UV_NO_MODIFY_PATH='1'
export UV_UNMANAGED_INSTALL="${UV_HOME}"

UV_INSTALLER_FILE="$(mktemp)"
register_cleanup_path "${UV_INSTALLER_FILE}"
run_or_fail "Failed to install uv version ${UV_VERSION}." \
	curl -LsSf "https://astral.sh/uv/${UV_VERSION}/install.sh" -o "${UV_INSTALLER_FILE}" || exit 1

sh "${UV_INSTALLER_FILE}"
EXIT_CODE=$?
if [ "${EXIT_CODE}" -ne 0 ]; then
	echo "Failed to install uv." >&2
	exit "${EXIT_CODE}"
fi

# Allow all users to access uv's install directory and cache store
chmod -R 777 "${UV_HOME}"

# Create symlinks for uv and uvx
for name in uv uvx; do
	if [ -x "${UV_HOME}/${name}" ]; then
		ln -sf "${UV_HOME}/${name}" "${UV_BIN_DIR}/${name}"
	fi
done

echo "Installed uv version ${UV_VERSION} to ${UV_HOME}."
