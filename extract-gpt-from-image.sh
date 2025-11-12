#!/bin/bash
# Extract GPT partition table directly from image file bytes (bypasses gpt show)
# This works even if GPT is slightly corrupted, as long as the structure is readable
# Usage: ./extract-gpt-from-image.sh <image-file>

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

log_info "=== Extract GPT from Image (Direct Byte Reading) ==="
log_info "Image file: $IMAGE_FILE"
log_info ""

# Handle compressed images
TEMP_IMAGE=""
if [[ "$IMAGE_FILE" == *.gz ]]; then
    log_step "Step 1: Decompressing image..."
    TEMP_IMAGE="/tmp/extract_gpt_$$.img"
    
    if command -v pv >/dev/null 2>&1; then
        COMPRESSED_SIZE=$(stat -f%z "$IMAGE_FILE" 2>/dev/null || stat -c%s "$IMAGE_FILE" 2>/dev/null)
        COMPRESSED_SIZE_MB=$((COMPRESSED_SIZE / 1024 / 1024))
        pv -s "${COMPRESSED_SIZE_MB}M" "$IMAGE_FILE" | gunzip -c > "$TEMP_IMAGE"
    else
        gunzip -c "$IMAGE_FILE" > "$TEMP_IMAGE"
    fi
    ACTUAL_IMAGE="$TEMP_IMAGE"
else
    ACTUAL_IMAGE="$IMAGE_FILE"
fi

IMAGE_SIZE=$(stat -f%z "$ACTUAL_IMAGE" 2>/dev/null || stat -c%s "$ACTUAL_IMAGE" 2>/dev/null)
log_info "Image size: $(echo "scale=2; $IMAGE_SIZE / 1024 / 1024 / 1024" | bc) GB"
log_info ""

# GPT structure locations:
# - Primary GPT header: sector 1 (offset 512 bytes)
# - Primary partition table: sectors 2-33 (offset 1024-16896 bytes)
# - Backup GPT header: last sector
# - Backup partition table: last 32 sectors before header

log_step "Step 2: Reading GPT structure directly from image..."

# Check GPT header signature (should be "EFI PART" at offset 0x200)
GPT_HEADER_OFFSET=512
GPT_SIGNATURE=$(dd if="$ACTUAL_IMAGE" bs=1 skip=$GPT_HEADER_OFFSET count=8 2>/dev/null | od -An -tx1 | tr -d ' \n')

if [ "$GPT_SIGNATURE" != "4546492050415254" ]; then  # "EFI PART" in hex
    log_error "GPT signature not found at expected location"
    log_error "This image may not have a valid GPT partition table"
    [ -n "$TEMP_IMAGE" ] && rm -f "$TEMP_IMAGE"
    exit 1
fi

log_info "✓ GPT signature found (EFI PART)"
log_info ""

# Read GPT header (sector 1, 512 bytes)
log_info "Reading GPT header..."
GPT_HEADER=$(dd if="$ACTUAL_IMAGE" bs=512 skip=1 count=1 2>/dev/null | hexdump -C | head -20)

# Read partition table (sectors 2-33, 32 sectors = 128 entries)
log_info "Reading partition table (128 entries)..."
PARTITION_TABLE_OFFSET=$((2 * 512))  # Sector 2

# Use Python to parse GPT structure (more reliable than shell)
log_step "Step 3: Parsing GPT partition entries..."

python3 << 'PYTHON_SCRIPT'
import struct
import sys

image_file = sys.argv[1]

def read_gpt_partition_table(image_file):
    """Read GPT partition table directly from image file"""
    partitions = []
    
    with open(image_file, 'rb') as f:
        # Read GPT header (sector 1)
        f.seek(512)  # Skip to sector 1
        header = f.read(512)
        
        # Parse header
        signature = header[0:8]
        revision = struct.unpack('<I', header[8:12])[0]
        header_size = struct.unpack('<I', header[12:16])[0]
        header_crc32 = struct.unpack('<I', header[16:20])[0]
        reserved = header[20:24]
        current_lba = struct.unpack('<Q', header[24:32])[0]
        backup_lba = struct.unpack('<Q', header[32:40])[0]
        first_usable_lba = struct.unpack('<Q', header[40:48])[0]
        last_usable_lba = struct.unpack('<Q', header[48:56])[0]
        disk_guid = header[56:72]
        partition_entry_lba = struct.unpack('<Q', header[72:80])[0]
        num_partition_entries = struct.unpack('<I', header[80:84])[0]
        partition_entry_size = struct.unpack('<I', header[84:88])[0]
        partition_array_crc32 = struct.unpack('<I', header[88:92])[0]
        
        print(f"GPT Header Info:")
        print(f"  Signature: {signature}")
        print(f"  Current LBA: {current_lba}")
        print(f"  Backup LBA: {backup_lba}")
        print(f"  First usable: {first_usable_lba}")
        print(f"  Last usable: {last_usable_lba}")
        print(f"  Partition entries: {num_partition_entries}")
        print(f"  Entry size: {partition_entry_size} bytes")
        print()
        
        # Read partition table (sectors 2-33)
        f.seek(partition_entry_lba * 512)
        
        for i in range(num_partition_entries):
            entry = f.read(partition_entry_size)
            if len(entry) < partition_entry_size:
                break
            
            # Parse partition entry (128 bytes standard)
            type_guid = entry[0:16]
            partition_guid = entry[16:32]
            first_lba = struct.unpack('<Q', entry[32:40])[0]
            last_lba = struct.unpack('<Q', entry[40:48])[0]
            attributes = struct.unpack('<Q', entry[48:56])[0]
            name = entry[56:128].decode('utf-16le', errors='ignore').rstrip('\x00')
            
            # Check if partition is used (type GUID not all zeros)
            if first_lba != 0 or last_lba != 0:
                type_guid_str = '-'.join([
                    struct.unpack('<I', type_guid[0:4])[0].to_bytes(4, 'big').hex(),
                    struct.unpack('<H', type_guid[4:6])[0].to_bytes(2, 'big').hex(),
                    struct.unpack('<H', type_guid[6:8])[0].to_bytes(2, 'big').hex(),
                    type_guid[8:10].hex(),
                    type_guid[10:16].hex()
                ]).upper()
                
                size_sectors = last_lba - first_lba + 1
                
                partitions.append({
                    'index': i + 1,
                    'start': first_lba,
                    'size': size_sectors,
                    'type_guid': type_guid_str,
                    'name': name
                })
        
        return partitions

