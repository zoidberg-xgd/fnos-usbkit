#!/bin/bash

# USB备份工具 - 公共函数库
# 版本: 1.0.0
# 用途: 提供通用的日志、设备检测、错误处理等功能

# ============================================
# 颜色定义
# ============================================
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m'  # No Color

# ============================================
# 全局变量
# ============================================
export SCRIPT_VERSION="1.0.0"
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LIB_DIR="$SCRIPT_DIR"
export CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"
export LOG_DIR="/var/log/usb-backup"
export LOG_FILE="$LOG_DIR/usb-backup.log"

# ============================================
# 日志函数
# ============================================

# 创建日志目录
init_logging() {
    mkdir -p "$LOG_DIR" 2>/dev/null || true
}

# 日志到文件和控制台
log_to_file() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" >> "$LOG_FILE" 2>/dev/null || true
}

# 信息日志
log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $message"
    log_to_file "INFO: $message"
}

# 成功日志
log_success() {
    local message="$1"
    echo -e "${GREEN}[✓]${NC} $message"
    log_to_file "SUCCESS: $message"
}

# 警告日志
log_warning() {
    local message="$1"
    echo -e "${YELLOW}[⚠]${NC} $message"
    log_to_file "WARNING: $message"
}

# 错误日志
log_error() {
    local message="$1"
    echo -e "${RED}[✗]${NC} $message" >&2
    log_to_file "ERROR: $message"
}

# 调试日志（仅在DEBUG模式下显示）
log_debug() {
    local message="$1"
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${CYAN}[DEBUG]${NC} $message"
        log_to_file "DEBUG: $message"
    fi
}

# 分隔线
log_section() {
    local title="$1"
    echo ""
    echo -e "${MAGENTA}════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} $title${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════${NC}"
    log_to_file "SECTION: $title"
}

# ============================================
# 权限检查
# ============================================

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# ============================================
# 配置文件加载
# ============================================

load_config() {
    local config_file="$1"
    
    if [ -z "$config_file" ]; then
        config_file="$CONFIG_DIR/usb_backup.conf"
    fi
    
    if [ -f "$config_file" ]; then
        log_debug "加载配置文件: $config_file"
        # shellcheck disable=SC1090
        source "$config_file"
        log_success "配置文件已加载"
        return 0
    else
        log_warning "配置文件不存在: $config_file"
        log_info "将使用默认配置"
        return 1
    fi
}

# ============================================
# 虚拟机USB占用检测与释放
# ============================================

# 检测虚拟机进程
detect_vm_processes() {
    local vm_processes=""
    
    # 检测QEMU/KVM
    if pgrep -f "qemu" > /dev/null 2>&1; then
        vm_processes="$vm_processes QEMU/KVM"
    fi
    
    # 检测VirtualBox
    if pgrep -f "VBoxHeadless\|VirtualBox" > /dev/null 2>&1; then
        vm_processes="$vm_processes VirtualBox"
    fi
    
    # 检测VMware
    if pgrep -f "vmware" > /dev/null 2>&1; then
        vm_processes="$vm_processes VMware"
    fi
    
    echo "$vm_processes" | xargs
}

# 检查USB设备是否被虚拟机占用
check_usb_vm_conflict() {
    local usb_bus="$1"
    local usb_device="$2"
    
    log_debug "检查USB设备是否被虚拟机占用: Bus $usb_bus Device $usb_device"
    
    # 检测虚拟机进程
    local vm_list
    vm_list=$(detect_vm_processes)
    
    if [ -z "$vm_list" ]; then
        log_debug "未检测到运行中的虚拟机"
        return 0
    fi
    
    log_warning "检测到运行中的虚拟机: $vm_list"
    
    # 检查设备是否被占用（通过lsof检查）
    local usb_path="/dev/bus/usb/${usb_bus}/${usb_device}"
    if [ -e "$usb_path" ]; then
        local processes
        processes=$(lsof "$usb_path" 2>/dev/null | tail -n +2 || true)
        
        if [ -n "$processes" ]; then
            log_error "USB设备正在被以下进程占用:"
            echo "$processes"
            return 1
        fi
    fi
    
    return 0
}

