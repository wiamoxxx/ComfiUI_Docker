# ==============================================================
# ComfyUI - Offline / Air-gapped Docker Image
# ==============================================================
# Build this image on a machine with internet access, then ship
# it (via export.sh / import.sh) to machines that have Docker +
# the NVIDIA Container Toolkit but no internet access.
#
# Model weights are NOT baked into the image - they are mounted
# at runtime from an external folder. See README.md.
# ==============================================================

ARG CUDA_IMAGE=nvidia/cuda:13.0.0-cudnn-runtime-ubuntu24.04
FROM ${CUDA_IMAGE}

# Pin ComfyUI to a known-good release tag so every build produces
# the same result. Bump this deliberately, then rebuild + retest.
ARG COMFYUI_REF=v0.36.0

# The PyTorch wheel index must match the CUDA version in the base
# image above. If you change CUDA_IMAGE, change this too.
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu130

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

# ------------------------------------------------------------
# System dependencies
#
# python3-dev / cmake / ninja-build are needed to build a few
# custom-node Python dependencies (e.g. insightface, dlib-style
# packages used by Impact-Pack / IPAdapter) that ship without a
# prebuilt wheel for every platform.
# ------------------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    git \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgomp1 \
    wget \
    curl \
    ca-certificates \
    build-essential \
    cmake \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Python
# ------------------------------------------------------------

RUN python3 -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

RUN python -m pip install --upgrade pip setuptools wheel

# ------------------------------------------------------------
# ComfyUI
# ------------------------------------------------------------

WORKDIR /opt

RUN git clone --branch "${COMFYUI_REF}" --depth 1 \
    https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /opt/ComfyUI

# ------------------------------------------------------------
# PyTorch
#
# NOTE:
# This must match the CUDA version of the base image and the
# NVIDIA driver on every target machine. All target machines are
# assumed to share the same GPU/driver generation (see README).
# ------------------------------------------------------------

RUN pip install \
    torch \
    torchvision \
    torchaudio \
    --index-url "${TORCH_INDEX_URL}"

# ------------------------------------------------------------
# ComfyUI dependencies
# ------------------------------------------------------------

RUN pip install -r requirements.txt

# ------------------------------------------------------------
# Custom nodes
# ------------------------------------------------------------

COPY nodes.txt /tmp/nodes.txt
COPY install-node-deps.sh /tmp/install-node-deps.sh

RUN chmod +x /tmp/install-node-deps.sh \
    && /tmp/install-node-deps.sh

# ------------------------------------------------------------
# Runtime directories
#
# These are placeholders baked into the image so ComfyUI has
# somewhere to start even before anything is mounted. In normal
# use every one of them is replaced by a bind mount (see
# docker-compose.yml / README.md) - nothing written here persists.
# ------------------------------------------------------------

RUN mkdir -p \
    /opt/ComfyUI/models \
    /opt/ComfyUI/input \
    /opt/ComfyUI/output \
    /opt/ComfyUI/user

# ------------------------------------------------------------
# Entrypoint
#
# Creates the standard model sub-folders (so ComfyUI doesn't
# complain about missing paths on first boot), warns loudly if
# the mounted models folder looks empty, and lets CLI_ARGS pass
# extra flags to ComfyUI at runtime without rebuilding the image.
# ------------------------------------------------------------

COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

WORKDIR /opt/ComfyUI

EXPOSE 8188

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 \
    CMD curl -fsS http://127.0.0.1:8188/system_stats || exit 1

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD []
