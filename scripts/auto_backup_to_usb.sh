#!/bin/bash

# 自动备份到移动硬盘脚本
# 作者：USB Backup Tools
# 用途：自动备份系统数据到移动硬盘
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
# 备份函数
# ============================================

# 执行备份
perform_backup() {
    local source="$1"
    local destination="$2"
    
    log_info "备份方式: rsync增量备份"
    log_info "源目录: $source"
    log_info "目标目录: $destination"
    log_info "这可能需要较长时间，请耐心等待..."
    echo ""
    
    # 开始计时
    local start_time
    start_time=$(date +%s)
    
    # 构建rsync排除参数
    local exclude_args=""
    if [ -n "${RSYNC_EXCLUDE_PATTERNS:-}" ]; then
        while IFS= read -r pattern; do
            pattern=$(echo "$pattern" | xargs)  # 去除空白
            if [ -n "$pattern" ]; then
                exclude_args="$exclude_args --exclude=$pattern"
            fi
        done <<< "$RSYNC_EXCLUDE_PATTERNS"
    fi
    
    # 构建rsync命令
    local rsync_cmd="rsync -avh"
    
    # 显示进度
    if [ "${BACKUP_SHOW_PROGRESS:-true}" = "true" ]; then
        rsync_cmd="$rsync_cmd --progress"
    fi
    
    # 压缩传输
    if [ "${BACKUP_COMPRESS:-false}" = "true" ]; then
        rsync_cmd="$rsync_cmd --compress"
    fi
    
    # 添加排除规则
    rsync_cmd="$rsync_cmd $exclude_args"
    
    # 源和目标
    rsync_cmd="$rsync_cmd \"$source/\" \"$destination/\""
    
    # 执行备份
    log_debug "执行命令: $rsync_cmd"
    
    if eval "$rsync_cmd" 2>&1 | tee -a "$LOG_FILE"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local duration_min=$((duration / 60))
        local duration_sec=$((duration % 60))
        
        log_success "备份完成！用时: ${duration_min}分${duration_sec}秒"
        
        # 返回备份信息
        echo "$duration"
        return 0
    else
        log_error "备份失败"
        return 1
    fi
}

# 创建备份元数据
create_backup_metadata() {
    local backup_dir="$1"
    local duration="$2"
    local source_size="$3"
    
    local duration_min=$((duration / 60))
    local duration_sec=$((duration % 60))
    local source_size_gb
    source_size_gb=$(echo "scale=2; $source_size / 1024 / 1024 / 1024" | bc)
    
    cat > "$backup_dir/backup_info.txt" << EOF
备份时间: $(date "+%Y-%m-%d %H:%M:%S")
备份源: $SOURCE_DIR
备份大小: ${source_size_gb}GB
备份用时: ${duration_min}分${duration_sec}秒
系统信息: $(uname -a)
主机名: $(hostname)
备份工具版本: $SCRIPT_VERSION
EOF
    
    log_success "元数据已保存: $backup_dir/backup_info.txt"
}

# 清理旧备份
cleanup_old_backups() {
    local backup_base="$1"
    local keep_count="${2:-5}"
    
    log_info "清理旧备份（保留最近 $keep_count 个）..."
    
    cd "$backup_base" || return 1
    
    local backup_count
    backup_count=$(ls -t 2>/dev/null | grep -c "^backup_" || echo "0")
    
    if [ "$backup_count" -le "$keep_count" ]; then
        log_info "当前备份数量: $backup_count，无需清理"
        return 0
    fi
    
    local to_delete
    to_delete=$(ls -t | grep "^backup_" | tail -n +$((keep_count + 1)))
    
    if [ -n "$to_delete" ]; then
        log_info "将删除以下旧备份:"
        echo "$to_delete" | sed 's/^/  - /'
        
        if [ "${NON_INTERACTIVE:-false}" = "true" ] || ask_yes_no "确认删除？" "y"; then
            echo "$to_delete" | xargs -r rm -rf
            log_success "旧备份已清理"
        else
            log_info "跳过清理"
        fi
    fi
}

# 验证备份完整性
verify_backup() {
    local source="$1"
    local destination="$2"
    
    log_info "验证备份完整性..."
    
    # 比较文件数量
    local source_count
    local dest_count
    source_count=$(find "$source" -type f 2>/dev/null | wc -l)
    dest_count=$(find "$destination" -type f 2>/dev/null | wc -l)
    
    log_info "源文件数量: $source_count"
    log_info "备份文件数量: $dest_count"
    
    if [ "$source_count" -eq "$dest_count" ]; then
        log_success "文件数量一致"
        return 0
    else
        local diff=$((source_count - dest_count))
        log_warning "文件数量不一致，差异: $diff 个文件"
        return 1
    fi
}

# ============================================
# 主函数
# ============================================

