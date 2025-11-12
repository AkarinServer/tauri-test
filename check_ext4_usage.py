#!/usr/bin/env python3
"""
Script to read ext4 filesystem usage information directly from the device
without mounting. This reads the superblock to get filesystem statistics.
"""

import struct
import sys
import os
import subprocess

# Ext4 superblock offsets (in bytes)
SUPERBLOCK_OFFSET = 1024  # First superblock is at offset 1024
SUPERBLOCK_SIZE = 1024    # Superblock is 1024 bytes

# Superblock field offsets
S_MAGIC_OFFSET = 0x38      # Magic number (offset 56)
S_INODES_COUNT_OFFSET = 0x00  # Total inodes (offset 0)
S_BLOCKS_COUNT_LO_OFFSET = 0x04  # Total blocks (low 32 bits, offset 4)
S_BLOCKS_COUNT_HI_OFFSET = 0x150  # Total blocks (high 32 bits, offset 336)
S_FREE_BLOCKS_COUNT_LO_OFFSET = 0x0C  # Free blocks (low 32 bits, offset 12)
S_FREE_BLOCKS_COUNT_HI_OFFSET = 0x154  # Free blocks (high 32 bits, offset 340)
S_FREE_INODES_COUNT_OFFSET = 0x10  # Free inodes (offset 16)
S_LOG_BLOCK_SIZE_OFFSET = 0x18  # Block size (offset 24)
S_INODES_PER_GROUP_OFFSET = 0x28  # Inodes per group (offset 40)
S_BLOCKS_PER_GROUP_OFFSET = 0x20  # Blocks per group (offset 32)

EXT4_SUPER_MAGIC = 0xEF53


def parse_size_to_bytes(size_str):
    """Convert size string (e.g., '63.8 GB', '4.2 MB') to bytes."""
    size_str = size_str.strip().upper()
    try:
        if 'GB' in size_str:
            num = float(size_str.replace('GB', '').strip())
            return int(num * 1024 * 1024 * 1024)
        elif 'MB' in size_str:
            num = float(size_str.replace('MB', '').strip())
            return int(num * 1024 * 1024)
        elif 'KB' in size_str:
            num = float(size_str.replace('KB', '').strip())
            return int(num * 1024)
        else:
            # Try to parse as bytes
            return int(float(size_str))
    except:
        return 0


def get_device_info():
    """Get SD card device information using diskutil."""
    try:
        result = subprocess.run(['diskutil', 'list'], capture_output=True, text=True, check=True)
        lines = result.stdout.split('\n')
        
        # Look for external disk with Linux filesystem
        current_disk = None
        partitions = []  # List of (partition, size_bytes) tuples
        
        for line in lines:
            if 'external, physical' in line:
                # Extract disk identifier (e.g., /dev/disk7)
                parts = line.split()
                if len(parts) > 0:
                    current_disk = parts[0].replace(':', '')
            elif 'Linux Filesystem' in line and current_disk:
                # Parse line like: "   6:           Linux Filesystem                         63.8 GB    disk7s1"
                parts = line.split()
                if len(parts) >= 3:
                    # Find the partition name (last element, e.g., disk7s1)
                    partition = parts[-1]
                    # Find size (look for GB/MB/KB in the line)
                    size_bytes = 0
                    for i, part in enumerate(parts):
                        if 'GB' in part or 'MB' in part or 'KB' in part:
                            # Get the number before the unit
                            if i > 0:
                                size_str = parts[i-1] + ' ' + part
                                size_bytes = parse_size_to_bytes(size_str)
                                break
                    partitions.append((f"/dev/{partition}", size_bytes))
        
        # Sort partitions by size (largest first) and return the largest one
        if partitions:
            partitions.sort(key=lambda x: x[1], reverse=True)
            largest_partition = partitions[0][0]
            print(f"Found {len(partitions)} Linux partition(s), using largest: {largest_partition}")
            return largest_partition
        
        # If auto-detection fails, try disk7s1 (from previous output)
        if os.path.exists("/dev/disk7s1"):
            return "/dev/disk7s1"
            
    except Exception as e:
        print(f"Error detecting device: {e}", file=sys.stderr)
    
    return None


