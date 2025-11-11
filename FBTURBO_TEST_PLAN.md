# fbturbo 驱动测试计划

## 安装状态

### ✅ 已完成

1. **驱动安装**:
   - 驱动模块: `/usr/lib/xorg/modules/drivers/fbturbo_drv.so`
   - 文件大小: 269352 bytes (263 KB)
   - 架构: RISC-V 64-bit
   - 权限: 644 (可读)

2. **配置安装**:
   - 配置文件: `/etc/X11/xorg.conf.d/10-d1.conf`
   - 分辨率: 2560x1600 (适配 Lichee RV Dock)
   - 旋转: 已禁用 (注释掉 CW 旋转)
   - 权限: 644 (可读)

3. **依赖检查**:
   - Shadow 模块: ✅ 可用
   - Framebuffer: ✅ `/dev/fb0` 存在
   - 驱动依赖: ✅ 只依赖 libc

### ⚠️ 已知问题

1. **设备节点缺失**:
   - `/dev/disp` - 不存在
   - `/dev/g2d` - 不存在

2. **预期行为**:
   - 驱动可以加载和工作
   - G2D 硬件加速不会启用
   - 性能与当前 modesetting 驱动类似

---

## 测试步骤

### 步骤 1: 备份当前状态

```bash
# 备份 X server 日志
sudo cp /var/log/Xorg.0.log /var/log/Xorg.0.log.backup

# 备份当前配置
sudo cp /etc/X11/xorg.conf.d/10-d1.conf /etc/X11/xorg.conf.d/10-d1.conf.test
```

### 步骤 2: 重启 X server

**方法 1: 重启 lightdm (推荐)**:
```bash
sudo systemctl restart lightdm
```

**方法 2: 重启系统**:
```bash
sudo reboot
```

**方法 3: 从远程会话测试** (如果可能):
```bash
# 在另一个终端或 SSH 会话中
sudo systemctl restart lightdm
```

### 步骤 3: 检查驱动状态

**检查 X server 日志**:
```bash
# 查看驱动加载消息
tail -100 /var/log/Xorg.0.log | grep -iE "fbturbo|g2d|disp"

# 查看错误消息
tail -100 /var/log/Xorg.0.log | grep -iE "error|fail|warning" | grep -iE "fbturbo|g2d|disp"

# 查看完整的驱动相关消息
grep -iE "fbturbo|g2d|disp" /var/log/Xorg.0.log | tail -20
```

**使用测试脚本**:
```bash
# 运行检查脚本
/tmp/check-fbturbo-after-restart.sh
```

### 步骤 4: 验证驱动功能

**检查驱动是否加载**:
```bash
# 查找驱动加载消息
grep -i "Loading.*fbturbo\|fbturbo.*loaded" /var/log/Xorg.0.log
```

**检查 G2D 加速状态**:
```bash
# 查找 G2D 相关消息
grep -i "G2D.*acceleration\|g2d.*enabled\|g2d.*disabled" /var/log/Xorg.0.log
```

**预期消息**:
- 如果设备节点存在: `enabled G2D acceleration`
- 如果设备节点不存在: `No sunxi-g2d hardware detected (check /dev/disp and /dev/g2d)`

### 步骤 5: 测试性能

**测试窗口移动**:
- 打开一个窗口
- 拖动窗口移动
- 观察是否流畅

**测试滚动**:
- 打开一个可以滚动的内容
- 滚动内容
- 观察是否流畅

**测试应用启动**:
- 启动 Tauri 应用
- 观察启动时间
- 对比之前的性能

---

## 预期结果

### 场景 1: 驱动正常加载，G2D 加速未启用

**X server 日志消息**:
```
[    XXX] (II) Loading /usr/lib/xorg/modules/drivers/fbturbo_drv.so
[    XXX] (II) fbturbo: FBDevScreenInit
[    XXX] (II) No sunxi-g2d hardware detected (check /dev/disp and /dev/g2d)
[    XXX] (II) G2D hardware acceleration can't be enabled
[    XXX] (II) fbturbo: FBDevScreenInit done
```

**行为**:
- 驱动正常加载
- 显示正常工作
- 性能与当前驱动类似
- 没有 G2D 硬件加速

### 场景 2: 驱动正常加载，G2D 加速启用 (如果设备节点存在)

**X server 日志消息**:
```
[    XXX] (II) Loading /usr/lib/xorg/modules/drivers/fbturbo_drv.so
[    XXX] (II) fbturbo: FBDevScreenInit
[    XXX] (II) enabled G2D acceleration
[    XXX] (II) fbturbo: FBDevScreenInit done
```

