#!/bin/bash
# Restore SD card image script
# Automatically detects image size and target SD card size
# Adjusts partition sizes to fit the target SD card
# Usage: sudo ./restore-sd-card.sh <image-file> <target-device>

# Don't use set -e, we want to handle errors explicitly and provide clear messages

# Configuration
IMAGE_FILE="${1}"
TARGET_DEVICE="${2}"
TEMP_DIR="/tmp/sd_restore_$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        log_info "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi
    # Remount target device if possible
    if [ -n "$TARGET_DISK" ]; then
        diskutil mountDisk "$TARGET_DISK" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "This script requires root privileges"
    log_error ""
    log_error "Please run with sudo:"
    log_error "  sudo $0 $*"
    exit 1
fi

# Verify we actually have root privileges
if ! diskutil list >/dev/null 2>&1; then
    log_error "Cannot access diskutil - root privileges may not be working correctly"
    log_error "Please ensure you're running with sudo"
    exit 1
fi

# Check arguments
if [ -z "$IMAGE_FILE" ] || [ -z "$TARGET_DEVICE" ]; then
    log_error "Usage: sudo $0 <image-file> <target-device>"
    log_error "Example: sudo $0 ~/backups/lichee-rv-dock/lichee-rv-dock-minimal-*.img.gz /dev/rdisk8"
    exit 1
fi

# Check if image file exists
if [ ! -f "$IMAGE_FILE" ]; then
    log_error "Image file not found: $IMAGE_FILE"
    exit 1
fi

# Convert raw device to regular device
TARGET_DISK=$(echo "$TARGET_DEVICE" | sed 's/rdisk/disk/')

# Check if target device exists
if [ ! -b "$TARGET_DEVICE" ] && [ ! -c "$TARGET_DEVICE" ]; then
    log_error "Target device $TARGET_DEVICE not found!"
    log_info "Available disks:"
    diskutil list | grep -E "^/dev/disk" | head -10
    exit 1
fi

log_info "=== SD Card Restore ==="
log_info "Image file: $IMAGE_FILE"
log_info "Target device: $TARGET_DEVICE (disk: $TARGET_DISK)"

# Step 1: Check image file
log_step "Step 1: Checking image file..."
if [[ "$IMAGE_FILE" == *.gz ]]; then
    IS_COMPRESSED=true
    log_info "Image is compressed (.gz)"
    
    # Get compressed size
    COMPRESSED_SIZE=$(stat -f%z "$IMAGE_FILE" 2>/dev/null || stat -c%s "$IMAGE_FILE" 2>/dev/null)
    COMPRESSED_SIZE_GB=$(echo "scale=2; $COMPRESSED_SIZE / 1024 / 1024 / 1024" | bc)
    log_info "Compressed size: ${COMPRESSED_SIZE_GB} GB"
    
    # Estimate uncompressed size (gzip typically compresses to 80-90% for sparse data)
    ESTIMATED_SIZE=$(gunzip -l "$IMAGE_FILE" 2>/dev/null | tail -1 | awk '{print $2}')
    if [ -n "$ESTIMATED_SIZE" ] && [ "$ESTIMATED_SIZE" != "0" ]; then
        IMAGE_SIZE=$ESTIMATED_SIZE
        IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE / 1024 / 1024 / 1024" | bc)
        log_info "Uncompressed size: ${IMAGE_SIZE_GB} GB"
    else
        # Fallback: estimate based on compression ratio
        IMAGE_SIZE=$((COMPRESSED_SIZE * 12 / 10))  # Estimate 1.2x compression
        IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE / 1024 / 1024 / 1024" | bc)
        log_warn "Could not determine uncompressed size, estimating: ${IMAGE_SIZE_GB} GB"
    fi
else
    IS_COMPRESSED=false
    IMAGE_SIZE=$(stat -f%z "$IMAGE_FILE" 2>/dev/null || stat -c%s "$IMAGE_FILE" 2>/dev/null)
    IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE / 1024 / 1024 / 1024" | bc)
    log_info "Image size: ${IMAGE_SIZE_GB} GB"
fi

