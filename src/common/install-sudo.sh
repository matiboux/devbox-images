#!/bin/sh
set -e

# Script to install sudo.

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
. "$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)/distro.sh"

DISTRO="$(detect_distro)"
PACKAGE_MANAGER_NAME="$(require_package_manager "${DISTRO}")" || exit 1

if [ "${PACKAGE_MANAGER_NAME}" = 'apk' ]; then

	# Install for Alpine Linux
	apk add --no-cache doas doas-sudo-shim

	# Allow members of group 'wheel' to execute commands without a password
	echo 'permit nopass :wheel' >> /etc/doas.conf

elif [ "${PACKAGE_MANAGER_NAME}" = 'apt-get' ]; then

	# Install for Debian/Ubuntu
	apt-get update
	apt-get install -y --no-install-recommends sudo

	# Allow members of group 'sudo' to execute commands without a password
	echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

else

	echo "Unsupported package manager: ${PACKAGE_MANAGER_NAME}" >&2
	exit 1

fi
