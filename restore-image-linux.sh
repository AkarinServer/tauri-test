#!/bin/bash
# Simple image restore script for Linux (including RISC-V)
# Similar to balenaEtcher - just writes the image directly
# Usage: sudo ./restore-image-linux.sh <image-file> <device>

set -e

IMAGE_FILE="${1}"
DEVICE="${2}"

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

if [ -z "$IMAGE_FILE" ] || [ -z "$DEVICE" ]; then
    log_error "Usage: sudo $0 <image-file> <device>"
    log_error "Example: sudo $0 ~/backups/.../image.img.gz /dev/mmcblk0"
    log_error "Example: sudo $0 ~/backups/.../image.img.gz /dev/sdb"
    exit 1
fi

if [ ! -f "$IMAGE_FILE" ]; then
    log_error "Image file not found: $IMAGE_FILE"
    exit 1
fi

if [ ! -b "$DEVICE" ]; then
    log_error "Device $DEVICE not found!"
    log_info "Available block devices:"
    lsblk -d -o NAME,SIZE,TYPE | grep -E "disk|mmc" || true
    exit 1
fi

log_info "=== Linux Image Restore ==="
log_info "Image: $IMAGE_FILE"
log_info "Device: $DEVICE"
log_info ""

# Check if compressed
TEMP_IMAGE=""
if [[ "$IMAGE_FILE" == *.gz ]]; then
    log_info "Image is compressed, decompressing..."
    TEMP_IMAGE="/tmp/restore_image_$$.img"
    if command -v pv >/dev/null 2>&1; then
        COMPRESSED_SIZE=$(stat -c%s "$IMAGE_FILE" 2>/dev/null || stat -f%z "$IMAGE_FILE" 2>/dev/null)
        COMPRESSED_SIZE_MB=$((COMPRESSED_SIZE / 1024 / 1024))
        pv -s "${COMPRESSED_SIZE_MB}M" "$IMAGE_FILE" | gunzip -c > "$TEMP_IMAGE"
    else
        gunzip -c "$IMAGE_FILE" > "$TEMP_IMAGE"
    fi
    ACTUAL_IMAGE="$TEMP_IMAGE"
else
    ACTUAL_IMAGE="$IMAGE_FILE"
fi

IMAGE_SIZE=$(stat -c%s "$ACTUAL_IMAGE" 2>/dev/null || stat -f%z "$ACTUAL_IMAGE" 2>/dev/null)
IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE / 1024 / 1024 / 1024" | bc)

DEVICE_SIZE=$(blockdev --getsize64 "$DEVICE" 2>/dev/null || echo "0")
DEVICE_SIZE_GB=$(echo "scale=2; $DEVICE_SIZE / 1024 / 1024 / 1024" | bc)

log_info "Image size: ${IMAGE_SIZE_GB} GB"
log_info "Device size: ${DEVICE_SIZE_GB} GB"

if [ "$IMAGE_SIZE" -gt "$DEVICE_SIZE" ]; then
    log_error "Image is larger than device!"
    [ -n "$TEMP_IMAGE" ] && rm -f "$TEMP_IMAGE"
    exit 1
fi

log_warn "WARNING: This will erase all data on $DEVICE!"
log_info ""
read -p "Continue? (yes/no) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    [ -n "$TEMP_IMAGE" ] && rm -f "$TEMP_IMAGE"
    exit 0
fi

# Unmount
log_info "Unmounting device..."
umount "${DEVICE}"* 2>/dev/null || true
sleep 1

# Write image directly
log_info "Writing image to device (this may take a while)..."
IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))

if command -v pv >/dev/null 2>&1; then
    dd if="$ACTUAL_IMAGE" bs=4M status=none 2>/dev/null | \
        pv -s "${IMAGE_SIZE_MB}M" | \
        dd of="$DEVICE" bs=4M status=none 2>/dev/null
else
    dd if="$ACTUAL_IMAGE" of="$DEVICE" bs=4M status=progress
fi

sync
log_info "Image written successfully"

# Try to fix GPT if needed
log_info "Verifying GPT..."
sleep 2

if command -v gdisk >/dev/null 2>&1; then
    if ! gdisk -l "$DEVICE" >/dev/null 2>&1; then
        log_warn "GPT may be corrupted, attempting recovery..."
        echo -e "r\nd\nw\ny" | gdisk "$DEVICE" 2>&1 | tail -10 || true
        sleep 1
    fi
    
    if gdisk -l "$DEVICE" >/dev/null 2>&1; then
        log_info "✓ GPT is readable"
        log_info ""
        log_info "Partition table:"
        gdisk -l "$DEVICE" | grep -A 20 "Number" | head -25
    else
        log_warn "GPT is still not readable, you may need to fix it manually"
    fi
fi

# Cleanup
[ -n "$TEMP_IMAGE" ] && rm -f "$TEMP_IMAGE"

log_info ""
log_info "=== Done ==="

