FROM nvidia/cuda:13.0.0-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

# ------------------------------------------------------------
# System dependencies
# ------------------------------------------------------------

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
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

RUN git clone https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /opt/ComfyUI

# ------------------------------------------------------------
# PyTorch
#
# NOTE:
# This should be changed if your GPU requires a different
# CUDA/PyTorch combination.
# ------------------------------------------------------------

RUN pip install \
    torch \
    torchvision \
    torchaudio \
    --index-url https://download.pytorch.org/whl/cu130

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
# ------------------------------------------------------------

RUN mkdir -p \
    /opt/ComfyUI/models \
    /opt/ComfyUI/input \
    /opt/ComfyUI/output \
    /opt/ComfyUI/user

# ------------------------------------------------------------
# Runtime
# ------------------------------------------------------------

WORKDIR /opt/ComfyUI

EXPOSE 8188

CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
