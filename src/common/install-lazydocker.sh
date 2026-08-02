#!/bin/sh

LAZYDOCKER_VERSION_INPUT="${1:-latest}"

# ---

LAZYDOCKER_BINARY_ARCHIVE=''
LAZYDOCKER_EXTRACT_DIR=''

cleanup() {
	if [ -n "${LAZYDOCKER_BINARY_ARCHIVE}" ]; then
		rm -f "${LAZYDOCKER_BINARY_ARCHIVE}"
	fi
	if [ -n "${LAZYDOCKER_EXTRACT_DIR}" ]; then
		rm -rf "${LAZYDOCKER_EXTRACT_DIR}"
	fi
}

trap 'cleanup' EXIT

# Detect CPU platform
ARCH_INPUT="$(uname -m)"
case "${ARCH_INPUT}" in
    x86_64)
        ARCH_PLATFORM='x86_64'
        ;;
    aarch64|arm64)
        ARCH_PLATFORM='arm64'
        ;;
    i386|i686|x86)
        ARCH_PLATFORM='x86'
        ;;
    armv7l)
        ARCH_PLATFORM='armv7'
        ;;
    armv6l)
        ARCH_PLATFORM='armv6'
        ;;
    *)
        echo "Unsupported architecture: ${ARCH_INPUT}" >&2
        exit 1
        ;;
esac

# ---

get_lazydocker_version() {
	local version="$1"
	local github_repo='jesseduffield/lazydocker'
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
				echo "Version '${version}' not found in lazydocker repository." >&2
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

LAZYDOCKER_VERSION="$(get_lazydocker_version "${LAZYDOCKER_VERSION_INPUT}")"
if [ -z "${LAZYDOCKER_VERSION}" ]; then
	echo "Failed to find a valid lazydocker version for '${LAZYDOCKER_VERSION_INPUT}'." >&2
	exit 1
fi

LAZYDOCKER_BINARY_ARCHIVE="$(mktemp)"
curl -sSL "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_${ARCH_PLATFORM}.tar.gz" \
    -o "${LAZYDOCKER_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download lazydocker binary archive for version ${LAZYDOCKER_VERSION}." >&2
	exit 1
fi

LAZYDOCKER_EXTRACT_DIR="$(mktemp -d)"
tar -xzf "${LAZYDOCKER_BINARY_ARCHIVE}" -C "${LAZYDOCKER_EXTRACT_DIR}"
if [ $? -ne 0 ]; then
    echo "Failed to extract lazydocker binary from archive." >&2
    exit 1
fi

mv "${LAZYDOCKER_EXTRACT_DIR}/lazydocker" /usr/local/bin/lazydocker
if [ $? -ne 0 ]; then
    echo "Failed to install lazydocker binary in /usr/local/bin." >&2
    exit 1
fi

echo "Installed lazydocker version ${LAZYDOCKER_VERSION} to /usr/local/bin/lazydocker."
