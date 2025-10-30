# FnOS-UsbKit

飞牛OS USB工具箱 - 解决USB掉盘问题 + 智能备份，支持RAID、LVM和虚拟机环境。

## 特性

- 自动识别USB设备、RAID阵列和LVM卷
- 基于rsync的增量备份，支持排除规则
- 虚拟机USB设备冲突检测与自动释放
- 磁盘空间预检查
- USB设备诊断工具
- 统一配置文件管理
- 详细操作日志

## 系统要求

### 必需
- Linux系统（Debian/Ubuntu/CentOS/RHEL/Fedora）
- Bash 4.0+
- 基础工具：`rsync`, `lsblk`, `blkid`, `mount`, `umount`, `df`, `du`, `findmnt`, `mountpoint`

### 可选
- `mdadm` - RAID支持
- `lvm2` - LVM支持
- `lsusb` - USB设备详细信息
- `smartctl` - 硬盘健康检查
- `virsh` 或 `VBoxManage` - 虚拟机管理

## 安装

### 方法一：自动安装

```bash
# 克隆仓库
git clone https://github.com/yourusername/fnos-usbkit.git
cd fnos-usbkit

# 运行安装脚本
sudo bash install.sh
```

安装脚本会：
1. 检查并安装依赖
2. 复制文件到 `/opt/fnos-usbkit`
3. 创建系统命令（`mount-usb`, `backup-to-usb` 等）
4. 初始化配置文件
5. 运行测试验证安装

### 方法二：手动安装

```bash
# 1. 复制文件
sudo mkdir -p /opt/fnos-usbkit
sudo cp -r lib scripts config tests /opt/fnos-usbkit/

# 2. 设置权限
sudo chmod +x /opt/fnos-usbkit/scripts/*.sh
sudo chmod 644 /opt/fnos-usbkit/lib/common.sh

# 3. 创建配置文件
sudo cp /opt/fnos-usbkit/config/usb_backup.conf.example \
        /opt/fnos-usbkit/config/usb_backup.conf

# 4. 创建符号链接（可选）
sudo ln -s /opt/fnos-usbkit/scripts/mount_usb_backup.sh /usr/local/bin/mount-usb
sudo ln -s /opt/fnos-usbkit/scripts/umount_usb_backup.sh /usr/local/bin/umount-usb
sudo ln -s /opt/fnos-usbkit/scripts/auto_backup_to_usb.sh /usr/local/bin/backup-to-usb
sudo ln -s /opt/fnos-usbkit/scripts/diagnose_usb_disk.sh /usr/local/bin/diagnose-usb
```

## 配置

编辑配置文件：

```bash
sudo vim /opt/fnos-usbkit/config/usb_backup.conf
```

### 核心配置项

```bash
# USB挂载点
MOUNT_POINT="/mnt/usb_backup"

# 备份源目录
SOURCE_DIR="/fnos"

# 备份目标基础目录（相对于USB挂载点）
BACKUP_BASE_DIR="backups"

# 日志目录
LOG_DIR="/opt/fnos-usbkit/logs"

# 自动从虚拟机释放USB设备
AUTO_RELEASE_FROM_VM=false

# 备份排除规则
RSYNC_EXCLUDE=(
    "*.tmp"
    "*.log"
    ".cache/*"
    "lost+found/"
)
```

## 使用方法

### 基本工作流程

```bash
# 1. 插入USB设备

# 2. 挂载USB备份盘
sudo mount-usb
# 或完整路径
sudo /opt/fnos-usbkit/scripts/mount_usb_backup.sh

# 3. 执行备份
sudo backup-to-usb
# 或完整路径
sudo /opt/fnos-usbkit/scripts/auto_backup_to_usb.sh

# 4. 卸载USB备份盘
sudo umount-usb
# 或完整路径
sudo /opt/fnos-usbkit/scripts/umount_usb_backup.sh
```

### 诊断工具

当USB设备无法识别时：

```bash
sudo diagnose-usb
# 或完整路径
sudo /opt/fnos-usbkit/scripts/diagnose_usb_disk.sh
```

诊断脚本会检查：
- USB设备连接状态
- RAID阵列状态
- LVM卷状态
- 虚拟机占用情况
- 硬盘健康状态
- 设备详细信息

## 高级功能

### RAID支持

工具自动检测并组装RAID阵列：

```bash
# 自动扫描并组装RAID
sudo mount-usb
```

手动RAID操作：

```bash
# 查看RAID状态
cat /proc/mdstat

# 手动组装
sudo mdadm --assemble --scan
```

### LVM支持

自动激活LVM卷组：

```bash
# 自动扫描并激活LVM
sudo mount-usb
```

手动LVM操作：

```bash
# 扫描卷组
sudo vgscan

# 激活卷组
sudo vgchange -ay
```

### 虚拟机USB冲突处理

