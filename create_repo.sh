#!/bin/bash
# 创建 GitHub 仓库并推送代码的脚本

echo "🚀 准备创建 GitHub 仓库..."

# 检查是否已安装 GitHub CLI
if command -v gh &> /dev/null; then
    echo "✅ 检测到 GitHub CLI"
    
    # 检查是否已登录
    if gh auth status &> /dev/null; then
        echo "✅ GitHub CLI 已登录"
        
        # 创建仓库
        echo "📦 创建仓库 tauri-test..."
        gh repo create tauri-test --public --source=. --remote=origin --push
        
        if [ $? -eq 0 ]; then
            echo "✅ 仓库创建成功！"
            echo "🔗 访问: https://github.com/AkarinServer/tauri-test"
            echo "🔗 Actions: https://github.com/AkarinServer/tauri-test/actions"
        else
            echo "❌ 创建失败，可能仓库已存在"
            echo "尝试添加 remote 并推送..."
            git remote add origin https://github.com/AkarinServer/tauri-test.git 2>/dev/null || git remote set-url origin https://github.com/AkarinServer/tauri-test.git
            git push -u origin main
        fi
    else
        echo "❌ GitHub CLI 未登录"
        echo "请运行: gh auth login"
        exit 1
    fi
else
    echo "⚠️  未安装 GitHub CLI"
    echo ""
    echo "请选择以下方式之一："
    echo ""
    echo "方式 1: 安装 GitHub CLI"
    echo "  brew install gh"
    echo "  gh auth login"
    echo "  然后重新运行此脚本"
    echo ""
    echo "方式 2: 手动创建"
    echo "  1. 访问 https://github.com/new"
    echo "  2. 创建名为 'tauri-test' 的仓库"
    echo "  3. 运行以下命令："
    echo "     git remote add origin https://github.com/AkarinServer/tauri-test.git"
    echo "     git push -u origin main"
    exit 1
fi