# 从虚拟机释放USB设备
release_usb_from_vm() {
    local usb_bus="$1"
    local usb_device="$2"
    local force="${3:-false}"
    
    log_section "从虚拟机释放USB设备"
    
    # 检测正在运行的虚拟机
    local vm_list
    vm_list=$(detect_vm_processes)
    
    if [ -z "$vm_list" ]; then
        log_info "未检测到运行中的虚拟机"
        return 0
    fi
    
    log_warning "检测到虚拟机: $vm_list"
    
    # 1. 尝试通过virsh释放设备（KVM/QEMU）
    if command -v virsh > /dev/null 2>&1; then
        log_info "尝试通过virsh释放USB设备..."
        
        # 列出所有运行中的虚拟机
        local vms
        vms=$(virsh list --name 2>/dev/null | grep -v "^$" || true)
        
        if [ -n "$vms" ]; then
            for vm in $vms; do
                log_info "检查虚拟机: $vm"
                
                # 获取虚拟机的USB设备配置
                local usb_devices
                usb_devices=$(virsh dumpxml "$vm" 2>/dev/null | grep -A5 "hostdev.*usb" || true)
                
                if echo "$usb_devices" | grep -q "bus='$usb_bus'.*device='$usb_device'"; then
                    log_warning "发现虚拟机 $vm 占用了USB设备"
                    
                    if [ "$force" = "true" ] || ask_yes_no "是否从虚拟机 $vm 中分离此USB设备？"; then
                        # 构造detach-device命令
                        log_info "正在从虚拟机分离USB设备..."
                        
                        # 这里需要具体的设备XML，实际使用中可能需要更复杂的逻辑
                        # 简化处理：暂停虚拟机
                        if [ "$force" = "true" ]; then
                            log_warning "强制暂停虚拟机: $vm"
                            virsh suspend "$vm" 2>/dev/null || true
                        fi
                    fi
                fi
            done
        fi
    fi
    
    # 2. 尝试解除内核USB设备占用
    log_info "尝试解除内核USB设备占用..."
    
    local usb_path="/sys/bus/usb/devices/${usb_bus}-*"
    for dev in $usb_path; do
        if [ -e "$dev/authorized" ]; then
            log_debug "重新授权USB设备: $dev"
            echo 0 > "$dev/authorized" 2>/dev/null || true
            sleep 1
            echo 1 > "$dev/authorized" 2>/dev/null || true
        fi
    done
    
    # 3. VirtualBox处理
    if pgrep -f "VBoxHeadless\|VirtualBox" > /dev/null 2>&1; then
        if command -v VBoxManage > /dev/null 2>&1; then
            log_info "检测到VirtualBox虚拟机..."
            
            # 获取运行中的VM
            local vbox_vms
            vbox_vms=$(VBoxManage list runningvms 2>/dev/null | awk -F'"' '{print $2}' || true)
            
            if [ -n "$vbox_vms" ]; then
                for vm in $vbox_vms; do
                    log_info "检查VirtualBox虚拟机: $vm"
                    
                    # 列出USB设备
                    local vm_usb
                    vm_usb=$(VBoxManage showvminfo "$vm" 2>/dev/null | grep -i "USB" || true)
                    
                    if [ -n "$vm_usb" ]; then
                        log_warning "虚拟机 $vm 可能占用了USB设备"
                        log_info "建议在VirtualBox界面中手动分离USB设备"
                    fi
                done
            fi
        fi
    fi
    
    log_success "USB设备释放处理完成"
    return 0
}

