# FnOS-UsbKit Scripts

核心脚本目录，提供USB设备挂载、备份和诊断功能。

## 📦 脚本列表

| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `mount_usb_backup.sh` | USB设备挂载 | 自动识别和组装RAID+LVM，挂载到 `/mnt/usb_backup` |
| `umount_usb_backup.sh` | 安全卸载 | 正确停用LVM和RAID，避免数据损坏 |
| `auto_backup_to_usb.sh` | 自动备份 | 增量备份数据到USB设备 |
| `diagnose_usb_disk.sh` | 健康诊断 | 检测USB设备问题、RAID状态、LVM状态 |

## 🚀 快速使用

### 基本工作流程

```bash
# 1. 挂载USB设备
sudo ./mount_usb_backup.sh

# 2. 执行备份
sudo ./auto_backup_to_usb.sh

# 3. 安全卸载
sudo ./umount_usb_backup.sh
```

### 故障诊断

当USB设备无法识别时：

```bash
sudo ./diagnose_usb_disk.sh
```

## 📖 详细说明

### mount_usb_backup.sh

**功能**：
- 自动检测USB存储设备
- 识别并组装RAID阵列（支持linear/0/1/5/6/10）
- 激活LVM逻辑卷
- 挂载文件系统到指定挂载点

**依赖**：
- `lsusb` - USB设备识别
- `blkid` - 文件系统识别
- `mdadm` - RAID管理（可选）
- `lvm2` - LVM管理（可选）

**配置**：
挂载点和其他配置在 `../config/usb_backup.conf` 中定义。

### umount_usb_backup.sh

**功能**：
- 检查并终止使用挂载点的进程
- 卸载文件系统
- 停用LVM卷组
- 停用RAID阵列

**安全特性**：
- 确保数据同步到磁盘
- 按正确顺序停用LVM和RAID
- 防止数据损坏

### auto_backup_to_usb.sh

**功能**：
- 增量备份（基于rsync）
- 自动排除临时文件和日志
- 磁盘空间预检查
- 生成备份元数据

**备份策略**：
- 使用rsync增量备份，只传输变化的文件
- 自动清理旧备份（保留最近N个）
- 记录备份日志

**配置**：
备份源目录、排除规则等在 `../config/usb_backup.conf` 中配置。

### diagnose_usb_disk.sh

**功能**：
- USB设备连接状态检测
- RAID阵列状态检查
- LVM卷状态检查
- 虚拟机USB占用检测
- 硬盘健康状态检查（需要smartctl）

**使用场景**：
- USB设备无法识别
- 挂载失败
- RAID异常
- LVM无法激活

## 🔧 技术细节

### 支持的存储结构

```
物理设备 (/dev/sdX)
├── 分区 (/dev/sdX1)
│   ├── 直接文件系统 (ext4/xfs/btrfs/ntfs)
│   ├── RAID成员
│   │   └── RAID设备 (/dev/mdX)
│   │       ├── 文件系统
│   │       └── LVM物理卷
│   │           └── LVM逻辑卷 (/dev/mapper/*)
│   │               └── 文件系统
│   └── LVM物理卷
│       └── LVM逻辑卷
│           └── 文件系统
```

### 支持的RAID类型

- RAID 0 (striping)
- RAID 1 (mirroring)
- RAID 5 (striping with parity)
- RAID 6 (dual parity)
- RAID 10 (1+0)
- RAID linear

### 支持的文件系统

- ext4
- xfs
- btrfs
- ntfs (只读)
- vfat/fat32

## ⚙️ 配置

所有脚本共享配置文件：`../config/usb_backup.conf`

主要配置项：
```bash
# USB挂载点
MOUNT_POINT="/mnt/usb_backup"

# 备份源目录
SOURCE_DIR="/fnos"

# 备份目标目录
BACKUP_BASE_DIR="backups"

# 日志目录
LOG_DIR="/opt/fnos-usbkit/logs"

# 排除规则
RSYNC_EXCLUDE=(
    "*.tmp"
    "*.log"
    ".cache/*"
)
```

## 📝 日志

所有脚本都会记录详细日志到：
- `/opt/fnos-usbkit/logs/usb_backup_YYYYMMDD.log`

查看日志：
```bash
# 查看最新日志
tail -f /opt/fnos-usbkit/logs/usb_backup_*.log

# 查看所有日志
ls -lh /opt/fnos-usbkit/logs/
```

## ⚠️ 注意事项

1. **需要root权限**：所有脚本都需要root权限运行
2. **挂载前检查**：确保USB设备已正确连接
3. **安全卸载**：拔出USB前务必运行卸载脚本
4. **备份验证**：定期验证备份完整性
5. **空间管理**：定期清理旧备份释放空间

## 🔗 相关文档

- [安装指南](../README.md#安装)
- [配置说明](../README.md#配置)
- [故障排除](../README.md#故障排除)
- [测试套件](../tests/README.md)

---

*更新时间: 2025-10-30*
