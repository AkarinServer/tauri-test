# SD 卡系统备份指南

## 备份方法概述

对于 Lichee RV Dock 的 SD 卡系统备份，有以下几种方法：

### 方法 1: 使用 `dd` 创建完整磁盘映像（推荐）
- **优点**: 完整备份，包括引导扇区、分区表等
- **缺点**: 备份文件大小等于 SD 卡大小（即使使用空间很少）
- **适用**: 需要完整系统恢复

### 方法 2: 使用 `dd` + `gzip` 压缩备份
- **优点**: 压缩后文件较小，节省存储空间
- **缺点**: 恢复时需要解压
- **适用**: 节省存储空间

### 方法 3: 通过网络备份到 macOS
- **优点**: 直接备份到本地 Mac，无需额外存储设备
- **缺点**: 需要网络传输，速度较慢
- **适用**: 没有额外存储设备时

### 方法 4: 文件系统级别备份（rsync）
- **优点**: 只备份使用的空间，文件较小
- **缺点**: 不包含引导扇区，需要手动恢复引导
- **适用**: 只需要备份文件系统

---

## 方法 1: 完整磁盘映像备份（推荐）

### 在 RV Dock 上备份（如果有足够的存储空间）

```bash
# 1. 确认 SD 卡设备（通常是 /dev/mmcblk0）
sudo fdisk -l

# 2. 创建完整备份（未压缩）
sudo dd if=/dev/mmcblk0 of=/path/to/backup.img bs=4M status=progress

# 3. 验证备份
sudo dd if=/path/to/backup.img of=/dev/null bs=4M status=progress
```

### 通过网络备份到 macOS

```bash
# 在 macOS 上执行
ssh root@192.168.31.145 "dd if=/dev/mmcblk0 bs=4M status=progress" | dd of=~/lichee-rv-dock-backup.img

# 或者使用压缩（节省空间和传输时间）
ssh root@192.168.31.145 "dd if=/dev/mmcblk0 bs=4M status=progress | gzip -c" | dd of=~/lichee-rv-dock-backup.img.gz
```

---

## 方法 2: 压缩备份（节省空间）

### 在 RV Dock 上压缩备份

```bash
# 1. 创建压缩备份
sudo dd if=/dev/mmcblk0 bs=4M status=progress | gzip -c > /path/to/backup.img.gz

# 2. 验证备份
gunzip -c /path/to/backup.img.gz | dd of=/dev/null bs=4M status=progress
```

### 通过网络压缩备份到 macOS

```bash
# 在 macOS 上执行（推荐）
ssh root@192.168.31.145 "dd if=/dev/mmcblk0 bs=4M status=progress | gzip -c" > ~/lichee-rv-dock-backup.img.gz
```

---

## 方法 3: 使用 pv 显示进度（推荐）

### 安装 pv（如果未安装）

```bash
# 在 RV Dock 上
sudo apt-get update
sudo apt-get install -y pv
```

### 使用 pv 备份

```bash
# 在 RV Dock 上
sudo dd if=/dev/mmcblk0 bs=4M | pv -s $(blockdev --getsize64 /dev/mmcblk0) | gzip -c > backup.img.gz

# 通过网络备份到 macOS
ssh root@192.168.31.145 "dd if=/dev/mmcblk0 bs=4M | pv -s \$(blockdev --getsize64 /dev/mmcblk0) | gzip -c" > ~/lichee-rv-dock-backup.img.gz
```

---

## 方法 4: 文件系统级别备份（rsync）

### 备份到外部存储

```bash
# 1. 挂载外部存储（USB 设备等）
sudo mount /dev/sda1 /mnt/backup

# 2. 使用 rsync 备份
sudo rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /mnt/backup/

# 3. 卸载
sudo umount /mnt/backup
```

---

## 恢复方法

### 从完整磁盘映像恢复

```bash
# 1. 在 macOS 上
# 插入 SD 卡，找到设备（通常是 /dev/disk2 或 /dev/rdisk2）

# 2. 卸载 SD 卡
diskutil unmountDisk /dev/disk2

# 3. 恢复备份（未压缩）
sudo dd if=~/lichee-rv-dock-backup.img of=/dev/rdisk2 bs=4M status=progress

# 4. 恢复备份（压缩）
gunzip -c ~/lichee-rv-dock-backup.img.gz | sudo dd of=/dev/rdisk2 bs=4M status=progress

# 5. 弹出 SD 卡
diskutil eject /dev/disk2
```

### 从文件系统备份恢复

