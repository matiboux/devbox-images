#!/bin/sh
# GitHub release binary download/install helpers for the install-*.sh scripts
# in the parent directory (src/common/). Requires lib/tmpfile.sh (for
# register_cleanup_path) and lib/exec.sh (for run_or_fail) to already be
# sourced.
#
# Downloads use `curl -f` so an HTTP error response (e.g. a 404 from a bad
# release URL) fails the curl invocation instead of silently writing the
# error page to the archive/binary file, plus `--retry` to ride out
# transient network/5xx blips from GitHub's release CDN.
#
# Usage (from a script in the parent directory):
#   . "$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)/github_release.sh"

# install_github_tarball_binary <tool_name> <archive_url> <path_in_archive> <dest_path>
#
# Downloads the .tar.gz release archive at <archive_url>, extracts it to a
# temporary directory, and moves the binary found at <path_in_archive>
# (a path relative to the archive root) to <dest_path>. The downloaded
# archive and extraction directory are registered for cleanup on exit.
# Prints an error naming <tool_name> to stderr and returns 1 on any failure.
install_github_tarball_binary() {
	local tool_name="$1"
	local archive_url="$2"
	local path_in_archive="$3"
	local dest_path="$4"

	local archive_file
	archive_file="$(mktemp)"
	register_cleanup_path "${archive_file}"
	run_or_fail "Failed to download ${tool_name} binary archive." \
		curl -fsSL --retry 3 --retry-connrefused "${archive_url}" -o "${archive_file}" || return 1

	local extract_dir
	extract_dir="$(mktemp -d)"
	register_cleanup_path "${extract_dir}"
	run_or_fail "Failed to extract ${tool_name} binary from archive." \
		tar -xzf "${archive_file}" -C "${extract_dir}" || return 1

	run_or_fail "Failed to install ${tool_name} binary in $(dirname "${dest_path}")." \
		mv "${extract_dir}/${path_in_archive}" "${dest_path}" || return 1
}

# install_github_raw_binary <tool_name> <download_url> <dest_path> [<mode>]
#
# Downloads the single executable file at <download_url> and installs it at
# <dest_path> with permission <mode> (default '0755'). The downloaded file
# is registered for cleanup on exit. Prints an error naming <tool_name> to
# stderr and returns 1 on any failure.
install_github_raw_binary() {
	local tool_name="$1"
	local download_url="$2"
	local dest_path="$3"
	local mode="${4:-0755}"

	local binary_file
	binary_file="$(mktemp)"
	register_cleanup_path "${binary_file}"
	run_or_fail "Failed to download ${tool_name} binary." \
		curl -fsSL --retry 3 --retry-connrefused "${download_url}" -o "${binary_file}" || return 1

	run_or_fail "Failed to install ${tool_name} binary in $(dirname "${dest_path}")." \
		install -m "${mode}" "${binary_file}" "${dest_path}" || return 1
}
