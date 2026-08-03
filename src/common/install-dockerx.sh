#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/exec.sh"

DOCKERX_VERSION_INPUT="${1:-latest}"

# ---

# DockerX is a plain POSIX shell script wrapping `docker`/`docker compose`,
# published straight from its repository (no per-arch release assets), so
# both prerequisites must already be in place.
run_or_fail 'Docker is not installed.' \
	sh -c 'docker --help > /dev/null 2>&1' || exit 1

run_or_fail 'Docker compose is not installed.' \
	sh -c 'docker compose --help > /dev/null 2>&1' || exit 1

DOCKERX_VERSION="$(github_resolve_version "${DOCKERX_VERSION_INPUT}" 'dockerx' 'matiboux/dockerx')"
if [ -z "${DOCKERX_VERSION}" ]; then
	echo "Failed to find a valid dockerx version for '${DOCKERX_VERSION_INPUT}'." >&2
	exit 1
fi

DOCKERX_BINARY="$(mktemp)"
register_cleanup_path "${DOCKERX_BINARY}"
run_or_fail "Failed to download dockerx script for version ${DOCKERX_VERSION}." \
	curl -sSL "https://raw.githubusercontent.com/matiboux/dockerx/v${DOCKERX_VERSION}/dockerx" \
	-o "${DOCKERX_BINARY}" || exit 1

run_or_fail 'Failed to install dockerx script in /usr/local/bin.' \
	install -m 0755 "${DOCKERX_BINARY}" /usr/local/bin/dockerx || exit 1

echo "Installed dockerx version ${DOCKERX_VERSION} to /usr/local/bin/dockerx."
