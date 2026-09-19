# ComfyUI Offline Docker Image

Build a self-contained ComfyUI + custom-nodes Docker image **once**, on a
machine with internet access, then ship it to any number of identical,
offline (or air-gapped) Linux machines — with either **NVIDIA** or **AMD**
GPUs. Model weights are **not** baked into the image — they live outside it
and are bind-mounted into the container at runtime.

```
┌─────────────────────┐          tar file           ┌──────────────────────┐
│   Build machine      │  ───────────────────────►   │   Target machine(s)   │
│   (has internet)      │   comfyui-offline-nvidia.tar │   (Docker + GPU only)  │
│                      │   comfyui-offline-rocm.tar    │                      │
│  ./build.sh            │   (+ .sha256 checksums)       │  ./import.sh           │
│  ./export.sh           │                              │  ./run.sh              │
└─────────────────────┘                              └──────────────────────┘
                                                                  ▲
                                                                  │ bind mount
                                                        /path/to/models (yours)
```

## Choosing a GPU backend

There are two Dockerfiles, one per GPU vendor:

| | `Dockerfile.nvidia` | `Dockerfile.rocm` |
|---|---|---|
| Base image | `nvidia/cuda:...-cudnn-runtime-ubuntu24.04` | `rocm/pytorch:rocm7.2_ubuntu24.04_...` |
| PyTorch | pip-installed from the CUDA wheel index | already installed in the base image, matched to its ROCm build |
| Target hardware | NVIDIA GPUs | AMD GPUs (ROCm-supported) |

`./build.sh` asks which one you want (or takes `--backend nvidia`/`--backend
rocm`, or a `BACKEND=...` environment variable, for scripted/CI use) and
builds the matching Dockerfile. Everything downstream — `export.sh`,
`import.sh`, `run.sh` — picks up the backend automatically from `.env`, so
you only choose once per build.

A single build machine can build both variants (they're tagged separately:
`comfyui-offline:nvidia-latest` / `comfyui-offline:rocm-latest`); each target
machine only ever needs the one matching its own GPU.

## What's in the image vs. what isn't

| Baked into the image | Provided separately, mounted at runtime |
|---|---|
| Ubuntu 24.04 + CUDA/cuDNN or ROCm runtime | Model weights (checkpoints, LoRAs, VAEs, ControlNet, …) |
| Python + PyTorch (matched to the chosen backend) | `input/`, `output/` folders |
| ComfyUI core (pinned to a release tag) | `user/` folder (settings, saved workflows) |
| The custom nodes listed in `nodes.txt` and their Python deps | Optional `extra_model_paths.yaml` |

