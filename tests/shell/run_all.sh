#!/bin/sh
# Runs every tests/shell/test_*.sh suite and reports an aggregate result.
# Usage: sh tests/shell/run_all.sh

DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

overall_status=0
for test_file in "${DIR}"/test_*.sh; do
	echo "--- ${test_file} ---"
	sh "${test_file}"
	status=$?
	if [ "${status}" -ne 0 ]; then
		overall_status=1
	fi
	echo ''
done

exit "${overall_status}"
