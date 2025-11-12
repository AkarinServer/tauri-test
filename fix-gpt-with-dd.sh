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

log_step "Step 5: Copying GPT backup..."
# GPT backup is at the end of the disk
# Calculate backup location: last 33 sectors of device (32 for partition table + 1 for header)
DEVICE_SECTORS=$((DEVICE_SIZE / 512))
BACKUP_START_SECTOR=$((DEVICE_SECTORS - 33))

log_info "Device has $DEVICE_SECTORS sectors"
log_info "GPT backup should start at sector $BACKUP_START_SECTOR (last 33 sectors)"

# Try to get backup from image (if image has it)
IMAGE_SECTORS=$((IMAGE_SIZE / 512))
if [ $IMAGE_SECTORS -gt 34 ]; then
    IMAGE_BACKUP_START=$((IMAGE_SECTORS - 33))
    log_info "Image has $IMAGE_SECTORS sectors, backup starts at sector $IMAGE_BACKUP_START"
    log_info "Copying GPT backup (33 sectors: partition table + header)..."
    
    # Copy the backup partition table (32 sectors)
    dd if="$IMAGE_FILE" of="$DEVICE" bs=512 skip=$IMAGE_BACKUP_START seek=$BACKUP_START_SECTOR count=32 2>&1 | grep -v "records" || {
        log_warn "Failed to copy backup partition table, trying header only..."
        # Try just the header
        IMAGE_BACKUP_HEADER=$((IMAGE_SECTORS - 1))
        DEVICE_BACKUP_HEADER=$((DEVICE_SECTORS - 1))
        dd if="$IMAGE_FILE" of="$DEVICE" bs=512 skip=$IMAGE_BACKUP_HEADER seek=$DEVICE_BACKUP_HEADER count=1 2>&1 | grep -v "records" || true
    }
    sync
else
    log_warn "Image is too small to contain GPT backup"
    log_warn "Will try to create backup from primary GPT..."
    
    # Copy primary GPT to backup location
    log_info "Copying primary GPT to backup location..."
    dd if="$DEVICE" of="$DEVICE" bs=512 skip=2 seek=$BACKUP_START_SECTOR count=32 2>&1 | grep -v "records" || true
    dd if="$DEVICE" of="$DEVICE" bs=512 skip=1 seek=$((DEVICE_SECTORS - 1)) count=1 2>&1 | grep -v "records" || true
    sync
fi

log_step "Step 6: Fixing GPT checksums..."
# GPT headers have checksums that need to be recalculated
# We can't easily fix this with dd, but we can try gpt recover if it works
log_info "Attempting to fix GPT checksums..."

# Try to use gdisk or gpt recover (may be blocked by SIP)
if command -v gdisk >/dev/null 2>&1; then
    log_info "Found gdisk, attempting to verify/fix GPT..."
    echo "v" | gdisk "$DISK_DEVICE" 2>&1 | head -20 || true
    echo "w" | gdisk "$DISK_DEVICE" 2>&1 | head -10 || true
elif gpt recover "$DISK_DEVICE" 2>/dev/null; then
    log_info "GPT recover succeeded"
else
    log_warn "Cannot fix GPT checksums automatically (may be blocked by SIP)"
    log_warn "The GPT structure is copied but checksums may be invalid"
fi

log_step "Step 7: Verifying GPT..."
sleep 3

# Try multiple times as device may need time to update
for attempt in 1 2 3; do
    if gpt show "$DISK_DEVICE" >/dev/null 2>&1; then
        log_info "✓ GPT partition table is now readable!"
        log_info ""
        log_info "Partition table:"
        gpt show "$DISK_DEVICE" | grep "GPT part" || log_warn "No partitions found"
        break
    else
        if [ $attempt -lt 3 ]; then
            log_warn "GPT not readable yet (attempt $attempt), waiting..."
            sleep 2
            diskutil unmountDisk "$DISK_DEVICE" 2>/dev/null || true
            sleep 1
        else
            log_warn "GPT still not readable after copying headers"
            log_warn ""
            log_warn "The GPT headers have been copied, but checksums may be invalid."
            log_warn "This is likely due to macOS SIP restrictions preventing checksum fixes."
            log_warn ""
            log_warn "Next steps:"
            log_warn "  1. Physically remove and reinsert the SD card"
            log_warn "  2. Try: sudo gpt recover /dev/disk7 (may still be blocked)"
            log_warn "  3. Or use a Linux system to fix:"
            log_warn "     sudo gdisk /dev/sdX"
            log_warn "     (then: r -> d -> w -> y)"
        fi
    fi
done

log_info ""
log_info "=== Done ==="

