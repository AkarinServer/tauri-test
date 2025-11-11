# fbturbo 驱动安装指南

## 预编译驱动包分析

### 包信息

**文件**: `fbturbo-r01-alpha/`

**关键发现**:
- ✅ **RISC-V 架构**: 驱动是为 RISC-V 架构编译的，可以在 Lichee RV Dock 上运行
- ✅ **架构匹配**: `ELF 64-bit LSB shared object, UCB RISC-V, RVC, double-float ABI`
- ✅ **依赖简单**: 只依赖 libc，无额外依赖
- ✅ **包含配置**: 包含完整的 X server 配置文件

### 驱动字符串分析

从驱动二进制文件中提取的字符串显示：

```
enabled G2D acceleration
No sunxi-g2d hardware detected (check /dev/disp and /dev/g2d)
G2D hardware acceleration can't be enabled
failed to enable the use of sunxi display controller
sunxi_disp_init: begin
```

**关键信息**:
- 驱动支持 G2D 硬件加速
- 需要 `/dev/disp` 和 `/dev/g2d` 设备节点
- 如果设备节点不存在，驱动仍然可以工作，但没有 G2D 加速

---

## 安装步骤

### 步骤 1: 备份现有配置

```bash
# 备份现有的 X server 配置
sudo cp /etc/X11/xorg.conf.d/10-d1.conf /etc/X11/xorg.conf.d/10-d1.conf.backup 2>/dev/null || echo "No existing config"
```

### 步骤 2: 安装驱动模块

```bash
# 复制驱动模块到 X server 模块目录
sudo mkdir -p /usr/lib/xorg/modules/drivers
sudo cp fbturbo-r01-alpha/.libs/fbturbo_drv.so /usr/lib/xorg/modules/drivers/
sudo chmod 644 /usr/lib/xorg/modules/drivers/fbturbo_drv.so
```

### 步骤 3: 安装配置文件

```bash
# 复制配置文件
sudo mkdir -p /etc/X11/xorg.conf.d
sudo cp fbturbo-r01-alpha/10-d1.conf /etc/X11/xorg.conf.d/
sudo chmod 644 /etc/X11/xorg.conf.d/10-d1.conf
```

### 步骤 4: 修改配置（如果需要）

**检查显示分辨率**:

```bash
# 检查当前显示分辨率
cat /sys/class/graphics/fb0/virtual_size
```

**修改配置文件** (如果分辨率不匹配):

编辑 `/etc/X11/xorg.conf.d/10-d1.conf`，修改 `Modes` 行：

```conf
Subsection "Display"
    Depth 24
    Modes "2560x1600" "1600x2560"  # 根据实际分辨率修改
EndSubsection
```

### 步骤 5: 检查依赖

```bash
# 检查 shadow 模块
find /usr/lib/xorg/modules -name '*shadow*'

# 检查驱动依赖
ldd /usr/lib/xorg/modules/drivers/fbturbo_drv.so
```

### 步骤 6: 重启 X server

```bash
# 重启 X server
sudo systemctl restart lightdm
# 或
sudo reboot
```

---

## 配置文件说明

### 10-d1.conf

```conf
Section "Module"
    Load    "shadow"
EndSection

Section "Device"
    Identifier      "FBDEV"
    Driver          "fbturbo"
    Option          "fbdev" "/dev/fb0"

    Option          "SwapbuffersWait" "true"
    Option          "OffTime" "0"
    Option          "Rotate" "CW"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device "FBDEV"
    DefaultDepth 24

    Subsection "Display"
        Depth 24
        Modes "1280x480" "480x1280"
    EndSubsection
EndSection
```

**配置选项说明**:
- `Load "shadow"` - 加载 shadow 模块（必需）
- `Driver "fbturbo"` - 使用 fbturbo 驱动
- `Option "fbdev" "/dev/fb0"` - 使用 /dev/fb0 framebuffer
- `Option "SwapbuffersWait" "true"` - 启用 VSYNC
- `Option "OffTime" "0"` - 禁用屏幕关闭
- `Option "Rotate" "CW"` - 顺时针旋转（可根据需要修改）
- `Modes` - 显示模式（需要根据实际分辨率修改）

---

## 测试步骤

### 步骤 1: 检查安装

```bash
# 检查驱动是否安装
ls -la /usr/lib/xorg/modules/drivers/fbturbo_drv.so

# 检查配置是否安装
ls -la /etc/X11/xorg.conf.d/10-d1.conf
```

