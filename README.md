# Devbox images

Docker images for development and testing environments, automatically built and updated following upstream releases, ready to use in CI/CD pipelines, dev containers, and `docker run` local commands.


## Available images


All images ship with common dev tools.

Examples of available images:

- `devbox-python`: Python 3.x only
  - `3.x` - Base image
  - `3.x-slim` - Base slim image
  - `3.x-alpine` - Base Alpine image
  - `3.x-poetry` - Base image, with Poetry package manager
  - `3.x-uv` - Base image, with uv package manager

<span></span>

- `devbox-python-docker`: Python 3.x with Docker CLI tools
  - Same tags as `devbox-python` above

<span></span>

- `devbox-python-node`: Python 3.x with Node x
  - `3.x-x` - Base image
  - `3.x-x-poetry` - Base image, with Poetry package manager
  - `3.x-x-uv` - Base image, with uv package manager
  - `3.x-x-yarn` - Base image, with Yarn package manager
  - `3.x-x-pnpm` - Base image, with pnpm package manager
  - `3.x-x-poetry-yarn` - Base image, with Poetry and Yarn package managers
  - `3.x-x-poetry-pnpm` - Base image, with Poetry and pnpm package managers
  - `3.x-x-uv-yarn` - Base image, with uv and Yarn package managers
  - `3.x-x-uv-pnpm` - Base image, with uv and pnpm package managers

- `devbox-python-node-docker`: Python 3.x with Node x and Docker CLI tools
  - Same tags as `devbox-python-node` above


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
