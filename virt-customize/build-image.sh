#!/bin/bash
# =============================================================================
# K3S BASE IMAGE BUILDER with virt-customize
# =============================================================================
# Creates a K3s base image WITHOUT consuming cloud-init
# Cloud-init remains untouched for later Terraform usage
# =============================================================================

set -e

# Configuration
K3S_VERSION="${K3S_VERSION:-v1.28.5+k3s1}"
SOURCE_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
CACHE_DIR="./cache"
OUTPUT_DIR="../libvirt-pool"
OUTPUT_IMAGE="k3s-base-image.qcow2"
WORK_IMAGE="work-image.qcow2"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== K3s Base Image Build with virt-customize ===${NC}"

# 1. Create cache directories
mkdir -p "$CACHE_DIR"
mkdir -p "$OUTPUT_DIR"

# 2. Download Debian cloud image (if not present)
DEBIAN_IMAGE="$CACHE_DIR/debian-12-generic-amd64.qcow2"
if [ ! -f "$DEBIAN_IMAGE" ]; then
    echo -e "${GREEN}Downloading Debian cloud image...${NC}"
    curl -L "$SOURCE_IMAGE_URL" -o "$DEBIAN_IMAGE"
else
    echo -e "${GREEN}Debian cloud image already present.${NC}"
fi

# 3. Cache k3s binary
K3S_BINARY="$CACHE_DIR/k3s-${K3S_VERSION}"
if [ ! -f "$K3S_BINARY" ]; then
    echo -e "${GREEN}Caching k3s binary...${NC}"
    ./lib/cache-k3s.sh "$K3S_VERSION"
else
    echo -e "${GREEN}K3s binary already cached.${NC}"
fi

# 4. Create working copy of the image
echo -e "${GREEN}Creating working copy of the image...${NC}"
cp "$DEBIAN_IMAGE" "$WORK_IMAGE"

# 5. Modify image with virt-customize
echo -e "${BLUE}=== Modifying image with virt-customize ===${NC}"

# Temporary directory for k3s binary
TEMP_DIR=$(mktemp -d)
cp "$K3S_BINARY" "$TEMP_DIR/k3s"

# Download install script
curl -sfL https://get.k3s.io -o "$TEMP_DIR/install-k3s.sh"
chmod +x "$TEMP_DIR/install-k3s.sh"

# Execute virt-customize (requires sudo for kernel access)
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

# 6. Move image to output directory
echo -e "${GREEN}Moving image to $OUTPUT_DIR...${NC}"
sudo mv "$WORK_IMAGE" "$OUTPUT_DIR/$OUTPUT_IMAGE"
sudo chown $USER:$USER "$OUTPUT_DIR/$OUTPUT_IMAGE"

# 7. Resize image (optional)
echo -e "${GREEN}Resizing image to 20G...${NC}"
qemu-img resize "$OUTPUT_DIR/$OUTPUT_IMAGE" 20G

echo -e "${BLUE}=== Base image created: $OUTPUT_DIR/$OUTPUT_IMAGE ===${NC}"
echo -e "${GREEN}Cloud-init is UNTOUCHED and ready for Terraform!${NC}"
