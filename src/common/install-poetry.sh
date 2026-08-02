#!/bin/sh

POETRY_VERSION_INPUT=${1:-latest}

POETRY_HOME="${POETRY_HOME:-/opt/poetry}"
POETRY_BIN_DIR="${POETRY_BIN_DIR:-/usr/local/bin}"

# ---

POETRY_INSTALLER_FILE="$(mktemp)"

cleanup() {
    if [ -n "${POETRY_INSTALLER_FILE}" ]; then
        rm -f "${POETRY_INSTALLER_FILE}"
    fi
}

trap 'cleanup' EXIT

link_poetry_binaries() {
    for name in poetry; do
        if [ -x "${POETRY_HOME}/bin/${name}" ]; then
            ln -sf "${POETRY_HOME}/bin/${name}" "${POETRY_BIN_DIR}/${name}"
        fi
    done
}

install_poetry_and_exit() {
    PYTHON_COMMAND="$(command -v python3 || command -v python)"
    "${PYTHON_COMMAND}" "${POETRY_INSTALLER_FILE}"
    EXIT_CODE=$?
    if [ "${EXIT_CODE}" -ne 0 ]; then
        echo "Failed to install Poetry." >&2
        exit ${EXIT_CODE}
    fi
    # Allow all users to access Poetry's install directory and venv
    chmod -R 777 "${POETRY_HOME}"
    link_poetry_binaries
    exit 0
}

mkdir -p "${POETRY_HOME}"

# Set Poetry install parameters
export POETRY_HOME

# Try to install Poetry with the specified version
POETRY_VERSION_FULL="$(echo "${POETRY_VERSION_INPUT}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true)"
if [ -n "${POETRY_VERSION_FULL}" ]; then
	export POETRY_VERSION="${POETRY_VERSION_FULL}"
	curl -sSL https://install.python-poetry.org -o "${POETRY_INSTALLER_FILE}"
    if [ $? -ne 0 ]; then
        echo "Failed to install Poetry version ${POETRY_VERSION_FULL}." >&2
        exit 1
    fi
    install_poetry_and_exit
fi

get_poetry_version() {
    local version="$1"
    if [ -z "${version}" ] || [ "${version}" = 'latest' ]; then
        pip index versions poetry 2>/dev/null \
            | sed -n 's/^Available versions: //p' \
            | tr ',' '\n' \
            | sed 's/^ *//' \
            | head -n1
    else
        pip index versions poetry 2>/dev/null \
            | sed -n 's/^Available versions: //p' \
            | tr ',' '\n' \
            | sed 's/^ *//' \
            | grep -E "^$(echo "${version}" | sed 's/\.*$//; s/\./\\./g')(\\.[0-9]+)*$" \
            | head -n1
    fi
}

# Install Poetry with the inferred version
POETRY_VERSION_INFERRED="$(get_poetry_version "${POETRY_VERSION_INPUT}")"
if [ -n "${POETRY_VERSION_INFERRED}" ]; then
    curl -LsSf "https://install.python-poetry.org" -o "${POETRY_INSTALLER_FILE}"
    if [ $? -ne 0 ]; then
        echo "Failed to install Poetry version ${POETRY_VERSION_INFERRED}." >&2
        exit 1
    fi
    install_poetry_and_exit
fi

echo "Failed to find a valid Poetry version for '${POETRY_VERSION_INPUT}'." >&2
exit 1
