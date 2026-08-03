#!/bin/sh

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)/lib"
for lib in version tmpfile exec github_release; do . "${COMMON_LIB_DIR}/${lib}.sh"; done

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

install_github_raw_binary 'dockerc' \
	"https://raw.githubusercontent.com/matiboux/dockerc/v${DOCKERC_VERSION}/dockerc" \
	/usr/local/bin/dockerc || exit 1

echo "Installed dockerc version ${DOCKERC_VERSION} to /usr/local/bin/dockerc."