# Step 2: Check target SD card size
log_step "Step 2: Checking target SD card size..."
TARGET_INFO=$(diskutil info "$TARGET_DISK" 2>/dev/null)
TARGET_SIZE=$(echo "$TARGET_INFO" | grep -i "disk size" | awk -F': ' '{print $2}' | awk '{print $1}')
TARGET_SIZE_BYTES=$(echo "$TARGET_INFO" | grep -i "disk size" | grep -oE "[0-9]+" | head -1)

if [ -z "$TARGET_SIZE_BYTES" ]; then
    # Try alternative method
    TARGET_SIZE_BYTES=$(diskutil info "$TARGET_DISK" 2>/dev/null | grep -i "total size" | grep -oE "[0-9]+" | head -1)
fi

if [ -z "$TARGET_SIZE_BYTES" ]; then
    log_error "Could not determine target SD card size"
    exit 1
fi

# Convert to bytes if it's in a different format
if [ ${#TARGET_SIZE_BYTES} -lt 10 ]; then
    # Likely in GB, convert to bytes
    TARGET_SIZE_BYTES=$(echo "$TARGET_SIZE_BYTES * 1024 * 1024 * 1024" | bc | awk '{print int($1)}')
fi

TARGET_SIZE_GB=$(echo "scale=2; $TARGET_SIZE_BYTES / 1024 / 1024 / 1024" | bc)
log_info "Target SD card size: ${TARGET_SIZE_GB} GB"

# Check if target is large enough
if [ "$IMAGE_SIZE" -gt "$TARGET_SIZE_BYTES" ]; then
    log_error "Image size (${IMAGE_SIZE_GB} GB) is larger than target SD card (${TARGET_SIZE_GB} GB)"
    log_error "Please use a larger SD card"
    exit 1
fi

log_info "✓ Target SD card is large enough"

# Step 3: Check partition info file
log_step "Step 3: Loading partition information..."
PARTITION_INFO_FILE="${IMAGE_FILE}.partitions"

if [ -f "$PARTITION_INFO_FILE" ]; then
    log_info "Found partition info file: $PARTITION_INFO_FILE"
    source "$PARTITION_INFO_FILE"
    log_info "Main partition: index=$MAIN_PARTITION_INDEX, start=$MAIN_PARTITION_START sectors, size=${MAIN_PARTITION_SIZE:-0} sectors"
else
    log_warn "Partition info file not found: $PARTITION_INFO_FILE"
    log_warn "Will attempt to read partition table from image after extraction"
    MAIN_PARTITION_INDEX=1
    MAIN_PARTITION_START=0
    MAIN_PARTITION_SIZE=0
fi

# Ensure MAIN_PARTITION_SIZE is set
MAIN_PARTITION_SIZE=${MAIN_PARTITION_SIZE:-0}

# Step 4: Create temporary directory
log_step "Step 4: Creating temporary directory..."
mkdir -p "$TEMP_DIR"
UNCOMPRESSED_IMAGE="$TEMP_DIR/image.img"

# Step 5: Decompress image if needed
if [ "$IS_COMPRESSED" = true ]; then
    log_step "Step 5: Decompressing image..."
    log_info "This may take a while..."
    
    if command -v pv &> /dev/null; then
        COMPRESSED_SIZE_MB=$((COMPRESSED_SIZE / 1024 / 1024))
        pv -s "${COMPRESSED_SIZE_MB}M" "$IMAGE_FILE" | gunzip -c > "$UNCOMPRESSED_IMAGE"
    else
        gunzip -c "$IMAGE_FILE" > "$UNCOMPRESSED_IMAGE"
    fi
    
    ACTUAL_UNCOMPRESSED_SIZE=$(stat -f%z "$UNCOMPRESSED_IMAGE" 2>/dev/null || stat -c%s "$UNCOMPRESSED_IMAGE" 2>/dev/null)
    ACTUAL_UNCOMPRESSED_SIZE_GB=$(echo "scale=2; $ACTUAL_UNCOMPRESSED_SIZE / 1024 / 1024 / 1024" | bc)
    log_info "Decompressed image size: ${ACTUAL_UNCOMPRESSED_SIZE_GB} GB"
    IMAGE_SIZE=$ACTUAL_UNCOMPRESSED_SIZE
else
    log_step "Step 5: Copying image..."
    cp "$IMAGE_FILE" "$UNCOMPRESSED_IMAGE"
fi

# Step 6: Confirm before proceeding
log_info ""
log_warn "=== Restore Summary ==="
log_info "Image file: $IMAGE_FILE"
log_info "Image size: $(echo "scale=2; $IMAGE_SIZE / 1024 / 1024 / 1024" | bc) GB"
log_info "Target device: $TARGET_DEVICE"
log_info "Target size: ${TARGET_SIZE_GB} GB"
log_info ""
log_warn "WARNING: This will erase all data on $TARGET_DEVICE!"
log_info ""
read -p "Continue with restore? (yes/no) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "Restore cancelled"
    exit 0
fi

# Step 7: Unmount target device
log_step "Step 7: Unmounting target device..."
if diskutil unmountDisk "$TARGET_DISK" 2>/dev/null; then
    log_info "Target device unmounted successfully"
else
    log_warn "Target device may already be unmounted"
fi

# Step 8: Write image to target device
log_step "Step 8: Writing image to target device..."
log_info "This may take a while, please be patient..."

START_TIME=$(date +%s)

IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
BS=4m
COUNT=$((IMAGE_SIZE / 1024 / 1024 / 4))
COUNT=$((COUNT + 1))  # Add one block for safety

if command -v pv &> /dev/null; then
    log_info "Writing with progress bar..."
    dd if="$UNCOMPRESSED_IMAGE" bs="$BS" count="$COUNT" 2>/dev/null | \
        pv -s "${IMAGE_SIZE_MB}M" | \
        dd of="$TARGET_DEVICE" bs="$BS" 2>/dev/null
else
    log_info "Writing (this may take a while)..."
    dd if="$UNCOMPRESSED_IMAGE" bs="$BS" count="$COUNT" status=progress of="$TARGET_DEVICE" 2>&1
fi

WRITE_EXIT_CODE=${PIPESTATUS[0]}

if [ $WRITE_EXIT_CODE -ne 0 ]; then
    log_error "Failed to write image to target device"
    exit 1
fi

# Sync to ensure data is written
sync
log_info "Image written successfully"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))
log_info "Duration: ${DURATION_MIN}m ${DURATION_SEC}s"

