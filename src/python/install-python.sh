#!/bin/sh
set -e

# Script to prepare the Devbox Python image.
# Orchestrates dynamic image building based on environment variables:
# - POETRY_VERSION: Version of Poetry to install if set
# - UV_VERSION: Version of uv to install if set
# - NODE_VERSION: Version of Node.js to install if set
# - YARN_VERSION: Version of Yarn to install if set
# - PNPM_VERSION: Version of pnpm to install if set
# - DOCKER_VERSION: Install Docker CLI tools if set
# - LAZYDOCKER_VERSION: Version of lazydocker to install if set
# - HADOLINT_VERSION: Version of hadolint to install if set
# - CTOP_VERSION: Version of ctop to install if set
# - DIVE_VERSION: Version of dive to install if set
# - DOCKERC_VERSION: Version of dockerc to install if set
# - DOCKERX_VERSION: Version of dockerx to install if set
# - GH_VERSION: Version of GitHub CLI to install if set
# - GLAB_VERSION: Version of GitLab CLI to install if set
# - USERNAME: Non-root username to create if set
# - USER_ID: Non-root user ID to create if set
# - GROUP_ID: Non-root group ID to create if set
# - SUDO_USER: Give sudo privileges to non-root user if true

COMMON_SCRIPTS_DIR="$(dirname "$(dirname "$0")")/common"

# Install system development tools
sh "${COMMON_SCRIPTS_DIR}/install-system-tools.sh"
sh "${COMMON_SCRIPTS_DIR}/install-yq.sh"

# Install Git forge CLI tools
sh "${COMMON_SCRIPTS_DIR}/install-gh.sh" "${GH_VERSION}"
sh "${COMMON_SCRIPTS_DIR}/install-glab.sh" "${GLAB_VERSION}"

# Install Python development tools
sh "${COMMON_SCRIPTS_DIR}/install-python-tools.sh"

if [ -n "${POETRY_VERSION}" ]; then
    # Install Poetry
    sh "${COMMON_SCRIPTS_DIR}/install-poetry.sh" "${POETRY_VERSION}"
fi

if [ -n "${UV_VERSION}" ]; then
    # Install uv
    sh "${COMMON_SCRIPTS_DIR}/install-uv.sh" "${UV_VERSION}"
fi

if [ -n "${NODE_VERSION}" ]; then
    # Install Node.js
    sh "${COMMON_SCRIPTS_DIR}/install-node.sh" "${NODE_VERSION}"
fi

if [ -n "${YARN_VERSION}" ]; then
    # Install Yarn
    sh "${COMMON_SCRIPTS_DIR}/install-yarn.sh" "${YARN_VERSION}"
fi

if [ -n "${PNPM_VERSION}" ]; then
    # Install pnpm
    sh "${COMMON_SCRIPTS_DIR}/install-pnpm.sh" "${PNPM_VERSION}"
fi

if [ -n "${DOCKER_VERSION}" ]; then
    # Install Docker CLI tools
    sh "${COMMON_SCRIPTS_DIR}/install-docker.sh"
fi

if [ -n "${LAZYDOCKER_VERSION}" ]; then
    # Install lazydocker
    sh "${COMMON_SCRIPTS_DIR}/install-lazydocker.sh" "${LAZYDOCKER_VERSION}"
fi

if [ -n "${HADOLINT_VERSION}" ]; then
    # Install hadolint
    sh "${COMMON_SCRIPTS_DIR}/install-hadolint.sh" "${HADOLINT_VERSION}"
fi

if [ -n "${CTOP_VERSION}" ]; then
    # Install ctop
    sh "${COMMON_SCRIPTS_DIR}/install-ctop.sh" "${CTOP_VERSION}"
fi

if [ -n "${DIVE_VERSION}" ]; then
    # Install dive
    sh "${COMMON_SCRIPTS_DIR}/install-dive.sh" "${DIVE_VERSION}"
fi

if [ -n "${DOCKERC_VERSION}" ]; then
    # Install dockerc
    sh "${COMMON_SCRIPTS_DIR}/install-dockerc.sh" "${DOCKERC_VERSION}"
fi

if [ -n "${DOCKERX_VERSION}" ]; then
    # Install dockerx
    sh "${COMMON_SCRIPTS_DIR}/install-dockerx.sh" "${DOCKERX_VERSION}"
fi

if [ "${SUDO_USER}" = 'true' ]; then
    # Install sudo
    sh "${COMMON_SCRIPTS_DIR}/install-sudo.sh"
fi

if [ -n "${USERNAME}" ] || [ -n "${USER_ID}" ] || [ -n "${GROUP_ID}" ]; then
    # Create non-root user
    sh "${COMMON_SCRIPTS_DIR}/create-user.sh" "${USERNAME}" "${USER_ID}" "${GROUP_ID}" "${SUDO_USER}"
fi
