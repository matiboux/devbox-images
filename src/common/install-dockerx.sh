#!/bin/sh

DOCKERX_VERSION_INPUT="${1:-latest}"

# ---

DOCKERX_BINARY=''

cleanup() {
	if [ -n "${DOCKERX_BINARY}" ]; then
		rm -f "${DOCKERX_BINARY}"
	fi
}

trap 'cleanup' EXIT

# ---

get_dockerx_version() {
	local version="$1"
	local github_repo='matiboux/dockerx'
	local version_prefix='v'
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
		version_full=$(
			echo "${response}" \
			| sed -n 's/.*"tag_name"[ ]*:[ ]*"\([^"]*\)".*/\1/p' \
			| sed 's/^v//'
		)
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
				echo "Version '${version}' not found in dockerx repository." >&2
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

# DockerX is a plain POSIX shell script wrapping `docker`/`docker compose`,
# published straight from its repository (no per-arch release assets), so
# both prerequisites must already be in place.
docker --help > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo 'Docker is not installed.' >&2
	exit 1
fi

docker compose --help > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo 'Docker compose is not installed.' >&2
	exit 1
fi

DOCKERX_VERSION="$(get_dockerx_version "${DOCKERX_VERSION_INPUT}")"
if [ -z "${DOCKERX_VERSION}" ]; then
	echo "Failed to find a valid dockerx version for '${DOCKERX_VERSION_INPUT}'." >&2
	exit 1
fi

DOCKERX_BINARY="$(mktemp)"
curl -sSL "https://raw.githubusercontent.com/matiboux/dockerx/v${DOCKERX_VERSION}/dockerx" \
    -o "${DOCKERX_BINARY}"
if [ $? -ne 0 ]; then
	echo "Failed to download dockerx script for version ${DOCKERX_VERSION}." >&2
	exit 1
fi

install -m 0755 "${DOCKERX_BINARY}" /usr/local/bin/dockerx
if [ $? -ne 0 ]; then
	echo "Failed to install dockerx script in /usr/local/bin." >&2
	exit 1
fi

echo "Installed dockerx version ${DOCKERX_VERSION} to /usr/local/bin/dockerx."