### 步骤 2: 检查设备节点

```bash
# 检查设备节点
ls -la /dev/disp /dev/g2d

# 如果不存在，驱动仍然可以工作，但没有 G2D 加速
```

### 步骤 3: 检查 X server 日志

```bash
# 查看 X server 日志
tail -f /var/log/Xorg.0.log

# 查找相关消息
grep -iE "fbturbo|g2d|disp" /var/log/Xorg.0.log
```

### 步骤 4: 测试性能

```bash
# 测试窗口移动性能
# 测试滚动性能
# 测试应用启动时间
```

---

## 预期行为

### 如果设备节点存在

**预期消息**:
```
enabled G2D acceleration
```

**行为**:
- G2D 硬件加速启用
- 窗口移动流畅
- 滚动性能提升
- 全屏旋转加速

### 如果设备节点不存在

**预期消息**:
```
No sunxi-g2d hardware detected (check /dev/disp and /dev/g2d)
G2D hardware acceleration can't be enabled
```

**行为**:
- 驱动仍然可以工作
- 使用软件渲染
- 性能与当前 modesetting 驱动类似
- 没有 G2D 硬件加速

---

## 故障排除

### 问题 1: 驱动无法加载

**症状**: X server 无法启动

**检查**:
```bash
# 检查驱动文件权限
ls -la /usr/lib/xorg/modules/drivers/fbturbo_drv.so

# 检查 X server 日志
tail -50 /var/log/Xorg.0.log
```

**解决方案**:
- 检查驱动文件权限
- 检查驱动依赖
- 检查配置文件语法

### 问题 2: G2D 加速未启用

**症状**: 日志显示 "No sunxi-g2d hardware detected"

**检查**:
```bash
# 检查设备节点
ls -la /dev/disp /dev/g2d

# 检查 G2D 时钟
ls -la /sys/kernel/debug/clk/g2d
```

**解决方案**:
- 设备节点不存在，需要创建适配层
- 或修改驱动以支持 DRM 接口

### 问题 3: 显示分辨率不正确

**症状**: 显示异常或分辨率不匹配

**检查**:
```bash
# 检查实际分辨率
cat /sys/class/graphics/fb0/virtual_size

# 检查配置中的分辨率
grep -i "Modes" /etc/X11/xorg.conf.d/10-d1.conf
```

**解决方案**:
- 修改配置文件中的分辨率
- 或移除 Modes 选项，让系统自动检测

### 问题 4: Shadow 模块未找到

**症状**: X server 无法加载 shadow 模块

**检查**:
```bash
# 查找 shadow 模块
find /usr/lib/xorg/modules -name '*shadow*'
```

**解决方案**:
- 安装缺失的 X server 模块
- 或修改配置，移除 shadow 模块（不推荐）

---

## 回滚步骤

### 如果安装失败

```bash
# 恢复备份的配置
sudo cp /etc/X11/xorg.conf.d/10-d1.conf.backup /etc/X11/xorg.conf.d/10-d1.conf

# 移除驱动
sudo rm /usr/lib/xorg/modules/drivers/fbturbo_drv.so

# 重启 X server
sudo systemctl restart lightdm
```

---

## 下一步

### 如果驱动工作但没有 G2D 加速

1. **检查设备节点**: 确认 `/dev/disp` 和 `/dev/g2d` 是否存在
2. **研究适配方案**: 研究如何创建设备节点或适配层
3. **开发解决方案**: 开发适配方案以启用 G2D 加速

### 如果驱动工作且有 G2D 加速

1. **测试性能**: 测试性能提升效果
2. **优化配置**: 优化驱动配置
3. **文档化**: 记录配置和性能数据

---

## 参考资源

### 驱动资源
- **预编译包**: fbturbo-r01-alpha
- **源码仓库**: https://github.com/yatli/xf86-video-fbturbo
- **下载链接**: https://nextcloud.yatao.info:10443/s/cJbbpto4TX3NMJn

### 文档资源
- **论坛帖子**: https://forum.clockworkpi.com/t/r01-fbturbo-accelerated-2d-graphics-in-x11/8900/15
- **配置文档**: 10-d1.conf

---

## 更新日志

- **2024-11-12**: 分析预编译驱动包
- **2024-11-12**: 确认驱动为 RISC-V 架构
- **2024-11-12**: 创建安装指南
- **2024-11-12**: 准备测试安装

