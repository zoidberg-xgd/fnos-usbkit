#!/bin/bash

# USB备份工具安装脚本
# 作者：USB Backup Tools
# 用途：自动安装和配置USB备份工具
# 版本：1.0.0

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 默认安装目录
DEFAULT_INSTALL_DIR="/opt/usb-backup-tools"
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

# ============================================
# 辅助函数
# ============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*"
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    read -r -p "$prompt" response
    response=${response:-$default}
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        echo "使用方法: sudo bash $0"
        exit 1
    fi
}

check_os() {
    if [ ! -f /etc/os-release ]; then
        log_warning "无法检测操作系统类型"
        return 1
    fi
    
    . /etc/os-release
    log_info "检测到操作系统: $NAME $VERSION"
    
    if [[ "$ID" =~ ^(debian|ubuntu|centos|fedora|rhel)$ ]]; then
        return 0
    else
        log_warning "未经测试的操作系统: $ID"
        return 1
    fi
}

# ============================================
# 安装步骤
# ============================================

# 步骤1: 检查依赖
check_dependencies() {
    log_section "步骤 1/7: 检查系统依赖"
    
    local missing_deps=()
    local required_commands=(
        "rsync"
        "lsblk"
        "blkid"
        "mount"
        "umount"
        "df"
        "du"
        "findmnt"
        "mountpoint"
    )
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            log_success "$cmd 已安装"
        else
            log_warning "$cmd 未安装"
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warning "缺少以下依赖: ${missing_deps[*]}"
        
        if ask_yes_no "是否尝试自动安装依赖？" "y"; then
            install_dependencies
        else
            log_error "缺少必需依赖，安装中止"
            exit 1
        fi
    else
        log_success "所有必需依赖已安装"
    fi
}

install_dependencies() {
    log_info "正在安装依赖..."
    
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        apt-get update -qq
        apt-get install -y rsync util-linux coreutils
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL/Fedora
        yum install -y rsync util-linux coreutils
    else
        log_error "不支持的包管理器，请手动安装依赖"
        exit 1
    fi
    
    log_success "依赖安装完成"
}

# 步骤2: 创建安装目录
create_install_directory() {
    log_section "步骤 2/7: 创建安装目录"
    
    if [ -d "$INSTALL_DIR" ]; then
        log_warning "安装目录已存在: $INSTALL_DIR"
        
        if ask_yes_no "是否覆盖现有安装？" "n"; then
            log_info "备份现有安装..."
            mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        else
            log_error "安装中止"
            exit 1
        fi
    fi
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/lib"
    mkdir -p "$INSTALL_DIR/scripts"
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$INSTALL_DIR/tests"
    
    log_success "安装目录创建完成: $INSTALL_DIR"
}

# 步骤3: 复制文件
copy_files() {
    log_section "步骤 3/7: 复制程序文件"
    
    # 复制公共库
    if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
        cp -f "$SCRIPT_DIR/lib/common.sh" "$INSTALL_DIR/lib/"
        chmod 644 "$INSTALL_DIR/lib/common.sh"
        log_success "已复制: lib/common.sh"
    else
        log_error "找不到公共库文件"
        exit 1
    fi
    
    # 复制脚本
    local scripts=(
        "mount_usb_backup.sh"
        "umount_usb_backup.sh"
        "auto_backup_to_usb.sh"
        "diagnose_usb_disk.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/scripts/$script" ]; then
            cp -f "$SCRIPT_DIR/scripts/$script" "$INSTALL_DIR/scripts/"
            chmod 755 "$INSTALL_DIR/scripts/$script"
            log_success "已复制: scripts/$script"
        else
            log_warning "找不到脚本: $script"
        fi
    done
    
    # 复制配置文件模板
    if [ -f "$SCRIPT_DIR/config/usb_backup.conf" ]; then
        cp -f "$SCRIPT_DIR/config/usb_backup.conf" "$INSTALL_DIR/config/usb_backup.conf.example"
        chmod 644 "$INSTALL_DIR/config/usb_backup.conf.example"
        log_success "已复制: config/usb_backup.conf.example"
    fi
    
    # 复制测试脚本
    if [ -f "$SCRIPT_DIR/tests/run_tests.sh" ]; then
        cp -f "$SCRIPT_DIR/tests/run_tests.sh" "$INSTALL_DIR/tests/"
        chmod 755 "$INSTALL_DIR/tests/run_tests.sh"
        log_success "已复制: tests/run_tests.sh"
    fi
    
    # 复制文档
    if [ -f "$SCRIPT_DIR/README.md" ]; then
        cp -f "$SCRIPT_DIR/README.md" "$INSTALL_DIR/"
        log_success "已复制: README.md"
    fi
}

