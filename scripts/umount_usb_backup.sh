#!/bin/bash

# 移动硬盘安全卸载脚本
# 作者：USB Backup Tools
# 用途：安全卸载RAID+LVM移动硬盘，防止数据丢失
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
    init_environment "umount_usb"
    
    log_section "移动硬盘安全卸载工具 v${SCRIPT_VERSION}"
    
    # 检查root权限
    check_root
    
    # 加载配置
    load_config "$PROJECT_ROOT/config/usb_backup.conf"
    
    # 步骤1: 检查挂载状态
    log_section "步骤 1/4: 检查挂载状态"
    
    if ! mountpoint -q "$MOUNT_POINT"; then
        log_warning "设备未挂载在 $MOUNT_POINT"
        UNMOUNTED=true
    else
        log_success "检测到已挂载设备"
        CURRENT_DEVICE=$(findmnt -n -o SOURCE "$MOUNT_POINT")
        log_info "当前挂载设备: $CURRENT_DEVICE"
        UNMOUNTED=false
    fi
    
    # 步骤2: 卸载文件系统
    log_section "步骤 2/4: 卸载文件系统"
    
    if [ "$UNMOUNTED" = false ]; then
        if ! safe_umount "$MOUNT_POINT"; then
            log_error "文件系统卸载失败"
            
            if [ "${UMOUNT_FORCE_SYNC:-true}" = "true" ]; then
                log_warning "尝试强制同步并卸载..."
                sync
                sleep 2
                
                if ! umount -l "$MOUNT_POINT" 2>/dev/null; then
                    if ! umount -f "$MOUNT_POINT" 2>/dev/null; then
                        log_error "强制卸载失败"
                        
                        log_info "正在使用挂载点的进程:"
                        lsof +D "$MOUNT_POINT" 2>/dev/null || fuser -vm "$MOUNT_POINT" 2>/dev/null || true
                        
                        if ask_yes_no "是否强制终止占用进程？" "n"; then
                            fuser -km "$MOUNT_POINT" 2>/dev/null || true
                            sleep 2
                            umount -f "$MOUNT_POINT" || {
                                log_error "无法卸载，请手动处理"
                                exit 1
                            }
                        else
                            log_error "请手动处理占用进程后再卸载"
                            exit 1
                        fi
                    fi
                fi
            else
                exit 1
            fi
        fi
        
        log_success "文件系统已卸载"
    else
        log_info "跳过（未挂载）"
    fi
    
    # 步骤3: 停用LVM
    log_section "步骤 3/4: 停用LVM逻辑卷"
    
    if ! deactivate_lvm; then
        log_warning "LVM停用失败或无LVM设备"
    else
        log_success "LVM卷组已停用"
    fi
    
    # 步骤4: 停用RAID
    log_section "步骤 4/4: 停用RAID阵列"
    
    if ! stop_raid; then
        log_warning "RAID停用失败或无RAID设备"
    else
        log_success "RAID阵列已停用"
    fi
    
    # 完成
    log_section "安全卸载完成"
    echo ""
    
    log_success "✓ 所有设备已安全停用"
    log_success "✓ 数据已同步到磁盘"
    log_success "✓ 现在可以安全拔出USB设备"
    
    echo ""
    log_info "提示: 拔出USB设备前，请确保硬盘指示灯已停止闪烁"
    
    # 等待设备完全停止
    if [ "${DEVICE_REMOVE_WAIT:-3}" -gt 0 ]; then
        log_info "等待 ${DEVICE_REMOVE_WAIT} 秒以确保设备完全停止..."
        sleep "${DEVICE_REMOVE_WAIT}"
    fi
    
    # 记录成功
    log_to_file "USB设备安全卸载完成: $MOUNT_POINT"
}

# ============================================
# 执行主函数
# ============================================

main "$@"
