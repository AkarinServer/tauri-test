# SSH 密钥登录设置指南

## 目标服务器
- **主机**: 192.168.31.145
- **用户**: ubuntu
- **系统**: Ubuntu 24.10 RISC-V (Lichee RV Dock)

## 本地 SSH 密钥
- **密钥类型**: ed25519
- **公钥文件**: `~/.ssh/id_ed25519.pub`
- **公钥内容**:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBODDojWPHavOYotVATo5fnlK1R5FBih1SKJ3aY+iuVE me@akarin.moe
```

---

## 快速安装方法

### 方法 1: 使用脚本（推荐）

```bash
cd /Users/lolotachibana/dev/tauri-test
./setup_ssh_key.sh
```

脚本会引导您完成安装过程。

### 方法 2: 使用 ssh-copy-id（最简单）

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@192.168.31.145
```

当提示输入密码时，输入 ubuntu 用户的密码。

### 方法 3: 手动安装

#### 步骤 1: 复制公钥内容

```bash
cat ~/.ssh/id_ed25519.pub
```

#### 步骤 2: SSH 登录到远程服务器

```bash
ssh ubuntu@192.168.31.145
```

#### 步骤 3: 在远程服务器上执行

```bash
# 创建 .ssh 目录（如果不存在）
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 添加公钥到 authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBODDojWPHavOYotVATo5fnlK1R5FBih1SKJ3aY+iuVE me@akarin.moe" >> ~/.ssh/authorized_keys

# 设置正确的权限
chmod 600 ~/.ssh/authorized_keys
```

#### 步骤 4: 退出并测试

```bash
exit
ssh ubuntu@192.168.31.145
```

如果不再提示输入密码，说明设置成功！

### 方法 4: 一行命令（需要输入密码）

```bash
cat ~/.ssh/id_ed25519.pub | ssh ubuntu@192.168.31.145 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

---

## 验证安装

安装完成后，测试无密码登录：

```bash
ssh ubuntu@192.168.31.145 "echo 'SSH 密钥登录成功！'"
```

如果成功，应该直接显示 "SSH 密钥登录成功！" 而不需要输入密码。

---

## 配置 SSH 别名（可选）

为了方便使用，可以在 `~/.ssh/config` 中添加别名：

```bash
cat >> ~/.ssh/config << 'EOF'

Host lichee
    HostName 192.168.31.145
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
EOF
```

然后就可以使用简短命令：

```bash
ssh lichee
```

---

## 故障排除

### 问题 1: Permission denied (publickey,password)

**原因**: 公钥未正确安装或权限不正确

**解决**:
1. 检查远程服务器上的 `~/.ssh/authorized_keys` 文件是否存在
2. 检查权限：`~/.ssh` 应该是 700，`~/.ssh/authorized_keys` 应该是 600
3. 检查公钥内容是否正确

### 问题 2: 仍然提示输入密码

**原因**: SSH 配置问题或公钥格式错误

**解决**:
1. 检查远程服务器的 SSH 日志：`sudo tail -f /var/log/auth.log`
2. 确认公钥格式正确（一行，以 `ssh-ed25519` 开头）
3. 检查 `/etc/ssh/sshd_config` 中的 `PubkeyAuthentication yes`

### 问题 3: 连接超时

**原因**: 网络问题或防火墙

**解决**:
1. 检查网络连接：`ping 192.168.31.145`
2. 检查 SSH 服务是否运行：`ssh ubuntu@192.168.31.145`（应该能连接，即使需要密码）
3. 检查防火墙设置

---

## 安装完成后

安装成功后，我就可以使用以下命令直接访问 Lichee RV Dock：

```bash
ssh ubuntu@192.168.31.145
```

或者如果配置了别名：

```bash
ssh lichee
```

然后我可以：
- 检查图形驱动问题
- 诊断应用运行时错误
- 查看系统配置
- 测试修复方案

