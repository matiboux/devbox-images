#!/bin/bash
set -euo pipefail

# Tag Docker image with specified tags and versions

# Inputs:
PYTHON_VERSION="${PYTHON_VERSION:-3.14.6}"
PYTHON_IMAGE_VARIANT="${PYTHON_IMAGE_VARIANT:-}" # [empty], slim, alpine
POETRY_VERSION="${POETRY_VERSION:-}"
UV_VERSION="${UV_VERSION:-}"
PYTHON_TAG_LEVEL="${PYTHON_TAG_LEVEL:-patch}" # global, major, minor, patch
POETRY_TAG_LEVEL="${POETRY_TAG_LEVEL:-patch}" # global, major, minor, patch
UV_TAG_LEVEL="${UV_TAG_LEVEL:-patch}" # global, major, minor, patch

# Secondary inputs (derived):
PYTHON_IMAGE_TAG="${PYTHON_IMAGE_TAG:-${PYTHON_VERSION}-${PYTHON_IMAGE_VARIANT}}"

# ---

# Validate tag levels to one of: global, major, minor, patch (fallbacks to patch)
validate_tag_level() {
	local level="$1"
	case "${level}" in
		global|major|minor|patch) printf '%s' "${level}" ;;
		*) printf '%s' "patch" ;;
	esac
}
PYTHON_TAG_LEVEL="$(validate_tag_level "${PYTHON_TAG_LEVEL}")"
POETRY_TAG_LEVEL="$(validate_tag_level "${POETRY_TAG_LEVEL}")"
UV_TAG_LEVEL="$(validate_tag_level "${UV_TAG_LEVEL}")"

# Given a version and a tag level, set an output array `component_options`
# with the list of version-string options for that component.
get_component_options() {
	local version="$1"
	local level="$2"
	local major minor rest

	major="${version%%.*}"
	rest="${version#*.}"
	if [ "${rest}" = "${version}" ]; then
		# no dot found
		minor=""
	else
		minor="${rest%%.*}"
	fi

	case "${level}" in
		global) component_options=("${version}" "${major}.${minor}" "${major}" "") ;;
		major)  component_options=("${version}" "${major}.${minor}" "${major}") ;;
		minor)  component_options=("${version}" "${major}.${minor}") ;;
		patch)  component_options=("${version}") ;;
	esac
}

# Compute Python component options
component_options=()
get_component_options "${PYTHON_VERSION}" "${PYTHON_TAG_LEVEL}"
python_component_options=("${component_options[@]}")
echo "Python component options: ${python_component_options[*]}"

# Compute Poetry component options
poetry_component_options=()
if [ -n "$POETRY_VERSION" ]; then
  component_options=()
  get_component_options "${POETRY_VERSION}" "${POETRY_TAG_LEVEL}"
  for c in "${component_options[@]}"; do
	poetry_component_options+=("poetry${c}")
  done
else
  poetry_component_options=('')
fi
echo "Poetry component options: ${poetry_component_options[*]}"

# Compute uv component options
uv_component_options=()
if [ -n "$UV_VERSION" ]; then
  component_options=()
  get_component_options "${UV_VERSION}" "${UV_TAG_LEVEL}"
  for c in "${component_options[@]}"; do
	uv_component_options+=("uv${c}")
  done
else
  uv_component_options=('')
fi
echo "uv component options: ${uv_component_options[*]}"

# Build list of image tags combinations
IMAGE_TAGS=""
for python_component in "${python_component_options[@]}"; do
  for poetry_component in "${poetry_component_options[@]}"; do
	for uv_component in "${uv_component_options[@]}"; do
	  tag_pieces=()
	  [ -n "${python_component}" ] && tag_pieces+=("${python_component}")
	  [ -n "${PYTHON_IMAGE_VARIANT}" ] && tag_pieces+=("${PYTHON_IMAGE_VARIANT}")
	  [ -n "${poetry_component}" ] && tag_pieces+=("${poetry_component}")
	  [ -n "${uv_component}" ] && tag_pieces+=("${uv_component}")

	  if [ "${#tag_pieces[@]}" -eq 0 ]; then
		image_tag="latest"
	  else
		image_tag="$(IFS='-'; echo "${tag_pieces[*]}")"
	  fi

	  IMAGE_TAGS="${IMAGE_TAGS:+${IMAGE_TAGS},}${image_tag}"
	done
  done
done

echo "$IMAGE_TAGS"
