#!/usr/bin/env bash
#
# Starts ComfyUI with the correct GPU overlay (NVIDIA or ROCm),
# based on the BACKEND recorded in .env by build.sh (or set by you
# by hand after import.sh on a machine that never ran build.sh).
#
# Any arguments are passed straight through to `docker compose up`,
# e.g.: ./run.sh --build   or   ./run.sh --no-recreate
#
set -euo pipefail

ENV_FILE=".env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "No .env found."
    echo "Run: cp .env.example .env   then edit it (in particular BACKEND and MODELS_PATH)."
    exit 1
fi

BACKEND="$(grep -E '^BACKEND=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"

if [[ "$BACKEND" != "nvidia" && "$BACKEND" != "rocm" ]]; then
    echo "No valid BACKEND set in $ENV_FILE (found: '${BACKEND:-<empty>}')."
    echo "Set BACKEND=nvidia or BACKEND=rocm in $ENV_FILE, matching the image you built/imported."
    exit 1
fi

OVERLAY="docker-compose.${BACKEND}.yml"
if [[ ! -f "$OVERLAY" ]]; then
    echo "Missing $OVERLAY - are you running this from the project root?"
    exit 1
fi

echo "Starting ComfyUI (${BACKEND} backend)..."
docker compose -f docker-compose.yml -f "$OVERLAY" up -d "$@"

PORT="$(grep -E '^COMFY_PORT=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
echo
echo "ComfyUI should be starting at http://localhost:${PORT:-8188}"
echo "Logs:    docker compose -f docker-compose.yml -f $OVERLAY logs -f"
echo "Stop:    docker compose -f docker-compose.yml -f $OVERLAY down"
