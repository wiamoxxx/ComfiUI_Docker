#!/usr/bin/env bash

set -euo pipefail

IMAGE="comfyui-offline"
TAG="latest"

echo
echo "=========================================="
echo " Building ComfyUI Offline Image"
echo "=========================================="
echo

docker build \
    --progress=plain \
    -t "${IMAGE}:${TAG}" \
    .

echo
echo "=========================================="
echo " Build complete"
echo "=========================================="

docker image inspect "${IMAGE}:${TAG}" \
    --format='Image size: {{.Size}} bytes'

echo
echo "Image:"
echo "  ${IMAGE}:${TAG}"
echo
echo "Next:"
echo "  ./export.sh"
