#!/bin/bash
# Minimal backup script for SD card
# Creates an image containing only valid data (used space) and partition table
# Usage: sudo ./backup-sd-card-minimal.sh [device] [output-dir]

set -e

# Configuration
SD_CARD_DEVICE="${1:-/dev/rdisk7}"
OUTPUT_DIR="${2:-$HOME/backups/lichee-rv-dock}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
IMAGE_FILE="lichee-rv-dock-minimal-${TIMESTAMP}.img"
IMAGE_FILE_GZ="${IMAGE_FILE}.gz"
IMAGE_PATH="$OUTPUT_DIR/$IMAGE_FILE"
IMAGE_PATH_GZ="$OUTPUT_DIR/$IMAGE_FILE_GZ"
LOG_FILE="$OUTPUT_DIR/backup-minimal-${TIMESTAMP}.log"

# Colors for output
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root or with sudo"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Convert raw device to regular device
DISK_DEVICE=$(echo "$SD_CARD_DEVICE" | sed 's/rdisk/disk/')

# Check if device exists
if [ ! -b "$SD_CARD_DEVICE" ] && [ ! -c "$SD_CARD_DEVICE" ]; then
    log_error "Device $SD_CARD_DEVICE not found!"
    log_info "Available disks:"
    diskutil list | grep -E "^/dev/disk" | head -10
    exit 1
fi

log_info "=== Minimal SD Card Backup ==="
log_info "Source device: $SD_CARD_DEVICE (disk: $DISK_DEVICE)"
log_info "Output directory: $OUTPUT_DIR"
log_info "Image file: $IMAGE_FILE_GZ"

# Step 1: Get actual filesystem usage
log_step "Step 1: Checking filesystem usage..."
USED_SIZE_GB=0
USED_SIZE_BYTES=0

if [ -f "check_ext4_usage.py" ]; then
    USAGE_INFO=$(python3 check_ext4_usage.py 2>&1 | tee -a "$LOG_FILE")
    USED_SIZE=$(echo "$USAGE_INFO" | grep "Used space:" | awk '{print $3, $4}')
    USED_SIZE_GB=$(echo "$USAGE_INFO" | grep "Used space:" | awk '{print $3}')
    log_info "Filesystem usage: $USED_SIZE"
    
    # Convert to bytes (approximate)
    USED_SIZE_BYTES=$(echo "$USED_SIZE_GB * 1024 * 1024 * 1024" | bc | awk '{print int($1)}')
else
    log_warn "check_ext4_usage.py not found, using default estimate"
    USED_SIZE_GB=10
    USED_SIZE_BYTES=$((10 * 1024 * 1024 * 1024))
fi

# Step 2: Read partition table
log_step "Step 2: Reading partition table..."
GPT_OUTPUT=$(gpt show "$DISK_DEVICE" 2>&1)
if [ $? -ne 0 ] || [ -z "$GPT_OUTPUT" ]; then
    log_error "Failed to read partition table: $GPT_OUTPUT"
    exit 1
fi

# Parse partition table
# Use arrays instead of associative arrays for compatibility with bash 3.x
declare -a PARTITION_STARTS
declare -a PARTITION_SIZES
declare -a PARTITION_TYPES
declare -a PARTITION_INDICES
MAIN_PARTITION_INDEX=0
MAIN_PARTITION_START=0
MAIN_PARTITION_SIZE=0
LAST_PARTITION_END=0
PARTITION_COUNT=0
GPT_BACKUP_START=0
GPT_BACKUP_SIZE=0

