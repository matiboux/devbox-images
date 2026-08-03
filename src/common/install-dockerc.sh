#!/bin/sh

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/version.sh"
. "${COMMON_LIB_DIR}/tmpfile.sh"
. "${COMMON_LIB_DIR}/exec.sh"
. "${COMMON_LIB_DIR}/github_release.sh"

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
require_resolved_version "${DOCKERC_VERSION}" 'dockerc' "${DOCKERC_VERSION_INPUT}" || exit 1

install_github_raw_binary 'dockerc' \
	"https://raw.githubusercontent.com/matiboux/dockerc/v${DOCKERC_VERSION}/dockerc" \
	/usr/local/bin/dockerc || exit 1

echo "Installed dockerc version ${DOCKERC_VERSION} to /usr/local/bin/dockerc."
