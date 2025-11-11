#!/bin/bash
# Backup script for Lichee RV Dock SD card system
# Usage: ./backup-lichee-rv-dock.sh

set -e

# Configuration
HOST="root@192.168.31.145"
DEVICE="/dev/mmcblk0"
BACKUP_DIR="$HOME/backups/lichee-rv-dock"
BACKUP_FILE="lichee-rv-dock-$(date +%Y%m%d-%H%M%S).img.gz"
LOG_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if device exists on remote host
log_info "Checking device on remote host..."
if ! ssh "$HOST" "test -b $DEVICE"; then
    log_error "Device $DEVICE not found on remote host!"
    log_info "Trying to detect device..."
    DETECTED_DEVICE=$(ssh "$HOST" "df -h / | tail -1 | awk '{print \$1}' | sed 's/[0-9]*$//'")
    if [ -n "$DETECTED_DEVICE" ]; then
        log_warn "Detected device: $DETECTED_DEVICE"
        DEVICE="$DETECTED_DEVICE"
    else
        log_error "Cannot detect device. Please check manually."
        exit 1
    fi
fi

# Get device size
log_info "Getting device size..."
DEVICE_SIZE=$(ssh "$HOST" "blockdev --getsize64 $DEVICE 2>/dev/null" || echo "0")
if [ "$DEVICE_SIZE" -eq 0 ]; then
    log_error "Cannot get device size!"
    exit 1
fi

DEVICE_SIZE_GB=$(echo "scale=2; $DEVICE_SIZE / 1024 / 1024 / 1024" | bc)
log_info "Device size: ${DEVICE_SIZE_GB} GB"

# Check available disk space
log_info "Checking available disk space..."
AVAILABLE_SPACE=$(df -h "$HOME" | tail -1 | awk '{print $4}')
log_info "Available space: $AVAILABLE_SPACE"

# Check if pv is installed on remote host
log_info "Checking if pv is installed on remote host..."
if ssh "$HOST" "command -v pv &> /dev/null"; then
    HAS_PV=true
    log_info "pv is installed, will show progress"
else
    HAS_PV=false
    log_warn "pv is not installed, progress will be limited"
    log_info "You can install pv with: ssh $HOST 'apt-get install -y pv'"
fi

# Start backup
log_info "Starting backup..."
log_info "Backup file: $BACKUP_DIR/$BACKUP_FILE"
log_info "This may take a while, please be patient..."

START_TIME=$(date +%s)

if [ "$HAS_PV" = true ]; then
    # Backup with pv progress
    ssh "$HOST" "dd if=$DEVICE bs=4M status=progress | pv -s $DEVICE_SIZE | gzip -c" > "$BACKUP_DIR/$BACKUP_FILE" 2>&1 | tee -a "$LOG_FILE"
else
    # Backup without pv
    ssh "$HOST" "dd if=$DEVICE bs=4M status=progress | gzip -c" > "$BACKUP_DIR/$BACKUP_FILE" 2>&1 | tee -a "$LOG_FILE"
fi

BACKUP_EXIT_CODE=${PIPESTATUS[0]}

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))

# Check backup result
if [ $BACKUP_EXIT_CODE -eq 0 ] && [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_FILE" | awk '{print $5}')
    log_info "Backup completed successfully!"
    log_info "Backup file: $BACKUP_DIR/$BACKUP_FILE"
    log_info "Backup size: $BACKUP_SIZE"
    log_info "Duration: ${DURATION_MIN}m ${DURATION_SEC}s"
    
    # Calculate compression ratio
    BACKUP_SIZE_BYTES=$(stat -f%z "$BACKUP_DIR/$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_DIR/$BACKUP_FILE" 2>/dev/null)
    if [ -n "$BACKUP_SIZE_BYTES" ] && [ "$BACKUP_SIZE_BYTES" -gt 0 ]; then
        COMPRESSION_RATIO=$(echo "scale=2; $BACKUP_SIZE_BYTES * 100 / $DEVICE_SIZE" | bc)
        log_info "Compression ratio: ${COMPRESSION_RATIO}%"
    fi
    
    # Create checksum
    log_info "Creating checksum..."
    sha256sum "$BACKUP_DIR/$BACKUP_FILE" > "$BACKUP_DIR/$BACKUP_FILE.sha256"
    log_info "Checksum file: $BACKUP_DIR/$BACKUP_FILE.sha256"
    
    log_info "Backup completed successfully!"
else
    log_error "Backup failed with exit code: $BACKUP_EXIT_CODE"
    if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        log_warn "Partial backup file exists: $BACKUP_DIR/$BACKUP_FILE"
        log_warn "You may want to remove it: rm $BACKUP_DIR/$BACKUP_FILE"
    fi
    exit 1
fi

