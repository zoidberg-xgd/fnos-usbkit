#!/bin/bash

# USB移动硬盘健康诊断脚本
# 作者：USB Backup Tools
# 用途：检测可能的物理连接问题（SATA松动、USB不稳定、虚拟机占用等）
# 版本：2.0.0 - 使用公共库重构

set -euo pipefail

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载公共库
if [ -f "$PROJECT_ROOT/lib/common.sh" ]; then
    # shellcheck source=../lib/common.sh
    source "$PROJECT_ROOT/lib/common.sh"
else
    echo "错误: 找不到公共库文件 $PROJECT_ROOT/lib/common.sh"
    exit 1
fi

# ============================================
# 诊断函数
# ============================================

ISSUE_COUNT=0
WARNING_COUNT=0

# 增加问题计数
add_issue() {
    ISSUE_COUNT=$((ISSUE_COUNT + 1))
}

add_warning() {
    WARNING_COUNT=$((WARNING_COUNT + 1))
}

# 检查1: USB设备检测
check_usb_device_presence() {
    log_section "1. USB设备检测"
    
    local usb_device
    usb_device=$(lsusb | grep -iE "JMicron|SATA|USB.*Storage|ASMedia" | head -1 || true)
    
    if [ -z "$usb_device" ]; then
        log_error "未检测到USB存储设备"
        log_warning "可能原因："
        echo "  • USB线缆未连接"
        echo "  • USB接口松动"
        echo "  • 硬盘盒电源未开"
        echo "  • 设备被虚拟机占用"
        add_issue
        
        # 检查虚拟机
        local vm_list
        vm_list=$(detect_vm_processes)
        if [ -n "$vm_list" ]; then
            log_warning "检测到运行中的虚拟机: $vm_list"
            log_info "USB设备可能被虚拟机占用"
            add_warning
        fi
    else
        log_success "检测到USB设备"
        echo "  $usb_device"
        
        # 提取设备信息
        local bus_num dev_num
        bus_num=$(echo "$usb_device" | grep -oP 'Bus \K\d+' || echo "")
        dev_num=$(echo "$usb_device" | grep -oP 'Device \K\d+' || echo "")
        
        # 检查虚拟机占用
        if [ -n "$bus_num" ] && [ -n "$dev_num" ]; then
            if ! check_usb_vm_conflict "$bus_num" "$dev_num"; then
                log_warning "USB设备可能被虚拟机占用"
                add_warning
            fi
        fi
    fi
}

# 检查2: 硬盘设备节点
check_disk_device_node() {
    log_section "2. 硬盘设备节点检测"
    
    local disk_device
    disk_device=$(ls /dev/sd* 2>/dev/null | grep -E "sd[a-z]$" | head -1 || true)
    
    if [ -z "$disk_device" ]; then
        log_error "未找到硬盘设备节点 (/dev/sd*)"
        log_warning "可能原因："
        echo "  • 硬盘盒内SATA连接松动 ← 常见原因"
        echo "  • 硬盘故障"
        echo "  • USB桥接芯片异常"
        echo "  • 虚拟机占用USB设备"
        add_issue
        
        # 尝试强制扫描
        log_info "尝试强制扫描SCSI总线..."
        for h in /sys/class/scsi_host/host*/scan; do
            echo "- - -" > "$h" 2>/dev/null || true
        done
        sleep 3
        
        disk_device=$(ls /dev/sd* 2>/dev/null | grep -E "sd[a-z]$" | head -1 || true)
        if [ -z "$disk_device" ]; then
            log_error "强制扫描后仍未找到设备"
            echo ""
            echo "🔧 建议操作："
            echo "  1. 检查是否有虚拟机占用USB设备"
            echo "  2. 拔出USB线缆"
            echo "  3. 打开硬盘盒，检查SATA数据线和供电线"
            echo "  4. 重新插紧SATA连接"
            echo "  5. 关闭硬盘盒，重新连接USB"
        else
            log_success "强制扫描后找到设备: $disk_device"
            add_warning
        fi
    else
        log_success "找到硬盘设备: $disk_device"
        export DETECTED_DISK="$disk_device"
    fi
}

# 检查3: 虚拟机占用分析
check_vm_occupation() {
    log_section "3. 虚拟机占用分析"
    
    local vm_list
    vm_list=$(detect_vm_processes)
    
    if [ -z "$vm_list" ]; then
        log_success "未检测到运行中的虚拟机"
    else
        log_warning "检测到以下虚拟机正在运行:"
        echo "  $vm_list"
        add_warning
        
        echo ""
        log_info "虚拟机可能占用USB设备，导致主机无法访问"
        echo ""
        echo "解决方法："
        echo "  1. 在虚拟机中断开USB设备连接"
        echo "  2. 暂停或关闭虚拟机"
        echo "  3. 使用脚本自动释放: 设置 AUTO_RELEASE_FROM_VM=true"
        
        # 检查lsof占用
        if [ -n "${DETECTED_DISK:-}" ]; then
            log_info "检查设备占用情况..."
            local processes
            processes=$(lsof "/dev/${DETECTED_DISK}" 2>/dev/null | tail -n +2 || true)
            
            if [ -n "$processes" ]; then
                log_error "设备被以下进程占用:"
                echo "$processes"
                add_issue
            fi
        fi
    fi
}

