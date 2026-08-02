#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"

DOCKERC_VERSION_INPUT="${1:-latest}"

# ---

# DockerC is a plain POSIX shell script wrapping `docker compose`, published
# straight from its repository (no per-arch release assets), so both
# prerequisites must already be in place.
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

DOCKERC_VERSION="$(github_resolve_version "${DOCKERC_VERSION_INPUT}" 'dockerc' 'matiboux/dockerc')"
if [ -z "${DOCKERC_VERSION}" ]; then
	echo "Failed to find a valid dockerc version for '${DOCKERC_VERSION_INPUT}'." >&2
	exit 1
fi

DOCKERC_BINARY="$(mktemp)"
register_cleanup_path "${DOCKERC_BINARY}"
curl -sSL "https://raw.githubusercontent.com/matiboux/dockerc/v${DOCKERC_VERSION}/dockerc" \
    -o "${DOCKERC_BINARY}"
if [ $? -ne 0 ]; then
	echo "Failed to download dockerc script for version ${DOCKERC_VERSION}." >&2
	exit 1
fi

install -m 0755 "${DOCKERC_BINARY}" /usr/local/bin/dockerc
if [ $? -ne 0 ]; then
	echo "Failed to install dockerc script in /usr/local/bin." >&2
	exit 1
fi

echo "Installed dockerc version ${DOCKERC_VERSION} to /usr/local/bin/dockerc."
