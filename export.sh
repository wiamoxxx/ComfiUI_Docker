#!/usr/bin/env bash

set -euo pipefail

IMAGE="comfyui-offline:latest"
OUTPUT="comfyui-offline.tar"

echo
echo "Exporting Docker image..."
echo

docker save \
    -o "$OUTPUT" \
    "$IMAGE"

echo
echo "=========================================="
echo " Export complete"
echo "=========================================="

ls -lh "$OUTPUT"

echo
echo "Transfer this file to the offline machine:"
echo
echo "  $OUTPUT"
echo
