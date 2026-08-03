#!/bin/sh
set -e

# Installs Docker CLI tools (docker, buildx, compose) and companion Docker
# development tools (lazydocker, hadolint, ctop, dive, dockerc, dockerx).
# Each tool's version can be pinned via its own *_VERSION env var (default:
# latest) -- LAZYDOCKER_VERSION, HADOLINT_VERSION, CTOP_VERSION,
# DIVE_VERSION, DOCKERC_VERSION, DOCKERX_VERSION.

COMMON_SCRIPT_DIR="${0%/*}"
[ "${COMMON_SCRIPT_DIR}" = "$0" ] && COMMON_SCRIPT_DIR='.'
COMMON_SCRIPT_DIR="$(CDPATH= cd -- "${COMMON_SCRIPT_DIR}" && pwd)"

sh "${COMMON_SCRIPT_DIR}/install-docker.sh"
sh "${COMMON_SCRIPT_DIR}/install-lazydocker.sh" "${LAZYDOCKER_VERSION}"
sh "${COMMON_SCRIPT_DIR}/install-hadolint.sh" "${HADOLINT_VERSION}"
sh "${COMMON_SCRIPT_DIR}/install-ctop.sh" "${CTOP_VERSION}"
sh "${COMMON_SCRIPT_DIR}/install-dive.sh" "${DIVE_VERSION}"
sh "${COMMON_SCRIPT_DIR}/install-dockerc.sh" "${DOCKERC_VERSION}"
sh "${COMMON_SCRIPT_DIR}/install-dockerx.sh" "${DOCKERX_VERSION}"
