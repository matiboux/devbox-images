#!/bin/sh

YQ_VERSION_INPUT="${1:-latest}"

# ---

YQ_BINARY_ARCHIVE=''
YQ_BINARY_FILE=''

cleanup() {
	if [ -n "${YQ_BINARY_ARCHIVE}" ]; then
		rm -f "${YQ_BINARY_ARCHIVE}"
	fi
	if [ -n "${YQ_BINARY_FILE}" ]; then
		rm -f "${YQ_BINARY_FILE}"
	fi
}

trap 'cleanup' EXIT

# Detect CPU platform
ARCH_INPUT="$(uname -m)"
case "${ARCH_INPUT}" in
    x86_64)
        ARCH_PLATFORM='linux_amd64'
        ;;
    aarch64|arm64)
        ARCH_PLATFORM='linux_arm64'
        ;;
    i386|i686|x86)
        ARCH_PLATFORM='linux_386'
        ;;
    armv7l|armv6l|armv5l|armv5b)
        ARCH_PLATFORM='linux_arm'
        ;;
    loongarch64)
        ARCH_PLATFORM='linux_loong64'
        ;;
    mips)
        ARCH_PLATFORM='linux_mips'
        ;;
    mips64)
        ARCH_PLATFORM='linux_mips64'
        ;;
    mips64el)
        ARCH_PLATFORM='linux_mips64le'
        ;;
    mipsel)
        ARCH_PLATFORM='linux_mipsle'
        ;;
    ppc64)
        ARCH_PLATFORM='linux_ppc64'
        ;;
    ppc64le)
        ARCH_PLATFORM='linux_ppc64le'
        ;;
    riscv64)
        ARCH_PLATFORM='linux_riscv64'
        ;;
    s390x)
        ARCH_PLATFORM='linux_s390x'
        ;;
    *)
        echo "Unsupported architecture: ${ARCH_INPUT}" >&2
        exit 1
        ;;
esac

# ---

get_yq_version() {
	local version="$1"
	local github_repo='mikefarah/yq'
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
				echo "Version '${version}' not found in yq repository." >&2
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

YQ_VERSION="$(get_yq_version "${YQ_VERSION_INPUT}")"
if [ -z "${YQ_VERSION}" ]; then
	echo "Failed to find a valid yq version for '${YQ_VERSION_INPUT}'." >&2
	exit 1
fi

YQ_BINARY_ARCHIVE="$(mktemp)"
curl -sSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${ARCH_PLATFORM}.tar.gz" \
    -o "${YQ_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download yq binary archive for version ${YQ_VERSION}." >&2
	exit 1
fi

YQ_EXTRACT_DIR="$(mktemp -d)"
tar -xzf "${YQ_BINARY_ARCHIVE}" -C "${YQ_EXTRACT_DIR}"
if [ $? -ne 0 ]; then
    echo "Failed to extract yq binary from archive." >&2
    exit 1
fi

mv "${YQ_EXTRACT_DIR}/yq_${ARCH_PLATFORM}" /usr/local/bin/yq
if [ $? -ne 0 ]; then
    echo "Failed to install yq binary in /usr/local/bin." >&2
    exit 1
fi

echo "Installed yq version ${YQ_VERSION} to /usr/local/bin/yq."