# 智能USB设备重置（解决占用问题）
reset_usb_device() {
    local vendor_id="$1"
    local product_id="$2"
    
    log_section "重置USB设备"
    
    log_info "设备ID: ${vendor_id}:${product_id}"
    
    # 方法1: 使用usbreset工具
    if command -v usbreset > /dev/null 2>&1; then
        log_info "使用usbreset重置设备..."
        usbreset "${vendor_id}:${product_id}" 2>/dev/null || true
        sleep 2
        return 0
    fi
    
    # 方法2: 通过sysfs重置
    log_info "通过sysfs重置USB设备..."
    
    for dev_path in /sys/bus/usb/devices/*; do
        if [ -f "$dev_path/idVendor" ] && [ -f "$dev_path/idProduct" ]; then
            local vid
            local pid
            vid=$(cat "$dev_path/idVendor" 2>/dev/null || echo "")
            pid=$(cat "$dev_path/idProduct" 2>/dev/null || echo "")
            
            if [ "$vid" = "$vendor_id" ] && [ "$pid" = "$product_id" ]; then
                log_info "找到设备: $dev_path"
                
                # 解除授权
                if [ -f "$dev_path/authorized" ]; then
                    echo 0 > "$dev_path/authorized" 2>/dev/null || true
                    sleep 1
                    echo 1 > "$dev_path/authorized" 2>/dev/null || true
                    log_success "设备已重置"
                fi
                
                # 解绑并重新绑定驱动
                local driver_path="$dev_path/driver"
                if [ -e "$driver_path" ]; then
                    local driver
                    driver=$(basename "$(readlink -f "$driver_path")")
                    local dev_name
                    dev_name=$(basename "$dev_path")
                    
                    log_info "解绑驱动: $driver"
                    echo "$dev_name" > "/sys/bus/usb/drivers/$driver/unbind" 2>/dev/null || true
                    sleep 1
                    echo "$dev_name" > "/sys/bus/usb/drivers/$driver/bind" 2>/dev/null || true
                    log_success "驱动已重新绑定"
                fi
                
                return 0
            fi
        fi
    done
    
    log_warning "未找到匹配的USB设备"
    return 1
}

# ============================================
# USB设备检测
# ============================================

# 检测USB存储设备
detect_usb_device() {
    local vendor_filter="${USB_VENDOR_FILTER:-JMicron|SATA|USB.*Storage|ASMedia}"
    local timeout="${USB_DETECTION_TIMEOUT:-10}"
    
    log_debug "USB厂商过滤器: $vendor_filter"
    
    local usb_device
    usb_device=$(lsusb | grep -iE "$vendor_filter" | head -1 || true)
    
    if [ -z "$usb_device" ]; then
        log_error "未检测到USB存储设备"
        log_info "请检查："
        echo "  • USB线缆是否连接"
        echo "  • 硬盘盒电源是否开启"
        echo "  • USB接口是否正常"
        echo "  • 设备是否被虚拟机占用"
        
        # 检查虚拟机占用
        local vm_list
        vm_list=$(detect_vm_processes)
        if [ -n "$vm_list" ]; then
            log_warning "检测到运行中的虚拟机: $vm_list"
            log_info "USB设备可能被虚拟机占用"
        fi
        
        return 1
    fi
    
    log_success "检测到USB设备: $usb_device"
    
    # 提取Bus和Device号
    local bus_num
    local dev_num
    bus_num=$(echo "$usb_device" | grep -oP 'Bus \K\d+' || echo "")
    dev_num=$(echo "$usb_device" | grep -oP 'Device \K\d+' || echo "")
    
    # 提取Vendor ID和Product ID
    local vendor_id
    local product_id
    vendor_id=$(echo "$usb_device" | grep -oP 'ID \K[0-9a-f]{4}' | head -1 || echo "")
    product_id=$(echo "$usb_device" | grep -oP 'ID [0-9a-f]{4}:\K[0-9a-f]{4}' || echo "")
    
    log_debug "USB Bus: $bus_num, Device: $dev_num"
    log_debug "Vendor ID: $vendor_id, Product ID: $product_id"
    
    # 检查虚拟机占用
    if ! check_usb_vm_conflict "$bus_num" "$dev_num"; then
        log_warning "USB设备可能被虚拟机占用"
        
        if [ "${AUTO_RELEASE_FROM_VM:-false}" = "true" ]; then
            log_info "尝试自动释放设备..."
            release_usb_from_vm "$bus_num" "$dev_num" "true"
        else
            log_info "提示：可以设置 AUTO_RELEASE_FROM_VM=true 自动释放设备"
            
            if ask_yes_no "是否尝试从虚拟机释放USB设备？"; then
                release_usb_from_vm "$bus_num" "$dev_num" "false"
            fi
        fi
    fi
    
    # 导出设备信息供其他函数使用
    export USB_BUS="$bus_num"
    export USB_DEVICE="$dev_num"
    export USB_VENDOR_ID="$vendor_id"
    export USB_PRODUCT_ID="$product_id"
    
    return 0
}

# 查找硬盘设备节点
find_disk_device() {
    local wait_time="${DEVICE_WAIT_TIME:-3}"
    
    log_info "等待设备稳定 (${wait_time}秒)..."
    sleep "$wait_time"
    
    local disk_device
    disk_device=$(ls /dev/sd* 2>/dev/null | grep -E "sd[a-z]$" | head -1 || true)
    
    if [ -z "$disk_device" ]; then
        log_warning "未找到硬盘设备，尝试强制扫描SCSI总线..."
        
        # 强制扫描SCSI总线
        for host in /sys/class/scsi_host/host*/scan; do
            if [ -f "$host" ]; then
                echo "- - -" > "$host" 2>/dev/null || true
            fi
        done
        
        sleep "$wait_time"
        disk_device=$(ls /dev/sd* 2>/dev/null | grep -E "sd[a-z]$" | head -1 || true)
        
        if [ -z "$disk_device" ]; then
            log_error "强制扫描后仍未找到设备"
            log_info "可能原因："
            echo "  • 硬盘盒内SATA连接松动"
            echo "  • 硬盘故障"
            echo "  • USB桥接芯片异常"
            return 1
        fi
        
        log_success "强制扫描后找到设备"
    fi
    
    log_success "找到硬盘设备: $disk_device"
    echo "$disk_device"
    return 0
}

