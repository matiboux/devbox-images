#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib"
for lib in version distro tmpfile exec; do . "${COMMON_LIB_DIR}/${lib}.sh"; done

NVM_VERSION_INPUT="${1:-latest}"

NVM_DIR="${NVM_DIR:-/opt/nvm}"
NVM_BASH_ENV="${NVM_BASH_ENV:-/etc/bash_env}"
NVM_BASHRC="${NVM_BASHRC:-/etc/bash.bashrc}"

# ---

# Detect Linux distribution
DISTRO="$(detect_distro)"

if [ "${DISTRO}" = 'alpine' ]; then
	echo "Sorry, Alpine Linux is not supported for nvm installation." >&2
	exit 1
fi

NVM_VERSION="$(github_resolve_version "${NVM_VERSION_INPUT}" 'nvm' 'nvm-sh/nvm')"
if [ -z "${NVM_VERSION}" ]; then
	echo "Failed to find a valid nvm version for '${NVM_VERSION_INPUT}'." >&2
	exit 1
fi

mkdir -p "${NVM_DIR}"

BASH_INSTALLED='false'
if ! command -v bash > /dev/null 2>&1; then
	if command -v apt-get > /dev/null 2>&1; then
		apt-get update && apt-get install -y --no-install-recommends bash || {
			echo "Failed to install bash temporarily, required to install nvm." >&2
			exit 1
		}
	elif command -v apk > /dev/null 2>&1; then
		apk add --no-cache bash || {
			echo "Failed to install bash temporarily, required to install nvm." >&2
			exit 1
		}
	else
		echo 'Bash is required to install nvm. No supported package manager found to install bash.' >&2
		exit 1
	fi
	echo 'Installed bash temporarily to install nvm.' >&2
	BASH_INSTALLED='true'
fi

NVM_INSTALLER_FILE="$(mktemp)"
register_cleanup_path "${NVM_INSTALLER_FILE}"
run_or_fail "Failed to download nvm installer for version ${NVM_VERSION}." \
	curl "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" \
	-o "${NVM_INSTALLER_FILE}" || exit 1

BASH_ENV="${NVM_BASH_ENV}"
touch "${BASH_ENV}"
if ! grep -q ". ${NVM_BASH_ENV}" "${NVM_BASHRC}" 2>/dev/null; then
	echo ". ${NVM_BASH_ENV}" >> "${NVM_BASHRC}"
fi

run_or_fail 'Failed to install nvm.' \
	env NVM_DIR="${NVM_DIR}" PROFILE="${BASH_ENV}" bash "${NVM_INSTALLER_FILE}" || exit 1

# Create user directories
while IFS= read -r dir; do
	mkdir -p "${NVM_DIR}/${dir}"
	chmod -R 777 "${NVM_DIR}/${dir}"
done <<EOF
.cache
alias
versions
EOF

echo "Installed nvm version ${NVM_VERSION} to ${NVM_DIR}."

if [ "${BASH_INSTALLED}" = 'true' ]; then
	if command -v apt-get > /dev/null 2>&1; then
		apt-get remove -y bash || {
			echo "Warning: Failed to uninstall bash." >&2
		}
	elif command -v apk > /dev/null 2>&1; then
		apk del bash || {
			echo "Warning: Failed to uninstall bash." >&2
		}
	fi
	echo "Uninstalled bash after installing nvm." >&2
fi
