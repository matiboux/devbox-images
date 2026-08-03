#!/bin/sh
# Temporary file/directory cleanup helper for the install-*.sh scripts in
# the parent directory (src/common/).
#
# Usage (from a script in the parent directory):
#   . "$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)/tmpfile.sh"
#   ARCHIVE="$(mktemp)"
#   register_cleanup_path "${ARCHIVE}"
#   EXTRACT_DIR="$(mktemp -d)"
#   register_cleanup_path "${EXTRACT_DIR}"
#
# Registered paths are removed (files and directories alike) when the
# script exits, for any reason (success, error, or signal).

__CLEANUP_PATHS=''

# register_cleanup_path <path> [<path> ...]
#
# Registers one or more paths to be removed when the script exits.
register_cleanup_path() {
	local p
	for p in "$@"; do
		__CLEANUP_PATHS="${__CLEANUP_PATHS} ${p}"
	done
}

__run_cleanup_paths() {
	local p
	for p in ${__CLEANUP_PATHS}; do
		rm -rf "${p}"
	done
}

trap '__run_cleanup_paths' EXIT