# Step 9: Read partition table - try from device first, fallback to image file
log_step "Step 9: Reading partition table..."
sleep 3  # Wait for device to be ready

# First, try to unmount the device in case it was auto-mounted
diskutil unmountDisk "$TARGET_DISK" 2>/dev/null || true
sleep 2

# Try to read from device first
log_info "Attempting to read partition table from device $TARGET_DISK..."
GPT_OUTPUT=$(gpt show "$TARGET_DISK" 2>&1)
GPT_EXIT_CODE=$?

# If failed, try reading from the image file instead
if [ $GPT_EXIT_CODE -ne 0 ]; then
    log_warn "Cannot read partition table from device (this is common after writing)"
    log_info "Attempting to read partition table from image file instead..."
    
    # Try to read from the uncompressed image file
    if [ -f "$UNCOMPRESSED_IMAGE" ]; then
        # Create a loop device or use gpt show on the file directly
        # On macOS, we can use hdiutil to attach the image, or read directly
        # For now, let's try using the partition info file we already have
        log_info "Using partition information from .partitions file to rebuild partition table"
        
        if [ -f "$PARTITION_INFO_FILE" ] && [ -n "$MAIN_PARTITION_INDEX" ]; then
            log_info "Partition info file found, will rebuild partition table from it"
            # We'll skip the GPT_OUTPUT parsing and go directly to rebuilding
            USE_PARTITION_INFO=true
        else
            log_error "Cannot read partition table from device and no partition info available"
            log_error "Exit code: $GPT_EXIT_CODE"
            log_error ""
            if [ -n "$GPT_OUTPUT" ]; then
                log_error "Error output:"
                echo "$GPT_OUTPUT" | while IFS= read -r line; do
                    log_error "  $line"
                done
            fi
            log_error ""
            log_error "Script stopped due to error. The partition table needs to be rebuilt manually."
            exit 1
        fi
    else
        log_error "Cannot read partition table and image file not available"
        log_error "Exit code: $GPT_EXIT_CODE"
        if [ -n "$GPT_OUTPUT" ]; then
            log_error "Error: $GPT_OUTPUT"
        fi
        exit 1
    fi
else
    USE_PARTITION_INFO=false
    log_info "Successfully read partition table from device"
fi

