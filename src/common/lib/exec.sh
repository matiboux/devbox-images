#!/bin/sh
# Command-execution helper for the install-*.sh scripts in the parent
# directory (src/common/).
#
# Usage (from a script in the parent directory):
#   . "$(CDPATH= cd -- "${SCRIPT_DIR}" && pwd)/lib/exec.sh"

# run_or_fail <error-message> <command> [args...]
#
# Runs <command> with its arguments. On failure, prints <error-message> to
# stderr and returns 1; the command's own stdout/stderr pass through
# normally either way. Standardizes the
#   cmd ...
#   if [ $? -ne 0 ]; then echo "..." >&2; exit 1; fi
# idiom repeated across install-*.sh scripts into a single call:
#   run_or_fail "..." cmd ... || exit 1
run_or_fail() {
	local error_message="$1"
	shift
	"$@"
	if [ $? -ne 0 ]; then
		echo "${error_message}" >&2
		return 1
	fi
}
