#!/bin/sh
set -e

# Script to prepare the Devbox Python image.
# Orchestrates dynamic image building based on environment variables:
# - POETRY_VERSION: Version of Poetry to install if set
# - UV_VERSION: Version of uv to install if set
# - NODE_VERSION: Version of Node.js to install if set, required for
#     YARN_VERSION/PNPM_VERSION below to have any effect
# - YARN_VERSION: Version of Yarn to install if set (requires NODE_VERSION)
# - PNPM_VERSION: Version of pnpm to install if set (requires NODE_VERSION)
# - DOCKER_VERSION: Install Docker CLI tools if set, along with lazydocker,
#     hadolint, ctop, dive, dockerc and dockerx (pin their versions via
#     LAZYDOCKER_VERSION, HADOLINT_VERSION, CTOP_VERSION, DIVE_VERSION,
#     DOCKERC_VERSION, DOCKERX_VERSION -- each defaults to latest)
# - DIND_VERSION: Install a Docker Engine (dockerd) for Docker-in-Docker
#     use if set, along with the same companion Docker development tools
#     as DOCKER_VERSION above
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

    if [ -n "${YARN_VERSION}" ]; then
        # Install Yarn
        sh "${COMMON_SCRIPTS_DIR}/install-yarn.sh" "${YARN_VERSION}"
    fi

    if [ -n "${PNPM_VERSION}" ]; then
        # Install pnpm
        sh "${COMMON_SCRIPTS_DIR}/install-pnpm.sh" "${PNPM_VERSION}"
    fi
fi

if [ -n "${DOCKER_VERSION}" ]; then
    # Install Docker CLI tools and companion Docker development tools
    sh "${COMMON_SCRIPTS_DIR}/install-docker-tools.sh"
fi

if [ -n "${DIND_VERSION}" ]; then
    # Install a Docker Engine (dockerd) for Docker-in-Docker use, and
    # companion Docker development tools
    sh "${COMMON_SCRIPTS_DIR}/install-dind-tools.sh"
fi

if [ "${SUDO_USER}" = 'true' ]; then
    # Install sudo
    sh "${COMMON_SCRIPTS_DIR}/install-sudo.sh"
fi

if [ -n "${USERNAME}" ] || [ -n "${USER_ID}" ] || [ -n "${GROUP_ID}" ]; then
    # Create non-root user
    sh "${COMMON_SCRIPTS_DIR}/create-user.sh" "${USERNAME}" "${USER_ID}" "${GROUP_ID}" "${SUDO_USER}"
fi