# Step 10: Calculate new partition sizes
log_step "Step 10: Calculating new partition sizes..."

# Get target device size in sectors
TARGET_SIZE_SECTORS=$((TARGET_SIZE_BYTES / 512))
# Reserve space for GPT (34 sectors at start + 33 sectors at end)
GPT_RESERVED=67
# Reserve extra space at the end for GPT backup (safety margin)
END_RESERVE=100
AVAILABLE_SECTORS=$((TARGET_SIZE_SECTORS - GPT_RESERVED - END_RESERVE))

log_info "Target device: ${TARGET_SIZE_SECTORS} sectors"
log_info "Available for partitions: ${AVAILABLE_SECTORS} sectors"

# Parse existing partitions and calculate new sizes
declare -a PARTITION_STARTS
declare -a PARTITION_SIZES
declare -a PARTITION_TYPES
declare -a PARTITION_INDICES
declare -a PARTITION_TYPE_GUIDS
TOTAL_FIXED_SIZE=0
MAIN_PARTITION_NEW_SIZE=0
MAIN_PARTITION_START=0

if [ "$USE_PARTITION_INFO" = true ]; then
    # Use partition info from .partitions file
    log_info "Rebuilding partition table from partition info file..."
    
    # Read partition info from the file
    if [ -f "$PARTITION_INFO_FILE" ]; then
        # Source the partition info file to get partition details
        source "$PARTITION_INFO_FILE"
        
        # Build partition arrays from the info file
        # Partition indices may not be sequential, so we need to find all PARTITION_*_START variables
        PARTITION_INDEX=0
        
        # Extract all partition indices from the sourced variables
        for var_name in $(set | grep -E "^PARTITION_[0-9]+_START=" | cut -d= -f1); do
            # Extract partition number from variable name (e.g., PARTITION_13_START -> 13)
            i=$(echo "$var_name" | sed 's/PARTITION_\([0-9]*\)_START/\1/')
            
            START_VAR="PARTITION_${i}_START"
            SIZE_VAR="PARTITION_${i}_SIZE"
            TYPE_VAR="PARTITION_${i}_TYPE"
            
            START_SECTOR=${!START_VAR}
            SIZE_SECTORS=${!SIZE_VAR}
            PARTITION_TYPE_STR=${!TYPE_VAR}
            
            if [ -n "$START_SECTOR" ] && [ -n "$SIZE_SECTORS" ] && [ "$START_SECTOR" != "0" ]; then
                # Extract type GUID from partition type string
                TYPE_GUID=$(echo "$PARTITION_TYPE_STR" | grep -oE "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}" | head -1)
                
                PARTITION_STARTS[$PARTITION_INDEX]=$START_SECTOR
                PARTITION_SIZES[$PARTITION_INDEX]=$SIZE_SECTORS
                PARTITION_TYPES[$PARTITION_INDEX]=$PARTITION_TYPE_STR
                PARTITION_INDICES[$PARTITION_INDEX]=$i
                PARTITION_TYPE_GUIDS[$PARTITION_INDEX]=$TYPE_GUID
                
                if [ -n "$TYPE_GUID" ]; then
                    log_info "Partition $i from info file: start=$START_SECTOR, size=$SIZE_SECTORS sectors, type=$TYPE_GUID"
                else
                    log_warn "Partition $i: could not extract type GUID from: $PARTITION_TYPE_STR"
                fi
                
                if [ "$i" != "$MAIN_PARTITION_INDEX" ]; then
                    TOTAL_FIXED_SIZE=$((TOTAL_FIXED_SIZE + SIZE_SECTORS))
                else
                    MAIN_PARTITION_START=$START_SECTOR
                fi
                
                PARTITION_INDEX=$((PARTITION_INDEX + 1))
            fi
        done
        
        if [ $PARTITION_INDEX -eq 0 ]; then
            log_error "No partitions found in partition info file"
            exit 1
        fi
    else
        log_error "Partition info file not found: $PARTITION_INFO_FILE"
        exit 1
    fi
