#!/bin/sh
set -e

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/version.sh"

YARN_VERSION_INPUT="${1:-latest}"

NVM_DIR="${NVM_DIR:-/opt/nvm}"

# ---

# Check for required system dependencies
while read -r command_dep; do
	if ! command -v "${command_dep}" > /dev/null 2>&1; then
		echo "Error: Required command '${command_dep}' not found. Please install it first." >&2
		exit 1
	fi
done <<EOF
curl
grep
sed
sort
tail
EOF

if ! command -v node > /dev/null 2>&1; then

	if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
		echo 'Failed to find Node and nvm. Please install Node before installing Yarn.' >&2
		exit 1
	fi

	# Activate nvm and enable Node
	\. "${NVM_DIR}/nvm.sh"
	nvm use default > /dev/null 2>&1 || true

	if ! command -v node > /dev/null 2>&1; then
		echo 'Failed to find Node after activating nvm. Please install Node before installing Yarn.' >&2
		exit 1
	fi

fi

if ! command -v corepack > /dev/null 2>&1; then

	if ! command -v npm > /dev/null 2>&1; then
		echo 'Failed to find corepack and npm. Please install Corepack or npm before installing Yarn.' >&2
		exit 1
	fi

	# Install corepack via npm as a fallback
	npm install -g corepack > /dev/null 2>&1 || true

	if ! command -v corepack > /dev/null 2>&1; then
		echo 'Failed to install corepack via npm. Please install Corepack before installing Yarn.' >&2
		exit 1
	fi

fi

# ---

YARN_VERSION="$(github_resolve_version "${YARN_VERSION_INPUT}" 'Yarn' 'yarnpkg/berry' '@yarnpkg/cli/')"
require_resolved_version "${YARN_VERSION}" 'Yarn' "${YARN_VERSION_INPUT}" || exit 1

echo "Installing yarn version ${YARN_VERSION}..."
corepack install -g "yarn@${YARN_VERSION}" || {
	echo "Failed to install Yarn version ${YARN_VERSION}." >&2
	exit 1
}

echo "Successfully installed Yarn version ${YARN_VERSION}."