# ============================================
# RAID管理
# ============================================

# 检测RAID成员
is_raid_member() {
    local device="$1"
    local fs_type
    fs_type=$(blkid -o value -s TYPE "$device" 2>/dev/null || echo "unknown")
    
    [ "$fs_type" = "linux_raid_member" ]
}

# 组装RAID阵列
assemble_raid() {
    log_info "正在组装RAID阵列..."
    
    # 组装所有可用的RAID阵列
    mdadm --assemble --scan --verbose 2>&1 | grep -E "started|active" || true
    
    local wait_time="${RAID_WAIT_TIME:-3}"
    sleep "$wait_time"
    
    # 查找新创建的RAID设备（排除系统RAID）
    local raid_device
    raid_device=$(grep -oE "md[0-9]+" /proc/mdstat | grep -v "md0" | tail -1 || true)
    
    if [ -z "$raid_device" ]; then
        log_error "RAID组装失败，未找到RAID设备"
        return 1
    fi
    
    raid_device="/dev/$raid_device"
    log_success "RAID设备已激活: $raid_device"
    
    # 显示RAID状态
    local raid_level
    raid_level=$(mdadm --detail "$raid_device" 2>/dev/null | grep "Raid Level" | awk '{print $4}' || echo "unknown")
    log_info "RAID级别: $raid_level"
    
    echo "$raid_device"
    return 0
}

# 停用RAID阵列
stop_raid() {
    local exclude_devices="${1:-md0}"  # 默认排除系统RAID md0
    
    log_info "正在停用RAID阵列..."
    
    local raid_devices
    raid_devices=$(grep -oE "md[0-9]+" /proc/mdstat | grep -v "$exclude_devices" || true)
    
    if [ -z "$raid_devices" ]; then
        log_info "未发现需要停用的RAID阵列"
        return 0
    fi
    
    for raid in $raid_devices; do
        local raid_dev="/dev/$raid"
        log_info "停用RAID设备: $raid_dev"
        
        if mdadm --stop "$raid_dev" 2>/dev/null; then
            log_success "RAID设备已停用: $raid_dev"
        else
            log_warning "RAID设备停用失败或已停用: $raid_dev"
        fi
    done
    
    return 0
}

# ============================================
# LVM管理
# ============================================

# 检测LVM成员
is_lvm_member() {
    local device="$1"
    local fs_type
    fs_type=$(blkid -o value -s TYPE "$device" 2>/dev/null || echo "unknown")
    
    [ "$fs_type" = "LVM2_member" ]
}

