#!/bin/sh
# Version-resolution helpers for the install-*.sh scripts in the parent
# directory (src/common/).
#
# Usage (from a script in the parent directory):
#   . "$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)/version.sh"

# github_resolve_version <version_input> <tool_name> <github_repo> [version_prefix] [strip_tag_v]
#
# Resolves a user-supplied version ("latest", a partial "X.Y", or a full
# "X.Y.Z") to a concrete "X.Y.Z" release version of a GitHub project, via the
# GitHub REST API. Prints the resolved version to stdout and returns 0, or
# prints an error to stderr and returns 1.
#
#   version_input  - 'latest' (or empty), a full X.Y.Z version, or a partial
#                    version prefix to match against tags
#   tool_name      - human-readable name used in error messages (e.g. 'gh')
#   github_repo    - '<owner>/<repo>' on GitHub
#   version_prefix - prefix prepended to a version to form its tag (default: 'v')
#   strip_tag_v    - if '1' (default), strip a leading 'v' from the tag_name
#                    returned by the "latest release" lookup; pass '0' for
#                    projects whose tags have no 'v' prefix
github_resolve_version() {
	local version="$1"
	local tool_name="$2"
	local github_repo="$3"
	local version_prefix="${4-v}"
	local strip_tag_v="${5-1}"

	local version_full="$(echo "${version}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true)"
	if [ -n "${version_full}" ]; then
		echo "${version_full}"
		return 0
	fi

	local http_code
	local response

	if [ -z "${version}" ] || [ "${version}" = 'latest' ]; then
		if [ -n "${GITHUB_TOKEN}" ]; then
			response=$(
				curl -sSL -w "\n%{http_code}" "https://api.github.com/repos/${github_repo}/releases/latest" \
					-H "Authorization: token ${GITHUB_TOKEN}"
			)
		else
			response=$(
				curl -sSL -w "\n%{http_code}" "https://api.github.com/repos/${github_repo}/releases/latest"
			)
		fi
		if [ $? -ne 0 ]; then
			echo 'Failed to connect to GitHub API.' >&2
			return 1
		fi
		http_code=$(echo "${response}" | tail -n1)
		response=$(echo "${response}" | sed '$d')
		if [ "${http_code}" != '200' ]; then
			if [ "${http_code}" = '403' ] || [ "${http_code}" = '429' ]; then
				echo "GitHub API rate limit exceeded. Please try again later or use a personal access token." >&2
			else
				echo "GitHub API error (HTTP ${http_code})." >&2
			fi
			return 1
		fi
		if [ -z "${response}" ]; then
			echo 'Empty response from GitHub API.' >&2
			return 1
		fi
		if [ "${strip_tag_v}" = '1' ]; then
			version_full=$(
				echo "${response}" \
				| sed -n 's/.*"tag_name"[ ]*:[ ]*"\([^"]*\)".*/\1/p' \
				| sed 's/^v//'
			)
		else
			version_full=$(
				echo "${response}" \
				| sed -n 's/.*"tag_name"[ ]*:[ ]*"\([^"]*\)".*/\1/p'
			)
		fi
	else
		if [ -n "${GITHUB_TOKEN}" ]; then
			response=$(
				curl -sSL -w "\n%{http_code}" "https://api.github.com/repos/${github_repo}/git/matching-refs/tags/${version_prefix}${version}" \
					-H "Authorization: token ${GITHUB_TOKEN}"
			)
		else
			response=$(
				curl -sSL -w "\n%{http_code}" "https://api.github.com/repos/${github_repo}/git/matching-refs/tags/${version_prefix}${version}"
			)
		fi
		if [ $? -ne 0 ]; then
			echo 'Failed to connect to GitHub API.' >&2
			return 1
		fi
		http_code=$(echo "${response}" | tail -n1)
		response=$(echo "${response}" | sed '$d')
		if [ "${http_code}" != '200' ]; then
			if [ "${http_code}" = '403' ] || [ "${http_code}" = '429' ]; then
				echo "GitHub API rate limit exceeded. Please try again later or use a personal access token." >&2
			elif [ "${http_code}" = '404' ]; then
				echo "Version '${version}' not found in ${tool_name} repository." >&2
			else
				echo "GitHub API error (HTTP ${http_code})." >&2
			fi
			return 1
		fi
		if [ -z "${response}" ]; then
			echo "No matching version found for '${version}'." >&2
			return 1
		fi
		version_full=$(
			echo "${response}" \
			| sed -n 's/.*"ref"[ ]*:[ ]*"\([^"]*\)".*/\1/p' \
			| sed "s|refs/tags/${version_prefix}||" \
			| sort -V \
			| tail -n1
		)
	fi

	if [ -z "${version_full}" ]; then
		echo 'Failed to parse version from GitHub API response.' >&2
		return 1
	fi
	echo "${version_full}"
}