else
    # Parse from GPT_OUTPUT (device read was successful)
    PARTITION_INDEX=0
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+GPT[[:space:]]+part ]]; then
            START_SECTOR=$(echo "$line" | awk '{print $1}')
            SIZE_SECTORS=$(echo "$line" | awk '{print $2}')
            INDEX=$(echo "$line" | awk '{print $3}')
            PARTITION_TYPE=$(echo "$line" | awk '{for(i=5;i<=NF;i++) printf "%s ", $i; print ""}' | xargs)
            
            # Extract partition type GUID (not UUID) - this is what gpt add -t expects
            # Format: "GPT part - C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
            TYPE_GUID=$(echo "$PARTITION_TYPE" | grep -oE "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}" | head -1)
            
            if [ -n "$START_SECTOR" ] && [ -n "$SIZE_SECTORS" ] && [ "$START_SECTOR" != "0" ]; then
                PARTITION_STARTS[$PARTITION_INDEX]=$START_SECTOR
                PARTITION_SIZES[$PARTITION_INDEX]=$SIZE_SECTORS
                PARTITION_TYPES[$PARTITION_INDEX]=$PARTITION_TYPE
                PARTITION_INDICES[$PARTITION_INDEX]=$INDEX
                PARTITION_TYPE_GUIDS[$PARTITION_INDEX]=$TYPE_GUID
                
                if [ -n "$TYPE_GUID" ]; then
                    log_info "Found partition $INDEX: start=$START_SECTOR, size=$SIZE_SECTORS sectors, type=$TYPE_GUID"
                else
                    log_warn "Found partition $INDEX: start=$START_SECTOR, size=$SIZE_SECTORS sectors, but could not extract type GUID"
                    log_warn "Partition type string: $PARTITION_TYPE"
                fi
                
                # If this is not the main partition, keep original size
                if [ "$INDEX" != "$MAIN_PARTITION_INDEX" ]; then
                    TOTAL_FIXED_SIZE=$((TOTAL_FIXED_SIZE + SIZE_SECTORS))
                else
                    # This is the main partition
                    MAIN_PARTITION_START=$START_SECTOR
                fi
                
                PARTITION_INDEX=$((PARTITION_INDEX + 1))
            fi
        fi
    done <<< "$GPT_OUTPUT"
fi

# Calculate new size for main partition
# Available space = Total sectors - GPT reserved - fixed partitions - partition start offset
# Main partition new size = Available sectors - (start of main partition)
if [ $MAIN_PARTITION_START -eq 0 ]; then
    log_error "Could not find main partition start"
    exit 1
fi

# Calculate space after all fixed partitions
# Find the end of the last fixed partition
LAST_FIXED_END=$MAIN_PARTITION_START
for i in "${!PARTITION_INDICES[@]}"; do
    if [ "${PARTITION_INDICES[$i]}" != "$MAIN_PARTITION_INDEX" ]; then
        FIXED_START=${PARTITION_STARTS[$i]}
        FIXED_SIZE=${PARTITION_SIZES[$i]}
        FIXED_END=$((FIXED_START + FIXED_SIZE))
        if [ $FIXED_END -gt $LAST_FIXED_END ]; then
            LAST_FIXED_END=$FIXED_END
        fi
    fi
done

# Main partition should start after the last fixed partition or at its original position
if [ $MAIN_PARTITION_START -lt $LAST_FIXED_END ]; then
    MAIN_PARTITION_START=$LAST_FIXED_END
fi

# Calculate new size: from main partition start to end of available space
MAIN_PARTITION_NEW_SIZE=$((AVAILABLE_SECTORS - MAIN_PARTITION_START))

if [ $MAIN_PARTITION_NEW_SIZE -le 0 ]; then
    log_error "Calculated partition size is invalid: ${MAIN_PARTITION_NEW_SIZE} sectors"
    exit 1
fi

log_info "Main partition will be resized:"
if [ "$MAIN_PARTITION_SIZE" -gt 0 ]; then
    ORIGINAL_SIZE_GB=$(echo "scale=2; $MAIN_PARTITION_SIZE * 512 / 1024 / 1024 / 1024" | bc)
    log_info "  Original: start=$MAIN_PARTITION_START, size=$MAIN_PARTITION_SIZE sectors (${ORIGINAL_SIZE_GB} GB)"
else
    log_info "  Original: start=$MAIN_PARTITION_START, size=unknown"
fi
NEW_SIZE_GB=$(echo "scale=2; $MAIN_PARTITION_NEW_SIZE * 512 / 1024 / 1024 / 1024" | bc)
log_info "  New: start=$MAIN_PARTITION_START, size=${MAIN_PARTITION_NEW_SIZE} sectors (${NEW_SIZE_GB} GB)"

