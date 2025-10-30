#!/bin/bash

# USB备份管理器主控脚本
# 作者：自动生成
# 用途：统一管理USB备份相关操作

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOUNT_POINT="/mnt/usb_backup"

# 显示菜单
show_menu() {
    clear
    echo -e "${CYAN}=========================================="
    echo -e "    USB备份管理器"
    echo -e "==========================================${NC}"
    echo ""
    
    # 检查挂载状态
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        echo -e "${GREEN}● 状态: 已挂载${NC}"
        DISK_INFO=$(df -h "$MOUNT_POINT" | tail -1)
        USED=$(echo "$DISK_INFO" | awk '{print $3}')
        AVAIL=$(echo "$DISK_INFO" | awk '{print $4}')
        USE_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}')
        echo -e "  已用: $USED | 可用: $AVAIL | 使用率: $USE_PERCENT"
    else
        echo -e "${RED}● 状态: 未挂载${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}请选择操作:${NC}"
    echo ""
    echo "  1) 挂载移动硬盘"
    echo "  2) 卸载移动硬盘"
    echo "  3) 开始备份"
    echo "  4) 查看备份历史"
    echo "  5) 恢复备份"
    echo "  6) 查看USB状态"
    echo "  7) 测试读写速度"
    echo "  0) 退出"
    echo ""
    echo -ne "${BLUE}请输入选项 [0-7]: ${NC}"
}

# 挂载移动硬盘
mount_usb() {
    echo ""
    echo -e "${BLUE}正在挂载移动硬盘...${NC}"
    bash "$SCRIPT_DIR/mount_usb_backup.sh"
    echo ""
    echo -ne "按回车键继续..."
    read
}

# 卸载移动硬盘
umount_usb() {
    echo ""
    echo -e "${BLUE}正在安全卸载移动硬盘...${NC}"
    bash "$SCRIPT_DIR/umount_usb_backup.sh"
    echo ""
    echo -ne "按回车键继续..."
    read
}

# 开始备份
start_backup() {
    echo ""
    if ! mountpoint -q "$MOUNT_POINT"; then
        echo -e "${RED}错误: 移动硬盘未挂载${NC}"
        echo -ne "按回车键返回..."
        read
        return
    fi
    
    echo -e "${BLUE}开始备份到移动硬盘...${NC}"
    bash "$SCRIPT_DIR/auto_backup_to_usb.sh"
    echo ""
    echo -ne "按回车键继续..."
    read
}

# 查看备份历史
view_backup_history() {
    echo ""
    if ! mountpoint -q "$MOUNT_POINT"; then
        echo -e "${RED}错误: 移动硬盘未挂载${NC}"
        echo -ne "按回车键返回..."
        read
        return
    fi
    
    BACKUP_DIR="$MOUNT_POINT/fnos_backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}没有找到备份历史${NC}"
        echo -ne "按回车键返回..."
        read
        return
    fi
    
    echo -e "${GREEN}备份历史:${NC}"
    echo ""
    ls -lth "$BACKUP_DIR" | grep "^d" | nl
    echo ""
    
    if [ -f "$BACKUP_DIR/backup.log" ]; then
        echo -e "${GREEN}最近备份日志:${NC}"
        tail -20 "$BACKUP_DIR/backup.log"
    fi
    
    echo ""
    echo -ne "按回车键继续..."
    read
}

