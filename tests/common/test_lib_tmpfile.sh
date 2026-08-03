#!/bin/sh
# Direct unit tests for src/common/lib/tmpfile.sh (register_cleanup_path),
# independent of any install-*.sh script that uses it.
#
# register_cleanup_path relies on an EXIT trap set when the lib is sourced,
# so to actually observe it firing we need a real subprocess exiting (not a
# command substitution in this shell, which never runs the parent's traps).
# Each scenario below writes a tiny throwaway script that sources the lib,
# registers path(s), and exits somehow; we then check from here whether
# those paths still exist.

. "$(dirname "$0")/../support/shell/harness.sh"

LIB="${COMMON_DIR}/lib/tmpfile.sh"

run_script() {
	# run_script <body> -- writes <body> to a temp script (after sourcing the
	# lib) and runs it, printing its stdout.
	script_file="$(mktemp)"
	{
		echo ". \"${LIB}\""
		printf '%s\n' "$1"
	} > "${script_file}"
	sh "${script_file}"
	code=$?
	rm -f "${script_file}"
	return "${code}"
}

assert_gone() {
	if [ -e "$1" ]; then
		fail "expected '$1' to have been removed by the EXIT trap, but it still exists"
	fi
}

assert_present() {
	if [ ! -e "$1" ]; then
		fail "expected '$1' to still exist, but it was removed"
	fi
}

test_case 'a registered temp file is removed when the script exits normally'
path=$(run_script 'F="$(mktemp)"; register_cleanup_path "${F}"; echo "${F}"')
code=$?
assert_exit_code "${code}" 0
assert_gone "${path}"

test_case 'a registered temp directory (with contents) is removed when the script exits normally'
path=$(run_script 'D="$(mktemp -d)"; register_cleanup_path "${D}"; touch "${D}/inside"; echo "${D}"')
code=$?
assert_exit_code "${code}" 0
assert_gone "${path}"

test_case 'multiple register_cleanup_path calls each get removed'
paths=$(run_script 'A="$(mktemp)"; B="$(mktemp -d)"; register_cleanup_path "${A}"; register_cleanup_path "${B}"; echo "${A}"; echo "${B}"')
path_a=$(echo "${paths}" | sed -n '1p')
path_b=$(echo "${paths}" | sed -n '2p')
assert_gone "${path_a}"
assert_gone "${path_b}"

test_case 'a single register_cleanup_path call accepts several paths at once'
paths=$(run_script 'A="$(mktemp)"; B="$(mktemp)"; register_cleanup_path "${A}" "${B}"; echo "${A}"; echo "${B}"')
path_a=$(echo "${paths}" | sed -n '1p')
path_b=$(echo "${paths}" | sed -n '2p')
assert_gone "${path_a}"
assert_gone "${path_b}"

test_case 'a registered path is removed even when the script exits with an error'
path=$(run_script 'F="$(mktemp)"; register_cleanup_path "${F}"; echo "${F}"; exit 1')
code=$?
assert_exit_code "${code}" 1
assert_gone "${path}"

test_case 'a registered path is removed even when a later command fails under set -e'
path=$(run_script 'set -e; F="$(mktemp)"; register_cleanup_path "${F}"; echo "${F}"; false')
code=$?
assert_exit_code "${code}" 1
assert_gone "${path}"

test_case 'an unregistered temp file is left untouched'
paths=$(run_script 'REGISTERED="$(mktemp)"; UNREGISTERED="$(mktemp)"; register_cleanup_path "${REGISTERED}"; echo "${REGISTERED}"; echo "${UNREGISTERED}"')
registered_path=$(echo "${paths}" | sed -n '1p')
unregistered_path=$(echo "${paths}" | sed -n '2p')
assert_gone "${registered_path}"
assert_present "${unregistered_path}"
rm -f "${unregistered_path}"

summary
