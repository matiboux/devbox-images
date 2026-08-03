#!/bin/sh
set -e

NODE_VERSION_INPUT="${1:-lts}"
NVM_VERSION_INPUT="${NVM_VERSION_INPUT:-latest}"

NVM_DIR="${NVM_DIR:-/opt/nvm}"

# ---

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_DIR="$(CDPATH= cd -- "${CURRENT_DIR}" && pwd)"

if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
	# nvm is not installed, install it first
	sh "${COMMON_DIR}/install-nvm.sh" "${NVM_VERSION_INPUT}"
fi

\. "${NVM_DIR}/nvm.sh"

if [ -z "${NODE_VERSION_INPUT}" ] || [ "${NODE_VERSION_INPUT}" = 'lts' ]; then

	# Install latest LTS version of Node.js
	nvm install --lts --latest-npm --default

elif [ "${NODE_VERSION_INPUT}" = 'latest' ]; then

	# Install latest version of Node.js
	nvm install node --latest-npm --default

else

	# Install specific version of Node.js
	nvm install "${NODE_VERSION_INPUT}" --latest-npm --default

fi
