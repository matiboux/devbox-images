#!/bin/sh

NVM_DIR="${NVM_DIR:-/opt/nvm}"
if [ -s "${NVM_DIR}/nvm.sh" ]; then
    \. "${NVM_DIR}/nvm.sh"
fi

if [ -z "${SHELL}" ]; then
	SHELL="$(command -v bash || command -v sh)"
fi

if [ $# -gt 0 ] && [ "$1" = "${1#-}" ]; then
	exec "$@"
else
	exec "${SHELL}" "$@"
fi
