#!/bin/sh

GLAB_VERSION_INPUT="${1:-latest}"

# ---

GLAB_BINARY_ARCHIVE=''

cleanup() {
	if [ -n "${GLAB_BINARY_ARCHIVE}" ]; then
		rm -f "${GLAB_BINARY_ARCHIVE}"
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

get_glab_version() {
	local version="$1"
	local gitlab_repo='gitlab-org%2Fcli'
	local version_prefix='v'
	local version_full="$(echo "${version}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true)"
	if [ -n "${version_full}" ]; then
		echo "${version_full}"
		return 0
	fi
	local http_code
	local response
	if [ -z "${version}" ] || [ "${version}" = 'latest' ]; then
		if [ -n "${CI_JOB_TOKEN}" ]; then
			response=$(
			    curl -sSL -w "\n%{http_code}" "https://gitlab.com/api/v4/projects/${gitlab_repo}/releases/permalink/latest" \
					-H "PRIVATE-TOKEN: ${CI_JOB_TOKEN}"
			)
		else
			response=$(
				curl -sSL -w "\n%{http_code}" "https://gitlab.com/api/v4/projects/${gitlab_repo}/releases/permalink/latest"
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

GLAB_VERSION="$(get_glab_version "${GLAB_VERSION_INPUT}")"
if [ -z "${GLAB_VERSION}" ]; then
	echo "Failed to find a valid glab version for '${GLAB_VERSION_INPUT}'." >&2
	exit 1
fi

GLAB_BINARY_ARCHIVE="$(mktemp)"
curl -sSL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${ARCH_PLATFORM}.tar.gz" \
    -o "${GLAB_BINARY_ARCHIVE}"
if [ $? -ne 0 ]; then
	echo "Failed to download glab binary archive for version ${GLAB_VERSION}." >&2
	exit 1
fi

GLAB_EXTRACT_DIR="$(mktemp -d)"
tar -xzf "${GLAB_BINARY_ARCHIVE}" -C "${GLAB_EXTRACT_DIR}"
if [ $? -ne 0 ]; then
    echo "Failed to extract glab binary from archive." >&2
    exit 1
fi

mv "${GLAB_EXTRACT_DIR}/glab" /usr/local/bin/glab
if [ $? -ne 0 ]; then
    echo "Failed to install glab binary in /usr/local/bin." >&2
    exit 1
fi

rm -rf "${GLAB_EXTRACT_DIR}"

echo "Installed glab version ${GLAB_VERSION} to /usr/local/bin/glab."
