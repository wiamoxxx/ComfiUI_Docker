#!/usr/bin/env bash
#
# Run this on the machine with internet access. It asks which GPU
# backend to build for (unless told already), then builds the
# matching Dockerfile.
#
# Non-interactive usage (scripting/CI):
#   BACKEND=nvidia ./build.sh
#   ./build.sh --backend rocm
#
# Extra arguments are passed straight through to `docker build`, so
# you can override the pinned versions without touching the
# Dockerfiles:
#   ./build.sh --backend nvidia --build-arg COMFYUI_REF=v0.36.1
#   ./build.sh --backend rocm   --build-arg ROCM_IMAGE=rocm/pytorch:rocm7.2_ubuntu24.04_py3.12_pytorch_release_2.10.0
#
set -euo pipefail

ENV_FILE=".env"
IMAGE="${IMAGE_NAME:-comfyui-offline}"
BACKEND="${BACKEND:-}"

# ---- Parse --backend, pass everything else through to docker build ----
EXTRA_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --backend)
            BACKEND="$2"
            shift 2
            ;;
        --backend=*)
            BACKEND="${1#*=}"
            shift
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# ---- Fall back to a previously-saved choice in .env ----
if [[ -z "$BACKEND" && -f "$ENV_FILE" ]]; then
    BACKEND="$(grep -E '^BACKEND=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
fi

# ---- Otherwise ask ----
if [[ -z "$BACKEND" ]]; then
    echo
    echo "Which GPU backend should this image target?"
    echo "  1) nvidia  - NVIDIA GPUs (CUDA)"
    echo "  2) rocm    - AMD GPUs (ROCm)"
    echo
    read -rp "Enter 1/nvidia or 2/rocm: " CHOICE
    case "$CHOICE" in
        1|nvidia|NVIDIA) BACKEND="nvidia" ;;
        2|rocm|ROCM|ROCm) BACKEND="rocm" ;;
        *)
            echo "Unrecognized choice: '$CHOICE'"
            exit 1
            ;;
    esac
fi

if [[ "$BACKEND" != "nvidia" && "$BACKEND" != "rocm" ]]; then
    echo "Invalid backend '$BACKEND' - must be 'nvidia' or 'rocm'."
    exit 1
fi

DOCKERFILE="Dockerfile.${BACKEND}"
if [[ ! -f "$DOCKERFILE" ]]; then
    echo "Missing $DOCKERFILE - are you running this from the project root?"
    exit 1
fi

TAG="${BACKEND}-latest"
DATED_TAG="${IMAGE}:${BACKEND}-build-$(date +%Y%m%d)"

echo
echo "=========================================="
echo " Building ComfyUI Offline Image ($BACKEND)"
echo "=========================================="
echo "  Dockerfile: $DOCKERFILE"
echo

docker build \
    --progress=plain \
    -f "$DOCKERFILE" \
    -t "${IMAGE}:${TAG}" \
    -t "${DATED_TAG}" \
    "${EXTRA_ARGS[@]}" \
    .

echo
echo "=========================================="
echo " Build complete"
echo "=========================================="

docker image inspect "${IMAGE}:${TAG}" \
    --format='Image size: {{.Size}} bytes'

# ---- Remember the choice for export.sh / import.sh / run.sh ----
if [[ ! -f "$ENV_FILE" ]]; then
    [[ -f .env.example ]] && cp .env.example "$ENV_FILE" || touch "$ENV_FILE"
fi
for kv in "BACKEND=${BACKEND}" "IMAGE_TAG=${TAG}"; do
    key="${kv%%=*}"
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${kv}|" "$ENV_FILE"
    else
        echo "$kv" >> "$ENV_FILE"
    fi
done

echo
echo "Images tagged:"
echo "  ${IMAGE}:${TAG}"
echo "  ${DATED_TAG}   (dated, so you can tell builds apart across machines)"
echo
echo "Backend '${BACKEND}' saved to ${ENV_FILE} (used by export.sh, import.sh, run.sh)."
echo
echo "Next:"
echo "  ./export.sh"
