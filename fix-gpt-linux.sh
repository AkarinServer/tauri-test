#!/bin/bash
# Fix GPT partition table on Linux (including RISC-V)
# Usage: sudo ./fix-gpt-linux.sh <device> [partitions-file]

set -e

DEVICE="${1}"
PARTITIONS_FILE="${2}"

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

if [ -z "$DEVICE" ]; then
    log_error "Usage: sudo $0 <device> [partitions-file]"
    log_error "Example: sudo $0 /dev/mmcblk0"
    log_error "Example: sudo $0 /dev/sdb ~/backups/.../image.partitions"
    exit 1
fi

log_info "=== Linux GPT Partition Table Fix ==="
log_info "Device: $DEVICE"
log_info ""

# Check if device exists
if [ ! -b "$DEVICE" ]; then
    log_error "Device $DEVICE not found!"
    log_info "Available block devices:"
    lsblk -d -o NAME,SIZE,TYPE | grep -E "disk|mmc" || true
    exit 1
fi

# Unmount device
log_step "Step 1: Unmounting device..."
umount "${DEVICE}"* 2>/dev/null || true
sleep 1

# Try to recover GPT using gdisk
log_step "Step 2: Attempting to recover GPT using gdisk..."

if ! command -v gdisk >/dev/null 2>&1; then
    log_error "gdisk is not installed"
    log_info "Install with: sudo apt-get install gdisk"
    log_info "Or: sudo yum install gdisk"
    exit 1
fi

# Check current GPT status
log_info "Checking GPT status..."
if gdisk -l "$DEVICE" 2>&1 | grep -q "bogus\|corrupt\|invalid"; then
    log_warn "GPT is corrupted, attempting recovery..."
    
    # Use gdisk to recover
    log_info "Running gdisk recovery..."
    echo -e "r\nd\nw\ny" | gdisk "$DEVICE" 2>&1 | tail -20
    
    sleep 1
    
    # Verify
    if gdisk -l "$DEVICE" 2>&1 | grep -q "GPT:"; then
        log_info "✓ GPT recovered successfully!"
    else
        log_warn "Recovery may have failed, trying to recreate..."
    fi
fi

# If partitions file is provided, recreate partitions
if [ -n "$PARTITIONS_FILE" ] && [ -f "$PARTITIONS_FILE" ]; then
    log_step "Step 3: Recreating partitions from info file..."
    
    source "$PARTITIONS_FILE"
    
    # Destroy and recreate GPT
    log_info "Destroying existing GPT..."
    sgdisk --zap-all "$DEVICE" 2>/dev/null || true
    
    log_info "Creating new GPT..."
    sgdisk --clear "$DEVICE" 2>/dev/null || true
    
    # Add partitions
    for var in $(set | grep -E "^PARTITION_[0-9]+_START=" | cut -d= -f1); do
        i=$(echo "$var" | sed 's/PARTITION_\([0-9]*\)_START/\1/')
        START_VAR="PARTITION_${i}_START"
        SIZE_VAR="PARTITION_${i}_SIZE"
        TYPE_VAR="PARTITION_${i}_TYPE"
        
        START=${!START_VAR}
        SIZE=${!SIZE_VAR}
        TYPE_STR=${!TYPE_VAR}
        TYPE_GUID=$(echo "$TYPE_STR" | grep -oE "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}" | head -1)
        
        if [ -n "$START" ] && [ -n "$SIZE" ] && [ -n "$TYPE_GUID" ]; then
            END=$((START + SIZE - 1))
            log_info "Adding partition $i: sectors $START-$END, type $TYPE_GUID"
            sgdisk --new="$i:${START}:${END}" --typecode="$i:${TYPE_GUID}" "$DEVICE" 2>&1 || {
                log_error "Failed to add partition $i"
            }
        fi
    done
    
    log_info "Partitions recreated"
fi

# Final verification
log_step "Step 4: Verifying GPT..."
sleep 1

if gdisk -l "$DEVICE" >/dev/null 2>&1; then
    log_info "✓ GPT partition table is readable!"
    log_info ""
    log_info "Partition table:"
    gdisk -l "$DEVICE" | grep -A 100 "Number" | head -20
else
    log_error "GPT is still not readable"
    exit 1
fi

log_info ""
log_info "=== Done ==="

