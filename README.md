# mflux-runpod-dockerfile

This repository holds a Docker image that runs [mflux](https://github.com/mflux-community/mflux) image generation with MLX CUDA on Runpod.

The image works as a Runpod Pod and as a Runpod serverless worker. At start, `start.sh` selects the mode. Set `MFLUX_MODE=pod` or `MFLUX_MODE=serverless` to select the mode manually.

## Image

GitHub Actions builds the image and pushes it to the GitHub Container Registry:

```
ghcr.io/ianscrivener/mflux-runpod-dockerfile:latest
```

| Event | Tags |
|---|---|
| Push to `main` | `latest`, `sha-<commit>` |
| Push of a `v*` tag | the tag name, `sha-<commit>` |
| Pull request | The workflow builds the image. It does not push the image. |

## Build locally

```
docker buildx build --platform linux/amd64 -t mflux-runpod .
```