**行为**:
- 驱动正常加载
- G2D 硬件加速启用
- 性能显著提升
- 窗口移动和滚动更流畅

### 场景 3: 驱动加载失败

**X server 日志消息**:
```
[    XXX] (EE) Failed to load module "fbturbo"
[    XXX] (EE) Module fbturbo does not exist
```

**行为**:
- 驱动无法加载
- X server 可能无法启动
- 需要检查驱动文件和配置

---

## 故障排除

### 问题 1: 驱动无法加载

**检查**:
```bash
# 检查驱动文件
ls -la /usr/lib/xorg/modules/drivers/fbturbo_drv.so

# 检查驱动依赖
ldd /usr/lib/xorg/modules/drivers/fbturbo_drv.so

# 检查配置文件
cat /etc/X11/xorg.conf.d/10-d1.conf
```

**解决方案**:
- 检查驱动文件权限
- 检查驱动依赖
- 检查配置文件语法

### 问题 2: X server 无法启动

**检查**:
```bash
# 查看完整日志
tail -200 /var/log/Xorg.0.log

# 查看错误消息
grep -i "error\|fail" /var/log/Xorg.0.log | tail -20
```

**解决方案**:
- 恢复备份的配置
- 检查配置文件语法
- 检查驱动兼容性

### 问题 3: 显示异常

**检查**:
```bash
# 检查分辨率
cat /sys/class/graphics/fb0/virtual_size

# 检查配置中的分辨率
grep -i "Modes" /etc/X11/xorg.conf.d/10-d1.conf
```

**解决方案**:
- 修改配置文件中的分辨率
- 或移除 Modes 选项，让系统自动检测

---

## 回滚步骤

### 如果测试失败

```bash
# 恢复备份的配置
sudo cp /etc/X11/xorg.conf.d/10-d1.conf.backup /etc/X11/xorg.conf.d/10-d1.conf

# 移除驱动
sudo rm /usr/lib/xorg/modules/drivers/fbturbo_drv.so

# 重启 X server
sudo systemctl restart lightdm
```

### 如果无法启动 X server

```bash
# 从另一个终端或 SSH 会话
# 恢复配置
sudo cp /etc/X11/xorg.conf.d/10-d1.conf.backup /etc/X11/xorg.conf.d/10-d1.conf

# 移除驱动
sudo rm /usr/lib/xorg/modules/drivers/fbturbo_drv.so

# 重启系统
sudo reboot
```

---

## 下一步

### 如果驱动工作但没有 G2D 加速

1. **分析设备节点问题**:
   - 研究如何创建 `/dev/disp` 和 `/dev/g2d` 设备节点
   - 或开发适配层

2. **开发适配方案**:
   - 创建用户空间适配层
   - 或修改驱动以支持 DRM 接口

3. **测试适配方案**:
   - 测试适配层
   - 验证 G2D 加速是否启用

### 如果驱动工作且有 G2D 加速

1. **测试性能**:
   - 测试性能提升效果
   - 对比之前的性能

2. **优化配置**:
   - 优化驱动配置
   - 调整性能参数

3. **文档化**:
   - 记录配置和性能数据
   - 更新文档

---

## 参考资源

### 驱动资源
- **预编译包**: fbturbo-r01-alpha
- **源码仓库**: https://github.com/yatli/xf86-video-fbturbo
- **下载链接**: https://nextcloud.yatao.info:10443/s/cJbbpto4TX3NMJn

### 文档资源
- **论坛帖子**: https://forum.clockworkpi.com/t/r01-fbturbo-accelerated-2d-graphics-in-x11/8900/15
- **安装指南**: FBTURBO_INSTALLATION_GUIDE.md

---

## 更新日志

- **2024-11-12**: 创建测试计划
- **2024-11-12**: 安装驱动和配置
- **2024-11-12**: 准备测试步骤

---

## 测试检查清单

### 安装前
- [ ] 备份现有配置
- [ ] 备份 X server 日志
- [ ] 检查系统状态

### 安装后
- [ ] 验证驱动文件
- [ ] 验证配置文件
- [ ] 检查依赖
- [ ] 检查设备节点

### 测试
- [ ] 重启 X server
- [ ] 检查驱动加载
- [ ] 检查 G2D 加速状态
- [ ] 测试性能
- [ ] 检查错误消息

### 回滚（如果需要）
- [ ] 恢复配置
- [ ] 移除驱动
- [ ] 重启 X server
- [ ] 验证系统恢复

---

**测试状态**: 准备就绪，等待测试
**测试日期**: 2024-11-12

