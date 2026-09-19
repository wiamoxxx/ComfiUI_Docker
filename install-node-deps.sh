#!/usr/bin/env bash

set -euo pipefail

COMFY_DIR="/opt/ComfyUI"
NODE_DIR="$COMFY_DIR/custom_nodes"
FAILED=0

mkdir -p "$NODE_DIR"

echo "=========================================="
echo " Installing ComfyUI custom nodes"
echo "=========================================="

while IFS= read -r line || [[ -n "$line" ]]; do

    # Skip comments and empty lines
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    repo=$(echo "$line" | awk '{print $1}')
    directory=$(echo "$line" | awk '{print $2}')
    # Optional 3rd column: a tag/branch/commit to pin the node to.
    # Leave it out to track that node's default branch (unpinned).
    ref=$(echo "$line" | awk '{print $3}')

    echo
    echo "------------------------------------------"
    echo "Node: $directory"
    echo "Repository: $repo"
    [[ -n "$ref" ]] && echo "Pinned ref: $ref"
    echo "------------------------------------------"

    cd "$NODE_DIR"

    if [ ! -d "$directory" ]; then
        if [[ -n "$ref" ]]; then
            git clone --branch "$ref" --depth 1 "$repo" "$directory"
        else
            git clone --depth 1 "$repo" "$directory"
        fi
    else
        echo "Already exists: $directory"
    fi

    cd "$directory"

    # Standard dependency file
    if [ -f requirements.txt ]; then
        echo "Installing requirements.txt..."
        pip install -r requirements.txt || {
            echo "WARNING: requirements.txt failed for $directory"
            FAILED=1
        }
    fi

    # Modern Python packaging
    if [ -f pyproject.toml ] && \
       [ ! -f requirements.txt ]; then

        echo "Installing Python package..."
        pip install . || {
            echo "WARNING: pip install . failed for $directory"
            FAILED=1
        }
    fi

    # ComfyUI Manager/custom-node convention
    if [ -f install.py ]; then
        echo "Running install.py..."
        python install.py || {
            echo
            echo "WARNING:"
            echo "install.py failed for $directory"
            echo "Continuing build so the complete dependency"
            echo "problem can be inspected later."
            echo
            FAILED=1
        }
    fi

done < /tmp/nodes.txt

echo
echo "=========================================="
echo " Custom nodes installed"
echo "=========================================="

echo
echo "Installed nodes:"
find "$NODE_DIR" -mindepth 1 -maxdepth 1 -type d \
    -printf "  %f\n" | sort

echo
echo "Python packages:"
pip freeze > /opt/comfyui-python-lock.txt

echo "Dependency lock written to:"
echo "/opt/comfyui-python-lock.txt"

if [ "$FAILED" -ne 0 ]; then
    echo
    echo "=========================================="
    echo " NOTE: one or more custom nodes reported a"
    echo " dependency install failure above. The image"
    echo " build did NOT stop, but that node may not"
    echo " work at runtime. Check the log, fix the"
    echo " version pin/ref in nodes.txt, and rebuild."
    echo "=========================================="
fi