当USB被虚拟机占用时，工具可以自动释放：

1. 在配置文件中启用：
```bash
AUTO_RELEASE_FROM_VM=true
```

2. 挂载时自动处理：
```bash
sudo mount-usb
```

支持的虚拟机：
- KVM/QEMU (virsh)
- VirtualBox (VBoxManage)
- VMware (检测进程)

### 自定义备份排除规则

编辑配置文件中的 `RSYNC_EXCLUDE` 数组：

```bash
RSYNC_EXCLUDE=(
    "*.tmp"           # 临时文件
    "*.log"           # 日志文件
    ".cache/*"        # 缓存目录
    "lost+found/"     # 系统目录
    "node_modules/"   # Node.js依赖
    "venv/"           # Python虚拟环境
    ".git/"           # Git仓库
)
```

### 定时自动备份

使用cron设置定时任务：

```bash
# 编辑root的crontab
sudo crontab -e

# 每天凌晨2点自动备份
0 2 * * * /opt/fnos-usbkit/scripts/auto_backup_to_usb.sh

# 每小时备份一次
0 * * * * /opt/fnos-usbkit/scripts/auto_backup_to_usb.sh
```

## 测试

运行测试套件：

```bash
sudo bash /opt/fnos-usbkit/tests/run_tests.sh
```

测试包括：
- 项目结构验证
- 公共库函数测试
- 配置文件解析
- 脚本语法检查
- 依赖命令检查
- 虚拟机检测功能
- USB设备检测
- RAID/LVM功能
- 日志功能

## 项目结构

```
fnos-usbkit/
├── README.md                   # 项目文档
├── install.sh                  # 安装脚本
├── lib/
│   └── common.sh              # 公共函数库
├── scripts/
│   ├── mount_usb_backup.sh    # USB挂载脚本
│   ├── umount_usb_backup.sh   # USB卸载脚本
│   ├── auto_backup_to_usb.sh  # 自动备份脚本
│   └── diagnose_usb_disk.sh   # USB诊断脚本
├── config/
│   └── usb_backup.conf        # 配置文件
├── tests/
│   └── run_tests.sh           # 测试套件
└── logs/                      # 日志目录
```

## 日志

所有操作都会记录日志：

```bash
# 查看最新日志
sudo tail -f /opt/fnos-usbkit/logs/usb_backup_*.log

# 查看备份日志
sudo ls -lh /opt/fnos-usbkit/logs/
```

日志包含：
- 时间戳
- 操作类型
- 设备信息
- 错误信息
- 备份统计

## 故障排除

### USB设备无法识别

1. 运行诊断工具：
```bash
sudo diagnose-usb
```

2. 检查USB连接：
```bash
lsusb
dmesg | tail -50
```

3. 检查内核日志：
```bash
sudo journalctl -xe | grep -i usb
```

### 设备被虚拟机占用

1. 手动释放（KVM）：
```bash
sudo virsh detach-device <vm-name> <device-xml>
```

2. 手动释放（VirtualBox）：
```bash
VBoxManage controlvm <vm-name> usbdetach <device-uuid>
```

3. 启用自动释放（配置文件）：
```bash
AUTO_RELEASE_FROM_VM=true
```

### RAID阵列无法组装

```bash
# 停止现有RAID
sudo mdadm --stop /dev/md*

# 重新扫描并组装
sudo mdadm --assemble --scan

# 查看状态
cat /proc/mdstat
```

### LVM卷无法激活

```bash
# 扫描卷组
sudo vgscan

# 激活所有卷组
sudo vgchange -ay

# 查看逻辑卷
sudo lvscan
```

### 备份速度慢

1. 检查USB接口速度（USB 2.0 vs 3.0）
2. 减少压缩级别（修改rsync参数）
3. 检查硬盘健康状态：
```bash
sudo smartctl -a /dev/sdX
```

### 磁盘空间不足

1. 清理旧备份：
```bash
sudo rm -rf /mnt/usb_backup/backups/backup_old_*
```

2. 添加更多排除规则（配置文件）
3. 使用更大容量的USB设备

## 安全建议

1. **权限管理**
   - 所有脚本应该只有root可写
   - 配置文件保护敏感信息

2. **备份验证**
   - 定期验证备份完整性
   - 测试恢复流程

3. **加密建议**
   - 敏感数据使用LUKS加密
   - 传输过程使用SSH隧道

4. **访问控制**
   - 限制物理访问USB设备
   - 使用防火墙保护网络备份

## 许可证

MIT License

## 版本历史

### v1.0.0 (2025-10-30)
- 初始版本发布
- USB设备自动检测
- 增量备份支持
- RAID和LVM支持
- 虚拟机冲突检测
- 磁盘空间检查
- 完整测试套件

---

**注意：** 请始终以root权限运行脚本，并在生产环境使用前充分测试。

