# 构建问题修复记录

## 问题 1: `sudo: command not found`

**错误**: 容器中找不到 `sudo` 命令

**原因**: `run-on-arch-action` 在容器中以 root 用户运行，不需要 `sudo`

**修复**: 移除所有 `sudo` 命令

**提交**: `f6280ae`

## 问题 2: NodeSource 不支持 RISCV64

**错误**: 
```
Error: Unsupported architecture: riscv64. Only amd64, arm64, and armhf are supported.
```

**原因**: NodeSource 的 Node.js 安装脚本不支持 RISCV64 架构

**修复**: 改用 nvm (Node Version Manager) 安装 Node.js

**修复前**:
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
```

**修复后**:
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 20
nvm use 20
```

**提交**: `ab7ffb1`

## 当前状态

- ✅ 已修复 sudo 问题
- ✅ 已修复 Node.js 安装问题
- ⏳ 等待新的构建完成以验证修复

## 可能仍存在的问题

1. **系统库不可用**: WebKitGTK 等库在 RISCV64 仓库中可能不可用
2. **依赖项缺失**: 某些系统依赖项可能需要手动处理
3. **构建时间**: QEMU 模拟环境构建较慢

## 查看构建状态

```bash
gh run list --repo AkarinServer/tauri-test
gh run watch --repo AkarinServer/tauri-test
```

或访问: https://github.com/AkarinServer/tauri-test/actions

