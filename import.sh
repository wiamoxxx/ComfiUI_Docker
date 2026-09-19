#!/usr/bin/env bash
#
# Run this on the OFFLINE / target machine after copying over the
# .tar produced by export.sh (and its .sha256 file, if present).
#
set -euo pipefail

INPUT="${1:-comfyui-offline.tar}"

echo
echo "=========================================="
echo " Importing ComfyUI Offline Image"
echo "=========================================="
echo

if [ ! -f "$INPUT" ]; then
    echo "File not found: $INPUT"
    echo "Usage: ./import.sh [path-to-tar]"
    exit 1
fi

if [ -f "${INPUT}.sha256" ]; then
    echo "Verifying checksum..."
    sha256sum -c "${INPUT}.sha256"
else
    echo "No ${INPUT}.sha256 found next to $INPUT - skipping integrity check."
    echo "(Re-run export.sh to generate one next time.)"
fi

echo
echo "Loading image into Docker..."
docker load -i "$INPUT"

echo
echo "=========================================="
echo " Import complete"
echo "=========================================="
echo
docker images --filter "reference=comfyui-offline"

echo
echo "Next steps:"
echo "  1. cp .env.example .env"
echo "     - set MODELS_PATH etc."
echo "     - set BACKEND=nvidia or BACKEND=rocm to match the image you just imported"
echo "       (the image's tag also tells you: comfyui-offline:nvidia-latest / rocm-latest)"
echo "  2. Put your model files under the folder MODELS_PATH points to"
echo "  3. ./run.sh"
echo
