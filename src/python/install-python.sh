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
# - USERNAME: Non-root username to create if set
# - USER_ID: Non-root user ID to create if set
# - GROUP_ID: Non-root group ID to create if set
# - SUDO_USER: Give sudo privileges to non-root user if true

COMMON_SCRIPTS_DIR="$(dirname "$(dirname "$0")")/common"

# Install system development tools
sh "${COMMON_SCRIPTS_DIR}/install-system-tools.sh"
sh "${COMMON_SCRIPTS_DIR}/install-yq.sh"

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

if [ "${SUDO_USER}" = 'true' ]; then
    # Install sudo
    sh "${COMMON_SCRIPTS_DIR}/install-sudo.sh"
fi

if [ -n "${USERNAME}" ] || [ -n "${USER_ID}" ] || [ -n "${GROUP_ID}" ]; then
    # Create non-root user
    sh "${COMMON_SCRIPTS_DIR}/create-user.sh" "${USERNAME}" "${USER_ID}" "${GROUP_ID}" "${SUDO_USER}"
fi