try:
    partitions = read_gpt_partition_table(image_file)
    
    if partitions:
        print(f"Found {len(partitions)} partition(s):")
        print()
        for p in partitions:
            size_gb = p['size'] * 512 / 1024 / 1024 / 1024
            print(f"Partition {p['index']}:")
            print(f"  Start sector: {p['start']}")
            print(f"  Size: {p['size']} sectors ({size_gb:.2f} GB)")
            print(f"  Type GUID: {p['type_guid']}")
            if p['name']:
                print(f"  Name: {p['name']}")
            print()
        
        # Generate .partitions file format
        print("# Partition table information extracted from image")
        print(f"# Generated: $(date)")
        print(f"# Image: {image_file}")
        print()
        
        # Find main partition (largest Linux partition)
        main_partition = None
        main_size = 0
        for p in partitions:
            if '0FC63DAF-8483-4772-8E79-3D69D8477DE4' in p['type_guid'] and p['size'] > main_size:
                main_partition = p
                main_size = p['size']
        
        for p in partitions:
            print(f"PARTITION_{p['index']}_START={p['start']}")
            print(f"PARTITION_{p['index']}_SIZE={p['size']}")
            print(f"PARTITION_{p['index']}_TYPE=\"part - {p['type_guid']}\"")
        
        print()
        if main_partition:
            print(f"MAIN_PARTITION_INDEX={main_partition['index']}")
            print(f"MAIN_PARTITION_START={main_partition['start']}")
            print(f"MAIN_PARTITION_SIZE={main_partition['size']}")
        else:
            print("MAIN_PARTITION_INDEX=1")
            print("MAIN_PARTITION_START=0")
            print("MAIN_PARTITION_SIZE=0")
        print(f"PARTITION_COUNT={len(partitions)}")
    else:
        print("No partitions found in GPT table")
        sys.exit(1)
        
except Exception as e:
    print(f"Error parsing GPT: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
"$ACTUAL_IMAGE" > /tmp/gpt_extract_$$.txt 2>&1

EXTRACT_EXIT=$?

if [ $EXTRACT_EXIT -eq 0 ]; then
    log_info "✓ GPT partition table extracted successfully!"
    log_info ""
    
    # Show summary
    head -30 /tmp/gpt_extract_$$.txt
    
    log_info ""
    read -p "Save partition information to .partitions file? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        PARTITIONS_FILE="${IMAGE_FILE%.gz}.partitions"
        PARTITIONS_FILE="${PARTITIONS_FILE%.img}.partitions"
        
        # Extract just the partition info part (skip the display output)
        grep -E "^PARTITION_|^MAIN_PARTITION_|^PARTITION_COUNT=" /tmp/gpt_extract_$$.txt > "$PARTITIONS_FILE" || {
            # If grep fails, try to extract from the full output
            tail -20 /tmp/gpt_extract_$$.txt | grep -E "^PARTITION_|^MAIN_PARTITION_|^PARTITION_COUNT=" > "$PARTITIONS_FILE" || {
                # Last resort: save everything after the partition list
                sed -n '/^# Partition table information/,$p' /tmp/gpt_extract_$$.txt > "$PARTITIONS_FILE"
            }
        }
        
        # Add header
        {
            echo "# Partition table information extracted from image"
            echo "# Generated: $(date)"
            echo "# Image: $IMAGE_FILE"
            echo ""
            cat "$PARTITIONS_FILE"
        } > "$PARTITIONS_FILE.tmp" && mv "$PARTITIONS_FILE.tmp" "$PARTITIONS_FILE"
        
        log_info "✓ Partition information saved to: $PARTITIONS_FILE"
    fi
else
    log_error "Failed to extract GPT partition table"
    log_error "Error output:"
    cat /tmp/gpt_extract_$$.txt
fi

rm -f /tmp/gpt_extract_$$.txt
[ -n "$TEMP_IMAGE" ] && rm -f "$TEMP_IMAGE"

log_info ""
log_info "=== Done ==="

