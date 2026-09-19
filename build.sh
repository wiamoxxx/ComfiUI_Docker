#!/usr/bin/env bash
#
# Run this on the machine with internet access. Any extra
# arguments are passed straight through to `docker build`, so you
# can override the pinned versions without touching the Dockerfile:
#
#   ./build.sh --build-arg COMFYUI_REF=v0.36.1
#   ./build.sh --build-arg CUDA_IMAGE=nvidia/cuda:13.0.0-cudnn-runtime-ubuntu24.04
#   ./build.sh --build-arg TORCH_INDEX_URL=https://download.pytorch.org/whl/cu128
#
set -euo pipefail

IMAGE="${IMAGE_NAME:-comfyui-offline}"
TAG="${IMAGE_TAG:-latest}"
DATED_TAG="${IMAGE}:build-$(date +%Y%m%d)"

echo
echo "=========================================="
echo " Building ComfyUI Offline Image"
echo "=========================================="
echo

docker build \
    --progress=plain \
    -t "${IMAGE}:${TAG}" \
    -t "${DATED_TAG}" \
    "$@" \
    .

echo
echo "=========================================="
echo " Build complete"
echo "=========================================="

docker image inspect "${IMAGE}:${TAG}" \
    --format='Image size: {{.Size}} bytes'

echo
echo "Images tagged:"
echo "  ${IMAGE}:${TAG}"
echo "  ${DATED_TAG}   (dated, so you can tell builds apart across machines)"
echo
echo "Next:"
echo "  ./export.sh"