PARTITION_ARRAY_INDEX=0
while IFS= read -r line; do
    # Parse partition entries
    if [[ $line =~ ^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+GPT[[:space:]]+part ]]; then
        PARTITION_COUNT=$((PARTITION_COUNT + 1))
        START_SECTOR=$(echo "$line" | awk '{print $1}')
        SIZE_SECTORS=$(echo "$line" | awk '{print $2}')
        INDEX=$(echo "$line" | awk '{print $3}')
        PARTITION_TYPE=$(echo "$line" | awk '{for(i=5;i<=NF;i++) printf "%s ", $i; print ""}' | xargs)
        
        if [ -n "$START_SECTOR" ] && [ -n "$SIZE_SECTORS" ] && [ "$START_SECTOR" != "0" ]; then
            END_SECTOR=$((START_SECTOR + SIZE_SECTORS))
            if [ $END_SECTOR -gt $LAST_PARTITION_END ]; then
                LAST_PARTITION_END=$END_SECTOR
            fi
            
            # Store partition info in arrays
            PARTITION_STARTS[$PARTITION_ARRAY_INDEX]=$START_SECTOR
            PARTITION_SIZES[$PARTITION_ARRAY_INDEX]=$SIZE_SECTORS
            PARTITION_TYPES[$PARTITION_ARRAY_INDEX]=$PARTITION_TYPE
            PARTITION_INDICES[$PARTITION_ARRAY_INDEX]=$INDEX
            
            log_info "Partition $INDEX: start=$START_SECTOR, size=$SIZE_SECTORS sectors, type=$PARTITION_TYPE"
            
            # Track main Linux partition (usually the largest, partition 1)
            if [ "$INDEX" = "1" ] && [[ "$PARTITION_TYPE" == *"0FC63DAF"* ]]; then
                MAIN_PARTITION_INDEX=1
                MAIN_PARTITION_START=$START_SECTOR
                MAIN_PARTITION_SIZE=$SIZE_SECTORS
            fi
            
            PARTITION_ARRAY_INDEX=$((PARTITION_ARRAY_INDEX + 1))
        fi
    # Parse GPT backup header
    elif [[ $line =~ Sec[[:space:]]+GPT[[:space:]]+header ]]; then
        GPT_BACKUP_START=$(echo "$line" | awk '{print $1}')
        GPT_BACKUP_SIZE=$(echo "$line" | awk '{print $2}')
        log_info "GPT backup header: start=$GPT_BACKUP_START, size=$GPT_BACKUP_SIZE sectors"
    fi
done <<< "$GPT_OUTPUT"

if [ $LAST_PARTITION_END -eq 0 ]; then
    log_error "Could not parse partition table"
    exit 1
fi

if [ $MAIN_PARTITION_INDEX -eq 0 ]; then
    log_error "Could not find main Linux partition"
    exit 1
fi

log_info "Found $PARTITION_COUNT partition(s)"
log_info "Main partition (partition $MAIN_PARTITION_INDEX): start=$MAIN_PARTITION_START, size=$MAIN_PARTITION_SIZE sectors"

# Step 3: Calculate minimal image size
log_step "Step 3: Calculating minimal image size..."

SECTOR_SIZE=512
MAIN_PARTITION_START_BYTES=$((MAIN_PARTITION_START * SECTOR_SIZE))

# Calculate minimal size: used space + partition start offset + safety margin
# We'll backup from start of main partition + used space + 10% overhead
OVERHEAD_BYTES=$((USED_SIZE_BYTES / 10))  # 10% overhead
MIN_DATA_SIZE=$((USED_SIZE_BYTES + OVERHEAD_BYTES))
MIN_IMAGE_SIZE=$((MAIN_PARTITION_START_BYTES + MIN_DATA_SIZE))

# Add GPT backup (33 sectors: 32 for table + 1 for header)
GPT_BACKUP_SIZE_BYTES=$((33 * SECTOR_SIZE))
MIN_IMAGE_SIZE=$((MIN_IMAGE_SIZE + GPT_BACKUP_SIZE_BYTES))

# Round up to sector boundary
MIN_IMAGE_SECTORS=$(( (MIN_IMAGE_SIZE + SECTOR_SIZE - 1) / SECTOR_SIZE ))
MIN_IMAGE_SIZE=$((MIN_IMAGE_SECTORS * SECTOR_SIZE))

MIN_IMAGE_SIZE_GB=$(echo "scale=2; $MIN_IMAGE_SIZE / 1024 / 1024 / 1024" | bc)
MIN_IMAGE_SIZE_MB=$((MIN_IMAGE_SIZE / 1024 / 1024))

log_info "Minimal image size calculation:"
log_info "  - Partition start offset: $(echo "scale=2; $MAIN_PARTITION_START_BYTES / 1024 / 1024 / 1024" | bc) GB"
log_info "  - Used data: $(echo "scale=2; $USED_SIZE_BYTES / 1024 / 1024 / 1024" | bc) GB"
log_info "  - Overhead (10%): $(echo "scale=2; $OVERHEAD_BYTES / 1024 / 1024 / 1024" | bc) GB"
log_info "  - GPT backup: $(echo "scale=2; $GPT_BACKUP_SIZE_BYTES / 1024 / 1024 / 1024" | bc) GB"
log_info "  - Total minimal size: ${MIN_IMAGE_SIZE_GB} GB (${MIN_IMAGE_SIZE_MB} MB)"