# Step 11: Recreate GPT partition table with new sizes
log_step "Step 11: Recreating GPT partition table..."

# Ensure device is unmounted
log_info "Ensuring device is unmounted..."
diskutil unmountDisk "$TARGET_DISK" 2>/dev/null || true
sleep 2

# Destroy existing GPT and create new one
log_info "Destroying existing partition table..."
# Try multiple times to destroy GPT, as it may be locked
for attempt in 1 2 3; do
    if gpt destroy "$TARGET_DISK" 2>/dev/null; then
        log_info "Existing GPT destroyed successfully"
        break
    else
        if [ $attempt -lt 3 ]; then
            log_warn "Attempt $attempt to destroy GPT failed, retrying..."
            sleep 2
            diskutil unmountDisk "$TARGET_DISK" 2>/dev/null || true
            sleep 1
        else
            log_warn "Could not destroy existing GPT (may not exist or already destroyed)"
        fi
    fi
done

sleep 1

log_info "Initializing new GPT partition table..."
# Initialize GPT with the full disk size
# Try multiple times as device may need time to be ready
for attempt in 1 2 3; do
    GPT_CREATE_OUTPUT=$(gpt create "$TARGET_DISK" 2>&1)
    GPT_CREATE_EXIT=$?
    
    if [ $GPT_CREATE_EXIT -eq 0 ]; then
        log_info "GPT partition table created successfully"
        break
    else
        if [ $attempt -lt 3 ]; then
            log_warn "Attempt $attempt to create GPT failed: $GPT_CREATE_OUTPUT"
            log_warn "Retrying after unmounting device..."
            diskutil unmountDisk "$TARGET_DISK" 2>/dev/null || true
            sleep 2
        else
            log_error "Failed to initialize GPT partition table after 3 attempts"
            log_error "Error: $GPT_CREATE_OUTPUT"
            log_error ""
            log_error "This may be due to:"
            log_error "  1. Device is locked or in use"
            log_error "  2. System Integrity Protection (SIP) restrictions"
            log_error "  3. Device needs to be physically removed and reinserted"
            log_error ""
            log_info "Try:"
            log_info "  1. Physically remove and reinsert the SD card"
            log_info "  2. Wait a few seconds"
            log_info "  3. Run: sudo ./prepare-sd-card.sh $TARGET_DEVICE"
            log_info "  4. Then run this restore script again"
            exit 1
        fi
    fi
done

log_info "Creating partitions with adjusted sizes..."

# Create array of partition info for sorting
declare -a PARTITION_INFO_ARRAY
PARTITION_INFO_COUNT=0

# First, collect all partitions with their info
for i in "${!PARTITION_INDICES[@]}"; do
    INDEX=${PARTITION_INDICES[$i]}
    START=${PARTITION_STARTS[$i]}
    TYPE_GUID=${PARTITION_TYPE_GUIDS[$i]}
    
    if [ "$INDEX" = "$MAIN_PARTITION_INDEX" ]; then
        # Use new size and start for main partition
        START=$MAIN_PARTITION_START
        SIZE=$MAIN_PARTITION_NEW_SIZE
    else
        # Keep original size for other partitions
        SIZE=${PARTITION_SIZES[$i]}
    fi
    
    # Store as: "START INDEX SIZE TYPE_GUID"
    PARTITION_INFO_ARRAY[$PARTITION_INFO_COUNT]="$START $INDEX $SIZE $TYPE_GUID"
    PARTITION_INFO_COUNT=$((PARTITION_INFO_COUNT + 1))
done

# Sort partitions by start sector (simple bubble sort)
for ((i=0; i<PARTITION_INFO_COUNT-1; i++)); do
    for ((j=0; j<PARTITION_INFO_COUNT-i-1; j++)); do
        START_I=$(echo "${PARTITION_INFO_ARRAY[$j]}" | awk '{print $1}')
        START_J=$(echo "${PARTITION_INFO_ARRAY[$((j+1))]}" | awk '{print $1}')
        if [ "$START_I" -gt "$START_J" ]; then
            # Swap
            temp="${PARTITION_INFO_ARRAY[$j]}"
            PARTITION_INFO_ARRAY[$j]="${PARTITION_INFO_ARRAY[$((j+1))]}"
            PARTITION_INFO_ARRAY[$((j+1))]="$temp"
        fi
    done
