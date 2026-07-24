#!/bin/sh

PNPM_VERSION_INPUT="${1:-latest}"

# ---

PNPM_INSTALLER_FILE=''

cleanup() {
    if [ -n "${PNPM_INSTALLER_FILE}" ]; then
        rm -f "${PNPM_INSTALLER_FILE}"
    fi
}

trap 'cleanup' EXIT

get_pnpm_version() {
	local version="$1"
	local version_full="$(echo "${version}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true)"
	if [ -n "${version_full}" ]; then
		echo "${version_full}"
		return 0
	fi
	local http_code
	local response
	if [ -z "${version}" ] || [ "${version}" = 'latest' ]; then
		response=$(curl -sSL -w "\n%{http_code}" 'https://api.github.com/repos/pnpm/pnpm/releases/latest')
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
		response=$(curl -sSL -w "\n%{http_code}" "https://api.github.com/repos/pnpm/pnpm/git/matching-refs/tags/v${version}")
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

PNPM_VERSION="$(get_pnpm_version "${PNPM_VERSION_INPUT}")"
if [ -z "${PNPM_VERSION}" ]; then
	echo "Failed to find a valid pnpm version for '${PNPM_VERSION_INPUT}'." >&2
	exit 1
fi

PNPM_INSTALLER_FILE="$(mktemp)"
curl -fsSL 'https://get.pnpm.io/install.sh' -o "${PNPM_INSTALLER_FILE}"
if [ $? -ne 0 ]; then
    echo 'Failed to download pnpm installer.' >&2
    exit 1
fi

PNPM_VERSION="${PNPM_VERSION}" \
ENV="${HOME}/.shrc" \
SHELL='/bin/sh' \
sh "${PNPM_INSTALLER_FILE}"
if [ $? -ne 0 ]; then
    echo "Failed to install pnpm version ${PNPM_VERSION}." >&2
    exit 1
fi

echo "Installed pnpm version ${PNPM_VERSION}."
