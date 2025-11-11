# 设置 GitHub 仓库指南

## 方法 1: 使用 GitHub CLI（推荐）

### 安装 GitHub CLI

```bash
# macOS
brew install gh

# 登录 GitHub
gh auth login
```

### 创建仓库并推送

```bash
cd /Users/lolotachibana/dev/tauri-test

# 创建仓库（私有或公开）
gh repo create tauri-test --public --source=. --remote=origin --push

# 或者如果已经创建了仓库，只需添加 remote 并推送
git remote add origin https://github.com/AkarinServer/tauri-test.git
git push -u origin main
```

## 方法 2: 手动创建（如果没有 GitHub CLI）

### 步骤 1: 在 GitHub 上创建仓库

1. 访问 https://github.com/new
2. 仓库名称: `tauri-test`
3. 选择 Public 或 Private
4. **不要**初始化 README、.gitignore 或 license（我们已经有了）
5. 点击 "Create repository"

### 步骤 2: 推送代码

```bash
cd /Users/lolotachibana/dev/tauri-test

# 添加远程仓库
git remote add origin https://github.com/AkarinServer/tauri-test.git

# 推送代码
git push -u origin main
```

## 验证 CI 是否运行

推送后：

1. 访问 https://github.com/AkarinServer/tauri-test
2. 点击 "Actions" 标签
3. 您应该看到 workflows 开始运行：
   - `Build RISCV64 (Simple)` - 推荐使用
   - `Build for All Platforms` - 构建所有平台
   - `Build RISCV64 with Docker` - Docker 方案

## 预期结果

- ✅ macOS ARM64 构建应该成功
- ⚠️ RISCV64 构建可能会因为系统库问题而失败，但这是正常的测试过程
- 📦 构建产物可以在 Actions 页面下载

## 故障排除

如果推送时遇到认证问题：

```bash
# 使用 SSH（如果已配置 SSH key）
git remote set-url origin git@github.com:AkarinServer/tauri-test.git
git push -u origin main

# 或使用 Personal Access Token
# 在 GitHub Settings > Developer settings > Personal access tokens 创建 token
git remote set-url origin https://YOUR_TOKEN@github.com/AkarinServer/tauri-test.git
git push -u origin main
```

