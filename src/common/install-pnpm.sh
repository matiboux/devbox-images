#!/bin/sh

PNPM_VERSION_INPUT="${1:-latest}"

PNPM_HOME="${PNPM_HOME:-/opt/pnpm}"
PNPM_BIN_DIR="${PNPM_BIN_DIR:-/usr/local/bin}"

# ---

PNPM_INSTALLER_FILE=''
PNPM_SHRC_FILE=''

cleanup() {
	if [ -n "${PNPM_INSTALLER_FILE}" ]; then
		rm -f "${PNPM_INSTALLER_FILE}"
	fi
	if [ -n "${PNPM_SHRC_FILE}" ]; then
		rm -f "${PNPM_SHRC_FILE}"
	fi
}

trap 'cleanup' EXIT

get_pnpm_version() {
	local version="$1"
	local github_repo='pnpm/pnpm'
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
				echo "Version '${version}' not found in pnpm repository." >&2
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

PNPM_VERSION="$(get_pnpm_version "${PNPM_VERSION_INPUT}")" || exit 1
if [ -z "${PNPM_VERSION}" ]; then
	echo "Failed to find a valid pnpm version for '${PNPM_VERSION_INPUT}'." >&2
	exit 1
fi

mkdir -p "${PNPM_HOME}"

PNPM_INSTALLER_FILE="$(mktemp)"
curl -fsSL 'https://get.pnpm.io/install.sh' -o "${PNPM_INSTALLER_FILE}"
if [ $? -ne 0 ]; then
    echo 'Failed to download pnpm installer.' >&2
    exit 1
fi

# Avoid relying on shell env files for binary discovery
PNPM_SHRC_FILE="$(mktemp)"

PNPM_VERSION="${PNPM_VERSION}" \
PNPM_HOME="${PNPM_HOME}" \
ENV="${PNPM_SHRC_FILE}" \
SHELL='/bin/sh' \
sh "${PNPM_INSTALLER_FILE}"
if [ $? -ne 0 ]; then
    echo "Failed to install pnpm version ${PNPM_VERSION}." >&2
    exit 1
fi

# Allow all users to access pnpm binaries and cache store
chmod -R 777 "${PNPM_HOME}"

# Create shims for pnpm, pnpx, pn, and pnx
# Shims preserve original paths for pnpm to resolve its sibling files correctly
for name in pnpm pnpx pn pnx; do
	target=''
	if [ -x "${PNPM_HOME}/bin/${name}" ]; then
		target="${PNPM_HOME}/bin/${name}"
	elif [ -x "${PNPM_HOME}/${name}" ]; then
		target="${PNPM_HOME}/${name}"
	fi
	if [ -n "${target}" ]; then
		printf '#!/bin/sh\nexec "%s" "$@"\n' "${target}" > "${PNPM_BIN_DIR}/${name}"
		chmod 755 "${PNPM_BIN_DIR}/${name}"
	fi
done

echo "Installed pnpm version ${PNPM_VERSION} to ${PNPM_HOME}."
