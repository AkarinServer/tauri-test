# 性能优化实施记录

## 第一阶段优化（已实施）

### 实施时间
2024年（通过 SSH 远程实施）

### 实施的方案

#### ✅ 方案 1: 软件渲染优化

**文件**: `/home/ubuntu/start-tauri.sh`

**内容**:
```bash
#!/bin/bash
# Tauri 应用启动脚本 - 优化软件渲染性能
# 强制使用软件渲染，消除 EGL 警告

export LIBGL_ALWAYS_SOFTWARE=1
export MESA_GL_VERSION_OVERRIDE=3.3
export GALLIUM_DRIVER=llvmpipe
export MESA_GLSL_VERSION_OVERRIDE=330
export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe

# 运行应用
tauri-riscv64-test "$@"
```

**使用方法**:
```bash
# 使用优化后的脚本启动应用
~/start-tauri.sh

# 或者创建桌面快捷方式
```

**预期效果**:
- ✅ 消除 EGL 警告
- ⚡ 启动时间减少 10-20%
- 📈 运行性能略微提升

---

#### ✅ 方案 3: 内存管理优化

**配置文件**: `/etc/sysctl.conf`

**添加的参数**:
```
vm.swappiness=10        # 减少 Swap 使用（从默认 60 降低到 10）
vm.vfs_cache_pressure=50  # 优化缓存策略（从默认 100 降低到 50）
```

**生效方式**:
- 已立即应用: `sysctl -p /etc/sysctl.conf`
- 永久生效: 系统重启后自动应用

**预期效果**:
- 📈 应用响应速度提升
- 📉 减少内存交换
- ⚡ 减少卡顿

---

## 验证步骤

### 1. 验证启动脚本
```bash
# 在 Lichee RV Dock 上执行
ls -la ~/start-tauri.sh
cat ~/start-tauri.sh
```

### 2. 验证内存管理配置
```bash
# 检查当前配置
sysctl vm.swappiness vm.vfs_cache_pressure

# 应该显示:
# vm.swappiness = 10
# vm.vfs_cache_pressure = 50
```

### 3. 测试应用启动
```bash
# 使用优化后的脚本启动
~/start-tauri.sh

# 观察:
# - 是否还有 EGL 警告
# - 启动时间是否减少
# - 运行是否更流畅
```

---

## 性能对比

### 优化前
- **EGL 警告**: ✅ 存在
- **启动时间**: 20-30 秒
- **内存交换**: 频繁（swappiness=60）
- **运行性能**: 基础性能

### 优化后（预期）
- **EGL 警告**: ❌ 消除
- **启动时间**: 15-25 秒（减少 10-20%）
- **内存交换**: 减少（swappiness=10）
- **运行性能**: 提升 10-20%

---

## 回滚方法

如果优化后出现问题，可以回滚：

### 回滚内存管理优化
```bash
# 恢复备份的配置
sudo cp /etc/sysctl.conf.backup.* /etc/sysctl.conf

# 重新加载配置
sudo sysctl -p /etc/sysctl.conf
```

### 回滚启动脚本
```bash
# 直接使用原命令启动
tauri-riscv64-test
```

---

## 第二阶段优化（已实施）

### 实施时间
2024年（通过 SSH 远程实施）

### 实施的方案

#### ✅ 方案 2: 系统服务优化

**禁用的服务**:
- `avahi-daemon.service`: 网络发现服务（通常不需要）
- `cups.service`: 打印服务（如果没有打印机）

**效果**:
- 📉 减少内存占用
- ⚡ 减少系统启动时间
- 📈 释放系统资源

#### ✅ 方案 4: I/O 优化

**内核参数优化** (`/etc/sysctl.conf`):
```
vm.dirty_ratio = 15              # 减少脏页比例（默认 20）
vm.dirty_background_ratio = 5    # 减少后台脏页比例（默认 10）
vm.dirty_expire_centisecs = 3000 # 优化脏页过期时间（默认 3000）
```

**文件描述符限制** (`/etc/security/limits.conf`):
```
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
```

**效果**:
- ⚡ I/O 性能提升
- 📈 减少 I/O 等待时间
- 🚀 提升应用响应速度

---

## 下一步

### 第三阶段优化（可选）
1. **方案 8**: 应用层面优化

---

## 注意事项

1. **备份已创建**: `/etc/sysctl.conf.backup.*`
2. **权限正确**: 启动脚本属于 ubuntu 用户
3. **立即生效**: 内存管理优化已立即应用
4. **永久生效**: 系统重启后配置仍然有效

---

## 测试建议

1. **启动时间测试**: 记录优化前后的启动时间
2. **内存使用测试**: 观察内存交换频率
3. **运行性能测试**: 测试应用响应速度
4. **稳定性测试**: 长时间运行测试稳定性

---

## 问题反馈

如果遇到问题，请检查：
1. 启动脚本权限是否正确
2. 内存管理配置是否正确应用
3. 系统日志是否有错误信息
4. 应用是否能正常启动

