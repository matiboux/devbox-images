#!/bin/sh

GH_VERSION_INPUT="${1:-latest}"

# ---

GH_BINARY_ARCHIVE=''

cleanup() {
	if [ -n "${GH_BINARY_ARCHIVE}" ]; then
		rm -f "${GH_BINARY_ARCHIVE}"
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
    i386|i686|x86)
        ARCH_PLATFORM='386'
        ;;
    armv7l|armv6l)
        ARCH_PLATFORM='armv6'
        ;;
    s390x)
        ARCH_PLATFORM='s390x'
        ;;
    ppc64le)
        ARCH_PLATFORM='ppc64le'
        ;;
    ppc64)
        ARCH_PLATFORM='ppc64'
        ;;
    *)
        echo "Unsupported architecture: ${ARCH_INPUT}" >&2
        exit 1
        ;;
esac

# ---

get_gh_version() {
	local version="$1"
	local github_repo='cli/cli'
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
				echo "Version '${version}' not found in gh repository." >&2
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

GH_VERSION="$(get_gh_version "${GH_VERSION_INPUT}")"
if [ -z "${GH_VERSION}" ]; then
	echo "Failed to find a valid gh version for '${GH_VERSION_INPUT}'." >&2
	exit 1
fi

GH_BINARY_ARCHIVE="$(mktemp)"
curl -sSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
    -o "${GH_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download gh binary archive for version ${GH_VERSION}." >&2
	exit 1
fi

GH_EXTRACT_DIR="$(mktemp -d)"
tar -xzf "${GH_BINARY_ARCHIVE}" -C "${GH_EXTRACT_DIR}"
if [ $? -ne 0 ]; then
    echo "Failed to extract gh binary from archive." >&2
    exit 1
fi

mv "${GH_EXTRACT_DIR}/gh_${GH_VERSION}_linux_${ARCH_PLATFORM}/bin/gh" /usr/local/bin/gh
if [ $? -ne 0 ]; then
    echo "Failed to install gh binary in /usr/local/bin." >&2
    exit 1
fi

rm -rf "${GH_EXTRACT_DIR}"

echo "Installed gh version ${GH_VERSION} to /usr/local/bin/gh."