# Step 4: Check available disk space
log_step "Step 4: Checking available disk space..."
AVAILABLE_SPACE=$(df -k "$OUTPUT_DIR" | tail -1 | awk '{print $4}')
AVAILABLE_SPACE_GB=$(echo "scale=2; $AVAILABLE_SPACE * 1024 / 1024 / 1024 / 1024" | bc)
log_info "Available space: ${AVAILABLE_SPACE_GB} GB"

# Estimate compressed size (typically 80-90% compression for mostly-empty partitions)
ESTIMATED_COMPRESSED=$(echo "scale=2; $MIN_IMAGE_SIZE_GB * 0.85" | bc)
log_info "Estimated compressed size: ~${ESTIMATED_COMPRESSED} GB"

if (( $(echo "$AVAILABLE_SPACE_GB < $ESTIMATED_COMPRESSED * 1.5" | bc -l) )); then
    log_warn "Available space (${AVAILABLE_SPACE_GB} GB) may be insufficient"
    log_warn "Recommended: at least $(echo "scale=2; $ESTIMATED_COMPRESSED * 1.5" | bc) GB"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 5: Check if pv is installed
if command -v pv &> /dev/null; then
    HAS_PV=true
    log_info "pv is installed, will show progress"
else
    HAS_PV=false
    log_warn "pv is not installed. Install with: brew install pv"
    log_info "Progress will be limited"
fi

# Step 6: Confirm before proceeding
log_info ""
log_warn "=== Backup Summary ==="
log_info "Source device: $SD_CARD_DEVICE"
log_info "Used data: ${USED_SIZE_GB} GB"
log_info "Minimal image size: ${MIN_IMAGE_SIZE_GB} GB (${MIN_IMAGE_SIZE_MB} MB)"
log_info "Estimated compressed: ~${ESTIMATED_COMPRESSED} GB"
log_info "Image file: $IMAGE_PATH_GZ"
log_info ""
read -p "Continue with backup? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Backup cancelled"
    exit 0
fi

# Step 7: Unmount SD card
log_step "Step 7: Unmounting SD card..."
if diskutil unmountDisk "$DISK_DEVICE" 2>/dev/null; then
    log_info "SD card unmounted successfully"
else
    log_warn "SD card may already be unmounted or cannot be unmounted"
fi

# Step 8: Create minimal image
log_step "Step 8: Creating minimal image..."
log_info "This may take a while, please be patient..."

START_TIME=$(date +%s)

# Calculate count for dd (in 4MB blocks)
BS=4m
COUNT=$((MIN_IMAGE_SIZE / 1024 / 1024 / 4))
# Add one extra block for safety
COUNT=$((COUNT + 1))

log_info "Creating image: $COUNT blocks of $BS each"
log_info "Target size: ${MIN_IMAGE_SIZE_GB} GB"

if [ "$HAS_PV" = true ]; then
    log_info "Creating image with progress bar..."
    dd if="$SD_CARD_DEVICE" bs="$BS" count="$COUNT" 2>/dev/null | \
        pv -s "${MIN_IMAGE_SIZE_MB}M" | \
        dd of="$IMAGE_PATH" bs="$BS" 2>/dev/null
else
    log_info "Creating image (this may take a while)..."
    dd if="$SD_CARD_DEVICE" bs="$BS" count="$COUNT" status=progress of="$IMAGE_PATH" 2>&1 | tee -a "$LOG_FILE"
fi

IMAGE_EXIT_CODE=${PIPESTATUS[0]}

if [ $IMAGE_EXIT_CODE -ne 0 ] || [ ! -f "$IMAGE_PATH" ]; then
    log_error "Failed to create image file"
    exit 1
fi

# Verify image size
ACTUAL_IMAGE_SIZE=$(stat -f%z "$IMAGE_PATH" 2>/dev/null || stat -c%s "$IMAGE_PATH" 2>/dev/null)
ACTUAL_IMAGE_SIZE_GB=$(echo "scale=2; $ACTUAL_IMAGE_SIZE / 1024 / 1024 / 1024" | bc)
ACTUAL_IMAGE_SIZE_MB=$((ACTUAL_IMAGE_SIZE / 1024 / 1024))
log_info "Image created: ${ACTUAL_IMAGE_SIZE_GB} GB (${ACTUAL_IMAGE_SIZE_MB} MB)"