# 激活LVM逻辑卷
activate_lvm() {
    log_info "正在激活LVM逻辑卷..."
    
    # 扫描物理卷
    pvscan > /dev/null 2>&1 || true
    
    # 扫描卷组
    vgscan > /dev/null 2>&1 || true
    
    # 激活所有卷组
    vgchange -ay > /dev/null 2>&1 || true
    
    # 查找新激活的逻辑卷（排除系统卷组）
    local system_vg
    system_vg=$(lvs --noheadings -o vg_name /vol1 2>/dev/null | tr -d ' ' || echo "")
    
    local lv_device
    lv_device=$(lvs --noheadings -o lv_path 2>/dev/null | grep -v "$system_vg" | tr -d ' ' | head -1 || true)
    
    if [ -z "$lv_device" ]; then
        log_error "未找到逻辑卷"
        return 1
    fi
    
    log_success "逻辑卷已激活: $lv_device"
    
    # 显示卷组信息
    local vg_name
    vg_name=$(lvs --noheadings -o vg_name "$lv_device" 2>/dev/null | tr -d ' ')
    log_info "卷组名称: $vg_name"
    
    echo "$lv_device"
    return 0
}

# 停用LVM卷组
deactivate_lvm() {
    local exclude_vg="${1:-}"  # 排除的卷组（如系统卷组）
    
    log_info "正在停用LVM卷组..."
    
    # 如果没有指定排除的卷组，尝试获取系统卷组
    if [ -z "$exclude_vg" ]; then
        exclude_vg=$(lvs --noheadings -o vg_name /vol1 2>/dev/null | tr -d ' ' || echo "")
    fi
    
    # 获取所有卷组
    local vg_list
    if [ -n "$exclude_vg" ]; then
        vg_list=$(vgs --noheadings -o vg_name 2>/dev/null | grep -v "$exclude_vg" | tr -d ' ' || true)
    else
        vg_list=$(vgs --noheadings -o vg_name 2>/dev/null | tr -d ' ' || true)
    fi
    
    if [ -z "$vg_list" ]; then
        log_info "未发现需要停用的LVM卷组"
        return 0
    fi
    
    for vg in $vg_list; do
        log_info "停用卷组: $vg"
        
        if vgchange -an "$vg" 2>/dev/null; then
            log_success "卷组已停用: $vg"
        else
            log_warning "卷组停用失败或已停用: $vg"
        fi
    done
    
    return 0
}

# ============================================
# 挂载管理
# ============================================

# 检查是否已挂载
is_mounted() {
    local mount_point="$1"
    mountpoint -q "$mount_point" 2>/dev/null
}

# 安全挂载设备
safe_mount() {
    local device="$1"
    local mount_point="$2"
    local options="${3:-}"
    
    # 创建挂载点
    mkdir -p "$mount_point"
    
    # 检查是否已挂载
    if is_mounted "$mount_point"; then
        log_warning "设备已挂载在 $mount_point"
        return 0
    fi
    
    # 挂载设备
    log_info "挂载设备 $device 到 $mount_point"
    
    if [ -n "$options" ]; then
        mount -o "$options" "$device" "$mount_point"
    else
        mount "$device" "$mount_point"
    fi
    
    log_success "设备已成功挂载"
    return 0
}

# 安全卸载设备
safe_umount() {
    local mount_point="$1"
    local force="${2:-false}"
    
    # 检查是否已挂载
    if ! is_mounted "$mount_point"; then
        log_info "设备未挂载在 $mount_point"
        return 0
    fi
    
    # 检查使用中的进程
    if command -v lsof > /dev/null 2>&1; then
        local processes
        processes=$(lsof +D "$mount_point" 2>/dev/null | tail -n +2 || true)
        
        if [ -n "$processes" ]; then
            log_warning "以下进程正在使用挂载点:"
            echo "$processes"
            
            if [ "$force" = "true" ]; then
                log_info "强制卸载..."
                umount -l "$mount_point" 2>/dev/null || umount -f "$mount_point"
            else
                log_error "请先关闭使用挂载点的进程"
                return 1
            fi
        fi
    fi
    
    # 卸载
    log_info "卸载 $mount_point"
    umount "$mount_point"
    log_success "设备已卸载"
    
    return 0
}

