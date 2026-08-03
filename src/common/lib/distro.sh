#!/bin/sh
# Linux distribution / package manager detection helpers for the
# install-*.sh scripts in the parent directory (src/common/).
#
# Usage (from a script in the parent directory):
#   . "$(CDPATH= cd -- "${SCRIPT_DIR}" && pwd)/lib/distro.sh"

# detect_distro
#
# Prints the host's distribution ID from /etc/os-release (e.g. 'alpine',
# 'debian', 'ubuntu'), or 'unknown' if that file doesn't exist.
detect_distro() {
	if [ -f /etc/os-release ]; then
		awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"'
	else
		echo 'unknown'
	fi
}

# detect_package_manager <distro>
#
# Prints the path to the package manager command for the given
# distribution ID ('apk' for alpine, 'apt-get' for debian/ubuntu), or
# nothing if the distribution isn't recognized.
detect_package_manager() {
	local distro="$1"
	case "${distro}" in
		alpine)
			command -v apk
			;;
		debian|ubuntu)
			command -v apt-get
			;;
	esac
}

# require_package_manager <distro>
#
# Resolves <distro> to its package manager via detect_package_manager and
# prints just its command name (e.g. 'apk', 'apt-get') to stdout. If
# <distro> isn't recognized (or its package manager isn't on PATH), prints
# "Unsupported distribution: <distro>" to stderr and returns 1.
require_package_manager() {
	local distro="$1"
	local package_manager
	package_manager="$(detect_package_manager "${distro}")"
	if [ -z "${package_manager}" ]; then
		echo "Unsupported distribution: ${distro}" >&2
		return 1
	fi
	basename "${package_manager}"
}