# 恢复备份
restore_backup() {
    echo ""
    if ! mountpoint -q "$MOUNT_POINT"; then
        echo -e "${RED}错误: 移动硬盘未挂载${NC}"
        echo -ne "按回车键返回..."
        read
        return
    fi
    
    BACKUP_DIR="$MOUNT_POINT/fnos_backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}没有找到备份${NC}"
        echo -ne "按回车键返回..."
        read
        return
    fi
    
    echo -e "${GREEN}可用备份:${NC}"
    echo ""
    BACKUPS=($(ls -t "$BACKUP_DIR" | grep "^backup_"))
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}没有找到备份${NC}"
        echo -ne "按回车键返回..."
        read
        return
    fi
    
    for i in "${!BACKUPS[@]}"; do
        echo "  $((i+1))) ${BACKUPS[$i]}"
        if [ -f "$BACKUP_DIR/${BACKUPS[$i]}/backup_info.txt" ]; then
            cat "$BACKUP_DIR/${BACKUPS[$i]}/backup_info.txt" | sed 's/^/     /'
        fi
        echo ""
    done
    
    echo -ne "${BLUE}选择要恢复的备份 [1-${#BACKUPS[@]}] (0取消): ${NC}"
    read choice
    
    if [ "$choice" = "0" ]; then
        return
    fi
    
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#BACKUPS[@]}" ]; then
        SELECTED_BACKUP="${BACKUPS[$((choice-1))]}"
        echo ""
        echo -e "${RED}警告: 恢复操作将覆盖当前数据！${NC}"
        echo -ne "${YELLOW}确认恢复 $SELECTED_BACKUP? (yes/no): ${NC}"
        read confirm
        
        if [ "$confirm" = "yes" ]; then
            echo ""
            echo -e "${BLUE}开始恢复...${NC}"
            rsync -avh --progress "$BACKUP_DIR/$SELECTED_BACKUP/" /vol1/
            echo ""
            echo -e "${GREEN}恢复完成！${NC}"
        else
            echo -e "${YELLOW}已取消${NC}"
        fi
    fi
    
    echo ""
    echo -ne "按回车键继续..."
    read
}

# 查看USB状态
view_usb_status() {
    echo ""
    echo -e "${GREEN}USB设备状态:${NC}"
    echo ""
    echo "=== USB设备列表 ==="
    lsusb | grep -E "JMicron|SATA|Storage" || echo "未找到USB存储设备"
    echo ""
    echo "=== 块设备 ==="
    lsblk | grep -E "sd|md|dm" || echo "未找到存储设备"
    echo ""
    echo "=== RAID状态 ==="
    cat /proc/mdstat
    echo ""
    echo "=== LVM状态 ==="
    pvs 2>/dev/null || echo "无物理卷"
    echo ""
    lvs 2>/dev/null || echo "无逻辑卷"
    echo ""
    echo -ne "按回车键继续..."
    read
}

# 测试读写速度
test_speed() {
    echo ""
    if ! mountpoint -q "$MOUNT_POINT"; then
        echo -e "${RED}错误: 移动硬盘未挂载${NC}"
        echo -ne "按回车键返回..."
        read
        return
    fi
    
    TEST_FILE="$MOUNT_POINT/speed_test.tmp"
    
    echo -e "${BLUE}测试写入速度（1GB）...${NC}"
    WRITE_SPEED=$(dd if=/dev/zero of="$TEST_FILE" bs=1M count=1024 2>&1 | grep -o "[0-9.]* MB/s")
    echo -e "${GREEN}写入速度: $WRITE_SPEED${NC}"
    echo ""
    
    echo -e "${BLUE}清空缓存...${NC}"
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo ""
    
    echo -e "${BLUE}测试读取速度（1GB）...${NC}"
    READ_SPEED=$(dd if="$TEST_FILE" of=/dev/null bs=1M 2>&1 | grep -o "[0-9.]* MB/s")
    echo -e "${GREEN}读取速度: $READ_SPEED${NC}"
    echo ""
    
    rm -f "$TEST_FILE"
    
    echo -e "${GREEN}速度测试完成${NC}"
    echo ""
    echo -ne "按回车键继续..."
    read
}

# 主循环
while true; do
    show_menu
    read choice
    
    case $choice in
        1) mount_usb ;;
        2) umount_usb ;;
        3) start_backup ;;
        4) view_backup_history ;;
        5) restore_backup ;;
        6) view_usb_status ;;
        7) test_speed ;;
        0) 
            echo ""
            echo -e "${GREEN}再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项${NC}"
            sleep 1
            ;;
    esac
done

