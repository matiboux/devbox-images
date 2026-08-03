#!/bin/sh
# Group-membership helper for create-user.sh in the parent directory
# (src/common/).
#
# Usage (from a script in the parent directory):
#   . "$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)/group.sh"

# add_user_to_group <username> <groupname> [required]
#
# Adds <username> to supplementary group <groupname> via `usermod -aG`
# (falling back to `adduser <username> <groupname>` if usermod isn't
# available). If <groupname> doesn't exist, or neither command is
# available: with required='1', prints an error to stderr and returns 1;
# otherwise (default) silently does nothing and returns 0.
add_user_to_group() {
	local username="$1"
	local groupname="$2"
	local required="${3:-0}"

	if ! getent group "${groupname}" > /dev/null 2>&1; then
		if [ "${required}" = '1' ]; then
			echo "Group '${groupname}' does not exist" >&2
			return 1
		fi
		return 0
	fi

	if command -v usermod > /dev/null 2>&1; then
		usermod -aG "${groupname}" "${username}"
	elif command -v adduser > /dev/null 2>&1; then
		adduser "${username}" "${groupname}"
	elif [ "${required}" = '1' ]; then
		echo "No suitable command found to add user to ${groupname} group" >&2
		return 1
	fi
}
