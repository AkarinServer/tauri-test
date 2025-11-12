#!/bin/bash
# Check GPT partition table in image file and optionally extract partition info
# Usage: ./check-image-gpt.sh <image-file>

set -e

IMAGE_FILE="${1}"

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

if [ -z "$IMAGE_FILE" ]; then
    log_error "Usage: $0 <image-file>"
    log_error "Example: $0 ~/backups/image.img"
    log_error "Example: $0 ~/backups/image.img.gz"
    exit 1
fi

if [ ! -f "$IMAGE_FILE" ]; then
    log_error "Image file not found: $IMAGE_FILE"
    exit 1
fi

log_info "=== Image GPT Partition Table Checker ==="
log_info "Image file: $IMAGE_FILE"
log_info ""

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
    GPT_CMD="gpt"
    USE_HDIUTIL=true
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    OS="Linux"
    GPT_CMD="gdisk"
    USE_HDIUTIL=false
else
    log_error "Unsupported OS: $OSTYPE"
    exit 1
fi

log_info "Detected OS: $OS"
log_info ""

# Handle compressed images
TEMP_IMAGE=""
if [[ "$IMAGE_FILE" == *.gz ]]; then
    log_step "Step 1: Decompressing image..."
    TEMP_IMAGE="/tmp/check_gpt_$$.img"
    
    if command -v pv >/dev/null 2>&1; then
        COMPRESSED_SIZE=$(stat -f%z "$IMAGE_FILE" 2>/dev/null || stat -c%s "$IMAGE_FILE" 2>/dev/null)
        COMPRESSED_SIZE_MB=$((COMPRESSED_SIZE / 1024 / 1024))
        log_info "Decompressing ${COMPRESSED_SIZE_MB}MB..."
        pv -s "${COMPRESSED_SIZE_MB}M" "$IMAGE_FILE" | gunzip -c > "$TEMP_IMAGE"
    else
        log_info "Decompressing (this may take a while)..."
        gunzip -c "$IMAGE_FILE" > "$TEMP_IMAGE"
    fi
    
    ACTUAL_IMAGE="$TEMP_IMAGE"
    log_info "Decompressed to: $TEMP_IMAGE"
else
    ACTUAL_IMAGE="$IMAGE_FILE"
fi

IMAGE_SIZE=$(stat -f%z "$ACTUAL_IMAGE" 2>/dev/null || stat -c%s "$ACTUAL_IMAGE" 2>/dev/null)
IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE / 1024 / 1024 / 1024" | bc)
log_info "Image size: ${IMAGE_SIZE_GB} GB"
log_info ""

# Check GPT partition table
log_step "Step 2: Checking GPT partition table..."

if [ "$OS" = "macOS" ]; then
    # macOS: Use hdiutil to attach image as a disk, then check GPT
    log_info "Attaching image as disk device (macOS)..."
    
    # Try to attach the image
    ATTACH_OUTPUT=$(hdiutil attach -nomount "$ACTUAL_IMAGE" 2>&1)
    ATTACH_EXIT=$?
    
    if [ $ATTACH_EXIT -eq 0 ]; then
        # Extract device path from output (usually /dev/diskX)
        DISK_DEVICE=$(echo "$ATTACH_OUTPUT" | grep -oE "/dev/disk[0-9]+" | head -1)
        
        if [ -n "$DISK_DEVICE" ]; then
            log_info "Image attached as: $DISK_DEVICE"
            
            # Wait a moment for device to be ready
            sleep 2
            
            # Check GPT (with error handling and timeout)
            log_info "Checking GPT partition table..."
            
            # Use background process with timeout to prevent hanging
            GPT_OUTPUT=""
            GPT_EXIT=1
            TIMEOUT_SEC=5
            
            # Run gpt show in background with timeout
            (gpt show "$DISK_DEVICE" >/tmp/gpt_output_$$.txt 2>&1; echo $? >/tmp/gpt_exit_$$.txt) &
            GPT_PID=$!
            
            # Wait with timeout
            for i in $(seq 1 $TIMEOUT_SEC); do
                if ! kill -0 $GPT_PID 2>/dev/null; then
                    # Process finished
                    break
                fi
                sleep 1
            done
            
            # If still running, kill it
            if kill -0 $GPT_PID 2>/dev/null; then
                log_warn "gpt show is taking too long, forcing termination..."
                kill -9 $GPT_PID 2>/dev/null || true
                GPT_EXIT=1
                GPT_OUTPUT="gpt show timed out or hung (GPT may be corrupted)"
            else
                # Process finished, get exit code
                wait $GPT_PID 2>/dev/null
                GPT_EXIT=$(cat /tmp/gpt_exit_$$.txt 2>/dev/null || echo "1")
                GPT_OUTPUT=$(cat /tmp/gpt_output_$$.txt 2>/dev/null || echo "Failed to read GPT")
            fi
            
            # Cleanup temp files
            rm -f /tmp/gpt_output_$$.txt /tmp/gpt_exit_$$.txt
            
            # Detach immediately
            hdiutil detach "$DISK_DEVICE" >/dev/null 2>&1 || true
            
            # Check if GPT is valid
            if [ $GPT_EXIT -eq 0 ] && [ -n "$GPT_OUTPUT" ] && ! echo "$GPT_OUTPUT" | grep -qi "bogus\|error\|unable\|operation not permitted"; then
                # Check if we actually got partition information
                if echo "$GPT_OUTPUT" | grep -q "GPT part"; then
                    GPT_VALID=true
                else
                    GPT_VALID=false
                    GPT_ERROR="No partitions found in GPT output"
                fi
            else
                GPT_VALID=false
                GPT_ERROR="$GPT_OUTPUT"
            fi
        else
            log_error "Could not determine disk device from hdiutil output"
            log_error "hdiutil output: $ATTACH_OUTPUT"
            GPT_VALID=false
        fi
    else
        log_error "Failed to attach image: $ATTACH_OUTPUT"
        GPT_VALID=false
        GPT_ERROR="$ATTACH_OUTPUT"
    fi
