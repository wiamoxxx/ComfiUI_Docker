#!/usr/bin/env bash
#
# Run this on the BUILD machine (the one with internet access)
# after build.sh has finished, then copy the resulting .tar (and
# its .sha256 checksum) to every target machine and run import.sh.
#
set -euo pipefail

ENV_FILE=".env"
BACKEND="${BACKEND:-}"
if [[ -z "$BACKEND" && -f "$ENV_FILE" ]]; then
    BACKEND="$(grep -E '^BACKEND=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
fi

DEFAULT_TAG="latest"
[[ -n "$BACKEND" ]] && DEFAULT_TAG="${BACKEND}-latest"

IMAGE="${IMAGE_NAME:-comfyui-offline}:${IMAGE_TAG:-$DEFAULT_TAG}"
OUTPUT="${OUTPUT_TAR:-comfyui-offline${BACKEND:+-$BACKEND}.tar}"

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
echo "Transfer ALL of these files to each offline machine:"
echo
echo "  $OUTPUT"
echo "  ${OUTPUT}.sha256"
echo "  docker-compose.yml, docker-compose.nvidia.yml, docker-compose.rocm.yml"
echo "  .env.example, import.sh, run.sh"
echo
echo "Then on each target machine run:"
echo "  ./import.sh $OUTPUT"
echo
