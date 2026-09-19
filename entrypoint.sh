#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="/opt/ComfyUI"
MODELS_DIR="${COMFY_DIR}/models"

# ------------------------------------------------------------
# Standard ComfyUI model sub-folders (core + the custom nodes
# baked into this image). Created empty on every start so
# ComfyUI never errors out on a missing path. Mount your real
# model folder over MODELS_DIR (see README.md) to populate them.
# ------------------------------------------------------------
MODEL_SUBDIRS=(
    checkpoints clip clip_vision configs controlnet diffusers
    embeddings gligen hypernetworks loras photomaker style_models
    unet upscale_models vae vae_approx
    animatediff_models ipadapter insightface ultralytics
)

for d in "${MODEL_SUBDIRS[@]}"; do
    mkdir -p "${MODELS_DIR}/${d}"
done

# ------------------------------------------------------------
# Sanity check: warn loudly (but don't fail) if nothing was
# mounted over MODELS_DIR - the single most common "it's not
# finding my models" support question.
# ------------------------------------------------------------
if [ -z "$(find "${MODELS_DIR}" -mindepth 2 -type f -print -quit 2>/dev/null)" ]; then
    echo "=========================================================="
    echo " WARNING: no files found under ${MODELS_DIR}"
    echo
    echo " ComfyUI will start, but no checkpoints/loras/etc. will"
    echo " show up until you mount your model folder there, e.g.:"
    echo
    echo "   docker run -v /path/to/models:${MODELS_DIR} ..."
    echo
    echo " or via docker-compose.yml / .env (MODELS_PATH=...)."
    echo " See README.md for the expected folder layout."
    echo "=========================================================="
fi

# ------------------------------------------------------------
# Optional: mount an extra_model_paths.yaml at the ComfyUI root
# to point at additional or differently-laid-out model folders
# instead of (or in addition to) MODELS_DIR. Purely informational
# here - ComfyUI reads the file itself if present.
# ------------------------------------------------------------
if [ -f "${COMFY_DIR}/extra_model_paths.yaml" ]; then
    echo "Found extra_model_paths.yaml - ComfyUI will also use those paths."
fi

# ------------------------------------------------------------
# CLI_ARGS lets you pass extra ComfyUI flags at runtime without
# rebuilding the image, e.g.:
#   CLI_ARGS="--lowvram --preview-method auto"
# ------------------------------------------------------------
read -ra EXTRA_ARGS <<< "${CLI_ARGS:-}"

exec python main.py \
    --listen "${COMFY_LISTEN:-0.0.0.0}" \
    --port "${COMFY_PORT:-8188}" \
    "${EXTRA_ARGS[@]}" \
    "$@"
