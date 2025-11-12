#!/bin/bash
# Fix GPT by copying GPT headers from image file using dd
# This bypasses macOS SIP restrictions
# Usage: sudo ./fix-gpt-with-dd.sh <device> <image-file>

set -e

DEVICE="${1:-/dev/rdisk7}"
IMAGE_FILE="${2}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then 
    log_error "Please run with sudo"
    exit 1
fi

if [ -z "$IMAGE_FILE" ] || [ ! -f "$IMAGE_FILE" ]; then
    log_error "Usage: sudo $0 <device> <image-file>"
    log_error "Example: sudo $0 /dev/rdisk7 ~/backups/.../image.img"
    exit 1
fi

DISK_DEVICE=$(echo "$DEVICE" | sed 's/rdisk/disk/')

log_info "=== Fix GPT using dd ==="
log_info "Device: $DEVICE (disk: $DISK_DEVICE)"
log_info "Image file: $IMAGE_FILE"
log_info ""

# Check if image is compressed
if [[ "$IMAGE_FILE" == *.gz ]]; then
    log_warn "Image is compressed. This script needs an uncompressed image."
    log_warn "Please decompress it first or use the uncompressed version."
    log_info "You can decompress with: gunzip -c $IMAGE_FILE > /tmp/image.img"
    exit 1
fi

# Get device size
log_step "Step 1: Getting device information..."
DEVICE_SIZE=$(diskutil info "$DISK_DEVICE" 2>/dev/null | grep -i "disk size" | grep -oE "[0-9]+" | head -1)
if [ -z "$DEVICE_SIZE" ]; then
    DEVICE_SIZE=$(diskutil info "$DISK_DEVICE" 2>/dev/null | grep -i "total size" | grep -oE "[0-9]+" | head -1)
fi
if [ ${#DEVICE_SIZE} -lt 10 ]; then
    DEVICE_SIZE=$(echo "$DEVICE_SIZE * 1024 * 1024 * 1024" | bc | awk '{print int($1)}')
fi

IMAGE_SIZE=$(stat -f%z "$IMAGE_FILE" 2>/dev/null || stat -c%s "$IMAGE_FILE" 2>/dev/null)

log_info "Device size: $(echo "scale=2; $DEVICE_SIZE / 1024 / 1024 / 1024" | bc) GB"
log_info "Image size: $(echo "scale=2; $IMAGE_SIZE / 1024 / 1024 / 1024" | bc) GB"

# GPT header is at sector 1 (512 bytes), GPT backup is at the end
# GPT header: 512 bytes at offset 512 (sector 1)
# GPT backup: 512 bytes at the end of the disk (or end of image if smaller)

log_step "Step 2: Unmounting device..."
diskutil unmountDisk "$DISK_DEVICE" 2>/dev/null || true
sleep 2

log_step "Step 3: Copying GPT header from image to device..."
log_info "Copying primary GPT header (512 bytes at offset 512)..."
dd if="$IMAGE_FILE" of="$DEVICE" bs=512 skip=1 seek=1 count=1 2>&1 | grep -v "records" || true
sync

log_step "Step 4: Copying GPT partition table (33 sectors starting at sector 2)..."
log_info "Copying GPT partition entries (16KB)..."
dd if="$IMAGE_FILE" of="$DEVICE" bs=512 skip=2 seek=2 count=32 2>&1 | grep -v "records" || true
sync

log_step "Step 5: Copying GPT backup header..."
# GPT backup is at the end of the disk
# Calculate backup location: last sector of device
DEVICE_SECTORS=$((DEVICE_SIZE / 512))
BACKUP_SECTOR=$((DEVICE_SECTORS - 1))

log_info "GPT backup should be at sector $BACKUP_SECTOR"
log_info "Copying GPT backup header from end of image..."

# Try to get backup from image (if image has it)
IMAGE_SECTORS=$((IMAGE_SIZE / 512))
if [ $IMAGE_SECTORS -gt 34 ]; then
    IMAGE_BACKUP_SECTOR=$((IMAGE_SECTORS - 1))
    log_info "Image has $IMAGE_SECTORS sectors, backup at sector $IMAGE_BACKUP_SECTOR"
    dd if="$IMAGE_FILE" of="$DEVICE" bs=512 skip=$IMAGE_BACKUP_SECTOR seek=$BACKUP_SECTOR count=1 2>&1 | grep -v "records" || true
    sync
else
    log_warn "Image is too small to contain GPT backup, skipping backup copy"
fi

log_step "Step 6: Verifying GPT..."
sleep 2

if gpt show "$DISK_DEVICE" >/dev/null 2>&1; then
    log_info "✓ GPT partition table is now readable!"
    log_info ""
    log_info "Partition table:"
    gpt show "$DISK_DEVICE" | grep "GPT part" || log_warn "No partitions found"
else
    log_warn "GPT still not readable, but headers have been copied"
    log_warn "You may need to:"
    log_warn "  1. Physically remove and reinsert the SD card"
    log_warn "  2. Or use a Linux system to fix the GPT"
fi

log_info ""
log_info "=== Done ==="