done

# Create partitions in order
for i in $(seq 0 $((PARTITION_INFO_COUNT - 1))); do
    START=$(echo "${PARTITION_INFO_ARRAY[$i]}" | awk '{print $1}')
    INDEX=$(echo "${PARTITION_INFO_ARRAY[$i]}" | awk '{print $2}')
    SIZE=$(echo "${PARTITION_INFO_ARRAY[$i]}" | awk '{print $3}')
    TYPE_GUID=$(echo "${PARTITION_INFO_ARRAY[$i]}" | awk '{print $4}')
    
    if [ -n "$TYPE_GUID" ]; then
        if [ "$INDEX" = "$MAIN_PARTITION_INDEX" ]; then
            log_info "Creating partition $INDEX: start=$START, size=$SIZE sectors (resized to $(echo "scale=2; $SIZE * 512 / 1024 / 1024 / 1024" | bc) GB), type=$TYPE_GUID"
        else
            log_info "Creating partition $INDEX: start=$START, size=$SIZE sectors (original), type=$TYPE_GUID"
        fi
        
        # Use -t for partition type GUID (not UUID)
        gpt add -b "$START" -s "$SIZE" -t "$TYPE_GUID" "$TARGET_DISK" 2>&1 || {
            log_error "Failed to create partition $INDEX with type $TYPE_GUID"
            log_error "This is critical - all partitions must be created for the system to boot"
            exit 1
        }
    else
        log_error "Could not extract type GUID for partition $INDEX"
        log_error "Partition type string: ${PARTITION_TYPES[$i]}"
        log_error "This partition is required for the system to boot - cannot continue"
        exit 1
    fi
done

log_info "Partition table recreated successfully"

# Step 12: Note about filesystem expansion
log_step "Step 12: Filesystem expansion information..."

# Get main partition device
MAIN_PARTITION_DEVICE="${TARGET_DISK}s${MAIN_PARTITION_INDEX}"

log_info "Main partition device: $MAIN_PARTITION_DEVICE"
log_info "New partition size: $(echo "scale=2; $MAIN_PARTITION_NEW_SIZE * 512 / 1024 / 1024 / 1024" | bc) GB"

log_info ""
log_info "Note: Filesystem expansion on macOS"
log_info "-----------------------------------"
log_info "The partition has been resized to fit the new SD card."
log_info "However, the ext4 filesystem inside the partition still needs to be expanded"
log_info "to use the full partition space. This can be done in two ways:"
log_info ""
log_info "Option 1: Automatic expansion (recommended)"
log_info "  Most modern Linux systems (including Lichee RV Dock) automatically expand"
log_info "  the filesystem on first boot. Just insert the SD card and boot normally."
log_info ""
log_info "Option 2: Manual expansion (if automatic expansion doesn't work)"
log_info "  After booting the system, run:"
log_info "    sudo resize2fs /dev/mmcblk0p${MAIN_PARTITION_INDEX}"
log_info "  Or:"
log_info "    sudo resize2fs /dev/sda${MAIN_PARTITION_INDEX}"
log_info "  (The device name may vary depending on your system)"
log_info ""
log_warn "The SD card is ready to use, but the filesystem will use the original size"
log_warn "until it is expanded (usually happens automatically on first boot)."

# Step 13: Verify
log_step "Step 13: Verifying restore..."

# Remount to verify
if diskutil mountDisk "$TARGET_DISK" 2>/dev/null; then
    log_info "Target device mounted successfully"
else
    log_warn "Could not mount target device (this is normal for Linux filesystems on macOS)"
fi

# Get final partition info
FINAL_GPT=$(gpt show "$TARGET_DISK" 2>&1)
log_info "Final partition table:"
echo "$FINAL_GPT" | grep "GPT part" | while read line; do
    log_info "  $line"
done

log_info ""
log_info "=== Restore Completed! ==="
log_info "Image restored to: $TARGET_DEVICE"
log_info "Partition sizes adjusted to fit target SD card"
log_info ""
log_info "The SD card is ready to use!"
log_info "Insert it into your device and boot normally."
log_info ""
log_info "✅ Done!"