# 检查4: dmesg内核日志分析
check_kernel_logs() {
    log_section "4. 内核日志分析（最近100行）"
    
    local dmesg_issues
    dmesg_issues=$(dmesg | tail -100 | grep -iE "usb.*reset|usb.*disconnect|i/o error|ata.*error|sense.*error|usb.*occupied|usb.*busy" || true)
    
    if [ -n "$dmesg_issues" ]; then
        log_warning "发现可疑的内核错误日志:"
        echo "$dmesg_issues" | head -10
        add_warning
        
        # 分析具体问题
        if echo "$dmesg_issues" | grep -qi "reset"; then
            echo ""
            log_warning "检测到USB总线重置事件"
            echo "  可能原因：USB供电不足、接触不良、虚拟机干扰"
        fi
        
        if echo "$dmesg_issues" | grep -qi "i/o error"; then
            echo ""
            log_warning "检测到I/O错误"
            echo "  可能原因：SATA连接不稳定、硬盘故障"
            add_issue
        fi
        
        if echo "$dmesg_issues" | grep -qi "sense.*error"; then
            echo ""
            log_warning "检测到SCSI Sense错误"
            echo "  可能原因：硬盘未就绪、SATA通信异常"
            add_issue
        fi
        
        if echo "$dmesg_issues" | grep -qi "occupied\|busy"; then
            echo ""
            log_warning "检测到设备占用标记"
            echo "  可能原因：虚拟机或其他进程占用USB设备"
            add_issue
        fi
    else
        log_success "未发现明显的内核错误"
    fi
}

# 检查5: SMART健康状态
check_smart_status() {
    log_section "5. 硬盘SMART状态"
    
    if [ -z "${DETECTED_DISK:-}" ]; then
        log_info "跳过（设备不可用）"
        return
    fi
    
    if ! command -v smartctl &> /dev/null; then
        log_info "smartctl未安装，跳过SMART检查"
        log_info "安装: apt-get install smartmontools"
        return
    fi
    
    local smart_status
    smart_status=$(smartctl -H "/dev/${DETECTED_DISK}" 2>&1 || true)
    
    if echo "$smart_status" | grep -qi "PASSED"; then
        log_success "SMART健康检查通过"
    elif echo "$smart_status" | grep -qi "FAILED"; then
        log_error "SMART健康检查失败！硬盘可能损坏"
        add_issue
    else
        log_warning "无法获取SMART信息（可能是USB桥接芯片不支持）"
        echo "  这很正常，大部分USB硬盘盒不传递SMART数据"
    fi
}

# 检查6: USB连接稳定性测试
check_usb_stability() {
    log_section "6. USB连接稳定性测试（10秒）"
    
    log_info "监控USB设备状态变化..."
    
    local initial_usb middle_usb final_usb
    initial_usb=$(lsusb | grep -iE "JMicron|SATA|USB.*Storage" | wc -l)
    sleep 5
    middle_usb=$(lsusb | grep -iE "JMicron|SATA|USB.*Storage" | wc -l)
    sleep 5
    final_usb=$(lsusb | grep -iE "JMicron|SATA|USB.*Storage" | wc -l)
    
    if [ "$initial_usb" -eq "$middle_usb" ] && [ "$middle_usb" -eq "$final_usb" ] && [ "$initial_usb" -gt 0 ]; then
        log_success "USB连接稳定（10秒内无变化）"
    else
        log_error "USB设备在测试期间消失或重连！"
        log_warning "可能原因："
        echo "  • USB接口接触不良"
        echo "  • USB供电不稳定"
        echo "  • USB线缆质量问题"
        echo "  • 虚拟机反复尝试获取设备"
        add_issue
    fi
}

# 检查7: 分区和文件系统
check_partition_filesystem() {
    log_section "7. 分区和文件系统检测"
    
    if [ -z "${DETECTED_DISK:-}" ]; then
        log_info "跳过（设备不可用）"
        return
    fi
    
    local partition="/dev/${DETECTED_DISK}1"
    
    if [ -b "$partition" ]; then
        log_success "分区存在: $partition"
        
        local fs_type
        fs_type=$(blkid -o value -s TYPE "$partition" 2>/dev/null || echo "unknown")
        log_info "文件系统类型: $fs_type"
        
        if [ "$fs_type" = "unknown" ]; then
            log_warning "无法识别文件系统类型"
            echo "  可能是RAID或LVM"
        fi
    else
        log_error "分区 $partition 不存在"
        log_warning "可能原因："
        echo "  • 硬盘未初始化"
        echo "  • 分区表损坏"
        echo "  • SATA连接异常导致读取失败"
        add_issue
    fi
}

