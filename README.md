# Devbox images

Docker images for development and testing environments, automatically built and updated following upstream releases, ready to use in CI/CD pipelines, dev containers, and `docker run` local commands.


## Available images

Devbox Python:
- `devbox-python:3.x` - Python 3.x image with common dev tools
- `devbox-python:3.x-slim` - Python 3.x slim image with common dev tools
- `devbox-python:3.x-alpine` - Python 3.x Alpine image with common dev tools
- `devbox-python:3.x-poetry` - Python 3.x image with Poetry package manager and common dev tools
- `devbox-python:3.x-slim-poetry` - Python 3.x slim image with Poetry package manager and common dev tools
- `devbox-python:3.x-alpine-poetry` - Python 3.x Alpine image with Poetry package manager and common dev tools
- `devbox-python:3.x-uv` - Python 3.x image with uv package manager and common dev tools
- `devbox-python:3.x-slim-uv` - Python 3.x slim image with uv package manager and common dev tools
- `devbox-python:3.x-alpine-uv` - Python 3.x Alpine image with uv package manager and common dev tools

Devbox Python + Docker:
- `devbox-python-docker:3.x` - Python 3.x image with Docker CLI tools and common dev tools
- `devbox-python-docker:3.x-poetry` - Python 3.x image with Docker CLI tools, Poetry package manager, and common dev tools
- `devbox-python-docker:3.x-uv` - Python 3.x image with Docker CLI tools, uv package manager, and common dev tools

Devbox Python + Node:
- `devbox-python-node:3.x-26` - Python 3.x image with Node 26 and common dev tools
- `devbox-python-node:3.x-26-poetry` - Python 3.x image with Node 26, Poetry package manager, and common dev tools
- `devbox-python-node:3.x-26-uv` - Python 3.x image with Node 26, uv package manager, and common dev tools
- `devbox-python-node:3.x-26-yarn` - Python 3.x image with Node 26, Yarn package manager, and common dev tools
- `devbox-python-node:3.x-26-poetry-yarn` - Python 3.x image with Node 26, Poetry and Yarn package managers, and common dev tools
- `devbox-python-node:3.x-26-uv-yarn` - Python 3.x image with Node 26, uv and Yarn package managers, and common dev tools
- `devbox-python-node:3.x-26-pnpm` - Python 3.x image with Node 26, pnpm package manager, and common dev tools
- `devbox-python-node:3.x-26-poetry-pnpm` - Python 3.x image with Node 26, Poetry and pnpm package managers, and common dev tools
- `devbox-python-node:3.x-26-uv-pnpm` - Python 3.x image with Node 26, uv and pnpm package managers, and common dev tools

Devbox Python + Node + Docker:
- `devbox-python-node-docker:3.x-26` - Python 3.x image with Node 26, Docker CLI tools, and common dev tools
- `devbox-python-node-docker:3.x-26-poetry` - Python 3.x image with Node 26, Docker CLI tools, Poetry package manager, and common dev tools
- `devbox-python-node-docker:3.x-26-uv` - Python 3.x image with Node 26, Docker CLI tools, uv package manager, and common dev tools
- `devbox-python-node-docker:3.x-26-yarn` - Python 3.x image with Node 26, Docker CLI tools, Yarn package manager, and common dev tools
- `devbox-python-node-docker:3.x-26-poetry-yarn` - Python 3.x image with Node 26, Docker CLI tools, Poetry and Yarn package managers, and common dev tools
- `devbox-python-node-docker:3.x-26-uv-yarn` - Python 3.x image with Node 26, Docker CLI tools, uv and Yarn package managers, and common dev tools
- `devbox-python-node-docker:3.x-26-pnpm` - Python 3.x image with Node 26, Docker CLI tools, pnpm package manager, and common dev tools
- `devbox-python-node-docker:3.x-26-poetry-pnpm` - Python 3.x image with Node 26, Docker CLI tools, Poetry and pnpm package managers, and common dev tools
- `devbox-python-node-docker:3.x-26-uv-pnpm` - Python 3.x image with Node 26, Docker CLI tools, uv and pnpm package managers, and common dev tools


## How to use images with Docker CLI tools

To use the Docker CLI tools from a Devbox image, you can mount the host's Docker socket into the container and run commands as a non-root user. For example:

```sh
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/matiboux/devbox-python-docker:3.14-docker-uv \
  docker ps
```

The container must run with the `CAP_DAC_OVERRIDE` capability (granted by default by Docker) to access the host-mounted Docker socket from a non-root user.

In a `devcontainer.json`, the equivalent is:

```json
{
  "image": "ghcr.io/matiboux/devbox-python-docker:3.14-docker-uv",
  "remoteUser": "user",
  "mounts": [
    "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
  ]
}
```
