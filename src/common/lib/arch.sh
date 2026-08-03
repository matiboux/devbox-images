#!/bin/sh
# CPU architecture detection helpers for the install-*.sh scripts in the
# parent directory (src/common/).
#
# Usage (from a script in the parent directory):
#   . "$(CDPATH= cd -- "${SCRIPT_DIR}" && pwd)/lib/arch.sh"

# detect_arch <pattern>=<value> [<pattern>=<value> ...]
#
# Maps the host's `uname -m` output to a project-specific architecture
# label, e.g. detect_arch 'x86_64=amd64' 'aarch64|arm64=arm64'. Patterns
# may combine multiple uname values with '|', same as a case arm. Prints
# the matching value to stdout and returns 0, or prints "Unsupported
# architecture: <uname -m>" to stderr and returns 1 if nothing matches.
detect_arch() {
	local input="$(uname -m)"
	local old_ifs="${IFS}"
	local pair key value k

	for pair in "$@"; do
		key="${pair%%=*}"
		value="${pair#*=}"
		IFS='|'
		set -- ${key}
		IFS="${old_ifs}"
		for k in "$@"; do
			if [ "${input}" = "${k}" ]; then
				echo "${value}"
				return 0
			fi
		done
	done

	echo "Unsupported architecture: ${input}" >&2
	return 1
}
