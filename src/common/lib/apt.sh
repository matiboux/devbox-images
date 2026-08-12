#!/bin/sh
# apt-get retry helper for the install-*.sh scripts in the parent
# directory (src/common/).
#
# Debian/Ubuntu mirrors occasionally serve truncated or corrupted package
# files while a sync is in progress (apt then fails with e.g. "File has
# unexpected size ... Mirror sync in progress?"). Retrying after clearing
# the local apt cache works around it.
#
# Usage (from a script in the parent directory):
#   . "$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)/apt.sh"

# apt_get_update_install <package...>
#
# Runs `apt-get update` followed by `apt-get install -y
# --no-install-recommends <package...>`. If either command fails, cleans
# the local apt cache and retries, for up to 3 attempts total.
apt_get_update_install() {
	local attempt=1
	local max_attempts=3
	while [ "${attempt}" -le "${max_attempts}" ]; do
		if apt-get update && apt-get install -y --no-install-recommends "$@"; then
			return 0
		fi
		if [ "${attempt}" -lt "${max_attempts}" ]; then
			echo "apt-get failed (attempt ${attempt}/${max_attempts}), cleaning apt cache and retrying..." >&2
			apt-get clean
		fi
		attempt=$((attempt + 1))
	done
	return 1
}
