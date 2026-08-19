#syntax=docker/dockerfile:1

# This Dockerfile uses the root folder as context.


# ----------------
# Global
# ----------------

# --
# Global build arguments

ARG NODE_VERSION=26.5.0
ARG NODE_VARIANT=
ARG YARN_VERSION=
ARG PNPM_VERSION=
ARG DOCKER_VERSION=
ARG DIND_VERSION=
ARG USERNAME=user
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG SUDO_USER=true


# --
# Upstream images

FROM node:${NODE_VERSION}${NODE_VARIANT:+-${NODE_VARIANT}} AS node_upstream


# ----------------
# Devbox Node
# ----------------

FROM node_upstream AS devbox

# Build arguments
ARG NODE_VERSION
ARG YARN_VERSION
ARG PNPM_VERSION
ARG DOCKER_VERSION
ARG DIND_VERSION
ARG USERNAME
ARG USER_ID
ARG GROUP_ID
ARG SUDO_USER

# Run installation script for Devbox Node image
RUN --mount=type=bind,source=./src/common,target=/tmp/devbox/common \
    --mount=type=bind,source=./src/node/install-node.sh,target=/tmp/devbox/node/install-node.sh \
    --mount=type=cache,sharing=locked,id=apt-cache,target=/var/cache/apt \
	--mount=type=cache,sharing=locked,id=apt-lib,target=/var/lib/apt \
	--mount=type=secret,id=GITHUB_TOKEN,env=GITHUB_TOKEN \
	sh /tmp/devbox/node/install-node.sh

# Run as created non-root user
USER ${USERNAME}
WORKDIR /home/${USERNAME}

COPY --link --chmod=755 ./src/node/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
CMD []
