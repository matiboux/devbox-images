#!/bin/sh
set -e

PYTHON_COMMAND="$(command -v python3 || command -v python)"

# Install Python development tools
${PYTHON_COMMAND} -m pip install \
	--no-cache-dir \
	--root-user-action ignore \
	black \
	ipython \
	mypy \
	pip-tools \
	pytest \
	ruff \
	ty