# pip_resolve_version <version_input> <pip_package_name>
#
# Resolves a user-supplied version ("latest", a partial "X.Y", or a full
# "X.Y.Z") to a concrete published "X.Y.Z" version of a PyPI package, via
# `pip index versions`. Prints the resolved version to stdout, which is
# empty if no published version matches.
pip_resolve_version() {
	local version="$1"
	local package="$2"

	local version_full="$(echo "${version}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true)"
	if [ -n "${version_full}" ]; then
		echo "${version_full}"
		return 0
	fi

	if [ -z "${version}" ] || [ "${version}" = 'latest' ]; then
		pip index versions "${package}" 2>/dev/null \
			| sed -n 's/^Available versions: //p' \
			| tr ',' '\n' \
			| sed 's/^ *//' \
			| head -n1
	else
		pip index versions "${package}" 2>/dev/null \
			| sed -n 's/^Available versions: //p' \
			| tr ',' '\n' \
			| sed 's/^ *//' \
			| grep -E "^$(echo "${version}" | sed 's/\.*$//; s/\./\\./g')(\\.[0-9]+)*$" \
			| head -n1
	fi
}

# gitlab_resolve_version <version_input> <gitlab_project>
#
# Resolves a user-supplied version to a concrete "X.Y.Z" release version of
# a GitLab project, via the GitLab REST API. Prints the resolved version to
# stdout and returns 0, or prints an error to stderr and returns 1.
#
#   version_input   - 'latest' (or empty) resolves via the project's
#                      releases/permalink/latest endpoint; a full X.Y.Z
#                      version is returned as-is; any other value (e.g. a
#                      partial version) is also returned as-is, with no API
#                      call or existence check -- GitLab has no equivalent
#                      of GitHub's matching-refs partial-version lookup
#   gitlab_project  - URL-encoded '<owner>%2F<repo>' path segment
gitlab_resolve_version() {
	local version="$1"
	local gitlab_project="$2"

	local version_full="$(echo "${version}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true)"
	if [ -n "${version_full}" ]; then
		echo "${version_full}"
		return 0
	fi

	if [ -z "${version}" ] || [ "${version}" = 'latest' ]; then
		local http_code
		local response
		if [ -n "${CI_JOB_TOKEN}" ]; then
			response=$(
				curl -sSL -w "\n%{http_code}" "https://gitlab.com/api/v4/projects/${gitlab_project}/releases/permalink/latest" \
					-H "PRIVATE-TOKEN: ${CI_JOB_TOKEN}"
			)
		else
			response=$(
				curl -sSL -w "\n%{http_code}" "https://gitlab.com/api/v4/projects/${gitlab_project}/releases/permalink/latest"
			)
		fi
		if [ $? -ne 0 ]; then
			echo 'Failed to connect to GitLab API.' >&2
			return 1
		fi
		http_code=$(echo "${response}" | tail -n1)
		response=$(echo "${response}" | sed '$d')
		if [ "${http_code}" != '200' ]; then
			if [ "${http_code}" = '403' ] || [ "${http_code}" = '429' ]; then
				echo "GitLab API rate limit exceeded. Please try again later or use a personal access token." >&2
			else
				echo "GitLab API error (HTTP ${http_code})." >&2
			fi
			return 1
		fi
		if [ -z "${response}" ]; then
			echo 'Empty response from GitLab API.' >&2
			return 1
		fi
		version_full=$(
			echo "${response}" \
			| sed -n 's/.*"tag_name"[ ]*:[ ]*"\([^"]*\)".*/\1/p' \
			| sed 's/^v//'
		)
	else
		version_full="${version}"
	fi

	if [ -z "${version_full}" ]; then
		echo 'Failed to parse version from GitLab API response.' >&2
		return 1
	fi
	echo "${version_full}"
}

# require_resolved_version <resolved_version> <tool_name> <version_input>
#
# Guards the "bail out if version resolution came back empty" idiom used
# right after every *_resolve_version call above. On success (non-empty
# <resolved_version>) returns 0 silently. On failure, prints
# "Failed to find a valid <tool_name> version for '<version_input>'." to
# stderr and returns 1.
require_resolved_version() {
	local resolved_version="$1"
	local tool_name="$2"
	local version_input="$3"

	if [ -z "${resolved_version}" ]; then
		echo "Failed to find a valid ${tool_name} version for '${version_input}'." >&2
		return 1
	fi
}
