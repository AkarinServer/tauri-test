#!/bin/bash
# Simple image writer like balenaEtcher - just writes the image directly
# Usage: sudo ./etcher-like-write.sh <image-file> <device>

set -e

IMAGE_FILE="${1}"
DEVICE="${2:-/dev/rdisk7}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then 
    log_error "Please run with sudo"
    exit 1
fi

if [ -z "$IMAGE_FILE" ] || [ ! -f "$IMAGE_FILE" ]; then
    log_error "Usage: sudo $0 <image-file> <device>"
    log_error "Example: sudo $0 ~/backups/.../image.img /dev/rdisk7"
    exit 1
fi

DISK_DEVICE=$(echo "$DEVICE" | sed 's/rdisk/disk/')

log_info "=== Etcher-like Image Writer ==="
log_info "Image: $IMAGE_FILE"
log_info "Device: $DEVICE (disk: $DISK_DEVICE)"
log_info ""

# Check if compressed
TEMP_IMAGE=""
if [[ "$IMAGE_FILE" == *.gz ]]; then
    log_info "Image is compressed, decompressing..."
    TEMP_IMAGE="/tmp/etcher_image_$$.img"
    if command -v pv >/dev/null 2>&1; then
        COMPRESSED_SIZE=$(stat -f%z "$IMAGE_FILE" 2>/dev/null || stat -c%s "$IMAGE_FILE" 2>/dev/null)
        COMPRESSED_SIZE_MB=$((COMPRESSED_SIZE / 1024 / 1024))
        pv -s "${COMPRESSED_SIZE_MB}M" "$IMAGE_FILE" | gunzip -c > "$TEMP_IMAGE"
    else
        gunzip -c "$IMAGE_FILE" > "$TEMP_IMAGE"
    fi
    ACTUAL_IMAGE="$TEMP_IMAGE"
else
    ACTUAL_IMAGE="$IMAGE_FILE"
fi

IMAGE_SIZE=$(stat -f%z "$ACTUAL_IMAGE" 2>/dev/null || stat -c%s "$ACTUAL_IMAGE" 2>/dev/null)
IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE / 1024 / 1024 / 1024" | bc)

log_info "Image size: ${IMAGE_SIZE_GB} GB"
log_warn "WARNING: This will erase all data on $DEVICE!"
log_info ""
read -p "Continue? (yes/no) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    [ -n "$TEMP_IMAGE" ] && rm -f "$TEMP_IMAGE"
    exit 0
fi

# Unmount
log_info "Unmounting device..."
diskutil unmountDisk "$DISK_DEVICE" 2>/dev/null || true
sleep 2

# Write image directly (like Etcher does)
log_info "Writing image to device (this may take a while)..."
IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))

if command -v pv >/dev/null 2>&1; then
    dd if="$ACTUAL_IMAGE" bs=4m 2>/dev/null | \
        pv -s "${IMAGE_SIZE_MB}M" | \
        dd of="$DEVICE" bs=4m 2>/dev/null
else
    dd if="$ACTUAL_IMAGE" of="$DEVICE" bs=4m status=progress
fi

sync
log_info "Image written successfully"

# Cleanup
[ -n "$TEMP_IMAGE" ] && rm -f "$TEMP_IMAGE"

log_info ""
log_info "=== Done ==="
log_info "The image has been written directly to the device."
log_info "If the GPT is still not readable, the image itself may have a corrupted GPT."
log_info ""
log_info "Verify with: sudo ./diagnose-sd-card.sh $DEVICE"

