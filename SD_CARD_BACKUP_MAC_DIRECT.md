# Mac 直接备份 SD 卡指南

## 方法概述

直接在 Mac 上通过读卡器备份 SD 卡有以下优点：
- ✅ **速度快**: USB 3.0 读卡器比网络传输快得多
- ✅ **稳定**: 不会因网络中断而失败
- ✅ **简单**: 不需要 SSH 连接
- ✅ **直接**: 可以直接使用 Mac 工具

---

## 步骤 1: 插入 SD 卡并识别设备

### 1.1 插入 SD 卡到读卡器

将 SD 卡插入读卡器，然后插入 Mac 的 USB 端口。

### 1.2 识别 SD 卡设备

```bash
# 查看所有磁盘设备
diskutil list

# 或者使用
diskutil list | grep -i "external\|sd card\|mmc"
```

**输出示例**:
```
/dev/disk2 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:     FDisk_partition_scheme                        *31.9 GB    disk2
   1:             Windows_FAT_32                         106.0 MB   disk2s1
   2:                      Linux                         29.6 GB    disk2s2
   3:             Windows_FAT_32                         4.0 MB     disk2s3
```

**重要**: 记住设备标识符（如 `/dev/disk2`）和原始设备（如 `/dev/rdisk2`）

### 1.3 确认 SD 卡信息

```bash
# 查看 SD 卡详细信息
diskutil info /dev/disk2

# 查看 SD 卡大小
diskutil info /dev/disk2 | grep -i "disk size\|total size"
```

---

## 步骤 2: 卸载 SD 卡（重要！）

### 2.1 卸载所有分区

```bash
# 卸载整个磁盘（推荐）
diskutil unmountDisk /dev/disk2

# 或者卸载所有分区
diskutil unmount /dev/disk2s1
diskutil unmount /dev/disk2s2
diskutil unmount /dev/disk2s3
```

### 2.2 验证卸载状态

```bash
# 检查挂载状态
diskutil list /dev/disk2

# 如果显示 "(external, physical)" 且没有挂载点，说明已卸载
```

**重要**: 备份前必须卸载 SD 卡，否则可能导致数据不一致！

---

## 步骤 3: 创建备份

### 方法 1: 使用 dd 命令（推荐）

#### 3.1 完整备份（未压缩）

```bash
# 创建备份目录
mkdir -p ~/backups/lichee-rv-dock

# 备份整个 SD 卡（使用原始设备 rdisk2，速度更快）
sudo dd if=/dev/rdisk2 of=~/backups/lichee-rv-dock/lichee-rv-dock-backup-$(date +%Y%m%d-%H%M%S).img bs=4m status=progress

# 或者使用 disk2（较慢但更安全）
sudo dd if=/dev/disk2 of=~/backups/lichee-rv-dock/lichee-rv-dock-backup-$(date +%Y%m%d-%H%M%S).img bs=4m status=progress
```

**参数说明**:
- `if=/dev/rdisk2`: 输入设备（原始设备，速度更快）
- `of=...`: 输出文件
- `bs=4m`: 块大小 4MB（提高速度）
- `status=progress`: 显示进度（macOS 10.13+）

#### 3.2 压缩备份（节省空间）

```bash
# 创建压缩备份
sudo dd if=/dev/rdisk2 bs=4m status=progress | gzip -c > ~/backups/lichee-rv-dock/lichee-rv-dock-backup-$(date +%Y%m%d-%H%M%S).img.gz
```

#### 3.3 使用 pv 显示详细进度（可选）

```bash
# 安装 pv（如果未安装）
brew install pv

# 使用 pv 显示进度
sudo dd if=/dev/rdisk2 bs=4m | pv -s 31.9G | gzip -c > ~/backups/lichee-rv-dock/lichee-rv-dock-backup-$(date +%Y%m%d-%H%M%S).img.gz
```

### 方法 2: 使用磁盘工具（GUI 方法）

#### 3.1 打开磁盘工具

1. 打开"磁盘工具"（Applications > Utilities > Disk Utility）
2. 选择 SD 卡设备（左侧列表）
3. 点击"文件" > "新建映像" > "来自 [设备名称] 的映像"

#### 3.2 设置备份选项

- **名称**: `lichee-rv-dock-backup`
- **位置**: 选择备份目录
- **格式**: 
  - **压缩**: 节省空间（推荐）
  - **读/写**: 可以修改（不推荐）
  - **DVD/CD 主映像**: 原始格式（不推荐）
