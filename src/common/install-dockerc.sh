#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/version.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/tmpfile.sh"
. "$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib/exec.sh"

DOCKERC_VERSION_INPUT="${1:-latest}"

# ---

# DockerC is a plain POSIX shell script wrapping `docker compose`, published
# straight from its repository (no per-arch release assets), so both
# prerequisites must already be in place.
run_or_fail 'Docker is not installed.' \
	sh -c 'docker --help > /dev/null 2>&1' || exit 1

run_or_fail 'Docker compose is not installed.' \
	sh -c 'docker compose --help > /dev/null 2>&1' || exit 1

DOCKERC_VERSION="$(github_resolve_version "${DOCKERC_VERSION_INPUT}" 'dockerc' 'matiboux/dockerc')"
if [ -z "${DOCKERC_VERSION}" ]; then
	echo "Failed to find a valid dockerc version for '${DOCKERC_VERSION_INPUT}'." >&2
	exit 1
fi

DOCKERC_BINARY="$(mktemp)"
register_cleanup_path "${DOCKERC_BINARY}"
run_or_fail "Failed to download dockerc script for version ${DOCKERC_VERSION}." \
	curl -sSL "https://raw.githubusercontent.com/matiboux/dockerc/v${DOCKERC_VERSION}/dockerc" \
	-o "${DOCKERC_BINARY}" || exit 1

run_or_fail 'Failed to install dockerc script in /usr/local/bin.' \
	install -m 0755 "${DOCKERC_BINARY}" /usr/local/bin/dockerc || exit 1

echo "Installed dockerc version ${DOCKERC_VERSION} to /usr/local/bin/dockerc."