# 步骤4: 配置文件初始化
initialize_config() {
    log_section "步骤 4/7: 初始化配置文件"
    
    local config_file="$INSTALL_DIR/config/usb_backup.conf"
    
    if [ -f "$config_file" ]; then
        log_warning "配置文件已存在，跳过初始化"
        return 0
    fi
    
    # 从示例复制
    cp -f "$INSTALL_DIR/config/usb_backup.conf.example" "$config_file"
    
    log_info "配置文件位置: $config_file"
    
    if ask_yes_no "是否现在配置？" "n"; then
        configure_interactive
    else
        log_info "您可以稍后编辑配置文件："
        echo "  vim $config_file"
    fi
    
    log_success "配置文件已初始化"
}

configure_interactive() {
    local config_file="$INSTALL_DIR/config/usb_backup.conf"
    
    echo ""
    log_info "开始交互式配置..."
    
    # 挂载点
    read -r -p "USB挂载点 [/mnt/usb_backup]: " mount_point
    mount_point=${mount_point:-/mnt/usb_backup}
    sed -i "s|^MOUNT_POINT=.*|MOUNT_POINT=\"$mount_point\"|" "$config_file"
    
    # 源目录
    read -r -p "备份源目录 [/fnos]: " source_dir
    source_dir=${source_dir:-/fnos}
    sed -i "s|^SOURCE_DIR=.*|SOURCE_DIR=\"$source_dir\"|" "$config_file"
    
    # 虚拟机自动释放
    if ask_yes_no "是否启用虚拟机USB自动释放？" "n"; then
        sed -i "s|^AUTO_RELEASE_FROM_VM=.*|AUTO_RELEASE_FROM_VM=true|" "$config_file"
    fi
    
    log_success "配置已保存"
}

# 步骤5: 创建符号链接
create_symlinks() {
    log_section "步骤 5/7: 创建命令符号链接"
    
    if ! ask_yes_no "是否创建系统命令（/usr/local/bin）？" "y"; then
        log_info "跳过符号链接创建"
        return 0
    fi
    
    local commands=(
        "mount-usb:scripts/mount_usb_backup.sh"
        "umount-usb:scripts/umount_usb_backup.sh"
        "backup-to-usb:scripts/auto_backup_to_usb.sh"
        "diagnose-usb:scripts/diagnose_usb_disk.sh"
    )
    
    for cmd_pair in "${commands[@]}"; do
        IFS=':' read -r cmd_name script_path <<< "$cmd_pair"
        
        local link_path="/usr/local/bin/$cmd_name"
        local target_path="$INSTALL_DIR/$script_path"
        
        if [ -L "$link_path" ]; then
            rm -f "$link_path"
        fi
        
        ln -s "$target_path" "$link_path"
        log_success "已创建命令: $cmd_name -> $script_path"
    done
    
    log_success "符号链接创建完成"
}

# 步骤6: 设置日志目录权限
setup_log_directory() {
    log_section "步骤 6/7: 设置日志目录"
    
    local log_dir="$INSTALL_DIR/logs"
    
    chmod 755 "$log_dir"
    
    log_success "日志目录: $log_dir"
}