# Step 9: Compress image
log_step "Step 9: Compressing image..."
log_info "Compressing to $IMAGE_PATH_GZ..."

if [ "$HAS_PV" = true ]; then
    log_info "Compressing with progress bar..."
    pv -s "${ACTUAL_IMAGE_SIZE_MB}M" "$IMAGE_PATH" | gzip -c > "$IMAGE_PATH_GZ"
else
    log_info "Compressing (this may take a while)..."
    gzip -c "$IMAGE_PATH" > "$IMAGE_PATH_GZ" 2>&1 | tee -a "$LOG_FILE"
fi

COMPRESS_EXIT_CODE=$?

if [ $COMPRESS_EXIT_CODE -ne 0 ] || [ ! -f "$IMAGE_PATH_GZ" ]; then
    log_error "Failed to compress image"
    exit 1
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))

# Step 10: Verify and report
log_step "Step 10: Verifying image..."

COMPRESSED_SIZE=$(stat -f%z "$IMAGE_PATH_GZ" 2>/dev/null || stat -c%s "$IMAGE_PATH_GZ" 2>/dev/null)
COMPRESSED_SIZE_GB=$(echo "scale=2; $COMPRESSED_SIZE / 1024 / 1024 / 1024" | bc)
COMPRESSED_SIZE_MB=$((COMPRESSED_SIZE / 1024 / 1024))

# Calculate compression ratio
COMPRESSION_RATIO=$(echo "scale=2; $COMPRESSED_SIZE * 100 / $ACTUAL_IMAGE_SIZE" | bc)

log_info ""
log_info "=== Backup Completed! ==="
log_info "Original image: $IMAGE_PATH (${ACTUAL_IMAGE_SIZE_GB} GB)"
log_info "Compressed image: $IMAGE_PATH_GZ (${COMPRESSED_SIZE_GB} GB / ${COMPRESSED_SIZE_MB} MB)"
log_info "Compression ratio: ${COMPRESSION_RATIO}%"
log_info "Duration: ${DURATION_MIN}m ${DURATION_SEC}s"

# Create checksum
log_step "Step 11: Creating checksum..."
shasum -a 256 "$IMAGE_PATH_GZ" > "$IMAGE_PATH_GZ.sha256"
log_info "Checksum file: $IMAGE_PATH_GZ.sha256"

# Save partition table information for restore script
PARTITION_INFO_FILE="${IMAGE_PATH_GZ}.partitions"
cat > "$PARTITION_INFO_FILE" << EOF
# Partition table information for restore script
# Generated: $(date)
MAIN_PARTITION_INDEX=$MAIN_PARTITION_INDEX
MAIN_PARTITION_START=$MAIN_PARTITION_START
MAIN_PARTITION_SIZE=$MAIN_PARTITION_SIZE
USED_SIZE_GB=$USED_SIZE_GB
USED_SIZE_BYTES=$USED_SIZE_BYTES
IMAGE_SIZE_SECTORS=$MIN_IMAGE_SECTORS
PARTITION_COUNT=$PARTITION_COUNT
EOF

# Append partition information
for i in $(seq 0 $((PARTITION_ARRAY_INDEX - 1))); do
    echo "PARTITION_${PARTITION_INDICES[$i]}_START=${PARTITION_STARTS[$i]}" >> "$PARTITION_INFO_FILE"
    echo "PARTITION_${PARTITION_INDICES[$i]}_SIZE=${PARTITION_SIZES[$i]}" >> "$PARTITION_INFO_FILE"
    echo "PARTITION_${PARTITION_INDICES[$i]}_TYPE=\"${PARTITION_TYPES[$i]}\"" >> "$PARTITION_INFO_FILE"
done

log_info "Partition info saved to: $PARTITION_INFO_FILE"

log_info ""
log_info "=== Usage Instructions ==="
log_info "To restore this image to a new SD card, use:"
log_info "  sudo ./restore-sd-card.sh $IMAGE_PATH_GZ /dev/rdiskX"
log_info ""
log_info "The restore script will:"
log_info "  1. Check if target SD card is large enough"
log_info "  2. Write the image to the SD card"
log_info "  3. Automatically adjust partition sizes to fit the new card"
log_info "  4. Expand the filesystem to use all available space"
log_info ""
log_info "✅ Done!"

# Optional: Remove uncompressed image to save space
log_info ""
read -p "Remove uncompressed image to save space? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm "$IMAGE_PATH"
    log_info "Uncompressed image removed"
fi

