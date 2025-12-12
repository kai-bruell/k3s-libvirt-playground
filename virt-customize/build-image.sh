#!/bin/bash
# =============================================================================
# K3S BASE IMAGE BUILDER mit virt-customize
# =============================================================================
# Erstellt ein K3s Base-Image OHNE Cloud-Init zu "verbrauchen"
# Cloud-Init bleibt unberührt für spätere Terraform-Nutzung
# =============================================================================

set -e

# Konfiguration
K3S_VERSION="${K3S_VERSION:-v1.28.5+k3s1}"
SOURCE_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
CACHE_DIR="./cache"
OUTPUT_DIR="../libvirt-pool"
OUTPUT_IMAGE="k3s-base-image.qcow2"
WORK_IMAGE="work-image.qcow2"

# Farben für Output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== K3s Base-Image Build mit virt-customize ===${NC}"

# 1. Cache-Verzeichnisse erstellen
mkdir -p "$CACHE_DIR"
mkdir -p "$OUTPUT_DIR"

# 2. Debian Cloud-Image herunterladen (wenn nicht vorhanden)
DEBIAN_IMAGE="$CACHE_DIR/debian-12-generic-amd64.qcow2"
if [ ! -f "$DEBIAN_IMAGE" ]; then
    echo -e "${GREEN}Debian Cloud-Image wird heruntergeladen...${NC}"
    curl -L "$SOURCE_IMAGE_URL" -o "$DEBIAN_IMAGE"
else
    echo -e "${GREEN}Debian Cloud-Image bereits vorhanden.${NC}"
fi

# 3. K3s Binary cachen
K3S_BINARY="$CACHE_DIR/k3s-${K3S_VERSION}"
if [ ! -f "$K3S_BINARY" ]; then
    echo -e "${GREEN}K3s Binary wird gecacht...${NC}"
    ./lib/cache-k3s.sh "$K3S_VERSION"
else
    echo -e "${GREEN}K3s Binary bereits gecacht.${NC}"
fi

# 4. Arbeitskopie des Images erstellen
echo -e "${GREEN}Arbeitskopie des Images wird erstellt...${NC}"
cp "$DEBIAN_IMAGE" "$WORK_IMAGE"

# 5. Image mit virt-customize modifizieren
echo -e "${BLUE}=== Image wird mit virt-customize modifiziert ===${NC}"

# Temporäres Verzeichnis für k3s Binary
TEMP_DIR=$(mktemp -d)
cp "$K3S_BINARY" "$TEMP_DIR/k3s"

# Install-Script herunterladen
curl -sfL https://get.k3s.io -o "$TEMP_DIR/install-k3s.sh"
chmod +x "$TEMP_DIR/install-k3s.sh"

# virt-customize ausführen (benötigt sudo für Kernel-Zugriff)
sudo virt-customize -a "$WORK_IMAGE" \
  --run-command 'apt-get update' \
  --install net-tools,curl,wget,qemu-guest-agent \
  --copy-in "$TEMP_DIR/k3s:/tmp/" \
  --copy-in "$TEMP_DIR/install-k3s.sh:/tmp/" \
  --run-command 'chmod +x /tmp/k3s' \
  --run-command 'mv /tmp/k3s /usr/local/bin/k3s' \
  --run-command 'chmod +x /tmp/install-k3s.sh' \
  --run-command 'INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_BIN_DIR=/usr/local/bin /tmp/install-k3s.sh' \
  --run-command 'systemctl disable k3s 2>/dev/null || true' \
  --run-command 'systemctl disable k3s-agent 2>/dev/null || true' \
  --run-command 'rm -f /tmp/install-k3s.sh' \
  --run-command 'apt-get clean' \
  --run-command 'rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*' \
  --truncate /etc/machine-id \
  --run-command 'rm -f /var/lib/dbus/machine-id'

# Cleanup
rm -rf "$TEMP_DIR"

# 6. Image in Output-Verzeichnis verschieben
echo -e "${GREEN}Image wird nach $OUTPUT_DIR verschoben...${NC}"
sudo mv "$WORK_IMAGE" "$OUTPUT_DIR/$OUTPUT_IMAGE"
sudo chown $USER:$USER "$OUTPUT_DIR/$OUTPUT_IMAGE"

# 7. Image vergrößern (optional)
echo -e "${GREEN}Image wird auf 20G vergrößert...${NC}"
qemu-img resize "$OUTPUT_DIR/$OUTPUT_IMAGE" 20G

echo -e "${BLUE}=== Base-Image erstellt: $OUTPUT_DIR/$OUTPUT_IMAGE ===${NC}"
echo -e "${GREEN}Cloud-Init ist UNBERÜHRT und bereit für Terraform!${NC}"
