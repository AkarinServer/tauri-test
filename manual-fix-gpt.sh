#!/bin/bash
# Manual GPT partition table fix script
# This script manually recreates the GPT partition table using gpt commands
# Usage: sudo ./manual-fix-gpt.sh <device> <partitions-file>

set -e

DEVICE="${1:-/dev/rdisk7}"
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

DISK_DEVICE=$(echo "$DEVICE" | sed 's/rdisk/disk/')

if [ -z "$PARTITIONS_FILE" ]; then
    log_error "Usage: sudo $0 <device> <partitions-file>"
    log_error "Example: sudo $0 /dev/rdisk7 ~/backups/.../image.partitions"
    exit 1
fi

if [ ! -f "$PARTITIONS_FILE" ]; then
    log_error "Partitions file not found: $PARTITIONS_FILE"
    exit 1
fi

log_info "=== Manual GPT Partition Table Fix ==="
log_info "Device: $DEVICE (disk: $DISK_DEVICE)"
log_info "Partitions file: $PARTITIONS_FILE"
log_info ""

# Source the partitions file
source "$PARTITIONS_FILE"

# Unmount device
log_step "Step 1: Unmounting device..."
diskutil unmountDisk "$DISK_DEVICE" 2>/dev/null || true
sleep 2

# Try to recover GPT first
log_step "Step 2: Attempting to recover GPT..."
if gpt recover "$DISK_DEVICE" 2>/dev/null; then
    log_info "GPT recovered, destroying to recreate..."
    gpt destroy "$DISK_DEVICE" 2>/dev/null || true
    sleep 1
fi

# Create new GPT
log_step "Step 3: Creating new GPT partition table..."
if ! gpt create "$DISK_DEVICE" 2>/dev/null; then
    log_error "Failed to create GPT. This may be a macOS security restriction."
    log_error ""
    log_error "Try:"
    log_error "  1. Physically remove and reinsert the SD card"
    log_error "  2. Wait 10 seconds"
    log_error "  3. Run this script again"
    exit 1
fi

log_info "GPT created successfully"
sleep 1

# Add partitions in order (sorted by start sector)
log_step "Step 4: Adding partitions..."

# Collect all partitions
declare -a PART_INDICES
declare -a PART_STARTS
declare -a PART_SIZES
declare -a PART_TYPES

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
        PART_INDICES+=($i)
        PART_STARTS+=($START)
        PART_SIZES+=($SIZE)
        PART_TYPES+=($TYPE_GUID)
    fi
done

# Sort by start sector (simple bubble sort)
n=${#PART_INDICES[@]}
for ((i=0; i<n-1; i++)); do
    for ((j=0; j<n-i-1; j++)); do
        if [ "${PART_STARTS[$j]}" -gt "${PART_STARTS[$((j+1))]}" ]; then
            # Swap indices
            temp_i=${PART_INDICES[$j]}
            PART_INDICES[$j]=${PART_INDICES[$((j+1))]}
            PART_INDICES[$((j+1))]=$temp_i
            
            # Swap starts
            temp_s=${PART_STARTS[$j]}
            PART_STARTS[$j]=${PART_STARTS[$((j+1))]}
            PART_STARTS[$((j+1))]=$temp_s
            
            # Swap sizes
            temp_z=${PART_SIZES[$j]}
            PART_SIZES[$j]=${PART_SIZES[$((j+1))]}
            PART_SIZES[$((j+1))]=$temp_z
            
            # Swap types
            temp_t=${PART_TYPES[$j]}
            PART_TYPES[$j]=${PART_TYPES[$((j+1))]}
            PART_TYPES[$((j+1))]=$temp_t
        fi
    done
done

# Add partitions
for i in $(seq 0 $((n-1))); do
    idx=${PART_INDICES[$i]}
    start=${PART_STARTS[$i]}
    size=${PART_SIZES[$i]}
    type=${PART_TYPES[$i]}
    
    log_info "Adding partition $idx: start=$start, size=$size, type=$type"
    
    if ! gpt add -b "$start" -s "$size" -t "$type" "$DISK_DEVICE" 2>&1; then
        log_error "Failed to add partition $idx"
        exit 1
    fi
done

log_info ""
log_info "=== GPT Partition Table Fixed! ==="
log_info "All partitions have been recreated."
log_info ""
log_info "Verify with: sudo ./diagnose-sd-card.sh $DEVICE"

