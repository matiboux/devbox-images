#!/bin/sh
# Tests for src/common/install-docker.sh
#
# NOTE: on a recognized distribution this script installs real packages
# (apt-get/apk) and writes to real system paths (/etc/apt/keyrings,
# /etc/apt/sources.list.d). That can't be safely intercepted by stubbing
# commands on PATH, so this suite only exercises the "unsupported
# distribution" error path, which is the only outcome we can guarantee is
# side-effect free. See tests/common/test_install_sudo.sh for the same
# rationale.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-docker.sh"

setup_stub_bin

test_case 'unsupported/unknown distribution errors out without touching the system'
if [ -f /etc/os-release ]; then
	skip_case 'host has a real /etc/os-release; this script would install real packages on a recognized distro, so it is not safe to exercise here'
else
	output=$(sh "${SCRIPT}" 2>&1)
	code=$?
	assert_exit_code "${code}" 1
	assert_contains "${output}" 'Unsupported distribution: unknown'
fi

summary
