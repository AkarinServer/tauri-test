#!/bin/bash
# Backup script for SD card on Mac (direct backup via card reader)
# Usage: ./backup-sd-card-mac.sh

set -e

# Configuration
BACKUP_DIR="$HOME/backups/lichee-rv-dock"
LOG_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Step 1: Detect SD card device
log_step "Step 1: Detecting SD card device..."
diskutil list

echo ""
read -p "Please enter the SD card device (e.g., disk2): " SD_CARD_DEVICE

if [ -z "$SD_CARD_DEVICE" ]; then
    log_error "No device specified!"
    exit 1
fi

SD_CARD_DEVICE="/dev/$SD_CARD_DEVICE"
RAW_DEVICE="/dev/r${SD_CARD_DEVICE#/dev/}"

# Check if device exists
if [ ! -b "$SD_CARD_DEVICE" ] && [ ! -c "$RAW_DEVICE" ]; then
    log_error "Device $SD_CARD_DEVICE not found!"
    exit 1
fi

log_info "SD card device: $SD_CARD_DEVICE"
log_info "Raw device: $RAW_DEVICE"

# Get device info
log_step "Step 2: Getting device information..."
DEVICE_INFO=$(diskutil info "$SD_CARD_DEVICE" 2>/dev/null)
DEVICE_SIZE=$(echo "$DEVICE_INFO" | grep -i "disk size" | awk '{print $3$4}' || echo "unknown")
DEVICE_NAME=$(echo "$DEVICE_INFO" | grep -i "device / media name" | cut -d: -f2 | xargs || echo "unknown")

log_info "Device name: $DEVICE_NAME"
log_info "Device size: $DEVICE_SIZE"

# Check available disk space
log_step "Step 3: Checking available disk space..."
AVAILABLE_SPACE=$(df -h "$HOME" | tail -1 | awk '{print $4}')
log_info "Available space: $AVAILABLE_SPACE"

# Step 4: Unmount SD card
log_step "Step 4: Unmounting SD card..."
if diskutil unmountDisk "$SD_CARD_DEVICE" 2>/dev/null; then
    log_info "SD card unmounted successfully"
else
    log_warn "Failed to unmount SD card, trying force unmount..."
    if sudo diskutil unmountDisk force "$SD_CARD_DEVICE" 2>/dev/null; then
        log_info "SD card force unmounted successfully"
    else
        log_error "Failed to unmount SD card!"
        log_error "Please manually unmount the SD card and try again."
        exit 1
    fi
fi

# Step 5: Create backup
log_step "Step 5: Creating backup..."
BACKUP_FILE="lichee-rv-dock-backup-$(date +%Y%m%d-%H%M%S).img.gz"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

log_info "Backup file: $BACKUP_PATH"
log_info "This may take a while, please be patient..."

START_TIME=$(date +%s)

# Create compressed backup
if sudo dd if="$RAW_DEVICE" bs=4m status=progress 2>&1 | tee -a "$LOG_FILE" | gzip -c > "$BACKUP_PATH"; then
    BACKUP_EXIT_CODE=0
else
    BACKUP_EXIT_CODE=$?
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))

# Check backup result
if [ $BACKUP_EXIT_CODE -eq 0 ] && [ -f "$BACKUP_PATH" ]; then
    BACKUP_SIZE=$(ls -lh "$BACKUP_PATH" | awk '{print $5}')
    log_info "Backup completed successfully!"
    log_info "Backup file: $BACKUP_PATH"
    log_info "Backup size: $BACKUP_SIZE"
    log_info "Duration: ${DURATION_MIN}m ${DURATION_SEC}s"
    
    # Step 6: Create checksum
    log_step "Step 6: Creating checksum..."
    if shasum -a 256 "$BACKUP_PATH" > "$BACKUP_PATH.sha256" 2>/dev/null; then
        log_info "Checksum created: $BACKUP_PATH.sha256"
    else
        log_warn "Failed to create checksum"
    fi
    
    # Step 7: Verify backup
    log_step "Step 7: Verifying backup..."
    if gunzip -t "$BACKUP_PATH" 2>/dev/null; then
        log_info "Backup file is valid (gzip compression verified)"
    else
        log_warn "Backup file verification failed"
    fi
    
    log_info "✅ Backup completed successfully!"
    log_info "📁 Backup location: $BACKUP_PATH"
    log_info "🔒 Checksum: $BACKUP_PATH.sha256"
else
    log_error "Backup failed with exit code: $BACKUP_EXIT_CODE"
    if [ -f "$BACKUP_PATH" ]; then
        log_warn "Partial backup file exists: $BACKUP_PATH"
        log_warn "You may want to remove it: rm $BACKUP_PATH"
    fi
    exit 1
fi

# Step 8: Remount SD card
log_step "Step 8: Remounting SD card..."
if diskutil mountDisk "$SD_CARD_DEVICE" 2>/dev/null; then
    log_info "SD card remounted successfully"
else
    log_warn "Failed to remount SD card (you can eject it manually)"
fi

log_info "🎉 All done!"