# 步骤7: 运行测试（可选）
run_tests() {
    log_section "步骤 7/7: 运行测试（可选）"
    
    if ! ask_yes_no "是否运行测试验证安装？" "y"; then
        log_info "跳过测试"
        return 0
    fi
    
    if [ -f "$INSTALL_DIR/tests/run_tests.sh" ]; then
        log_info "运行测试套件..."
        echo ""
        
        if bash "$INSTALL_DIR/tests/run_tests.sh"; then
            log_success "测试通过！"
        else
            log_warning "部分测试失败（可能是正常的，取决于系统环境）"
        fi
    else
        log_warning "测试脚本不存在"
    fi
}

# ============================================
# 安装总结
# ============================================

show_installation_summary() {
    echo ""
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║          安装完成！                    ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    log_success "USB备份工具已成功安装到: $INSTALL_DIR"
    echo ""
    
    echo "📋 可用命令："
    echo "  mount-usb         - 挂载USB备份盘"
    echo "  umount-usb        - 卸载USB备份盘"
    echo "  backup-to-usb     - 执行备份"
    echo "  diagnose-usb      - 诊断USB设备问题"
    echo ""
    
    echo "📁 重要路径："
    echo "  配置文件: $INSTALL_DIR/config/usb_backup.conf"
    echo "  日志目录: $INSTALL_DIR/logs"
    echo "  脚本目录: $INSTALL_DIR/scripts"
    echo ""
    
    echo "🚀 快速开始："
    echo "  1. 编辑配置: vim $INSTALL_DIR/config/usb_backup.conf"
    echo "  2. 挂载设备: mount-usb"
    echo "  3. 执行备份: backup-to-usb"
    echo ""
    
    echo "📖 查看文档: cat $INSTALL_DIR/README.md"
    echo ""
}

# ============================================
# 卸载功能
# ============================================

uninstall() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║          卸载 USB备份工具              ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "未找到安装目录: $INSTALL_DIR"
        exit 1
    fi
    
    log_warning "这将删除以下内容:"
    echo "  • 程序文件: $INSTALL_DIR"
    echo "  • 系统命令: /usr/local/bin/{mount-usb,umount-usb,backup-to-usb,diagnose-usb}"
    echo ""
    
    if ! ask_yes_no "确认卸载？" "n"; then
        log_info "取消卸载"
        exit 0
    fi
    
    # 删除符号链接
    log_info "删除系统命令..."
    rm -f /usr/local/bin/mount-usb
    rm -f /usr/local/bin/umount-usb
    rm -f /usr/local/bin/backup-to-usb
    rm -f /usr/local/bin/diagnose-usb
    
    # 备份配置文件
    if [ -f "$INSTALL_DIR/config/usb_backup.conf" ]; then
        log_info "备份配置文件..."
        cp "$INSTALL_DIR/config/usb_backup.conf" "/tmp/usb_backup.conf.backup"
        log_info "配置备份到: /tmp/usb_backup.conf.backup"
    fi
    
    # 删除安装目录
    log_info "删除安装目录..."
    rm -rf "$INSTALL_DIR"
    
    echo ""
    log_success "卸载完成！"
    echo ""
}

# ============================================
# 主函数
# ============================================

main() {
    # 解析参数
    case "${1:-install}" in
        install)
            echo ""
            echo "╔════════════════════════════════════════╗"
            echo "║   USB备份工具安装向导 v1.0.0           ║"
            echo "╚════════════════════════════════════════╝"
            echo ""
            
            check_root
            check_os
            
            log_info "安装目录: $INSTALL_DIR"
            echo ""
            
            if ! ask_yes_no "开始安装？" "y"; then
                log_info "取消安装"
                exit 0
            fi
            
            # 执行安装步骤
            check_dependencies
            create_install_directory
            copy_files
            initialize_config
            create_symlinks
            setup_log_directory
            run_tests
            
            # 显示总结
            show_installation_summary
            ;;
            
        uninstall)
            check_root
            uninstall
            ;;
            
        *)
            echo "用法: $0 [install|uninstall]"
            echo ""
            echo "  install   - 安装USB备份工具（默认）"
            echo "  uninstall - 卸载USB备份工具"
            echo ""
            exit 1
            ;;
    esac
}

# ============================================
# 执行主函数
# ============================================

main "$@"