- **加密**: 可选（如果需要加密）

#### 3.3 开始备份

点击"存储"开始备份。备份完成后，会在指定位置生成 `.dmg` 文件。

### 方法 3: 使用命令行工具（diskutil）

```bash
# 创建磁盘映像
sudo diskutil createDiskImage /dev/disk2 ~/backups/lichee-rv-dock/lichee-rv-dock-backup.dmg -format UDZO -srcdevice /dev/disk2

# 参数说明:
# -format UDZO: 压缩格式（节省空间）
# -srcdevice: 源设备
```

---

## 步骤 4: 验证备份

### 4.1 检查备份文件

```bash
# 查看备份文件大小
ls -lh ~/backups/lichee-rv-dock/

# 查看备份文件信息
file ~/backups/lichee-rv-dock/lichee-rv-dock-backup-*.img
```

### 4.2 计算校验和

```bash
# 计算备份文件的 SHA256 校验和
sha256sum ~/backups/lichee-rv-dock/lichee-rv-dock-backup-*.img > ~/backups/lichee-rv-dock/lichee-rv-dock-backup-*.img.sha256

# 验证校验和
sha256sum -c ~/backups/lichee-rv-dock/lichee-rv-dock-backup-*.img.sha256
```

### 4.3 验证备份完整性（可选）

```bash
# 验证压缩备份
gunzip -t ~/backups/lichee-rv-dock/lichee-rv-dock-backup-*.img.gz

# 或者验证磁盘映像
hdiutil verify ~/backups/lichee-rv-dock/lichee-rv-dock-backup-*.dmg
```

---

## 步骤 5: 重新挂载 SD 卡

```bash
# 重新挂载 SD 卡（如果需要继续使用）
diskutil mountDisk /dev/disk2

# 或者弹出 SD 卡
diskutil eject /dev/disk2
```

---

## 自动化备份脚本

### Mac 备份脚本

```bash
#!/bin/bash
# backup-sd-card-mac.sh

set -e

# 配置
BACKUP_DIR="$HOME/backups/lichee-rv-dock"
BACKUP_FILE="lichee-rv-dock-backup-$(date +%Y%m%d-%H%M%S).img.gz"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 检测 SD 卡设备
log_info "Detecting SD card device..."
SD_CARD_DEVICE=$(diskutil list | grep -i "external\|sd card\|mmc" | head -1 | awk '{print $NF}')

if [ -z "$SD_CARD_DEVICE" ]; then
    log_error "SD card not found! Please insert SD card and try again."
    exit 1
fi

log_info "Found SD card: $SD_CARD_DEVICE"

# 获取原始设备
RAW_DEVICE="/dev/r${SD_CARD_DEVICE#/dev/}"

# 获取设备大小
DEVICE_SIZE=$(diskutil info "$SD_CARD_DEVICE" | grep -i "disk size" | awk '{print $3$4}')
log_info "Device size: $DEVICE_SIZE"

# 卸载 SD 卡
log_info "Unmounting SD card..."
diskutil unmountDisk "$SD_CARD_DEVICE" || {
    log_error "Failed to unmount SD card!"
    exit 1
}

# 开始备份
log_info "Starting backup..."
log_info "Backup file: $BACKUP_DIR/$BACKUP_FILE"
log_info "This may take a while, please be patient..."

START_TIME=$(date +%s)

# 备份（压缩）
sudo dd if="$RAW_DEVICE" bs=4m status=progress | gzip -c > "$BACKUP_DIR/$BACKUP_FILE"

BACKUP_EXIT_CODE=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))

# 检查备份结果
if [ $BACKUP_EXIT_CODE -eq 0 ] && [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_FILE" | awk '{print $5}')
    log_info "Backup completed successfully!"
    log_info "Backup file: $BACKUP_DIR/$BACKUP_FILE"
    log_info "Backup size: $BACKUP_SIZE"
    log_info "Duration: ${DURATION_MIN}m ${DURATION_SEC}s"
    
    # 创建校验和
    log_info "Creating checksum..."
    shasum -a 256 "$BACKUP_DIR/$BACKUP_FILE" > "$BACKUP_DIR/$BACKUP_FILE.sha256"
    log_info "Checksum file: $BACKUP_DIR/$BACKUP_FILE.sha256"
    
    log_info "Backup completed successfully!"
else
    log_error "Backup failed with exit code: $BACKUP_EXIT_CODE"
    exit 1
fi

# 重新挂载 SD 卡
log_info "Remounting SD card..."
diskutil mountDisk "$SD_CARD_DEVICE" || log_warn "Failed to remount SD card (you can eject it manually)"
```

