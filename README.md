# Tauri RISCV64 测试项目

这是一个用于验证 Tauri 在 Ubuntu Linux RISCV64 系统上运行的最小可行性测试项目。

## 项目结构

```
.
├── src-tauri/          # Tauri 后端 (Rust)
│   ├── src/
│   │   └── main.rs     # Rust 主文件
│   ├── Cargo.toml      # Rust 依赖配置
│   ├── tauri.conf.json # Tauri 配置文件
│   └── .cargo/
│       └── config.toml # RISCV64 交叉编译配置
├── index.html          # 前端 HTML
├── main.js             # 前端 JavaScript
├── vite.config.js      # Vite 配置
└── package.json        # Node.js 依赖配置
```

## 前置要求

### 1. 安装系统依赖

在 Ubuntu Linux RISCV64 系统上安装以下依赖：

```bash
sudo apt update
sudo apt install -y \
  libwebkit2gtk-4.1-dev \
  build-essential \
  curl \
  wget \
  file \
  libxdo-dev \
  libssl-dev \
  libayatana-appindicator3-dev \
  librsvg2-dev
```

**注意**: 某些依赖项在 RISCV64 架构上可能不可用或需要替代方案。请根据实际情况调整。

### 2. 安装 Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### 3. 添加 RISCV64 目标

```bash
rustup target add riscv64gc-unknown-linux-gnu
```

### 4. 安装交叉编译工具链

```bash
sudo apt install -y gcc-riscv64-linux-gnu
```

### 5. 安装 Node.js 和 npm

```bash
# 使用 nvm 或直接安装
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install --lts
```

## 安装项目依赖

```bash
npm install
```

## 开发模式

```bash
npm run dev
```

这将启动 Vite 开发服务器和 Tauri 应用。

## 构建项目

### 构建 macOS ARM64 架构

```bash
npm run tauri build -- --target aarch64-apple-darwin
```

### 构建 RISCV64 架构

**⚠️ 重要提示**: 在 macOS 上交叉编译 RISCV64 Linux 应用非常复杂且不现实，因为需要：
- RISCV64 Linux sysroot
- 交叉编译的 GTK/WebKit 等系统库
- 复杂的 pkg-config 配置

**推荐方案**: 使用 GitHub Actions CI 进行构建（见下方）

#### 在 RISCV64 系统上直接构建

如果您有 Ubuntu Linux RISCV64 系统：

```bash
npm run tauri build -- --target riscv64gc-unknown-linux-gnu
```

#### 使用 GitHub Actions CI（推荐）

项目已配置 GitHub Actions workflows，可以在 CI 中自动构建 RISCV64 版本：

1. **简单方案** (推荐): `.github/workflows/build-riscv64-simple.yml`
   - 使用 `uraimo/run-on-arch-action` 在 QEMU 模拟的 RISCV64 环境中构建
   - 最简单，推荐使用

2. **Docker 方案**: `.github/workflows/build-riscv64-docker.yml`
   - 使用 Docker 容器构建

3. **交叉编译方案**: `.github/workflows/build-riscv64.yml`
   - 使用 QEMU 和交叉编译工具链

只需将代码推送到 GitHub，CI 会自动运行 RISCV64 构建。

## 已知问题和限制

1. **WebKitGTK 支持**: WebKitGTK 在 RISCV64 上的支持可能有限。如果遇到问题，可能需要：
   - 使用替代的 WebView 实现
   - 等待上游支持
   - 使用社区维护的构建

2. **依赖项可用性**: 某些系统依赖项可能在 RISCV64 仓库中不可用，需要：
   - 从源码编译
   - 使用替代包
   - 等待官方支持

3. **交叉编译**: 如果从其他架构交叉编译到 RISCV64，可能需要额外的配置和工具链设置。

## 测试验证

1. 运行开发模式，确认应用可以正常启动
2. 测试前端与 Rust 后端的通信（点击 Greet 按钮）
3. 构建 RISCV64 版本并验证可执行文件
4. 在目标 RISCV64 系统上运行构建产物

## 故障排除

### 链接器错误

如果遇到链接器相关错误，检查 `.cargo/config.toml` 中的链接器配置是否正确。

### WebKit 相关错误

如果 WebKitGTK 不可用，可能需要：
- 检查系统是否安装了正确的 WebKit 版本
- 考虑使用其他 WebView 后端（如果 Tauri 支持）

### 构建失败

- 确保所有系统依赖已安装
- 检查 Rust 工具链是否正确安装
- 验证交叉编译工具链是否可用

## 许可证

本项目仅用于测试目的。