# ============================================
# 磁盘空间检查
# ============================================

# 获取目录大小（字节）
get_dir_size() {
    local dir="$1"
    du -sb "$dir" 2>/dev/null | awk '{print $1}' || echo "0"
}

# 获取可用空间（字节）
get_available_space() {
    local mount_point="$1"
    df -B1 "$mount_point" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0"
}

# 字节转人类可读格式
bytes_to_human() {
    local bytes="$1"
    
    if command -v numfmt > /dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "$bytes"
    else
        # 备用方法
        awk -v bytes="$bytes" 'BEGIN {
            units[1]="B"; units[2]="KiB"; units[3]="MiB"; units[4]="GiB"; units[5]="TiB"
            for(i=5; i>0; i--) {
                if(bytes >= 1024^(i-1)) {
                    printf "%.2f%s\n", bytes/(1024^(i-1)), units[i]
                    break
                }
            }
        }'
    fi
}

# 检查磁盘空间是否充足
check_disk_space() {
    local source_dir="$1"
    local target_mount="$2"
    local safety_margin="${3:-0.9}"  # 默认只使用90%的可用空间
    
    log_info "检查磁盘空间..."
    
    local source_size
    local available_size
    
    source_size=$(get_dir_size "$source_dir")
    available_size=$(get_available_space "$target_mount")
    
    # 计算安全可用空间
    available_size=$(awk -v avail="$available_size" -v margin="$safety_margin" 'BEGIN {print int(avail * margin)}')
    
    local source_human
    local available_human
    
    source_human=$(bytes_to_human "$source_size")
    available_human=$(bytes_to_human "$available_size")
    
    log_info "源目录大小: $source_human"
    log_info "可用空间: $available_human"
    
    if [ "$source_size" -gt "$available_size" ]; then
        log_error "磁盘空间不足！"
        log_error "需要: $source_human，可用: $available_human"
        return 1
    fi
    
    log_success "磁盘空间充足"
    return 0
}

# ============================================
# 错误处理
# ============================================

# 清理函数（用于trap）
cleanup() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        log_error "脚本异常退出，代码: $exit_code"
    fi
    
    # 这里可以添加清理逻辑
    
    exit $exit_code
}

# 设置错误处理
setup_error_handling() {
    set -e  # 遇到错误立即退出
    set -u  # 使用未定义变量时报错
    set -o pipefail  # 管道中任何命令失败都会导致整个管道失败
    
    trap cleanup EXIT
    trap 'log_error "脚本在第 $LINENO 行被中断"' INT TERM
}

# ============================================
# 交互式输入
# ============================================

# 询问是否/否问题
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"  # 默认为No
    
    # 非交互模式直接返回默认值
    if [ "${NON_INTERACTIVE:-false}" = "true" ]; then
        [ "$default" = "y" ] && return 0 || return 1
    fi
    
    local prompt
    if [ "$default" = "y" ]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi
    
    while true; do
        echo -ne "${YELLOW}[?]${NC} $question $prompt "
        read -r answer
        
        # 空输入使用默认值
        if [ -z "$answer" ]; then
            answer="$default"
        fi
        
        case "$answer" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "请输入 y(yes) 或 n(no)"
                ;;
        esac
    done
}

# 询问选择问题
ask_choice() {
    local question="$1"
    shift
    local options=("$@")
    
    echo -e "${YELLOW}[?]${NC} $question"
    
    local i=1
    for option in "${options[@]}"; do
        echo "  $i) $option"
        ((i++))
    done
    
    while true; do
        echo -ne "${YELLOW}[?]${NC} 请选择 [1-${#options[@]}]: "
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "${options[$((choice-1))]}"
            return 0
        else
            echo "无效选择，请输入 1-${#options[@]} 之间的数字"
        fi
    done
}

# ============================================
# 版本信息
# ============================================

show_version() {
    echo "USB Backup Tools v${SCRIPT_VERSION}"
    echo "Copyright (c) 2025"
}

# ============================================
# 初始化
# ============================================

# 初始化日志系统
init_logging

log_debug "公共函数库已加载 (版本 $SCRIPT_VERSION)"

