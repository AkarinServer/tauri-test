# 快速开始 - 创建 GitHub 仓库

## 🚀 一键创建仓库（推荐）

项目已准备好，只需几个步骤：

### 步骤 1: 登录 GitHub CLI

```bash
cd /Users/lolotachibana/dev/tauri-test
gh auth login
```

按照提示选择：
- GitHub.com
- HTTPS
- 登录方式（浏览器或 token）

### 步骤 2: 创建并推送仓库

```bash
# 方式 1: 使用自动化脚本
./create_repo.sh

# 方式 2: 手动创建
gh repo create tauri-test --public --source=. --remote=origin --push
```

## 📋 手动方式（如果没有 GitHub CLI）

### 1. 在 GitHub 上创建仓库

访问: https://github.com/new
- 仓库名: `tauri-test`
- 选择 Public
- **不要**勾选任何初始化选项

### 2. 推送代码

```bash
cd /Users/lolotachibana/dev/tauri-test
git remote add origin https://github.com/AkarinServer/tauri-test.git
git push -u origin main
```

## ✅ 验证 CI 运行

推送成功后：

1. 访问: https://github.com/AkarinServer/tauri-test
2. 点击 "Actions" 标签
3. 查看构建状态

## 🎯 预期结果

- ✅ **macOS ARM64**: 应该成功构建
- ⚠️ **RISCV64**: 可能会因为系统库问题失败，这是正常的测试过程

## 📦 构建产物

构建完成后，在 Actions 页面可以下载：
- macOS: `.app` 和 `.dmg` 文件
- RISCV64: 可执行文件（如果构建成功）

## 🔧 如果遇到问题

### 认证问题

```bash
# 使用 SSH（如果已配置）
git remote set-url origin git@github.com:AkarinServer/tauri-test.git
git push -u origin main
```

### 仓库已存在

```bash
git remote add origin https://github.com/AkarinServer/tauri-test.git
git push -u origin main
```

