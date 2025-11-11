# 问题 1 修复方案：Cargo 命令找不到

## 问题描述
- Rust 已安装（rustc 1.91.1）
- 但在 "Build Tauri application" 步骤中找不到 cargo 命令
- 错误：`No such file or directory (os error 2)`

## 根本原因
- Rust 安装步骤中执行了 `source $HOME/.cargo/env`，但这只在当前 shell 会话中有效
- 后续步骤在新的 shell 中运行，PATH 中没有 cargo
- 环境变量没有正确传递到后续步骤

---

## 修复方案

### 方案 1：在 Rust 安装步骤后设置 GITHUB_ENV（推荐）

**修改位置**：`.github/workflows/build-riscv64-selfhosted.yml` 的 "Install Rust" 步骤

**修改内容**：
```yaml
      - name: Install Rust
        run: |
          if command -v rustc &> /dev/null; then
            echo "Rust already installed: $(rustc --version)"
          else
            echo "Installing Rust..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source $HOME/.cargo/env
            rustup target add riscv64gc-unknown-linux-gnu
            echo "Rust installed: $(rustc --version)"
          fi
          
          # 确保 cargo 在后续步骤中可用
          echo "PATH=$HOME/.cargo/bin:$PATH" >> $GITHUB_ENV
          echo "CARGO_HOME=$HOME/.cargo" >> $GITHUB_ENV
```

**优点**：
- ✅ 简单直接，只需添加两行
- ✅ 使用 GitHub Actions 的标准机制（GITHUB_ENV）
- ✅ 适用于所有后续步骤
- ✅ 即使 Rust 已安装，也会设置 PATH

**缺点**：
- ⚠️ 需要确保 `$HOME/.cargo/bin` 存在

---

### 方案 2：在 Build Tauri application 步骤中显式设置 PATH

**修改位置**：`.github/workflows/build-riscv64-selfhosted.yml` 的 "Build Tauri application" 步骤

**修改内容**：
```yaml
      - name: Build Tauri application
        run: |
          # 确保 cargo 在 PATH 中
          export PATH="$HOME/.cargo/bin:$PATH"
          source $HOME/.cargo/env || true
          
          npm run tauri build -- --target riscv64gc-unknown-linux-gnu
```

**优点**：
- ✅ 只在需要 cargo 的步骤中设置
- ✅ 不依赖 GITHUB_ENV
- ✅ 如果 cargo env 文件存在，会加载完整环境

**缺点**：
- ⚠️ 需要在每个需要 cargo 的步骤中重复设置
- ⚠️ 如果后续添加更多需要 cargo 的步骤，容易遗漏

---

### 方案 3：在 Install Rust 步骤中同时使用 source 和 GITHUB_ENV

**修改位置**：`.github/workflows/build-riscv64-selfhosted.yml` 的 "Install Rust" 步骤

**修改内容**：
```yaml
      - name: Install Rust
        run: |
          if command -v rustc &> /dev/null; then
            echo "Rust already installed: $(rustc --version)"
            CARGO_PATH=$(dirname $(which cargo)) || echo "$HOME/.cargo/bin"
          else
            echo "Installing Rust..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source $HOME/.cargo/env
            rustup target add riscv64gc-unknown-linux-gnu
            echo "Rust installed: $(rustc --version)"
            CARGO_PATH="$HOME/.cargo/bin"
          fi
          
          # 确保 cargo 在后续步骤中可用
          echo "PATH=$CARGO_PATH:$PATH" >> $GITHUB_ENV
          echo "CARGO_HOME=$HOME/.cargo" >> $GITHUB_ENV
          
          # 验证 cargo 可用
          cargo --version || echo "Warning: cargo not found in PATH"
```

**优点**：
- ✅ 处理了 Rust 已安装和未安装两种情况
- ✅ 验证 cargo 是否可用
- ✅ 使用 GITHUB_ENV 确保后续步骤可用

**缺点**：
- ⚠️ 稍微复杂一些
- ⚠️ 需要处理 `which cargo` 可能失败的情况

---

### 方案 4：在 job 级别设置环境变量

**修改位置**：`.github/workflows/build-riscv64-selfhosted.yml` 的 job 定义

**修改内容**：
```yaml
jobs:
  build-riscv64-selfhosted:
    name: Build for RISCV64 Linux (Self-Hosted)
    runs-on: [self-hosted, Linux, RISCV64]
    env:
      CARGO_HOME: ${{ env.HOME }}/.cargo
      PATH: ${{ env.HOME }}/.cargo/bin:${{ env.PATH }}
    
    steps:
      ...
```

**优点**：
- ✅ 在 job 级别设置，所有步骤都可用
- ✅ 不需要在每个步骤中重复设置

**缺点**：
- ⚠️ `${{ env.HOME }}` 可能不可用，需要使用 `$HOME` 或硬编码路径
- ⚠️ 需要知道 runner 的用户主目录路径

---

## 推荐方案

**推荐使用方案 1**，因为：
1. 简单直接，只需添加两行代码
2. 使用 GitHub Actions 的标准机制
3. 适用于所有后续步骤
4. 即使 Rust 已安装也会设置 PATH

**备选方案 3**，如果：
- 需要更健壮的错误处理
- 需要验证 cargo 是否可用
- 需要处理 Rust 已安装的情况

---

## 实施建议

1. **首选**：方案 1（最简单）
2. **如果需要更健壮**：方案 3（处理更多边界情况）
3. **如果需要在多个步骤中使用 cargo**：方案 1 或方案 3（使用 GITHUB_ENV）

