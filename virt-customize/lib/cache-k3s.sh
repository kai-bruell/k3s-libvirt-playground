#!/bin/bash
# Stellt sicher, dass das k3s Binary gecacht ist.

K3S_VERSION=${1:-"v1.28.5+k3s1"}
TARGET_DIR="cache"
K3S_BINARY_PATH="${TARGET_DIR}/k3s-${K3S_VERSION}"

mkdir -p "$TARGET_DIR"

if [ ! -f "$K3S_BINARY_PATH" ]; then
    echo "Lade k3s Version $K3S_VERSION herunter..."
    curl -sfL https://github.com/k3s-io/k3s/releases/download/"$K3S_VERSION"/k3s --output "$K3S_BINARY_PATH"
    chmod +x "$K3S_BINARY_PATH"
    echo "Download abgeschlossen. Binary gespeichert unter $K3S_BINARY_PATH"
else
    echo "k3s Version $K3S_VERSION ist bereits gecacht."
fi