---

## 恢复备份

### 从 .img 文件恢复

```bash
# 1. 插入 SD 卡，识别设备
diskutil list

# 2. 卸载 SD 卡
diskutil unmountDisk /dev/disk2

# 3. 恢复备份（未压缩）
sudo dd if=~/backups/lichee-rv-dock/lichee-rv-dock-backup-*.img of=/dev/rdisk2 bs=4m status=progress

# 4. 恢复备份（压缩）
gunzip -c ~/backups/lichee-rv-dock/lichee-rv-dock-backup-*.img.gz | sudo dd of=/dev/rdisk2 bs=4m status=progress

# 5. 弹出 SD 卡
diskutil eject /dev/disk2
```

### 从 .dmg 文件恢复

```bash
# 1. 挂载磁盘映像
hdiutil attach ~/backups/lichee-rv-dock/lichee-rv-dock-backup.dmg

# 2. 使用磁盘工具恢复
# 打开磁盘工具，选择 SD 卡，点击"恢复"，选择挂载的映像

# 或者使用命令行
sudo diskutil restoreDisk ~/backups/lichee-rv-dock/lichee-rv-dock-backup.dmg /dev/disk2
```

---

## 注意事项

### ⚠️ 重要提示

1. **卸载 SD 卡**: 备份前必须卸载 SD 卡，否则可能导致数据不一致
2. **使用原始设备**: 使用 `/dev/rdisk2` 而不是 `/dev/disk2`，速度更快
3. **确认设备**: 确认 SD 卡设备路径正确，避免覆盖错误设备
4. **备份空间**: 确保 Mac 有足够的磁盘空间（至少 32GB）
5. **备份时间**: 完整备份可能需要 10-30 分钟，取决于 SD 卡大小和速度

### 🔒 安全建议

1. **校验和**: 创建备份后计算校验和，验证备份完整性
2. **多个备份**: 创建多个备份，保存在不同位置
3. **定期备份**: 定期备份，特别是在重要更改后
4. **加密备份**: 如果包含敏感数据，考虑加密备份

---

## 性能对比

### 方法对比

| 方法 | 速度 | 稳定性 | 文件大小 | 推荐 |
|------|------|--------|----------|------|
| 网络备份 (SSH) | 慢 (10-30 min) | 中等 | 3-7 GB | ⭐⭐ |
| 直接备份 (dd) | 快 (5-15 min) | 高 | 29.7 GB | ⭐⭐⭐⭐ |
| 压缩备份 (dd+gzip) | 中 (10-20 min) | 高 | 3-7 GB | ⭐⭐⭐⭐⭐ |
| 磁盘工具 (GUI) | 中 (10-20 min) | 高 | 3-7 GB | ⭐⭐⭐⭐ |

### 推荐方案

**最佳方案**: 使用 `dd` + `gzip` 压缩备份
- ✅ 速度快
- ✅ 文件小
- ✅ 稳定可靠
- ✅ 易于恢复

---

## 故障排除

### 问题 1: 无法卸载 SD 卡

```bash
# 强制卸载
sudo diskutil unmountDisk force /dev/disk2

# 或者卸载所有分区
sudo diskutil unmount /dev/disk2s1
sudo diskutil unmount /dev/disk2s2
```

### 问题 2: 权限不足

```bash
# 使用 sudo
sudo dd if=/dev/rdisk2 of=backup.img bs=4m status=progress
```

### 问题 3: 设备忙碌

```bash
# 检查哪个进程在使用设备
sudo lsof | grep disk2

# 或者使用活动监视器查找相关进程
```

### 问题 4: 备份文件损坏

```bash
# 验证备份文件
file backup.img

# 或者验证压缩备份
gunzip -t backup.img.gz
```

---

## 更新日志

- **2024-11-12**: 创建 Mac 直接备份指南
- **2024-11-12**: 添加多种备份方法
- **2024-11-12**: 添加自动化脚本
- **2024-11-12**: 添加恢复方法

---

**最后更新**: 2024-11-12

