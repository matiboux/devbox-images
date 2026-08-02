#!/bin/bash
set -euo pipefail

# Build Docker image with specified tags and versions.

NODE_VERSION="${NODE_VERSION:-26.5.0}"
NODE_VARIANT="${NODE_VARIANT:-}"
YARN_VERSION="${YARN_VERSION:-}"
PNPM_VERSION="${PNPM_VERSION:-}"

NODE_TAG_LEVEL="${NODE_TAG_LEVEL:-patch}"
YARN_TAG_LEVEL="${YARN_TAG_LEVEL:-patch}"
PNPM_TAG_LEVEL="${PNPM_TAG_LEVEL:-patch}"

# ---

PYTHON_COMMAND="$(command -v python3 || command -v python || true)"
if [ -z "${PYTHON_COMMAND}" ]; then
    echo "Error: Python is not installed or not found in PATH." 2>&1
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not found in PATH." 2>&1
    exit 1
fi

if [ -z "${NODE_VERSION}" ]; then
    echo "Error: NODE_VERSION is not set." 2>&1
    exit 1
fi

SOURCE_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="$(dirname "$(dirname "${SOURCE_DIR}")")"

BUILD_DOCKERFILE="${SOURCE_DIR}/Dockerfile"
if [ ! -f "${BUILD_DOCKERFILE}" ]; then
    echo "Error: Dockerfile not found: ${BUILD_DOCKERFILE}" 2>&1
    exit 1
fi

REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-matiboux}"
REGISTRY_REPOSITORY="${REGISTRY_REPOSITORY:-devbox-node}"
NODE_IMAGE_TAG="${NODE_VERSION}${NODE_VARIANT:+-${NODE_VARIANT}}"

# Image tags for the targetted Docker build
IMAGE_TAGS="$(
    "${PYTHON_COMMAND}" "${PROJECT_DIR}/scripts/image_tag.py" \
        node="${NODE_IMAGE_TAG}":"${NODE_TAG_LEVEL}" \
        yarn="${YARN_VERSION}":"${YARN_TAG_LEVEL}" \
        pnpm="${PNPM_VERSION}":"${PNPM_TAG_LEVEL}" \
)"

IMAGE_TAG_FIRST="$(echo "${IMAGE_TAGS}" | head -n 1)"

echo "Building image: ${IMAGE_TAG_FIRST}"
echo "  Node.js: ${NODE_VERSION} (variant: ${NODE_VARIANT:-default})"
if [ -n "${YARN_VERSION}" ]; then
    echo "  Yarn: ${YARN_VERSION}"
fi
if [ -n "${PNPM_VERSION}" ]; then
    echo "  pnpm: ${PNPM_VERSION}"
fi

# Build arguments
BUILD_ARGS=(
    --build-arg "NODE_VERSION=${NODE_VERSION}"
    --build-arg "NODE_VARIANT=${NODE_VARIANT}"
    --build-arg "YARN_VERSION=${YARN_VERSION}"
    --build-arg "PNPM_VERSION=${PNPM_VERSION}"
)

# Build tags
BUILD_TAGS=()
for TAG in ${IMAGE_TAGS}; do
    BUILD_TAGS+=(--tag "${REGISTRY_NAMESPACE}/${REGISTRY_REPOSITORY}:${TAG}")
done

if command -v docker buildx &> /dev/null; then
    docker buildx build \
        "${BUILD_ARGS[@]}" \
        "${BUILD_TAGS[@]}" \
        --load \
        --file "${BUILD_DOCKERFILE}" \
        "${PROJECT_DIR}"
elif command -v docker &> /dev/null; then
    docker build \
        "${BUILD_ARGS[@]}" \
        "${BUILD_TAGS[@]}" \
        --file "${BUILD_DOCKERFILE}" \
        "${PROJECT_DIR}"
else
    echo 'Error: Docker is not installed or not found in PATH.'
    exit 1
fi

echo "Image built successfully: ${REGISTRY_NAMESPACE}/${REGISTRY_REPOSITORY}:${IMAGE_TAG_FIRST}"