```bash
# 1. 创建新的 SD 卡系统
# 2. 挂载 SD 卡
# 3. 使用 rsync 恢复
sudo rsync -aAXv /mnt/backup/ /mnt/sdcard/
```

---

## 自动化备份脚本

### 在 macOS 上创建备份脚本

```bash
#!/bin/bash
# backup-lichee-rv-dock.sh

# 配置
HOST="root@192.168.31.145"
DEVICE="/dev/mmcblk0"
BACKUP_DIR="$HOME/backups/lichee-rv-dock"
BACKUP_FILE="lichee-rv-dock-$(date +%Y%m%d-%H%M%S).img.gz"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 备份
echo "Starting backup..."
ssh "$HOST" "dd if=$DEVICE bs=4M status=progress | gzip -c" > "$BACKUP_DIR/$BACKUP_FILE"

# 验证备份
if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo "Backup completed: $BACKUP_DIR/$BACKUP_FILE"
    ls -lh "$BACKUP_DIR/$BACKUP_FILE"
else
    echo "Backup failed!"
    exit 1
fi
```

### 在 RV Dock 上创建备份脚本

```bash
#!/bin/bash
# backup-system.sh

# 配置
DEVICE="/dev/mmcblk0"
BACKUP_DIR="/home/ubuntu/backups"
BACKUP_FILE="system-backup-$(date +%Y%m%d-%H%M%S).img.gz"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 备份
echo "Starting backup..."
sudo dd if=$DEVICE bs=4M status=progress | gzip -c > "$BACKUP_DIR/$BACKUP_FILE"

# 验证备份
if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo "Backup completed: $BACKUP_DIR/$BACKUP_FILE"
    ls -lh "$BACKUP_DIR/$BACKUP_FILE"
else
    echo "Backup failed!"
    exit 1
fi
```

---

## 注意事项

### 1. 备份前检查
- ✅ 确认 SD 卡设备路径（通常是 `/dev/mmcblk0`）
- ✅ 确认有足够的存储空间
- ✅ 确认系统未在使用中（最好在单用户模式）

### 2. 备份时注意
- ⚠️ 备份过程中不要断开连接
- ⚠️ 备份文件大小可能很大（SD 卡大小）
- ⚠️ 压缩可以显著减小文件大小

### 3. 恢复时注意
- ⚠️ 恢复会覆盖 SD 卡上的所有数据
- ⚠️ 确认 SD 卡设备路径正确
- ⚠️ 恢复前备份 SD 卡上的重要数据

### 4. 存储建议
- 💾 备份文件可以存储在外部硬盘
- 💾 可以创建多个备份（不同时间点）
- 💾 定期验证备份文件完整性

---

## 备份文件大小估算

### 典型 SD 卡大小
- **16GB SD 卡**: 备份文件约 16GB（未压缩）或 4-8GB（压缩）
- **32GB SD 卡**: 备份文件约 32GB（未压缩）或 8-16GB（压缩）
- **64GB SD 卡**: 备份文件约 64GB（未压缩）或 16-32GB（压缩）

### 压缩率
- 典型压缩率: 50-70%（取决于数据内容）
- 已使用的空间: 压缩率更高
- 未使用的空间: 压缩率较低

---

## 验证备份完整性

### 方法 1: 计算校验和

```bash
# 创建备份时计算校验和
ssh root@192.168.31.145 "dd if=/dev/mmcblk0 bs=4M | sha256sum" > backup.sha256

# 验证备份
sha256sum -c backup.sha256
```

### 方法 2: 验证备份文件

```bash
# 验证压缩备份
gunzip -t backup.img.gz

# 验证磁盘映像
file backup.img
```

---

## 推荐方案

### 对于当前情况（通过网络备份）

**推荐**: 使用方法 2（压缩备份）+ 方法 3（pv 显示进度）

```bash
# 在 macOS 上执行
ssh root@192.168.31.145 "dd if=/dev/mmcblk0 bs=4M | pv -s \$(blockdev --getsize64 /dev/mmcblk0) | gzip -c" > ~/lichee-rv-dock-backup.img.gz
```

**优点**:
- 直接备份到 Mac
- 压缩节省空间
- 显示进度
- 完整备份

---

## 更新日志

- **2024-11-12**: 创建 SD 卡备份指南
- **2024-11-12**: 添加多种备份方法
- **2024-11-12**: 添加恢复方法
- **2024-11-12**: 添加自动化脚本

---

**最后更新**: 2024-11-12