Because models are never copied into the image, the exported `.tar` stays a
manageable size and you're free to reuse/reorganize your model library
independently of the image itself. This includes **GGUF-quantized models**
(supported via a baked-in custom node) — see
[Working with GGUF models](#working-with-gguf-models).

## Prerequisites

**Build machine** (only needs internet for this one step):
- Docker Engine
- Enough disk space for the base image + PyTorch + custom nodes (a few GB
  per backend you build)

**Every target machine:**
- Linux, with the **same GPU/driver generation as every other target
  machine** (see [Pinned versions](#pinned-versions--why-they-matter) for
  why this matters)
- Docker Engine
- No internet access required from this point on

Plus, depending on the GPU:

<table>
<tr><th>NVIDIA</th><th>AMD (ROCm)</th></tr>
<tr><td>

- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
  installed and configured — `docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu24.04 nvidia-smi`
  should work before you go further
- A driver new enough for the CUDA version baked into the image (check the
  [CUDA/driver compatibility table](https://docs.nvidia.com/deploy/cuda-compatibility/))

</td><td>

- The `amdgpu-dkms` kernel driver installed on the host (no separate
  "container toolkit" needed — ROCm GPU access is plain device nodes)
- `/dev/kfd` and `/dev/dri` present, and your user in the `video`/`render`
  groups — see [AMD's docs](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/how-to/docker.html)
- A ROCm-supported GPU/driver matching the ROCm version baked into the image

</td></tr>
</table>

## 1. Build

```bash
./build.sh
```

You'll be asked `nvidia` or `rocm`. It then builds and tags the image as
`comfyui-offline:<backend>-latest` and `comfyui-offline:<backend>-build-YYYYMMDD`
(the dated tag makes it easy to tell which build is running on which machine
later), and records your choice in `.env`. To skip the prompt:

```bash
./build.sh --backend nvidia
./build.sh --backend rocm
```

Extra arguments are passed straight through to `docker build`, so you can
override the pinned versions without editing a Dockerfile:

```bash
./build.sh --backend nvidia --build-arg COMFYUI_REF=v0.36.1
./build.sh --backend nvidia --build-arg TORCH_INDEX_URL=https://download.pytorch.org/whl/cu128
./build.sh --backend rocm   --build-arg ROCM_IMAGE=rocm/pytorch:rocm7.1.1_ubuntu24.04_py3.12_pytorch_release_2.10.0
```

## 2. Export

```bash
./export.sh
```

Writes `comfyui-offline-<backend>.tar` and its `.sha256` checksum in the
current directory (the backend comes from `.env`, set by `build.sh`). Copy
**both files** to every target machine, along with `docker-compose.yml`,
`docker-compose.nvidia.yml`, `docker-compose.rocm.yml`, `.env.example`,
`import.sh` and `run.sh`.

## 3. Import (on each target machine)

```bash
./import.sh comfyui-offline-nvidia.tar   # or comfyui-offline-rocm.tar
```

This verifies the checksum (if the `.sha256` file is next to it) and runs
`docker load`. If you'd rather do it by hand:

```bash
sha256sum -c comfyui-offline-nvidia.tar.sha256   # optional but recommended
docker load -i comfyui-offline-nvidia.tar
```

## 4. Mount your models and run

ComfyUI expects a `models/` directory with a specific set of sub-folders.
The container creates all of them automatically on startup (empty), so all
you need to do is point `MODELS_PATH` at a folder laid out like this on the
**host**:

```
models/
├── checkpoints/         # main Stable Diffusion / Flux / etc. models
├── loras/
├── vae/
├── vae_approx/
├── clip/                # also GGUF text encoders (ComfyUI-GGUF)
├── clip_vision/
├── controlnet/
├── upscale_models/
├── embeddings/
├── unet/                # also GGUF diffusion models (ComfyUI-GGUF)
├── diffusers/
├── gligen/
├── hypernetworks/
├── photomaker/
├── style_models/
├── configs/
├── animatediff_models/     # used by ComfyUI-AnimateDiff-Evolved
├── ipadapter/              # used by ComfyUI_IPAdapter_plus
├── insightface/            # used by ComfyUI_IPAdapter_plus / Impact-Pack
└── ultralytics/            # used by ComfyUI-Impact-Pack (detector models)
```

You don't need to create these by hand — copy your existing model files into
the matching folders and the container will pick them up. If your model
library is already organized differently, see
[Using extra_model_paths.yaml](#using-extra_model_pathsyaml-instead) below
instead of reshuffling everything.

Set up your `.env` (skip this if `build.sh` already created/updated it for
you on this machine):

```bash
cp .env.example .env
# then edit .env, in particular:
#   BACKEND=nvidia            (or rocm - must match the image you imported)
#   MODELS_PATH=/path/to/your/models
```

Then start ComfyUI:

```bash
./run.sh
```

This reads `BACKEND` from `.env` and runs `docker compose` with the matching
GPU overlay (`docker-compose.nvidia.yml` or `docker-compose.rocm.yml`) on
top of the shared `docker-compose.yml`. Equivalent by hand:

```bash
docker compose -f docker-compose.yml -f docker-compose.nvidia.yml up -d
# or
docker compose -f docker-compose.yml -f docker-compose.rocm.yml up -d
```

Open `http://<machine-ip>:8188` in a browser. To confirm the API is up
without a browser:

```bash
curl http://localhost:8188/system_stats
```

### Without docker-compose

```bash
# NVIDIA
docker run -d \
  --name comfyui-offline \
  --gpus all \
  -p 8188:8188 \
  -v /path/to/models:/opt/ComfyUI/models \
  -v /path/to/input:/opt/ComfyUI/input \
  -v /path/to/output:/opt/ComfyUI/output \
  -v /path/to/user:/opt/ComfyUI/user \
  comfyui-offline:nvidia-latest

# AMD ROCm
docker run -d \
  --name comfyui-offline \
  --device=/dev/kfd --device=/dev/dri \
  --group-add video --group-add render \
  --ipc=host --shm-size=8g \
  -p 8188:8188 \
  -v /path/to/models:/opt/ComfyUI/models \
  -v /path/to/input:/opt/ComfyUI/input \
  -v /path/to/output:/opt/ComfyUI/output \
  -v /path/to/user:/opt/ComfyUI/user \
  comfyui-offline:rocm-latest
```

## Configuration

Everything is controlled through `.env` (copied from `.env.example`):

| Variable | Default | Purpose |
|---|---|---|
| `BACKEND` | `nvidia` | `nvidia` or `rocm` — selects the GPU overlay `run.sh` uses, and the default tag `export.sh`/`build.sh` use |
| `IMAGE_NAME` / `IMAGE_TAG` | `comfyui-offline` / `<backend>-latest` | Which image/tag is run |
| `COMFY_PORT` | `8188` | Host port ComfyUI is published on |
| `MODELS_PATH` | `./data/models` | Host folder mounted at `/opt/ComfyUI/models` |
| `INPUT_PATH` / `OUTPUT_PATH` / `USER_PATH` | `./data/…` | Host folders for input images, output images, and ComfyUI's own settings |
| `CLI_ARGS` | *(empty)* | Extra flags appended to `python main.py`, e.g. `--lowvram`, `--preview-method auto`, `--cpu` |

`CLI_ARGS` means you can tune ComfyUI per-machine (e.g. a lower-VRAM card)
without rebuilding or re-exporting the image.

### Using extra_model_paths.yaml instead

If reorganizing your existing model folder into the layout above isn't
practical, create a `extra_model_paths.yaml` next to `docker-compose.yml`
(see the [example in the ComfyUI repo](https://github.com/comfyanonymous/ComfyUI/blob/master/extra_model_paths.yaml.example)
for the exact format), then uncomment its line in `docker-compose.yml`:

```yaml
    volumes:
      - ./extra_model_paths.yaml:/opt/ComfyUI/extra_model_paths.yaml:ro
```

This can be used **in addition to** the `MODELS_PATH` mount, not just
instead of it. It works the same way regardless of `BACKEND`.

## Working with GGUF models

The image includes [ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF)
(listed in `nodes.txt`), which adds native support for models quantized to
the **GGUF** format — the format popularized by llama.cpp. GGUF lets large
diffusion models (Flux, SD3.5, …) run in far less VRAM by using lower-bit
quantized weights, at some cost to quality — handy for lower-end GPUs on
either backend.

### Where GGUF files go

No separate setup — GGUF files use the same `MODELS_PATH` mount as every
other model, just in the folder matching what they contain:

| Model type | Folder | Node to use |
|---|---|---|
| Diffusion/UNet model (e.g. `flux1-dev-Q4_0.gguf`) | `models/unet/` | **UNETLoader (GGUF)** |
| Quantized text encoder (e.g. a GGUF T5) | `models/clip/` | **CLIPLoader (gguf)** / **DualCLIPLoader (gguf)** |

Both node types live under the **bootleg** category in ComfyUI's node
picker. In a workflow, swap the stock "Load Diffusion Model" node for
**UNETLoader (GGUF)**, point it at your `.gguf` file, and wire it up the
same way you would a regular checkpoint. The CLIP-side GGUF loaders can mix
`.gguf` and regular `.safetensors`/`.bin` encoders interchangeably, so you
only need a GGUF version of whichever part you actually want quantized.

### Getting GGUF models

Pre-quantized GGUF versions of popular models are published on Hugging
Face, e.g.:
- [city96/FLUX.1-dev-gguf](https://huggingface.co/city96/FLUX.1-dev-gguf)
- [city96/FLUX.1-schnell-gguf](https://huggingface.co/city96/FLUX.1-schnell-gguf)
- [city96/stable-diffusion-3.5-large-gguf](https://huggingface.co/city96/stable-diffusion-3.5-large-gguf)
- [city96/t5-v1_1-xxl-encoder-gguf](https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf) (quantized T5 text encoder)

Download these on a machine with internet access, then copy the `.gguf`
files into `MODELS_PATH/unet` or `MODELS_PATH/clip` on the target machine
like any other model file — no import step, no rebuild.

### Notes

- LoRA loading against a GGUF base model works through the regular built-in
  LoRA loader nodes, but is considered experimental upstream.
- This works identically on both builds: the node's only dependencies
  (`gguf`, `sentencepiece`, `protobuf`) are plain Python packages with no
  CUDA/ROCm-specific builds, so `install-node-deps.sh` installs them the
  same way regardless of `BACKEND`.

## Pinned versions — why they matter

- **ComfyUI** is cloned at a specific tag (`COMFYUI_REF` build arg, default
  `v0.36.0`) in *both* Dockerfiles, not the `main` branch, so a rebuild
  months from now doesn't silently pull in breaking changes.
- **NVIDIA build**: PyTorch is installed from a CUDA-version-specific index
  (`TORCH_INDEX_URL` build arg, default the `cu130` index) rather than a
  pinned exact version, since the officially compatible
  PyTorch/torchvision/torchaudio trio for a given CUDA index changes over
  time and pip resolves a matching set automatically.
- **ROCm build**: PyTorch is *not* pip-installed at all — it comes
  preinstalled and pre-validated in the `rocm/pytorch` base image
  (`ROCM_IMAGE` build arg). This is more reliable than pip-installing a ROCm
  wheel yourself: AMD's stable PyTorch wheel index consistently lags behind
  the newest ROCm releases (nightly-only for the newest ones), while the
  `rocm/pytorch` image tags are pre-tested combinations. Change `ROCM_IMAGE`
  to a different tag from [Docker Hub](https://hub.docker.com/r/rocm/pytorch/tags)
  if you need a different ROCm/PyTorch/GPU-architecture pairing.
- The exact Python packages actually installed for any given build are
  recorded in `/opt/comfyui-python-lock.txt` inside the image —
  `docker run --rm comfyui-offline:nvidia-latest cat /opt/comfyui-python-lock.txt`
  to inspect them (swap the tag for `rocm-latest` as needed).
- **Custom nodes** (`nodes.txt`) are unpinned by default (tracking each
  node's default branch at build time), because most of them don't publish
  stable release tags. Once you have a build you've tested and trust, pin
  every row to the commit hash you built with by adding it as a third
  column, e.g.:
  ```
  https://github.com/cubiq/ComfyUI_essentials ComfyUI_essentials a1b2c3d4
  ```
  so a future rebuild reproduces exactly what you validated. This applies
  identically to both backends, since custom nodes are GPU-agnostic Python.
- **The base image / driver**: all target machines of a given backend must
  have a driver that supports the CUDA/ROCm version baked into that image.
  Since the brief here is "same specs, same everything" per fleet, this is
  usually a non-issue, but it's the first thing to check if the container
  starts on one machine and fails on another.

## Updating

- **New/updated custom node config**: edit `nodes.txt`, then rebuild both
  backends you use (`./build.sh --backend nvidia && ./build.sh --backend rocm`)
  and redistribute.
- **New ComfyUI version**: `./build.sh --backend nvidia --build-arg COMFYUI_REF=v0.x.y`
  (and/or `--backend rocm`), test it, then export/redistribute as usual.
- **New models**: no rebuild needed at all — just add files under
  `MODELS_PATH` on each target machine and restart the container
  (`docker compose -f docker-compose.yml -f docker-compose.<backend>.yml restart`)
  so ComfyUI rescans.

## Troubleshooting

- **"could not select device driver... with capabilities: [[gpu]]"** (NVIDIA)
  — the NVIDIA Container Toolkit isn't installed/configured on this machine,
  or the driver doesn't support the image's CUDA version.
- **"docker: Error response from daemon: ... /dev/kfd: no such file"** (ROCm)
  — the `amdgpu-dkms` driver isn't loaded on the host, or this machine's GPU
  isn't ROCm-supported.
- **Permission denied accessing `/dev/kfd` / `/dev/dri`** (ROCm) — your user
  (or whoever Docker runs as) isn't in the `video`/`render` groups on the
  **host**; add them and re-login, or `sudo usermod -aG video,render $USER`.
- **Container starts but the web UI shows no models** — check `MODELS_PATH`
  in `.env`, and check the startup logs (`docker compose ... logs`) for the
  "no files found under /opt/ComfyUI/models" warning the entrypoint prints;
  it means the mount isn't pointing where you think it is.
- **Startup log says "no GPU visible to PyTorch"** — the entrypoint's own
  sanity check failing; almost always one of the two points above,
  independent of which backend you're on.
- **Permission denied writing to output/user folders** — the container runs
  as root by default, but the host folders may be owned by a different
  user; either `chown` the host folders or run as your own UID.
- **ComfyUI-Manager tries to reach the internet and hangs/times out** — this
  is expected on an air-gapped machine. It's only used to browse/install
  *additional* nodes; everything already baked into the image works without
  it. You can ignore the failed update checks, or disable them via
  ComfyUI-Manager's own config file if they're too noisy.
- **Port already in use** — change `COMFY_PORT` in `.env`.
- **Wrong overlay / image for this machine's GPU** — `run.sh` and
  `export.sh` both trust `BACKEND` in `.env`; if it's wrong for this
  machine's actual hardware, fix `.env` rather than the scripts.

## Security notes

- The container currently runs as **root** and ComfyUI listens on
  `0.0.0.0` with **no authentication**. That's fine on an isolated/trusted
  network, but if a target machine is reachable from anywhere less trusted,
  put it behind a reverse proxy with auth, or bind it to `127.0.0.1` and use
  an SSH tunnel, rather than exposing `8188` directly.
- Each custom node in `nodes.txt` carries its own license and its own trust
  boundary — you're running third-party code inside the container. Review
  `nodes.txt` before adding new entries.

## License

This repository only contains build tooling. ComfyUI and each custom node
listed in `nodes.txt` are separate projects with their own licenses — see
their respective repositories.
