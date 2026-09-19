# ComfyUI Offline Docker Image

Build a self-contained ComfyUI + custom-nodes Docker image **once**, on a
machine with internet access, then ship it to any number of identical,
offline (or air-gapped) Linux machines that only have Docker and an NVIDIA
GPU. Model weights are **not** baked into the image — they live outside it
and are bind-mounted into the container at runtime.

```
┌─────────────────────┐          tar file           ┌──────────────────────┐
│   Build machine      │  ───────────────────────►   │   Target machine(s)   │
│   (has internet)      │   comfyui-offline.tar        │   (Docker + GPU only)  │
│                      │   comfyui-offline.tar.sha256 │                      │
│  build.sh            │                              │  import.sh            │
│  export.sh           │                              │  docker compose up    │
└─────────────────────┘                              └──────────────────────┘
                                                                  ▲
                                                                  │ bind mount
                                                        /path/to/models (yours)
```

## What's in the image vs. what isn't

| Baked into the image | Provided separately, mounted at runtime |
|---|---|
| Ubuntu 24.04 + CUDA/cuDNN runtime | Model weights (checkpoints, LoRAs, VAEs, ControlNet, …) |
| Python venv + PyTorch | `input/`, `output/` folders |
| ComfyUI core (pinned to a release tag) | `user/` folder (settings, saved workflows) |
| The custom nodes listed in `nodes.txt` and their Python deps | Optional `extra_model_paths.yaml` |

Because models are never copied into the image, the exported `.tar` stays a
manageable size and you're free to reuse/reorganize your model library
independently of the image itself.

## Prerequisites

**Build machine** (only needs internet for this one step):
- Docker Engine
- Enough disk space for the CUDA base image + PyTorch + custom nodes (a few GB)

**Every target machine:**
- Linux, with the **same GPU/driver generation** as the others (see
  [Pinned versions](#pinned-versions--why-they-matter) below for why this
  matters)
- Docker Engine
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
  installed and configured (`docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu24.04 nvidia-smi`
  should work before you go any further)
- An NVIDIA driver new enough for the CUDA version baked into the image
  (check the [CUDA/driver compatibility table](https://docs.nvidia.com/deploy/cuda-compatibility/))
- No internet access required from this point on

## 1. Build

```bash
./build.sh
```

This builds and tags the image as `comfyui-offline:latest` and
`comfyui-offline:build-YYYYMMDD` (the dated tag makes it easy to tell which
build is running on which machine later). Extra arguments are passed
straight through to `docker build`, so you can override the pinned versions
without editing the `Dockerfile`:

```bash
./build.sh --build-arg COMFYUI_REF=v0.36.1
./build.sh --build-arg TORCH_INDEX_URL=https://download.pytorch.org/whl/cu128
```

## 2. Export

```bash
./export.sh
```

Writes `comfyui-offline.tar` and `comfyui-offline.tar.sha256` in the current
directory. Copy **both files** (USB drive, `scp`, internal file share, …) to
every target machine, along with `docker-compose.yml`, `.env.example` and
`import.sh`.

## 3. Import (on each target machine)

```bash
./import.sh comfyui-offline.tar
```

This verifies the checksum (if the `.sha256` file is next to it) and runs
`docker load`. If you'd rather do it by hand:

```bash
sha256sum -c comfyui-offline.tar.sha256   # optional but recommended
docker load -i comfyui-offline.tar
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
├── clip/
├── clip_vision/
├── controlnet/
├── upscale_models/
├── embeddings/
├── unet/
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

Set up your `.env`:

```bash
cp .env.example .env
# then edit .env, in particular:
#   MODELS_PATH=/path/to/your/models
```

Then start ComfyUI:

```bash
docker compose up -d
```

Open `http://<machine-ip>:8188` in a browser. To confirm the API is up
without a browser:

```bash
curl http://localhost:8188/system_stats
```

### Without docker-compose

```bash
docker run -d \
  --name comfyui-offline \
  --gpus all \
  -p 8188:8188 \
  -v /path/to/models:/opt/ComfyUI/models \
  -v /path/to/input:/opt/ComfyUI/input \
  -v /path/to/output:/opt/ComfyUI/output \
  -v /path/to/user:/opt/ComfyUI/user \
  comfyui-offline:latest
```

## Configuration

Everything is controlled through `.env` (copied from `.env.example`):

| Variable | Default | Purpose |
|---|---|---|
| `IMAGE_NAME` / `IMAGE_TAG` | `comfyui-offline` / `latest` | Which image/tag `docker compose` runs |
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
instead of it.

## Pinned versions — why they matter

- **ComfyUI** is cloned at a specific tag (`COMFYUI_REF` build arg, default
  `v0.36.0`), not the `main` branch, so a rebuild months from now doesn't
  silently pull in breaking changes.
- **PyTorch** is installed from a CUDA-version-specific index
  (`TORCH_INDEX_URL`, default the `cu130` index) rather than a pinned exact
  version, since the officially compatible PyTorch/torchvision/torchaudio
  trio for a given CUDA index changes over time and pip resolves a matching
  set automatically. The exact versions actually installed for any given
  build are recorded in `/opt/comfyui-python-lock.txt` inside the image —
  `docker run --rm comfyui-offline:latest cat /opt/comfyui-python-lock.txt`
  to inspect them.
- **Custom nodes** (`nodes.txt`) are unpinned by default (tracking each
  node's default branch at build time), because most of them don't publish
  stable release tags. Once you have a build you've tested and trust, pin
  every row to the commit hash you built with by adding it as a third
  column, e.g.:
  ```
  https://github.com/cubiq/ComfyUI_essentials ComfyUI_essentials a1b2c3d4
  ```
  so a future rebuild reproduces exactly what you validated.
- **The base CUDA image / driver**: all target machines must have an NVIDIA
  driver that supports the CUDA version baked into the image. Since the
  brief here is "same specs, same everything," this is usually a non-issue,
  but it's the first thing to check if the container starts on one machine
  and fails on another.

## Updating

- **New/updated custom node config**: edit `nodes.txt`, then `./build.sh &&
  ./export.sh` and redistribute.
- **New ComfyUI version**: `./build.sh --build-arg COMFYUI_REF=v0.x.y`, test
  it, then export/redistribute as usual.
- **New models**: no rebuild needed at all — just add files under
  `MODELS_PATH` on each target machine and restart the container
  (`docker compose restart`) so ComfyUI rescans.

## Troubleshooting

- **"could not select device driver... with capabilities: [[gpu]]"** — the
  NVIDIA Container Toolkit isn't installed/configured on this machine, or
  the driver doesn't support the image's CUDA version.
- **Container starts but the web UI shows no models** — check `MODELS_PATH`
  in `.env`, and check the startup logs (`docker compose logs`) for the
  "no files found under /opt/ComfyUI/models" warning the entrypoint prints;
  it means the mount isn't pointing where you think it is.
- **Permission denied writing to output/user folders** — the container runs
  as root by default, but the host folders may be owned by a different
  user; either `chown` the host folders or run as your own UID (see
  [Security notes](#security-notes)).
- **ComfyUI-Manager tries to reach the internet and hangs/times out** — this
  is expected on an air-gapped machine. It's only used to browse/install
  *additional* nodes; everything already baked into the image works without
  it. You can ignore the failed update checks, or disable them via
  ComfyUI-Manager's own config file if they're too noisy.
- **Port already in use** — change `COMFY_PORT` in `.env`.

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
