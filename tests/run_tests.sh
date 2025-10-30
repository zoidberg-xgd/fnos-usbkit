#!/bin/bash

# FnOS-UsbKit 测试套件
# 作者：USB Backup Tools
# 用途：测试所有脚本功能的正确性
# 版本：1.0.0

set -euo pipefail

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# 测试工具函数
# ============================================

# 打印测试标题
print_test_header() {
    local test_name="$1"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing: $test_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 测试断言
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ -n "$value" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo "  Value is empty"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo "  File not found: $file"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

assert_command_succeeds() {
    local command="$1"
    local message="${2:-Command should succeed}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        echo "  Command failed: $command"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

skip_test() {
    local message="$1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    echo -e "${YELLOW}○ SKIP${NC}: $message"
}

# ============================================
# 测试：项目结构
# ============================================

test_project_structure() {
    print_test_header "项目结构测试"
    
    # 测试目录结构
    assert_file_exists "$PROJECT_ROOT/lib/common.sh" "公共库文件存在"
    assert_file_exists "$PROJECT_ROOT/config/usb_backup.conf" "配置文件存在"
    assert_file_exists "$PROJECT_ROOT/scripts/mount_usb_backup.sh" "挂载脚本存在"
    assert_file_exists "$PROJECT_ROOT/scripts/umount_usb_backup.sh" "卸载脚本存在"
    assert_file_exists "$PROJECT_ROOT/scripts/auto_backup_to_usb.sh" "备份脚本存在"
    assert_file_exists "$PROJECT_ROOT/scripts/diagnose_usb_disk.sh" "诊断脚本存在"
    
    # 测试脚本可执行性
    for script in mount_usb_backup.sh umount_usb_backup.sh auto_backup_to_usb.sh diagnose_usb_disk.sh; do
        local script_path="$PROJECT_ROOT/scripts/$script"
        if [ -x "$script_path" ]; then
            echo -e "${GREEN}✓ PASS${NC}: $script 具有可执行权限"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${YELLOW}○ WARN${NC}: $script 缺少可执行权限（非致命）"
        fi
    done
}

# ============================================
# 测试：公共库函数
# ============================================

test_common_library() {
    print_test_header "公共库函数测试"
    
    # 加载公共库
    if ! source "$PROJECT_ROOT/lib/common.sh" 2>/dev/null; then
        echo -e "${RED}✗ FAIL${NC}: 无法加载公共库"
        FAILED_TESTS=$((FAILED_TESTS + 10))
        TOTAL_TESTS=$((TOTAL_TESTS + 10))
        return 1
    fi
    
    echo -e "${GREEN}✓ PASS${NC}: 公共库加载成功"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    PASSED_TESTS=$((PASSED_TESTS + 1))
    
    # 测试日志函数
    assert_command_succeeds "log_info 'Test message'" "log_info 函数可用"
    assert_command_succeeds "log_success 'Test success'" "log_success 函数可用"
    assert_command_succeeds "log_warning 'Test warning'" "log_warning 函数可用"
    assert_command_succeeds "log_error 'Test error'" "log_error 函数可用"
    
    # 测试版本变量
    assert_not_empty "${SCRIPT_VERSION:-}" "SCRIPT_VERSION 已定义"
    
    # 测试颜色变量
    assert_not_empty "${GREEN:-}" "颜色变量 GREEN 已定义"
    assert_not_empty "${RED:-}" "颜色变量 RED 已定义"
    assert_not_empty "${YELLOW:-}" "颜色变量 YELLOW 已定义"
}

# ============================================
# 测试：配置文件解析
# ============================================

test_config_parsing() {
    print_test_header "配置文件解析测试"
    
    # 加载公共库
    source "$PROJECT_ROOT/lib/common.sh" 2>/dev/null || return 1
    
    # 测试配置加载
    if load_config "$PROJECT_ROOT/config/usb_backup.conf" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: 配置文件加载成功"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
        
        # 测试关键配置变量
        assert_not_empty "${MOUNT_POINT:-}" "MOUNT_POINT 已定义"
        assert_not_empty "${SOURCE_DIR:-}" "SOURCE_DIR 已定义"
        assert_not_empty "${BACKUP_BASE_DIR:-}" "BACKUP_BASE_DIR 已定义"
        assert_not_empty "${LOG_DIR:-}" "LOG_DIR 已定义"
        
        # 测试布尔值配置
        if [ "${AUTO_RELEASE_FROM_VM:-}" = "true" ] || [ "${AUTO_RELEASE_FROM_VM:-}" = "false" ]; then
            echo -e "${GREEN}✓ PASS${NC}: AUTO_RELEASE_FROM_VM 值有效"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}: AUTO_RELEASE_FROM_VM 值无效: ${AUTO_RELEASE_FROM_VM:-}"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        echo -e "${RED}✗ FAIL${NC}: 配置文件加载失败"
        FAILED_TESTS=$((FAILED_TESTS + 5))
        TOTAL_TESTS=$((TOTAL_TESTS + 5))
    fi
}

# ============================================
# 测试：虚拟机检测功能
# ============================================

test_vm_detection() {
    print_test_header "虚拟机检测功能测试"
    
    # 加载公共库
    source "$PROJECT_ROOT/lib/common.sh" 2>/dev/null || return 1
    
    # 测试虚拟机进程检测
    assert_command_succeeds "detect_vm_processes" "detect_vm_processes 函数可用"
    
    local vm_result
    vm_result=$(detect_vm_processes)
    
    if [ -n "$vm_result" ]; then
        echo -e "${YELLOW}○ INFO${NC}: 检测到运行中的虚拟机: $vm_result"
    else
        echo -e "${YELLOW}○ INFO${NC}: 未检测到运行中的虚拟机"
    fi
    
    # 测试USB设备虚拟机冲突检测（需要实际USB设备才能完整测试）
    if command -v lsusb &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: lsusb 命令可用"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
        
        # 尝试检测USB设备
        local usb_device
        usb_device=$(lsusb | grep -iE "JMicron|SATA|USB.*Storage" | head -1 || true)
        
        if [ -n "$usb_device" ]; then
            echo -e "${YELLOW}○ INFO${NC}: 检测到USB存储设备"
            echo "  $usb_device"
        else
            echo -e "${YELLOW}○ INFO${NC}: 未检测到USB存储设备（跳过部分测试）"
        fi
    else
        skip_test "lsusb 命令不可用"
    fi
}

# ============================================
# 测试：USB设备检测
# ============================================

test_usb_detection() {
    print_test_header "USB设备检测测试"
    
    # 加载公共库
    source "$PROJECT_ROOT/lib/common.sh" 2>/dev/null || return 1
    
    # 测试USB设备检测函数
    if detect_usb_device 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: detect_usb_device 函数执行成功"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
        
        if [ -n "${DETECTED_USB_DEVICE:-}" ]; then
            echo -e "${YELLOW}○ INFO${NC}: 检测到USB设备: $DETECTED_USB_DEVICE"
        fi
    else
        echo -e "${YELLOW}○ INFO${NC}: 未检测到USB设备（正常，可能没有插入）"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    fi
    
    # 测试硬盘设备检测
    if find_disk_device 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: find_disk_device 函数执行成功"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
        
        if [ -n "${DETECTED_DISK_DEVICE:-}" ]; then
            echo -e "${YELLOW}○ INFO${NC}: 检测到硬盘设备: $DETECTED_DISK_DEVICE"
        fi
    else
        echo -e "${YELLOW}○ INFO${NC}: 未检测到硬盘设备（正常，可能没有插入）"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    fi
}

# ============================================
# 测试：RAID和LVM功能
# ============================================

test_raid_lvm_functions() {
    print_test_header "RAID和LVM功能测试"
    
    # 加载公共库
    source "$PROJECT_ROOT/lib/common.sh" 2>/dev/null || return 1
    
    # 测试RAID相关命令可用性
    if command -v mdadm &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: mdadm 命令可用"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        skip_test "mdadm 命令不可用（安装: apt-get install mdadm）"
    fi
    
    # 测试LVM相关命令可用性
    if command -v vgscan &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: vgscan 命令可用"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        skip_test "LVM命令不可用（安装: apt-get install lvm2）"
    fi
    
    if command -v lvscan &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: lvscan 命令可用"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        skip_test "LVM命令不可用"
    fi
    
    # 测试RAID/LVM函数存在性（不执行，仅检查函数定义）
    assert_command_succeeds "type assemble_raid" "assemble_raid 函数已定义"
    assert_command_succeeds "type activate_lvm" "activate_lvm 函数已定义"
    assert_command_succeeds "type stop_raid" "stop_raid 函数已定义"
    assert_command_succeeds "type deactivate_lvm" "deactivate_lvm 函数已定义"
}

# ============================================
# 测试：磁盘空间检查
# ============================================

test_disk_space_check() {
    print_test_header "磁盘空间检查测试"
    
    # 加载公共库
    source "$PROJECT_ROOT/lib/common.sh" 2>/dev/null || return 1
    
    # 测试磁盘空间检查函数
    assert_command_succeeds "type check_disk_space" "check_disk_space 函数已定义"
    
    # 使用 /tmp 作为测试目录（总是存在）
    if check_disk_space "/tmp" "/tmp" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: check_disk_space 函数执行成功"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}○ INFO${NC}: 磁盘空间可能不足（预期行为）"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    fi
}

# ============================================
# 测试：脚本语法检查
# ============================================

test_script_syntax() {
    print_test_header "脚本语法检查测试"
    
    local scripts=(
        "lib/common.sh"
        "scripts/mount_usb_backup.sh"
        "scripts/umount_usb_backup.sh"
        "scripts/auto_backup_to_usb.sh"
        "scripts/diagnose_usb_disk.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="$PROJECT_ROOT/$script"
        
        if [ -f "$script_path" ]; then
            if bash -n "$script_path" 2>/dev/null; then
                echo -e "${GREEN}✓ PASS${NC}: $script 语法正确"
                TOTAL_TESTS=$((TOTAL_TESTS + 1))
                PASSED_TESTS=$((PASSED_TESTS + 1))
            else
                echo -e "${RED}✗ FAIL${NC}: $script 存在语法错误"
                bash -n "$script_path" 2>&1 | head -5
                TOTAL_TESTS=$((TOTAL_TESTS + 1))
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
        else
            echo -e "${RED}✗ FAIL${NC}: $script 文件不存在"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    done
}

# ============================================
# 测试：ShellCheck静态分析（可选）
# ============================================

test_shellcheck() {
    print_test_header "ShellCheck 静态分析（可选）"
    
    if ! command -v shellcheck &> /dev/null; then
        skip_test "shellcheck 未安装（可选工具）"
        return 0
    fi
    
    local scripts=(
        "lib/common.sh"
        "scripts/mount_usb_backup.sh"
        "scripts/umount_usb_backup.sh"
        "scripts/auto_backup_to_usb.sh"
        "scripts/diagnose_usb_disk.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="$PROJECT_ROOT/$script"
        
        if [ -f "$script_path" ]; then
            # 忽略一些常见的ShellCheck警告
            # SC1090: 无法跟踪source的文件
            # SC2034: 变量未使用（可能在其他脚本中使用）
            if shellcheck -x -e SC1090,SC2034 "$script_path" 2>/dev/null; then
                echo -e "${GREEN}✓ PASS${NC}: $script 通过 ShellCheck 检查"
                TOTAL_TESTS=$((TOTAL_TESTS + 1))
                PASSED_TESTS=$((PASSED_TESTS + 1))
            else
                echo -e "${YELLOW}○ WARN${NC}: $script 有 ShellCheck 警告（非致命）"
                shellcheck -x -e SC1090,SC2034 "$script_path" 2>&1 | head -10
            fi
        fi
    done
}

# ============================================
# 测试：依赖命令检查
# ============================================

test_dependencies() {
    print_test_header "依赖命令检查测试"
    
    local required_commands=(
        "lsusb"
        "lsblk"
        "blkid"
        "mount"
        "umount"
        "rsync"
        "df"
        "du"
        "findmnt"
        "mountpoint"
    )
    
    local optional_commands=(
        "mdadm"
        "vgscan"
        "lvscan"
        "vgchange"
        "smartctl"
        "lsof"
        "fuser"
        "virsh"
        "VBoxManage"
    )
    
    echo "必需命令检查:"
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}✓ PASS${NC}: $cmd 可用"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}: $cmd 不可用（必需）"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    done
    
    echo ""
    echo "可选命令检查:"
    for cmd in "${optional_commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}✓ OK${NC}: $cmd 可用"
        else
            echo -e "${YELLOW}○ SKIP${NC}: $cmd 不可用（可选）"
        fi
    done
}

# ============================================
# 测试：日志和输出功能
# ============================================

test_logging() {
    print_test_header "日志和输出功能测试"
    
    # 加载公共库
    source "$PROJECT_ROOT/lib/common.sh" 2>/dev/null || return 1
    
    # 创建临时日志目录
    local test_log_dir="/tmp/usb_backup_test_logs_$$"
    mkdir -p "$test_log_dir"
    
    export LOG_DIR="$test_log_dir"
    export LOG_FILE="$test_log_dir/test.log"
    
    # 测试日志写入
    log_to_file "Test log entry" 2>/dev/null || true
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "${GREEN}✓ PASS${NC}: 日志文件创建成功"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
        
        if grep -q "Test log entry" "$LOG_FILE"; then
            echo -e "${GREEN}✓ PASS${NC}: 日志写入成功"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}: 日志写入失败"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        echo -e "${YELLOW}○ SKIP${NC}: 无法创建日志文件（权限问题）"
        TOTAL_TESTS=$((TOTAL_TESTS + 2))
        SKIPPED_TESTS=$((SKIPPED_TESTS + 2))
    fi
    
    # 清理
    rm -rf "$test_log_dir"
}

# ============================================
# 测试总结
# ============================================

print_test_summary() {
    echo ""
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║          测试结果总结                  ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    echo "总测试数: $TOTAL_TESTS"
    echo -e "${GREEN}通过:     $PASSED_TESTS${NC}"
    echo -e "${RED}失败:     $FAILED_TESTS${NC}"
    echo -e "${YELLOW}跳过:     $SKIPPED_TESTS${NC}"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        local pass_rate=100
        if [ $TOTAL_TESTS -gt 0 ]; then
            pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        fi
        
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ 所有测试通过！(${pass_rate}%)${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        return 0
    else
        local pass_rate=0
        if [ $TOTAL_TESTS -gt 0 ]; then
            pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        fi
        
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}✗ 有 $FAILED_TESTS 个测试失败 (${pass_rate}%)${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        return 1
    fi
}

# ============================================
# 主函数
# ============================================

main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   FnOS-UsbKit 测试套件 v1.0.0         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "项目目录: $PROJECT_ROOT"
    echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 运行所有测试
    test_project_structure
    test_common_library
    test_config_parsing
    test_script_syntax
    test_dependencies
    test_vm_detection
    test_usb_detection
    test_raid_lvm_functions
    test_disk_space_check
    test_logging
    test_shellcheck
    
    # 打印总结
    print_test_summary
    
    # 返回测试结果
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# ============================================
# 执行主函数
# ============================================

main "$@"

