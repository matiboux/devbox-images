#!/bin/sh

DELTA_VERSION_INPUT="${1:-latest}"

# ---

DELTA_BINARY_ARCHIVE=''

cleanup() {
	if [ -n "${DELTA_BINARY_ARCHIVE}" ]; then
		rm -f "${DELTA_BINARY_ARCHIVE}"
	fi
}

trap 'cleanup' EXIT

# Detect CPU platform
ARCH_INPUT="$(uname -m)"
case "${ARCH_INPUT}" in
    x86_64)
        ARCH_PLATFORM='amd64'
        ;;
    aarch64|arm64)
        ARCH_PLATFORM='arm64'
        ;;
    armv7l)
        ARCH_PLATFORM='armhf'
        ;;
    i386|i686|x86)
        ARCH_PLATFORM='i386'
        ;;
    *)
        echo "Unsupported architecture: ${ARCH_INPUT}" >&2
        exit 1
        ;;
esac

# ---

get_delta_version() {
	local version="$1"
	local github_repo='dandavison/delta'
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
			| sed -n 's/.*"tag_name"[ ]*:[ ]*"\([^"]*\)".*/\1/p'
		)
	else
		if [ -n "${GITHUB_TOKEN}" ]; then
			response=$(
				curl -sSL -w "\n%{http_code}" "https://api.github.com/repos/${github_repo}/git/matching-refs/tags/${version}" \
					-H "Authorization: token ${GITHUB_TOKEN}"
			)
		else
			response=$(
				curl -sSL -w "\n%{http_code}" "https://api.github.com/repos/${github_repo}/git/matching-refs/tags/${version}"
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
				echo "Version '${version}' not found in delta repository." >&2
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
			| sed 's|refs/tags/||' \
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

DELTA_VERSION="$(get_delta_version "${DELTA_VERSION_INPUT}")"
if [ -z "${DELTA_VERSION}" ]; then
	echo "Failed to find a valid delta version for '${DELTA_VERSION_INPUT}'." >&2
	exit 1
fi

DELTA_BINARY_ARCHIVE="$(mktemp)"
curl -sSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${ARCH_PLATFORM}.deb" \
    -o "${DELTA_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download delta package for version ${DELTA_VERSION}." >&2
	exit 1
fi

dpkg -i "${DELTA_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to install delta package." >&2
	exit 1
fi

echo "Installed delta version ${DELTA_VERSION} to /usr/local/bin/delta."
