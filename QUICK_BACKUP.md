# 快速备份命令

## 最简单的方法（推荐）

### 在 macOS 上执行：

```bash
# 创建备份目录
mkdir -p ~/backups/lichee-rv-dock

# 备份到 Mac（压缩，显示进度）
ssh root@192.168.31.145 "dd if=/dev/mmcblk0 bs=4M status=progress | gzip -c" > ~/backups/lichee-rv-dock/lichee-rv-dock-backup-$(date +%Y%m%d-%H%M%S).img.gz
```

### 或者使用自动化脚本：

```bash
cd /Users/lolotachibana/dev/tauri-test
./backup-lichee-rv-dock.sh
```

## 预计时间和空间

- **SD 卡大小**: 29.7 GB
- **预计备份文件大小**: 约 3-7 GB（压缩后，取决于数据）
- **预计备份时间**: 10-30 分钟（取决于网络速度）
- **备份位置**: `~/backups/lichee-rv-dock/`

## 恢复方法

### 在 macOS 上恢复：

```bash
# 1. 插入 SD 卡，找到设备（通常是 /dev/disk2 或 /dev/rdisk2）
diskutil list

# 2. 卸载 SD 卡
diskutil unmountDisk /dev/disk2

# 3. 恢复备份
gunzip -c ~/backups/lichee-rv-dock/lichee-rv-dock-backup-*.img.gz | sudo dd of=/dev/rdisk2 bs=4M status=progress

# 4. 弹出 SD 卡
diskutil eject /dev/disk2
```

## 注意事项

⚠️ **备份期间**:
- 不要断开 SSH 连接
- 不要关闭 RV Dock
- 确保 Mac 有足够的磁盘空间（至少 10GB）

⚠️ **恢复期间**:
- 会覆盖 SD 卡上的所有数据
- 确认 SD 卡设备路径正确
- 恢复前备份 SD 卡上的重要数据
