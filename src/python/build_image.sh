#!/bin/bash
set -euo pipefail

# Build Docker image with specified tags and versions.

PYTHON_VERSION="${PYTHON_VERSION:-3.14.6}"
PYTHON_VARIANT="${PYTHON_VARIANT:-}"
POETRY_VERSION="${POETRY_VERSION:-}"
UV_VERSION="${UV_VERSION:-}"
NODE_VERSION="${NODE_VERSION:-}"
YARN_VERSION="${YARN_VERSION:-}"
PNPM_VERSION="${PNPM_VERSION:-}"

PYTHON_TAG_LEVEL="${PYTHON_TAG_LEVEL:-patch}"
POETRY_TAG_LEVEL="${POETRY_TAG_LEVEL:-patch}"
UV_TAG_LEVEL="${UV_TAG_LEVEL:-patch}"
NVM_TAG_LEVEL="${NVM_TAG_LEVEL:-patch}"
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

if [ -z "${PYTHON_VERSION}" ]; then
    echo "Error: PYTHON_VERSION is not set." 2>&1
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
REGISTRY_REPOSITORY="${REGISTRY_REPOSITORY:-python-devbox}"
PYTHON_IMAGE_TAG="${PYTHON_VERSION}${PYTHON_VARIANT:+-${PYTHON_VARIANT}}"

# Image tags for the targetted Docker build
IMAGE_TAGS="$(
    "${PYTHON_COMMAND}" "${PROJECT_DIR}/scripts/image_tag.py" \
        python="${PYTHON_IMAGE_TAG}":"${PYTHON_TAG_LEVEL}" \
        poetry="${POETRY_VERSION}":"${POETRY_TAG_LEVEL}" \
        uv="${UV_VERSION}":"${UV_TAG_LEVEL}" \
        node="${NODE_VERSION}":"${NODE_TAG_LEVEL}" \
        yarn="${YARN_VERSION}":"${YARN_TAG_LEVEL}" \
        pnpm="${PNPM_VERSION}":"${PNPM_TAG_LEVEL}" \
)"

IMAGE_TAG_FIRST="$(echo "${IMAGE_TAGS}" | head -n 1)"

echo "Building image: ${IMAGE_TAG_FIRST}"
echo "  Python: ${PYTHON_VERSION} (variant: ${PYTHON_VARIANT:-default})"
if [ -n "${POETRY_VERSION}" ]; then
    echo "  Poetry: ${POETRY_VERSION}"
fi
if [ -n "${UV_VERSION}" ]; then
    echo "  uv: ${UV_VERSION}"
fi
if [ -n "${NODE_VERSION}" ]; then
    echo "  Node.js: ${NODE_VERSION}"
fi
if [ -n "${YARN_VERSION}" ]; then
    echo "  Yarn: ${YARN_VERSION}"
fi
if [ -n "${PNPM_VERSION}" ]; then
    echo "  pnpm: ${PNPM_VERSION}"
fi

# Build arguments
BUILD_ARGS=(
    --build-arg "PYTHON_VERSION=${PYTHON_VERSION}"
    --build-arg "PYTHON_VARIANT=${PYTHON_VARIANT}"
    --build-arg "POETRY_VERSION=${POETRY_VERSION}"
    --build-arg "UV_VERSION=${UV_VERSION}"
    --build-arg "NODE_VERSION=${NODE_VERSION}"
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
