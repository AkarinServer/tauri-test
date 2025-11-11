# fbturbo 驱动重新测试 - 1920x1080 分辨率

## 测试目标
- **驱动**: fbturbo
- **分辨率**: 1920x1080 (与 modesetting 相同)
- **桌面环境**: lxqt
- **目的**: 测试 fbturbo 驱动在 1920x1080 分辨率下是否正常工作

---

## 配置更改

### 1. 更新 fbturbo 配置

**文件**: `/etc/X11/xorg.conf.d/10-d1.conf`

**配置内容**:
```conf
Section "ServerLayout"
	Identifier	"Layout0"
	Screen	0	"Screen0"
EndSection

Section "Module"
	Load	"shadow"
EndSection

Section "Device"
	Identifier	"FBDEV"
	Driver		"fbturbo"
	Option		"fbdev" "/dev/fb0"
	Option		"SwapbuffersWait" "true"
	Option		"OffTime" "0"
EndSection

Section "Screen"
	Identifier	"Screen0"
	Device		"FBDEV"
	DefaultDepth	24
	SubSection "Display"
		Depth	24
		Modes	"1920x1080" "1280x720"
	EndSubSection
EndSection
```

### 2. 禁用 modesetting 驱动

```bash
# 备份 modesetting 配置
cp /etc/X11/xorg.conf.d/10-monitor.conf /etc/X11/xorg.conf.d/10-monitor.conf.backup-test

# 禁用 modesetting 配置
mv /etc/X11/xorg.conf.d/10-monitor.conf /etc/X11/xorg.conf.d/10-monitor.conf.disabled-test
```

### 3. 启用 fbturbo 驱动

```bash
# fbturbo 配置已更新并启用
# 文件: /etc/X11/xorg.conf.d/10-d1.conf
```

---

## 测试步骤

### 步骤 1: 配置更新
- ✅ 更新 fbturbo 配置为 1920x1080
- ✅ 禁用 modesetting 驱动
- ✅ 启用 fbturbo 驱动

### 步骤 2: 重启 X server
- ✅ 重启 lightdm
- ✅ 等待 X server 启动

### 步骤 3: 检查驱动状态
- 🔄 检查驱动加载
- 🔄 检查分辨率设置
- 🔄 检查 G2D 状态
- 🔄 检查错误和警告

### 步骤 4: 验证显示
- 🔄 检查显示是否正常
- 🔄 检查桌面环境
- 🔄 检查是否有闪烁

---

## 测试结果

### 驱动加载状态
**状态**: 🔄 测试中

**检查项**:
- 驱动是否成功加载
- 驱动初始化是否成功
- 分辨率是否设置为 1920x1080

### 显示状态
**状态**: 🔄 测试中

**检查项**:
- 显示是否正常
- 是否有闪烁
- 分辨率是否正确

### 桌面环境状态
**状态**: 🔄 测试中

**检查项**:
- lxqt 是否正常启动
- 用户会话是否正常
- 桌面是否可用

### G2D 加速状态
**状态**: 🔄 测试中

**预期结果**:
- G2D 加速不会启用（设备节点不存在）
- 驱动仍然可以工作（软件渲染）

---

## 预期问题

### 可能的问题 1: 屏幕闪烁
**症状**: 屏幕闪烁，无法正常显示

**可能原因**:
- 驱动兼容性问题
- 分辨率配置问题
- 驱动初始化失败

**解决方案**:
- 回滚到 modesetting 驱动
- 检查驱动日志
- 研究驱动兼容性

### 可能的问题 2: 分段错误
**症状**: X server 崩溃，出现分段错误

**可能原因**:
- 驱动与系统不兼容
- 内存访问问题
- 驱动初始化失败

**解决方案**:
- 回滚到 modesetting 驱动
- 检查系统日志
- 研究驱动版本兼容性

### 可能的问题 3: 分辨率问题
**症状**: 分辨率不正确或无法设置

**可能原因**:
- 驱动不支持该分辨率
- 配置格式问题
- 硬件限制

**解决方案**:
- 检查驱动日志
- 尝试其他分辨率
- 检查硬件支持

---

## 回滚方案

### 如果测试失败

```bash
# 1. 禁用 fbturbo 配置
mv /etc/X11/xorg.conf.d/10-d1.conf /etc/X11/xorg.conf.d/10-d1.conf.disabled

# 2. 恢复 modesetting 配置
mv /etc/X11/xorg.conf.d/10-monitor.conf.disabled-test /etc/X11/xorg.conf.d/10-monitor.conf

# 3. 重启 X server
systemctl restart lightdm
```

---

## 配置对比

### modesetting 配置 (工作正常)
```conf
Section "Device"
	Identifier "Card0"
	Driver "modesetting"
EndSection

Section "Screen"
	Identifier "Screen0"
	Device "Card0"
	DefaultDepth 24
	SubSection "Display"
		Depth 24
		Modes "1920x1080" "1280x720"
	EndSubSection
EndSection
```

### fbturbo 配置 (测试中)
```conf
Section "ServerLayout"
	Identifier	"Layout0"
	Screen	0	"Screen0"
EndSection

Section "Module"
	Load	"shadow"
EndSection

Section "Device"
	Identifier	"FBDEV"
	Driver		"fbturbo"
	Option		"fbdev" "/dev/fb0"
	Option		"SwapbuffersWait" "true"
	Option		"OffTime" "0"
EndSection

Section "Screen"
	Identifier	"Screen0"
	Device		"FBDEV"
	DefaultDepth	24
	SubSection "Display"
		Depth	24
		Modes	"1920x1080" "1280x720"
	EndSubSection
EndSection
```

---

## 关键差异

### modesetting vs fbturbo

1. **ServerLayout**: fbturbo 需要 ServerLayout  section
2. **Module**: fbturbo 需要加载 shadow 模块
3. **Device Options**: fbturbo 需要额外的选项（fbdev, SwapbuffersWait, OffTime）
4. **驱动接口**: modesetting 使用 DRM，fbturbo 使用 framebuffer

---

## 更新日志

- **2024-11-12**: 开始重新测试 fbturbo 驱动
- **2024-11-12**: 更新配置为 1920x1080 分辨率
- **2024-11-12**: 禁用 modesetting，启用 fbturbo
- **2024-11-12**: 重启 X server 测试

---

**测试状态**: 🔄 进行中
**最后更新**: 2024-11-12

