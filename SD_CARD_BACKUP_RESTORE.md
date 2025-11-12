# SD卡备份和恢复指南

## 概述

这套脚本用于创建SD卡的最小化备份镜像（只包含有效数据和分区表），并可以恢复到任意大小的SD卡上（只要目标SD卡大于系统实际使用的数据量）。

## 特点

- **最小化备份**：只备份实际使用的数据（例如64GB卡只用了10GB，备份文件只有10-12GB）
- **智能恢复**：自动检测目标SD卡大小，自动调整分区大小
- **通用性**：可以恢复到任意大小的SD卡（32GB、64GB、128GB等），只要大于实际数据量
- **即插即用**：恢复后的SD卡可以直接使用，系统会在首次启动时自动扩展文件系统

## 使用方法

### 1. 备份SD卡

```bash
# 基本用法（使用默认设备 /dev/rdisk7）
sudo ./backup-sd-card-minimal.sh

# 指定SD卡设备
sudo ./backup-sd-card-minimal.sh /dev/rdisk7

# 指定SD卡设备和输出目录
sudo ./backup-sd-card-minimal.sh /dev/rdisk7 ~/backups/lichee-rv-dock
```

**备份过程：**
1. 自动检测SD卡的实际使用情况（通过 `check_ext4_usage.py`）
2. 读取分区表信息
3. 计算最小镜像大小（实际使用数据 + 10%开销 + GPT备份）
4. 创建压缩的镜像文件（.img.gz）
5. 保存分区信息文件（.partitions），用于恢复时调整分区大小

**输出文件：**
- `lichee-rv-dock-minimal-YYYYMMDD-HHMMSS.img.gz` - 压缩的镜像文件
- `lichee-rv-dock-minimal-YYYYMMDD-HHMMSS.img.gz.sha256` - 校验和文件
- `lichee-rv-dock-minimal-YYYYMMDD-HHMMSS.img.gz.partitions` - 分区信息文件

### 2. 恢复SD卡

```bash
# 基本用法
sudo ./restore-sd-card.sh <镜像文件> <目标设备>

# 示例
sudo ./restore-sd-card.sh ~/backups/lichee-rv-dock/lichee-rv-dock-minimal-20240101-120000.img.gz /dev/rdisk8
```

**恢复过程：**
1. 检查镜像文件和目标SD卡大小
2. 验证目标SD卡是否足够大（必须大于镜像大小）
3. 解压并写入镜像到目标SD卡
4. 读取分区表信息
5. 重新创建GPT分区表，调整主分区大小到目标SD卡大小
6. 提供文件系统扩展说明

**注意事项：**
- 文件系统扩展通常在首次启动时自动完成
- 如果自动扩展失败，可以在系统启动后手动运行：`sudo resize2fs /dev/mmcblk0p1`

## 示例

### 备份64GB SD卡（实际使用10GB）

```bash
$ sudo ./backup-sd-card-minimal.sh /dev/rdisk7

[STEP] Step 1: Checking filesystem usage...
[INFO] Filesystem usage: 9.30 GB
[STEP] Step 2: Reading partition table...
[INFO] Found 6 partition(s)
[STEP] Step 3: Calculating minimal image size...
[INFO] Minimal image size: 12.5 GB
[STEP] Step 8: Creating minimal image...
[STEP] Step 9: Compressing image...
[INFO] Compressed image: 10.2 GB

✅ Backup completed!
```

### 恢复到32GB SD卡

```bash
$ sudo ./restore-sd-card.sh ~/backups/lichee-rv-dock/lichee-rv-dock-minimal-*.img.gz /dev/rdisk8

[STEP] Step 1: Checking image file...
[INFO] Image size: 12.5 GB (compressed: 10.2 GB)
[STEP] Step 2: Checking target SD card size...
[INFO] Target SD card size: 32.0 GB
[INFO] ✓ Target SD card is large enough
[STEP] Step 8: Writing image to target device...
[STEP] Step 10: Calculating new partition sizes...
[INFO] Main partition will be resized: 12.5 GB → 28.5 GB
[STEP] Step 11: Recreating GPT partition table...
[INFO] Partition table recreated successfully

✅ Restore completed!
```

## 文件说明

### backup-sd-card-minimal.sh
- **功能**：创建最小化SD卡备份镜像
- **输入**：SD卡设备（如 `/dev/rdisk7`）
- **输出**：压缩的镜像文件（.img.gz）和分区信息文件

### restore-sd-card.sh
- **功能**：恢复镜像到SD卡，自动调整分区大小
- **输入**：镜像文件（.img.gz）和目标SD卡设备
- **输出**：恢复后的SD卡，分区大小已调整

### check_ext4_usage.py
- **功能**：读取ext4文件系统的实际使用情况
- **用法**：`sudo python3 check_ext4_usage.py [设备]`
- **输出**：显示总大小、已用空间、剩余空间等信息

## 工作原理

### 备份过程
1. 使用 `check_ext4_usage.py` 读取ext4文件系统的实际使用情况
2. 读取GPT分区表，获取所有分区信息
3. 计算最小镜像大小：主分区起始位置 + 实际使用数据 + 10%开销 + GPT备份
4. 使用 `dd` 备份指定大小的数据
5. 使用 `gzip` 压缩镜像文件
6. 保存分区信息到 `.partitions` 文件

### 恢复过程
1. 检查镜像文件和目标SD卡大小
2. 解压镜像文件（如果是压缩的）
3. 写入镜像到目标SD卡
4. 读取写入后的分区表
5. 计算新的主分区大小（目标SD卡大小 - 其他分区 - GPT开销）
6. 重新创建GPT分区表，调整主分区大小
7. 提供文件系统扩展说明

## 注意事项

1. **必须使用sudo**：备份和恢复都需要root权限
2. **确认设备**：使用 `diskutil list` 确认正确的设备（通常是 `/dev/rdisk7` 或 `/dev/rdisk8`）
3. **备份大小**：压缩后的备份通常只有实际使用数据的80-90%（因为大部分空间是空的）
4. **文件系统扩展**：大多数现代Linux系统会在首次启动时自动扩展文件系统
5. **目标SD卡大小**：目标SD卡必须大于镜像大小（未压缩）
6. **数据安全**：恢复过程会擦除目标SD卡上的所有数据

## 故障排除

### 备份失败
- 检查SD卡是否已卸载：`diskutil unmountDisk /dev/diskX`
- 检查是否有足够的磁盘空间
- 检查 `check_ext4_usage.py` 是否可用

### 恢复失败
- 检查目标SD卡是否足够大
- 检查镜像文件是否完整（验证校验和）
- 检查分区信息文件（.partitions）是否存在

### 文件系统未扩展
- 检查系统是否支持自动扩展（大多数现代Linux系统支持）
- 手动扩展：`sudo resize2fs /dev/mmcblk0p1`（设备名可能不同）

## 相关文件

- `backup-sd-card-minimal.sh` - 备份脚本
- `restore-sd-card.sh` - 恢复脚本
- `check_ext4_usage.py` - 文件系统使用情况检查脚本