def read_ext4_superblock(device):
    """Read ext4 superblock from device."""
    try:
        with open(device, 'rb') as f:
            # Seek to superblock offset
            f.seek(SUPERBLOCK_OFFSET)
            # Read superblock
            superblock = f.read(SUPERBLOCK_SIZE)
            return superblock
    except PermissionError:
        print(f"ERROR: Permission denied accessing {device}", file=sys.stderr)
        print(f"Please run with sudo: sudo python3 {sys.argv[0]}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"ERROR: Failed to read superblock: {e}", file=sys.stderr)
        return None


def parse_superblock(superblock):
    """Parse ext4 superblock and extract filesystem information."""
    if len(superblock) < SUPERBLOCK_SIZE:
        return None
    
    # Check magic number
    magic = struct.unpack('<H', superblock[S_MAGIC_OFFSET:S_MAGIC_OFFSET+2])[0]
    if magic != EXT4_SUPER_MAGIC:
        print(f"ERROR: Invalid ext4 magic number: 0x{magic:04X} (expected 0x{EXT4_SUPER_MAGIC:04X})", file=sys.stderr)
        return None
    
    # Read block size
    log_block_size = struct.unpack('<I', superblock[S_LOG_BLOCK_SIZE_OFFSET:S_LOG_BLOCK_SIZE_OFFSET+4])[0]
    block_size = 1024 << log_block_size  # Block size in bytes
    
    # Read total blocks (64-bit value)
    blocks_count_lo = struct.unpack('<I', superblock[S_BLOCKS_COUNT_LO_OFFSET:S_BLOCKS_COUNT_LO_OFFSET+4])[0]
    blocks_count_hi = struct.unpack('<I', superblock[S_BLOCKS_COUNT_HI_OFFSET:S_BLOCKS_COUNT_HI_OFFSET+4])[0]
    total_blocks = blocks_count_lo | (blocks_count_hi << 32)
    
    # Read free blocks (64-bit value)
    free_blocks_lo = struct.unpack('<I', superblock[S_FREE_BLOCKS_COUNT_LO_OFFSET:S_FREE_BLOCKS_COUNT_LO_OFFSET+4])[0]
    free_blocks_hi = struct.unpack('<I', superblock[S_FREE_BLOCKS_COUNT_HI_OFFSET:S_FREE_BLOCKS_COUNT_HI_OFFSET+4])[0]
    free_blocks = free_blocks_lo | (free_blocks_hi << 32)
    
    # Calculate used blocks
    used_blocks = total_blocks - free_blocks
    
    # Read inode information
    total_inodes = struct.unpack('<I', superblock[S_INODES_COUNT_OFFSET:S_INODES_COUNT_OFFSET+4])[0]
    free_inodes = struct.unpack('<I', superblock[S_FREE_INODES_COUNT_OFFSET:S_FREE_INODES_COUNT_OFFSET+4])[0]
    used_inodes = total_inodes - free_inodes
    
    # Calculate sizes
    total_size = total_blocks * block_size
    used_size = used_blocks * block_size
    free_size = free_blocks * block_size
    
    return {
        'block_size': block_size,
        'total_blocks': total_blocks,
        'free_blocks': free_blocks,
        'used_blocks': used_blocks,
        'total_inodes': total_inodes,
        'free_inodes': free_inodes,
        'used_inodes': used_inodes,
        'total_size': total_size,
        'used_size': used_size,
        'free_size': free_size,
        'usage_percent': (used_blocks / total_blocks * 100) if total_blocks > 0 else 0
    }


def format_size(size_bytes):
    """Format size in human-readable format."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} PB"


def main():
    # Get device
    device = get_device_info()
    if device is None:
        print("ERROR: Could not detect SD card device", file=sys.stderr)
        print("Please specify device manually:", file=sys.stderr)
        print(f"  sudo python3 {sys.argv[0]} <device>", file=sys.stderr)
        print("\nExample: sudo python3 {} /dev/disk7s1".format(sys.argv[0]), file=sys.stderr)
        sys.exit(1)
    
    # Allow manual device specification
    if len(sys.argv) > 1:
        device = sys.argv[1]
        if not device.startswith('/dev/'):
            device = f"/dev/{device}"
    
    print(f"Reading ext4 filesystem information from: {device}")
    print()
    
    # Read superblock
    superblock = read_ext4_superblock(device)
    if superblock is None:
        sys.exit(1)
    
    # Parse superblock
    fs_info = parse_superblock(superblock)
    if fs_info is None:
        sys.exit(1)
    
    # Display information
    print("=" * 60)
    print("📊 SD Card Usage Summary (Ext4 Filesystem)")
    print("=" * 60)
    print(f"Device:              {device}")
    print(f"Block size:          {fs_info['block_size']} bytes")
    print()
    print(f"Total size:          {format_size(fs_info['total_size'])}")
    print(f"Used space:          {format_size(fs_info['used_size'])}")
    print(f"Free space:          {format_size(fs_info['free_size'])}")
    print(f"Usage:               {fs_info['usage_percent']:.2f}%")
    print()
    print(f"Total blocks:        {fs_info['total_blocks']:,}")
    print(f"Used blocks:         {fs_info['used_blocks']:,}")
    print(f"Free blocks:         {fs_info['free_blocks']:,}")
    print()
    print(f"Total inodes:        {fs_info['total_inodes']:,}")
    print(f"Used inodes:         {fs_info['used_inodes']:,}")
    print(f"Free inodes:         {fs_info['free_inodes']:,}")
    print("=" * 60)


if __name__ == '__main__':
    main()

