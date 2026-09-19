#!/usr/bin/env bash
#
# Run this on the BUILD machine (the one with internet access)
# after build.sh has finished, then copy the resulting .tar (and
# its .sha256 checksum) to every target machine and run import.sh.
#
set -euo pipefail

IMAGE="${IMAGE_NAME:-comfyui-offline}:${IMAGE_TAG:-latest}"
OUTPUT="${OUTPUT_TAR:-comfyui-offline.tar}"

echo
echo "Exporting Docker image..."
echo "  Image:  $IMAGE"
echo "  Output: $OUTPUT"
echo

docker save \
    -o "$OUTPUT" \
    "$IMAGE"

echo "Writing checksum..."
sha256sum "$OUTPUT" > "${OUTPUT}.sha256"

echo
echo "=========================================="
echo " Export complete"
echo "=========================================="

ls -lh "$OUTPUT" "${OUTPUT}.sha256"

echo
echo "Transfer BOTH of these files to each offline machine:"
echo
echo "  $OUTPUT"
echo "  ${OUTPUT}.sha256"
echo
echo "Then on each target machine run:"
echo "  ./import.sh $OUTPUT"
echo
