#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib"
for lib in version tmpfile exec; do . "${COMMON_LIB_DIR}/${lib}.sh"; done

POETRY_VERSION_INPUT=${1:-latest}

POETRY_HOME="${POETRY_HOME:-/opt/poetry}"
POETRY_BIN_DIR="${POETRY_BIN_DIR:-/usr/local/bin}"

# ---

POETRY_VERSION="$(pip_resolve_version "${POETRY_VERSION_INPUT}" 'poetry')"
require_resolved_version "${POETRY_VERSION}" 'Poetry' "${POETRY_VERSION_INPUT}" || exit 1

mkdir -p "${POETRY_HOME}"

# Set Poetry install parameters
export POETRY_HOME
export POETRY_VERSION

POETRY_INSTALLER_FILE="$(mktemp)"
register_cleanup_path "${POETRY_INSTALLER_FILE}"
run_or_fail "Failed to install Poetry version ${POETRY_VERSION}." \
	curl -sSL https://install.python-poetry.org -o "${POETRY_INSTALLER_FILE}" || exit 1

PYTHON_COMMAND="$(command -v python3 || command -v python)"
"${PYTHON_COMMAND}" "${POETRY_INSTALLER_FILE}"
EXIT_CODE=$?
if [ "${EXIT_CODE}" -ne 0 ]; then
	echo "Failed to install Poetry." >&2
	exit "${EXIT_CODE}"
fi

# Allow all users to access Poetry's install directory and venv
chmod -R 777 "${POETRY_HOME}"

# Create a symlink for poetry
if [ -x "${POETRY_HOME}/bin/poetry" ]; then
	ln -sf "${POETRY_HOME}/bin/poetry" "${POETRY_BIN_DIR}/poetry"
fi

echo "Installed Poetry version ${POETRY_VERSION} to ${POETRY_HOME}."
