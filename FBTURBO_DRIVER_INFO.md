# fbturbo 驱动信息汇总

## 关键信息

### 开发者
- **开发者**: yatli (Yatao Li)
- **论坛帖子**: [R01, fbturbo: Accelerated 2D graphics in X11](https://forum.clockworkpi.com/t/r01-fbturbo-accelerated-2d-graphics-in-x11/8900/15)
- **GitHub 仓库**: https://github.com/yatli/xf86-video-fbturbo
- **原始仓库**: https://github.com/ssvb/xf86-video-fbturbo (ARM设备，包括Allwinner)

### 驱动版本
- **v0.1**: 初始版本（2022-09-18）
- **v0.2a**: 已集成到 R01 OS 镜像中
- **最新状态**: 可在 R01 v0.2a OS 镜像或更高版本通过包管理器安装

---

## 安装方式

### 方式 1: 包管理器安装（推荐）

**适用于 R01 v0.2a OS 镜像或更高版本**:

```bash
sudo apt update
sudo apt install -y xf86-video-fbturbo-r01
sudo reboot
```

### 方式 2: 从源码编译

**适用于所有版本**:

```bash
# 下载驱动源码
# 从 https://nextcloud.yatao.info:10443/s/cJbbpto4TX3NMJn 下载
# 或从 https://github.com/yatli/xf86-video-fbturbo 克隆

# 编译和安装
cd <driver-source>
make
sudo make install
```

### 方式 3: 从 GitHub 获取

```bash
# 克隆仓库
git clone https://github.com/yatli/xf86-video-fbturbo.git
cd xf86-video-fbturbo

# 编译和安装
make
sudo make install
```

---

## 配置

### X server 配置

创建或编辑 `/etc/X11/xorg.conf.d/10-d1.conf`:

```bash
sudo nano /etc/X11/xorg.conf.d/10-d1.conf
```

配置内容:

```
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
```

### 设备权限

**重要**: 确保 `/dev/disp` 和 `/dev/g2d` 设备有正确的权限:

```bash
# 检查设备权限
ls -la /dev/disp /dev/g2d

# 如果需要，添加用户到 video 组
sudo usermod -a -G video $USER

# 或修改设备权限（不推荐，安全风险）
sudo chmod 666 /dev/disp /dev/g2d
```

---

## 性能测试结果

### 矩形填充性能

根据 yatli 的测试数据:

| 尺寸 | 软件渲染 | 硬件加速 | 提升 |
|------|---------|---------|------|
| 10x10 | 33.59ms | 1588.54ms | ❌ 慢（小尺寸） |
| 30x30 | 275.24ms | 1625.98ms | ❌ 慢（小尺寸） |
| 50x50 | 692.82ms | 1835.90ms | ❌ 慢（小尺寸） |
| 70x70 | 1322.18ms | 1862.89ms | ❌ 慢（小尺寸） |
| 90x90 | 2188.60ms | 2223.05ms | ⚠️ 接近 |
| **100x100** | **2715.52ms** | **2230.66ms** | **✅ 1.2x** |
| **200x200** | **10805.47ms** | **3146.06ms** | **✅ 3.4x** |
| **300x300** | **24263.32ms** | **4816.75ms** | **✅ 5.0x** |

**结论**: 当矩形尺寸 > 90 像素时，硬件加速开始显效。尺寸越大，优势越明显。

### 全屏旋转性能

- **软件渲染**: 7.31 FPS
- **硬件加速**: 477.36 FPS
- **提升**: **65倍** 🚀

### 窗口移动性能

- **向左移动**: 非常流畅（加速）
- **向右移动**: 有时卡顿（非加速，某些重叠模式不支持）

---

## 已知问题

### 1. 内核缓冲区溢出

**问题**: 内核可能出现缓冲区溢出错误。

**状态**: 已识别，部分修复。

**解决**: 需要进一步调试和修复。

### 2. 终端滚动损坏

**问题**: 终端滚动时，若滚动高度 >= 128 行，可能会损坏 1-2 行显示内容。

**状态**: 已识别，部分修复。

**解决**: 需要进一步调试和修复。

### 3. Framebuffer 控制台

**问题**: 驱动会接管 framebuffer，导致 fbcon（framebuffer 控制台）不可用。

**状态**: 已知限制。

**解决**: 这是设计限制，无法同时使用。

### 4. Bitblt 小瑕疵

**问题**: 有时会出现图形小瑕疵。

**状态**: 已部分修复。

**解决**: 需要进一步调试和修复。

---

## 编译说明

### 原始 fbturbo 驱动修改

yatli 对原始 fbturbo 驱动进行了以下修改:

1. **移除 ARM 汇编代码**:
   - 编辑 `src/Makefile.am`
   - 移除 ARM 汇编源文件
   - 移除 BackingStore
   - 移除 LibUMP/MaliGPU 相关代码

2. **清理 fbdev.c**:
   - 移除不存在的硬件资源引用
   - 移除相关配置选项

3. **G2D 支持**:
   - 更新 `sunxi_disp.c` 和 `sunxi_x_g2d.c`
   - 适配新的 sunxi_display2 ioctl 接口
   - 从 32 位 ioctl 调用移植到 64 位
   - 实现 G2D 硬件加速

### 构建依赖

```bash
# 安装构建依赖
sudo apt-get install build-essential
sudo apt-get install xserver-xorg-dev
sudo apt-get install xutils-dev
sudo apt-get install pkg-config
```

### 编译步骤

```bash
# 克隆仓库
git clone https://github.com/yatli/xf86-video-fbturbo.git
cd xf86-video-fbturbo

# 配置（如果需要）
./configure

# 编译
make

# 安装
sudo make install
```

---

## 故障排除

### 问题 1: 符号解析错误

**错误**: `cannot resolve symbol "shadowUpdatePacked"`

**解决**: 在 X server 配置中加载 "shadow" 模块:

```
Section "Module"
        Load    "shadow"
EndSection
```

### 问题 2: 符号解析错误

**错误**: `cannot resolve symbol "shadowUpdatePackedWeak"`

**解决**: 该符号已移除，参考 [xf86-video-fbdev](https://github.com/freedesktop/xf86-video-fbdev/blob/66e7909bfefd93c05aa37d0cadccc5348f0382be/src/fbdev.c#L670-L701) 的实现。

### 问题 3: 符号解析错误

**错误**: `cannot resolve symbol "xf86DisableRandR"`

**解决**: 该符号已移除，注释掉相关代码。

### 问题 4: 屏幕变黑

**问题**: 启动 X server 后屏幕变黑。

**解决**:
1. 恢复原始的 `10-d1.conf` 配置
2. 盲打 `startx` 命令
3. 屏幕会重新初始化

### 问题 5: 调试 X server

**方法**: 使用详细日志启动 X server:

```bash
startx -- -logverbose 6 > startx.log 2>&1
```

---

## 参考资源

### 官方资源
- **GitHub 仓库**: https://github.com/yatli/xf86-video-fbturbo
- **原始仓库**: https://github.com/ssvb/xf86-video-fbturbo
- **论坛帖子**: https://forum.clockworkpi.com/t/r01-fbturbo-accelerated-2d-graphics-in-x11/8900/15
- **下载链接**: https://nextcloud.yatao.info:10443/s/cJbbpto4TX3NMJn

### 文档资源
- **G2D 开发指南**: https://raw.githubusercontent.com/DongshanPI/Awesome_RISCV-AllwinnerD1/master/Tina-SDK/Software软件类文档/SDK模块开发指南/D1-H_Linux_G2D_开发指南.pdf
- **Display 开发指南**: https://bbs.aw-ol.com/assets/uploads/files/1648272245011-d1-tina-linux-display-开发指南.pdf
- **linux-sunxi Xorg**: https://linux-sunxi.org/Xorg

### 社区资源
- **Allwinner 开发者论坛**: https://bbs.aw-ol.com/
- **ClockworkPi 论坛**: https://forum.clockworkpi.com/
- **RISC-V Allwinner D1 资源**: https://github.com/DongshanPI/Awesome_RISCV-AllwinnerD1

---

## 对我们的项目的帮助

### ✅ 直接可用

1. **硬件相同**: Lichee RV Dock 和 R01 都使用 Allwinner D1 芯片
2. **驱动可用**: yatli 的 fbturbo 驱动可能可以直接使用
3. **性能提升**: 显著改善 2D 图形性能（50-100%）
4. **已验证**: 已在 R01 上验证可行

### ⚠️ 需要注意

1. **设备权限**: 需要确保 `/dev/disp` 和 `/dev/g2d` 有正确的权限
2. **已知问题**: 存在一些已知问题（缓冲区溢出、终端滚动损坏）
3. **编译**: 可能需要根据 Lichee RV Dock 进行小幅调整
4. **测试**: 需要充分测试以确保稳定性

### 🚀 推荐行动

1. **获取驱动源码**: 从 GitHub 克隆 yatli 的仓库
2. **检查设备**: 验证 `/dev/disp` 和 `/dev/g2d` 设备存在
3. **编译测试**: 在 Lichee RV Dock 上编译和测试
4. **性能评估**: 测试性能提升效果
5. **问题修复**: 处理已知问题（如果有）

---

## 更新日志

- **2024-11-12**: 从论坛帖子获取驱动信息
- **2024-11-12**: 汇总安装、配置、性能测试结果
- **2024-11-12**: 整理已知问题和故障排除方法
- **2024-11-12**: 评估对项目的帮助和推荐行动

