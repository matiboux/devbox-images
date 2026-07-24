#!/bin/sh

YARN_VERSION_INPUT="${1:-latest}"

# ---

get_yarn_version() {
	local version="$1"
	local version_full="$(echo "${version}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true)"
	if [ -n "${version_full}" ]; then
		echo "${version_full}"
		return 0
	fi
	local http_code
	local response
	if [ -z "${version}" ] || [ "${version}" = 'latest' ]; then
		response=$(curl -sSL -w "\n%{http_code}" 'https://api.github.com/repos/yarnpkg/berry/releases/latest')
		http_code=$(echo "${response}" | tail -n1)
		response=$(echo "${response}" | sed '$d')
		if [ "${http_code}" = '403' ] || [ "${http_code}" = '429' ]; then
			echo "GitHub API rate limit exceeded. Please try again later or use a personal access token." >&2
			return 1
		fi
		if [ -z "${response}" ]; then
			echo 'Empty response from GitHub API.' >&2
			return 1
		fi
		echo "${response}" \
			| sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' \
			| sed 's/^v//'
	else
		response=$(curl -sSL -w "\n%{http_code}" "https://api.github.com/repos/yarnpkg/berry/git/matching-refs/tags/v${version}")
		http_code=$(echo "${response}" | tail -n1)
		response=$(echo "${response}" | sed '$d')
		if [ "${http_code}" = '403' ] || [ "${http_code}" = '429' ]; then
			echo "GitHub API rate limit exceeded. Please try again later or use a personal access token." >&2
			return 1
		fi
		if [ -z "${response}" ]; then
			echo 'Empty response from GitHub API.' >&2
			return 1
		fi
		echo "${response}" \
			| sed -n 's/.*"ref": "\([^"]*\)".*/\1/p' \
			| sed 's|refs/tags/v||' \
			| sort -V \
			| tail -n1
	fi
}

YARN_VERSION="$(get_yarn_version "${YARN_VERSION_INPUT}")"
if [ -z "${YARN_VERSION}" ]; then
	echo "Failed to find a valid yarn version for '${YARN_VERSION_INPUT}'." >&2
	exit 1
fi

corepack install -g "yarn@${YARN_VERSION}"
if [ $? -ne 0 ]; then
	echo "Failed to install yarn version ${YARN_VERSION}." >&2
	exit 1
fi

echo "Installed yarn version ${YARN_VERSION}."
