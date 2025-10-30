#!/bin/bash
#
# GitHub仓库设置脚本
# 使用方法: ./setup_github.sh <GitHub用户名> <仓库名>
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印信息
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 检查参数
if [ $# -lt 1 ]; then
    error "用法: $0 <GitHub用户名> [仓库名]"
    echo ""
    echo "示例:"
    echo "  $0 yourusername"
    echo "  $0 yourusername custom-repo-name"
    echo ""
    echo "默认仓库名: fnos-usbkit"
    exit 1
fi

GITHUB_USERNAME="$1"
REPO_NAME="${2:-fnos-usbkit}"
REPO_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"

echo ""
echo "╔════════════════════════════════════════╗"
echo "║     GitHub 仓库设置向导                ║"
echo "╚════════════════════════════════════════╝"
echo ""

info "GitHub用户名: ${GITHUB_USERNAME}"
info "仓库名称: ${REPO_NAME}"
info "仓库地址: ${REPO_URL}"
echo ""

# 检查是否安装了gh CLI
if command -v gh &> /dev/null; then
    info "检测到 GitHub CLI (gh)，可以自动创建仓库"
    echo ""
    read -p "是否使用 gh 自动创建仓库？(y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "创建GitHub仓库..."
        
        # 创建仓库
        gh repo create "${REPO_NAME}" \
            --public \
            --description "飞牛OS USB工具箱 - 解决USB掉盘问题 + 智能备份" \
            --source=. \
            --remote=origin \
            --push
        
        success "仓库创建并推送成功！"
        echo ""
        info "仓库地址: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"
        
        # 设置topics
        warning "建议添加以下 topics 标签到仓库："
        echo "  - fnos"
        echo "  - backup"
        echo "  - usb"
        echo "  - shell-script"
        echo "  - linux"
        echo "  - nas"
        echo ""
        info "可以在仓库页面手动添加，或运行："
        echo "  gh repo edit --add-topic fnos,backup,usb,shell-script,linux,nas"
        
        exit 0
    fi
fi

# 手动设置流程
echo ""
warning "请按照以下步骤操作："
echo ""
echo "1️⃣  在浏览器中打开: https://github.com/new"
echo ""
echo "2️⃣  填写仓库信息："
echo "   - 仓库名称: ${REPO_NAME}"
echo "   - 描述: 飞牛OS USB工具箱 - 解决USB掉盘问题 + 智能备份"
echo "   - 可见性: Public (或 Private)"
echo "   - ❌ 不要勾选 'Add a README file'"
echo "   - ❌ 不要勾选 'Add .gitignore'"
echo "   - ❌ 不要勾选 'Choose a license'"
echo ""
echo "3️⃣  点击 'Create repository'"
echo ""

read -p "完成上述步骤后按回车继续..." 

# 添加远程仓库
info "添加远程仓库..."
if git remote | grep -q "^origin$"; then
    warning "远程仓库 'origin' 已存在，将先删除"
    git remote remove origin
fi

git remote add origin "${REPO_URL}"
success "远程仓库添加成功"

# 推送代码
info "推送代码到GitHub..."
if git push -u origin master; then
    success "代码推送成功！"
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║         🎉 设置完成！                  ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    info "仓库地址: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"
    echo ""
    warning "建议后续操作："
    echo "  1. 添加 topics 标签 (fnos, backup, usb, shell-script, linux, nas)"
    echo "  2. 添加 LICENSE 文件 (推荐 MIT License)"
    echo "  3. 启用 GitHub Pages (可选)"
    echo ""
else
    error "推送失败，请检查："
    echo "  1. 仓库是否已创建"
    echo "  2. GitHub认证是否正确"
    echo "  3. 仓库地址是否正确: ${REPO_URL}"
    exit 1
fi