else
    # Linux: Use gdisk or kpartx to check GPT
    if command -v gdisk >/dev/null 2>&1; then
        log_info "Checking GPT using gdisk..."
        GPT_OUTPUT=$(gdisk -l "$ACTUAL_IMAGE" 2>&1)
        GPT_EXIT=$?
        
        if [ $GPT_EXIT -eq 0 ] && ! echo "$GPT_OUTPUT" | grep -qi "bogus\|corrupt\|invalid\|not found"; then
            GPT_VALID=true
        else
            GPT_VALID=false
            GPT_ERROR="$GPT_OUTPUT"
        fi
    else
        log_error "gdisk is not installed"
        log_info "Install with: sudo apt-get install gdisk"
        [ -n "$TEMP_IMAGE" ] && rm -f "$TEMP_IMAGE"
        exit 1
    fi
fi

# Display results
log_step "Step 3: Results"
log_info ""

if [ "$GPT_VALID" = true ]; then
    log_info "✓ GPT partition table is VALID and readable!"
    log_info ""
    
    if [ "$OS" = "macOS" ]; then
        # Re-attach to show partitions
        log_info "Re-attaching to read partition details..."
        ATTACH_OUTPUT=$(hdiutil attach -nomount "$ACTUAL_IMAGE" 2>&1)
        DISK_DEVICE=$(echo "$ATTACH_OUTPUT" | grep -oE "/dev/disk[0-9]+" | head -1)
        if [ -n "$DISK_DEVICE" ]; then
            sleep 1
            log_info "Partition table:"
            PARTITION_TABLE=$(gpt show "$DISK_DEVICE" 2>&1)
            echo "$PARTITION_TABLE" | grep "GPT part" || log_warn "No partitions found"
            GPT_SHOW_OUTPUT="$PARTITION_TABLE"
            hdiutil detach "$DISK_DEVICE" >/dev/null 2>&1 || true
        else
            log_warn "Could not re-attach image to show partitions"
            GPT_SHOW_OUTPUT="$GPT_OUTPUT"
        fi
    else
        log_info "Partition table:"
        echo "$GPT_OUTPUT" | grep -A 50 "Number" | head -30
        GPT_SHOW_OUTPUT="$GPT_OUTPUT"
    fi
    
    log_info ""
    log_info "The GPT partition table in this image is intact and can be used."
    log_info ""
    
    # Ask if user wants to extract partition info
    read -p "Extract partition information to .partitions file? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_step "Step 4: Extracting partition information..."
        
        PARTITIONS_FILE="${IMAGE_FILE%.gz}.partitions"
        PARTITIONS_FILE="${PARTITIONS_FILE%.img}.partitions"
        
        log_info "Creating partition info file: $PARTITIONS_FILE"
        
        # Extract partition information
        if [ "$OS" = "macOS" ]; then
            ATTACH_OUTPUT=$(hdiutil attach -nomount "$ACTUAL_IMAGE" 2>&1)
            DISK_DEVICE=$(echo "$ATTACH_OUTPUT" | grep -oE "/dev/disk[0-9]+" | head -1)
            
            if [ -n "$DISK_DEVICE" ]; then
                # Get partition info using gpt show
                log_info "Reading partition information..."
                sleep 1
                GPT_SHOW_OUTPUT=$(gpt show "$DISK_DEVICE" 2>&1)
                
                # Parse and save partition info
                {
                    echo "# Partition table information extracted from image"
                    echo "# Generated: $(date)"
                    echo "# Image: $IMAGE_FILE"
                    echo ""
                    
                    PARTITION_COUNT=0
                    MAIN_PARTITION_INDEX=0
                    MAIN_PARTITION_START=0
                    MAIN_PARTITION_SIZE=0
                    
                    while IFS= read -r line; do
                        if [[ $line =~ ^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+GPT[[:space:]]+part ]]; then
                            PARTITION_COUNT=$((PARTITION_COUNT + 1))
                            START_SECTOR=$(echo "$line" | awk '{print $1}')
                            SIZE_SECTORS=$(echo "$line" | awk '{print $2}')
                            INDEX=$(echo "$line" | awk '{print $3}')
                            PARTITION_TYPE=$(echo "$line" | awk '{for(i=5;i<=NF;i++) printf "%s ", $i; print ""}' | xargs)
                            
                            echo "PARTITION_${INDEX}_START=$START_SECTOR"
                            echo "PARTITION_${INDEX}_SIZE=$SIZE_SECTORS"
                            echo "PARTITION_${INDEX}_TYPE=\"$PARTITION_TYPE\""
                            
                            # Detect main partition (usually the largest Linux partition)
                            if [[ "$PARTITION_TYPE" == *"0FC63DAF-8483-4772-8E79-3D69D8477DE4"* ]] && [ "$SIZE_SECTORS" -gt "$MAIN_PARTITION_SIZE" ]; then
                                MAIN_PARTITION_INDEX=$INDEX
                                MAIN_PARTITION_START=$START_SECTOR
                                MAIN_PARTITION_SIZE=$SIZE_SECTORS
                            fi
                        fi
                    done <<< "$GPT_SHOW_OUTPUT"
                    
                    echo ""
                    echo "MAIN_PARTITION_INDEX=$MAIN_PARTITION_INDEX"
                    echo "MAIN_PARTITION_START=$MAIN_PARTITION_START"
                    echo "MAIN_PARTITION_SIZE=$MAIN_PARTITION_SIZE"
                    echo "PARTITION_COUNT=$PARTITION_COUNT"
                } > "$PARTITIONS_FILE"
                
                hdiutil detach "$DISK_DEVICE" >/dev/null 2>&1 || true
                
                if [ -f "$PARTITIONS_FILE" ] && [ -s "$PARTITIONS_FILE" ]; then
                    log_info "✓ Partition information saved to: $PARTITIONS_FILE"
                else
                    log_error "Failed to save partition information"
                fi
            fi
        else
            # Linux: Extract using gdisk
            {
                echo "# Partition table information extracted from image"
                echo "# Generated: $(date)"
                echo "# Image: $IMAGE_FILE"
                echo ""
                
                # Parse gdisk output
                PARTITION_COUNT=0
                MAIN_PARTITION_INDEX=0
                MAIN_PARTITION_START=0
                MAIN_PARTITION_SIZE=0
                
                while IFS= read -r line; do
                    if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+.*$ ]]; then
                        PARTITION_COUNT=$((PARTITION_COUNT + 1))
                        INDEX="${BASH_REMATCH[1]}"
                        START_SECTOR="${BASH_REMATCH[2]}"
                        END_SECTOR="${BASH_REMATCH[3]}"
                        SIZE_SECTORS=$((END_SECTOR - START_SECTOR + 1))
                        
                        # Get partition type GUID from gdisk
                        TYPE_LINE=$(echo "$GPT_OUTPUT" | grep -E "^[[:space:]]*${INDEX}[[:space:]]" | awk '{print $(NF-1)}')
                        
                        echo "PARTITION_${INDEX}_START=$START_SECTOR"
                        echo "PARTITION_${INDEX}_SIZE=$SIZE_SECTORS"
                        echo "PARTITION_${INDEX}_TYPE=\"part - $TYPE_LINE\""
                        
                        # Detect main partition
                        if [[ "$TYPE_LINE" == *"8300"* ]] || [[ "$TYPE_LINE" == *"0FC63DAF"* ]]; then
                            if [ "$SIZE_SECTORS" -gt "$MAIN_PARTITION_SIZE" ]; then
                                MAIN_PARTITION_INDEX=$INDEX
                                MAIN_PARTITION_START=$START_SECTOR
                                MAIN_PARTITION_SIZE=$SIZE_SECTORS
                            fi
                        fi
                    fi
                done <<< "$(echo "$GPT_OUTPUT" | grep -E "^[[:space:]]*[0-9]+")"
                
                echo ""
                echo "MAIN_PARTITION_INDEX=$MAIN_PARTITION_INDEX"
                echo "MAIN_PARTITION_START=$MAIN_PARTITION_START"
                echo "MAIN_PARTITION_SIZE=$MAIN_PARTITION_SIZE"
                echo "PARTITION_COUNT=$PARTITION_COUNT"
            } > "$PARTITIONS_FILE"
            
            log_info "✓ Partition information saved to: $PARTITIONS_FILE"
        fi
        
        log_info ""
        log_info "You can now use this .partitions file with the restore scripts."
    else
        log_info "Skipped partition extraction."
    fi
else
    log_error "✗ GPT partition table is INVALID or corrupted!"
    log_error ""
    
    if [ -n "$GPT_ERROR" ]; then
        log_error "Error details:"
        echo "$GPT_ERROR" | while IFS= read -r line; do
            log_error "  $line"
        done
    fi
    
    log_error ""
    log_error "This image cannot be used as-is. The GPT needs to be repaired."
    log_error ""
    log_warn "Options:"
    log_warn "  1. Use a different backup image"
    log_warn "  2. Try to repair the GPT (risky, may cause data loss)"
    log_warn "  3. Restore from a known-good backup"
fi

# Cleanup
[ -n "$TEMP_IMAGE" ] && rm -f "$TEMP_IMAGE"

log_info ""
log_info "=== Done ==="

