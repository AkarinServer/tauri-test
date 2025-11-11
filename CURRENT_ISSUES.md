# 当前构建问题报告

## 检查时间
2025-11-11 12:55

## 当前状态

所有 workflows 都失败了：
- ❌ Build RISCV64 (Simple) - 失败
- ❌ Build RISCV64 with Docker - 失败

## 问题 1: Build RISCV64 (Simple) - Node.js 22 下载失败

### 错误信息
```
警告: 下载 Node.js 22.11.0 失败，尝试其他版本...
错误: 无法下载 Node.js 22 for RISCV64
```

### 问题分析
- **问题类型**: Node.js 22.11.0 和 22.10.0 在 unofficial-builds 上不可用（404错误）
- **原因**: 
  - 尝试下载的版本可能不存在
  - unofficial-builds 可能没有这些特定版本
  - 需要检查实际可用的 Node.js 22 版本
- **影响**: 无法安装 Node.js，构建失败
- **严重程度**: 高（必须修复）

### 实际可用版本
检查 unofficial-builds.nodejs.org 发现：
- ❌ Node.js 22.11.0 - **不存在**
- ❌ Node.js 22.10.0 - **不存在**
- ✅ Node.js 22.21.1 - **存在**
- ✅ Node.js 22.21.0 - **存在**
- ✅ Node.js 22.20.0 - **存在**

**问题**: 代码中使用的版本号（22.11.0, 22.10.0）在 unofficial-builds 上不存在

**解决方案**: 需要使用实际存在的版本，如 22.21.1 或 22.21.0

## 问题 2: Build RISCV64 with Docker - Bash 语法错误

### 错误信息
```
apt-get: -c: line 8: syntax error: unexpected end of file
```

### 问题分析
- **问题类型**: Bash 脚本语法错误
- **原因**: 
  - 在 Docker 命令的字符串中，bash 语法可能有问题
  - 可能是重试逻辑的语法在字符串转义时出错
  - `set -e` 可能导致脚本提前退出
- **影响**: 无法执行 apt-get update，构建失败
- **严重程度**: 高（必须修复）

### 可能原因
1. 在 Docker `bash -c` 命令字符串中，bash 语法解析错误
2. 嵌套的 `||` 和 `{}` 在字符串转义时出现问题
3. `set -e` 与错误处理逻辑冲突

## 建议的修复方案

### 对于问题 1 (Node.js 版本)
1. **检查可用版本**: 查询 unofficial-builds 上实际可用的 Node.js 22 版本
2. **使用可用版本**: 使用实际存在的版本号
3. **添加更多降级选项**: 如果 22.x 不可用，尝试 20.x 或 18.x

### 对于问题 2 (Docker bash 语法)
1. **简化重试逻辑**: 使用更简单的 bash 语法
2. **移除 set -e**: 或调整错误处理逻辑
3. **使用脚本文件**: 将复杂逻辑提取到单独的脚本文件中

## 优先级

1. **高优先级**: 问题 1 - Node.js 下载失败（阻止所有构建）
2. **高优先级**: 问题 2 - Docker bash 语法错误（阻止 Docker workflow）

## 下一步

1. 检查 unofficial-builds 上可用的 Node.js 22 版本
2. 修复 Docker workflow 的 bash 语法错误
3. 重新测试构建