# 检查8: 磁盘读取测试
check_disk_read() {
    log_section "8. 磁盘读取测试"
    
    if [ -z "${DETECTED_DISK:-}" ]; then
        log_info "跳过（设备不可用）"
        return
    fi
    
    log_info "尝试读取磁盘前1MB数据..."
    
    if dd if="/dev/${DETECTED_DISK}" of=/dev/null bs=1M count=1 2>&1 | grep -q "1+0 records"; then
        log_success "磁盘可读取"
    else
        log_error "磁盘读取失败！"
        log_warning "这通常表示："
        echo "  • SATA连接松动导致无法读取"
        echo "  • 硬盘物理故障"
        echo "  • 设备被锁定（虚拟机占用）"
        add_issue
    fi
}

# ============================================
# 诊断总结
# ============================================

show_diagnosis_summary() {
    log_section "诊断总结"
    
    echo ""
    if [ "$ISSUE_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -eq 0 ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ 所有检查通过！设备健康状态良好${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    elif [ "$ISSUE_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}⚠ 发现 $WARNING_COUNT 个警告，设备可用但需注意${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}✗ 发现 $ISSUE_COUNT 个严重问题！${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        echo ""
        echo "📋 最可能的问题诊断："
        echo ""
        
        # 分析主要问题
        local has_usb_device
        local has_disk_device
        local has_vm
        
        has_usb_device=$(lsusb | grep -iE "JMicron|SATA|USB.*Storage" | head -1 || echo "")
        has_disk_device=$(ls /dev/sd* 2>/dev/null | grep -E "sd[a-z]$" | head -1 || echo "")
        has_vm=$(detect_vm_processes)
        
        if [ -n "$has_vm" ]; then
            echo -e "${RED}【高度怀疑】USB设备被虚拟机占用${NC}"
            echo ""
            echo "🔧 解决步骤："
            echo "  1. 在虚拟机管理器中分离USB设备"
            echo "  2. 或者暂停/关闭虚拟机"
            echo "  3. 或者设置 AUTO_RELEASE_FROM_VM=true 自动释放"
            echo ""
        fi
        
        if [ -z "$has_disk_device" ] && [ -n "$has_usb_device" ]; then
            echo -e "${RED}【高度怀疑】硬盘盒内SATA连接松动${NC}"
            echo ""
            echo "🔧 解决步骤："
            echo "  1. 拔出USB线缆和电源"
            echo "  2. 用螺丝刀打开硬盘盒"
            echo "  3. 检查SATA数据线（L型接口）"
            echo "  4. 检查SATA供电线（4针或15针）"
            echo "  5. 重新插紧，确保完全咬合"
            echo "  6. 关闭硬盘盒，重新测试"
            echo ""
        elif [ -z "$has_usb_device" ] && [ -z "$has_vm" ]; then
            echo -e "${RED}【高度怀疑】USB连接问题${NC}"
            echo ""
            echo "🔧 解决步骤："
            echo "  1. 检查USB线缆是否插紧"
            echo "  2. 更换USB接口（优先USB 3.0）"
            echo "  3. 更换USB线缆"
            echo "  4. 检查硬盘盒电源适配器"
        else
            echo -e "${YELLOW}【需要进一步检查】多种可能原因${NC}"
            echo ""
            echo "  • 查看内核日志: dmesg | tail -50"
            if [ -n "$has_disk_device" ]; then
                echo "  • 检查SMART状态: smartctl -a $has_disk_device"
            fi
            echo "  • 重新连接硬件后再次诊断"
        fi
    fi
    
    echo ""
    log_info "诊断完成！"
    echo ""
}

# ============================================
# 主函数
# ============================================

main() {
    # 初始化
    init_environment "diagnose"
    
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   USB移动硬盘健康诊断工具 v${SCRIPT_VERSION}      ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    # 检查root权限
    check_root
    
    # 加载配置
    load_config "$PROJECT_ROOT/config/usb_backup.conf" || true
    
    # 执行所有检查
    check_usb_device_presence
    check_disk_device_node
    check_vm_occupation
    check_kernel_logs
    check_smart_status
    check_usb_stability
    check_partition_filesystem
    check_disk_read
    
    # 显示总结
    show_diagnosis_summary
    
    # 记录日志
    log_to_file "诊断完成: $ISSUE_COUNT 个问题, $WARNING_COUNT 个警告"
    
    exit $ISSUE_COUNT
}

# ============================================
# 执行主函数
# ============================================

main "$@"
