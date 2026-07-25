#!/bin/sh
# Tests for src/common/install-sudo.sh
#
# NOTE: this script writes directly to the real, hardcoded paths
# /etc/sudoers or /etc/doas.conf (`echo ... >> /etc/sudoers`) once it
# resolves a known distribution + package manager. That write can't be
# safely intercepted by stubbing commands on PATH, so this suite only
# exercises the "unsupported distribution" error path, which is the only
# outcome we can guarantee is side-effect free. On a host that DOES have a
# recognized /etc/os-release, the risky branches are skipped rather than
# run, to avoid ever mutating the real system's sudoers/doas config.

. "$(dirname "$0")/harness.sh"

SCRIPT="${COMMON_DIR}/install-sudo.sh"

setup_stub_bin

test_case 'unsupported/unknown distribution errors out without touching the system'
if [ -f /etc/os-release ]; then
	skip_case 'host has a real /etc/os-release; this script would write to real /etc/sudoers or /etc/doas.conf on a recognized distro, so it is not safe to exercise here'
else
	output=$(sh "${SCRIPT}" 2>&1)
	code=$?
	assert_exit_code "${code}" 1
	assert_contains "${output}" 'Unsupported distribution: unknown'
fi

summary
