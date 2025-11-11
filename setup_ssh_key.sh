#!/bin/bash

# SSH 密钥安装脚本
# 用于将本地 SSH 公钥安装到 Lichee RV Dock

REMOTE_HOST="192.168.31.145"
REMOTE_USER="ubuntu"
SSH_KEY="${HOME}/.ssh/id_ed25519.pub"

echo "=== SSH 密钥安装脚本 ==="
echo ""
echo "目标服务器: ${REMOTE_USER}@${REMOTE_HOST}"
echo "公钥文件: ${SSH_KEY}"
echo ""

# 检查公钥文件是否存在
if [ ! -f "${SSH_KEY}" ]; then
    echo "❌ 错误: 公钥文件不存在: ${SSH_KEY}"
    exit 1
fi

echo "公钥内容："
cat "${SSH_KEY}"
echo ""

# 方法 1: 使用 ssh-copy-id（推荐）
echo "=== 方法 1: 使用 ssh-copy-id（推荐）==="
echo "执行命令: ssh-copy-id -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST}"
echo ""
echo "如果提示输入密码，请输入 ubuntu 用户的密码"
echo ""

read -p "是否现在执行？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ssh-copy-id -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}"
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ SSH 密钥安装成功！"
        echo ""
        echo "测试连接："
        ssh -i "${SSH_KEY%.pub}" "${REMOTE_USER}@${REMOTE_HOST}" "echo 'SSH 密钥登录成功！'"
    else
        echo ""
        echo "❌ 安装失败，请尝试方法 2"
    fi
fi

echo ""
echo "=== 方法 2: 手动安装 ==="
echo ""
echo "如果方法 1 失败，可以手动执行以下命令："
echo ""
echo "1. 将公钥内容复制到剪贴板："
echo "   cat ${SSH_KEY} | pbcopy"
echo ""
echo "2. SSH 登录到远程服务器："
echo "   ssh ${REMOTE_USER}@${REMOTE_HOST}"
echo ""
echo "3. 在远程服务器上执行："
echo "   mkdir -p ~/.ssh"
echo "   chmod 700 ~/.ssh"
echo "   echo '$(cat ${SSH_KEY})' >> ~/.ssh/authorized_keys"
echo "   chmod 600 ~/.ssh/authorized_keys"
echo ""
echo "4. 或者使用一行命令（需要输入密码）："
echo "   cat ${SSH_KEY} | ssh ${REMOTE_USER}@${REMOTE_HOST} 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'"
echo ""