main() {
    # 初始化
    init_environment "auto_backup"
    
    log_section "飞牛OS 自动备份工具 v${SCRIPT_VERSION}"
    
    # 检查root权限
    check_root
    
    # 加载配置
    load_config "$PROJECT_ROOT/config/usb_backup.conf"
    
    # 步骤1: 检查挂载点
    log_section "步骤 1/7: 检查移动硬盘挂载状态"
    
    if ! mountpoint -q "$MOUNT_POINT"; then
        log_error "移动硬盘未挂载在 $MOUNT_POINT"
        log_info "请先运行挂载脚本:"
        log_info "  bash $SCRIPT_DIR/mount_usb_backup.sh"
        exit 1
    fi
    
    log_success "移动硬盘已挂载"
    
    CURRENT_DEVICE=$(findmnt -n -o SOURCE "$MOUNT_POINT")
    log_info "挂载设备: $CURRENT_DEVICE"
    
    # 步骤2: 创建备份目录
    log_section "步骤 2/7: 创建备份目录"
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="$BACKUP_BASE_DIR/backup_$TIMESTAMP"
    
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$BACKUP_BASE_DIR"
    
    log_success "备份目录: $BACKUP_DIR"
    
    # 步骤3: 检查源目录
    log_section "步骤 3/7: 检查源目录"
    
    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "源目录不存在: $SOURCE_DIR"
        exit 1
    fi
    
    log_success "源目录存在: $SOURCE_DIR"
    
    # 步骤4: 检查磁盘空间
    log_section "步骤 4/7: 检查磁盘空间"
    
    if ! check_disk_space "$SOURCE_DIR" "$MOUNT_POINT"; then
        log_error "磁盘空间不足，备份中止"
        
        if [ "${DISK_SPACE_ACTION:-abort}" = "warn" ]; then
            if ! ask_yes_no "是否继续备份（可能失败）？" "n"; then
                exit 1
            fi
        else
            exit 1
        fi
    fi
    
    log_success "磁盘空间充足"
    
    # 步骤5: 执行备份前钩子
    if [ -n "${PRE_BACKUP_HOOK:-}" ] && [ -x "$PRE_BACKUP_HOOK" ]; then
        log_info "执行备份前钩子: $PRE_BACKUP_HOOK"
        "$PRE_BACKUP_HOOK" || log_warning "钩子执行失败"
    fi
    
    # 步骤6: 执行备份
    log_section "步骤 5/7: 执行备份"
    
    DURATION=$(perform_backup "$SOURCE_DIR" "$BACKUP_DIR")
    
    if [ $? -ne 0 ]; then
        log_error "备份失败"
        exit 1
    fi
    
    # 步骤7: 创建备份元数据
    log_section "步骤 6/7: 创建备份元数据"
    
    SOURCE_SIZE=$(du -sb "$SOURCE_DIR" 2>/dev/null | awk '{print $1}' || echo "0")
    create_backup_metadata "$BACKUP_DIR" "$DURATION" "$SOURCE_SIZE"
    
    # 步骤8: 验证备份（可选）
    if [ "${BACKUP_VERIFY:-false}" = "true" ]; then
        log_section "步骤 7/7: 验证备份"
        verify_backup "$SOURCE_DIR" "$BACKUP_DIR" || log_warning "备份验证有差异"
    fi
    
    # 执行备份后钩子
    if [ -n "${POST_BACKUP_HOOK:-}" ] && [ -x "$POST_BACKUP_HOOK" ]; then
        log_info "执行备份后钩子: $POST_BACKUP_HOOK"
        "$POST_BACKUP_HOOK" || log_warning "钩子执行失败"
    fi
    
    # 清理旧备份
    log_section "清理旧备份"
    cleanup_old_backups "$BACKUP_BASE_DIR" "${KEEP_BACKUPS:-5}"
    
    # 显示备份列表
    log_section "备份完成"
    echo ""
    
    log_success "✓ 备份成功完成"
    echo ""
    
    log_info "当前所有备份:"
    ls -lth "$BACKUP_BASE_DIR" 2>/dev/null | grep "^d" | head -5 || echo "  (无法列出)"
    
    echo ""
    log_info "最新备份位置: $BACKUP_DIR"
    
    SOURCE_SIZE_GB=$(echo "scale=2; $SOURCE_SIZE / 1024 / 1024 / 1024" | bc)
    DURATION_MIN=$((DURATION / 60))
    DURATION_SEC=$((DURATION % 60))
    
    echo ""
    log_info "备份统计:"
    echo "  • 备份大小: ${SOURCE_SIZE_GB}GB"
    echo "  • 用时: ${DURATION_MIN}分${DURATION_SEC}秒"
    echo "  • 时间戳: $TIMESTAMP"
    
    # 记录日志
    cat >> "$LOG_FILE" << EOF

===== 备份记录 =====
时间: $(date)
大小: ${SOURCE_SIZE_GB}GB
用时: ${DURATION_MIN}分${DURATION_SEC}秒
位置: $BACKUP_DIR
===================

EOF
    
    log_to_file "备份完成: $SOURCE_DIR -> $BACKUP_DIR (${SOURCE_SIZE_GB}GB)"
}

# ============================================
# 执行主函数
# ============================================

main "$@"
