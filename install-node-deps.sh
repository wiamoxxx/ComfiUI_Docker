#!/usr/bin/env bash

set -euo pipefail

COMFY_DIR="/opt/ComfyUI"
NODE_DIR="$COMFY_DIR/custom_nodes"

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

    echo
    echo "------------------------------------------"
    echo "Node: $directory"
    echo "Repository: $repo"
    echo "------------------------------------------"

    cd "$NODE_DIR"

    if [ ! -d "$directory" ]; then
        git clone --depth 1 "$repo" "$directory"
    else
        echo "Already exists: $directory"
    fi

    cd "$directory"

    # Standard dependency file
    if [ -f requirements.txt ]; then
        echo "Installing requirements.txt..."
        pip install -r requirements.txt
    fi

    # Modern Python packaging
    if [ -f pyproject.toml ] && \
       [ ! -f requirements.txt ]; then

        echo "Installing Python package..."
        pip install .
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
