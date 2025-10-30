#!/bin/bash

# 移动硬盘自动挂载脚本（支持RAID+LVM）
# 作者：USB Backup Tools
# 用途：自动检测并挂载复杂的移动硬盘（RAID/LVM）
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
# 主函数
# ============================================

main() {
    # 初始化
    init_environment "mount_usb"
    
    log_section "移动硬盘自动挂载工具 v${SCRIPT_VERSION}"
    
    # 检查root权限
    check_root
    
    # 加载配置
    load_config "$PROJECT_ROOT/config/usb_backup.conf"
    
    # 步骤1: 检测USB设备
    log_section "步骤 1/5: 检测USB设备"
    if ! detect_usb_device; then
        log_error "USB设备检测失败"
        exit 1
    fi
    
    # 步骤2: 查找硬盘设备
    log_section "步骤 2/5: 查找硬盘设备"
    if ! find_disk_device; then
        log_error "未找到硬盘设备"
        log_info "提示: 可以运行诊断脚本检查问题"
        log_info "  bash $SCRIPT_DIR/diagnose_usb_disk.sh"
        exit 1
    fi
    
    DISK_DEVICE="$DETECTED_DISK_DEVICE"
    log_success "找到硬盘: $DISK_DEVICE"
    
    # 步骤3: 分析分区类型
    log_section "步骤 3/5: 分析分区类型"
    
    PARTITION="${DISK_DEVICE}1"
    if [ ! -b "$PARTITION" ]; then
        log_error "分区 $PARTITION 不存在"
        log_info "磁盘分区列表:"
        lsblk "$DISK_DEVICE" 2>/dev/null || true
        exit 1
    fi
    
    FS_TYPE=$(blkid -o value -s TYPE "$PARTITION" 2>/dev/null || echo "unknown")
    log_info "分区类型: $FS_TYPE"
    
    # 步骤4: 处理RAID和LVM
    log_section "步骤 4/5: 处理RAID和LVM"
    
    MOUNT_DEVICE=""
    
    # 处理RAID设备
    if [ "$FS_TYPE" = "linux_raid_member" ]; then
        log_warning "检测到RAID成员，正在组装RAID阵列..."
        
        if ! assemble_raid; then
            log_error "RAID组装失败"
            exit 1
        fi
        
        RAID_DEVICE="$ASSEMBLED_RAID_DEVICE"
        log_success "RAID设备已激活: $RAID_DEVICE"
        
        # 检查RAID设备类型
        RAID_TYPE=$(blkid -o value -s TYPE "$RAID_DEVICE" 2>/dev/null || echo "unknown")
        log_info "RAID设备类型: $RAID_TYPE"
        
        # 处理LVM
        if [ "$RAID_TYPE" = "LVM2_member" ]; then
            log_warning "检测到LVM2成员，正在激活逻辑卷..."
            
            if ! activate_lvm; then
                log_error "LVM激活失败"
                exit 1
            fi
            
            LV_DEVICE="$ACTIVATED_LV_DEVICE"
            log_success "逻辑卷已激活: $LV_DEVICE"
            MOUNT_DEVICE="$LV_DEVICE"
        else
            MOUNT_DEVICE="$RAID_DEVICE"
        fi
    elif [ "$FS_TYPE" = "LVM2_member" ]; then
        # 直接是LVM（没有RAID）
        log_warning "检测到LVM2成员，正在激活逻辑卷..."
        
        if ! activate_lvm; then
            log_error "LVM激活失败"
            exit 1
        fi
        
        LV_DEVICE="$ACTIVATED_LV_DEVICE"
        log_success "逻辑卷已激活: $LV_DEVICE"
        MOUNT_DEVICE="$LV_DEVICE"
    else
        # 普通分区
        MOUNT_DEVICE="$PARTITION"
    fi
    
    if [ -z "$MOUNT_DEVICE" ]; then
        log_error "无法确定挂载设备"
        exit 1
    fi
    
    log_info "将要挂载的设备: $MOUNT_DEVICE"
    
    # 步骤5: 挂载设备
    log_section "步骤 5/5: 挂载设备"
    
    # 创建挂载点
    mkdir -p "$MOUNT_POINT"
    
    # 检查是否已挂载
    if mountpoint -q "$MOUNT_POINT"; then
        log_warning "设备已挂载在 $MOUNT_POINT"
        CURRENT_DEVICE=$(findmnt -n -o SOURCE "$MOUNT_POINT")
        log_info "当前挂载设备: $CURRENT_DEVICE"
        
        if [ "$CURRENT_DEVICE" = "$MOUNT_DEVICE" ]; then
            log_success "目标设备已正确挂载"
        else
            log_warning "挂载点被其他设备占用"
            
            if ask_yes_no "是否卸载当前设备并重新挂载？"; then
                umount "$MOUNT_POINT"
                mount "$MOUNT_DEVICE" "$MOUNT_POINT"
                log_success "设备已重新挂载到: $MOUNT_POINT"
            fi
        fi
    else
        mount "$MOUNT_DEVICE" "$MOUNT_POINT"
        log_success "设备已挂载到: $MOUNT_POINT"
    fi
    
    # 显示挂载信息
    log_section "挂载完成"
    echo ""
    
    log_info "磁盘使用情况:"
    df -h "$MOUNT_POINT" | tail -1 | awk '{
        printf "  容量:   %s\n", $2
        printf "  已用:   %s\n", $3
        printf "  可用:   %s\n", $4
        printf "  使用率: %s\n", $5
    }'
    
    echo ""
    log_info "内容预览:"
    ls -lh "$MOUNT_POINT" 2>/dev/null | head -10 || log_warning "无法列出目录内容"
    
    echo ""
    log_success "挂载成功！挂载点: $MOUNT_POINT"
    
    # 记录成功
    log_to_file "USB设备挂载成功: $MOUNT_DEVICE -> $MOUNT_POINT"
}

# ============================================
# 执行主函数
# ============================================

main "$@"
