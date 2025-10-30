# USB备份工具使用指南

## 📦 工具介绍

这套工具专门为**飞牛OS**设计，支持自动识别和挂载**复杂的移动硬盘**（RAID + LVM），并提供完整的备份/恢复功能。

### ✨ 特性

- ✅ 自动检测USB存储设备
- ✅ 支持RAID阵列自动组装
- ✅ 支持LVM逻辑卷激活
- ✅ 增量备份（rsync）
- ✅ 备份历史管理
- ✅ 安全卸载机制
- ✅ 读写速度测试
- ✅ 图形化菜单界面

---

## 🚀 快速开始

### 方法一：图形化管理器（推荐）

```bash
ssh root@192.168.31.104
usb-backup
```

进入交互式菜单，按数字选择操作：
- `1` - 挂载移动硬盘
- `2` - 安全卸载
- `3` - 开始备份
- `4` - 查看备份历史
- `5` - 恢复备份
- `6` - 查看USB状态
- `7` - 测试读写速度

### 方法二：命令行直接调用

```bash
# 挂载移动硬盘
mount_usb_backup.sh

# 执行备份
auto_backup_to_usb.sh

# 安全卸载
umount_usb_backup.sh
```

---

## 📖 详细说明

### 1️⃣ 挂载移动硬盘

**脚本**: `mount_usb_backup.sh`

**功能**:
- 自动检测USB设备
- 识别RAID成员并组装RAID阵列
- 激活LVM逻辑卷
- 挂载到 `/mnt/usb_backup`

**示例输出**:
```
======================================
  移动硬盘自动挂载工具
======================================

[INFO] 步骤 1/5: 检测USB设备...
[SUCCESS] 检测到USB设备: Bus 001 Device 004: ID 152d:0562 JMicron...
[INFO] 步骤 2/5: 查找硬盘设备...
[SUCCESS] 找到硬盘: /dev/sda
[INFO] 步骤 3/5: 分析分区类型...
[INFO] 分区类型: linux_raid_member
[WARNING] 检测到RAID成员，正在组装RAID阵列...
[SUCCESS] RAID设备已激活: /dev/md126
[INFO] RAID设备类型: LVM2_member
[WARNING] 检测到LVM2成员，正在激活逻辑卷...
[SUCCESS] 逻辑卷已激活: /dev/trim_8ed93b3b.../0
[INFO] 步骤 5/5: 挂载设备...
[SUCCESS] 设备已挂载到: /mnt/usb_backup

======================================
[SUCCESS] 挂载完成！
======================================

磁盘使用情况:
  容量: 238G
  已用: 136G
  可用: 101G
  使用率: 58%
```

### 2️⃣ 自动备份

**脚本**: `auto_backup_to_usb.sh`

**功能**:
- 增量备份 `/vol1` 到移动硬盘
- 自动排除临时文件和日志
- 保留最近5个备份
- 生成备份元数据

**排除的目录**:
- `lost+found`
- `@apptemp/*`
- `tmp/*`
- `*.log`

**备份位置**: `/mnt/usb_backup/fnos_backups/backup_YYYYMMDD_HHMMSS/`

**示例输出**:
```
==========================================
  飞牛OS 自动备份工具
==========================================

[INFO] 步骤 1/5: 检查移动硬盘挂载状态...
[SUCCESS] 移动硬盘已挂载
[INFO] 步骤 2/5: 创建备份目录...
[SUCCESS] 备份目录: /mnt/usb_backup/fnos_backups/backup_20251030_201500
[INFO] 步骤 3/5: 检查磁盘空间...
[INFO] 源目录大小: 45.23GB
[INFO] 可用空间: 101.50GB
[SUCCESS] 空间检查通过
[INFO] 步骤 4/5: 开始备份...
[INFO] 备份方式: rsync增量备份
[INFO] 这可能需要较长时间，请耐心等待...

sending incremental file list
...

[SUCCESS] 备份完成！用时: 15分32秒
```

### 3️⃣ 安全卸载

**脚本**: `umount_usb_backup.sh`

**功能**:
- 检查并关闭正在使用的进程
- 卸载文件系统
- 停用LVM逻辑卷
- 停用RAID阵列

**示例输出**:
```
======================================
  移动硬盘安全卸载工具
======================================

[INFO] 步骤 1/4: 检查挂载状态...
[SUCCESS] 检测到已挂载设备
[INFO] 步骤 2/4: 卸载文件系统...
[SUCCESS] 文件系统已卸载
[INFO] 步骤 3/4: 停用LVM逻辑卷...
[SUCCESS] LVM卷组已停用: trim_8ed93b3b_e241_4932_bad8_633fa001c81a
[INFO] 步骤 4/4: 停用RAID阵列...
[SUCCESS] RAID阵列已停用: /dev/md126

======================================
[SUCCESS] 安全卸载完成！
======================================

[SUCCESS] 现在可以安全地拔出USB设备了
```

### 4️⃣ 恢复备份

在 `usb-backup` 菜单中选择 `5) 恢复备份`：

1. 列出所有可用备份
2. 显示每个备份的详细信息
3. 选择要恢复的备份
4. 确认后执行恢复

**⚠️ 警告**: 恢复操作会覆盖当前数据，请谨慎操作！

---

## 🛠️ 故障排除

### 问题1: 移动硬盘无法识别

**症状**: 执行 `lsusb` 能看到设备，但 `ls /dev/sd*` 没有设备

**原因**: SATA硬盘与硬盘盒连接不良

**解决方案**:
1. 重新插拔USB线
2. 检查硬盘盒电源
3. 检查硬盘盒内SATA连接

### 问题2: 挂载失败 "unknown filesystem"

**症状**: `mount: unknown filesystem type 'linux_raid_member'`

**解决方案**: 使用 `mount_usb_backup.sh`，它会自动处理RAID和LVM

### 问题3: 空间不足

**症状**: 备份时提示空间不足

**解决方案**:
```bash
# 查看旧备份
ls -lth /mnt/usb_backup/fnos_backups/

# 手动删除旧备份
rm -rf /mnt/usb_backup/fnos_backups/backup_YYYYMMDD_HHMMSS
```

### 问题4: 卸载时提示设备忙

**症状**: `umount: target is busy`

**解决方案**: 
```bash
# 查找占用进程
lsof +D /mnt/usb_backup

# 强制卸载
umount -l /mnt/usb_backup
```

---

## 📊 技术细节

### 硬盘结构

你的移动硬盘采用以下结构：

```
/dev/sda (物理设备)
└── /dev/sda1 (分区)
    └── /dev/md126 (RAID linear阵列)
        └── /dev/trim_8ed93b3b_e241_4932_bad8_633fa001c81a/0 (LVM逻辑卷)
            └── btrfs文件系统
```

### 挂载流程

1. **USB识别**: JMicron JMS567 SATA桥接芯片
2. **SCSI枚举**: 创建 `/dev/sda`
3. **RAID组装**: `mdadm --assemble` → `/dev/md126`
4. **LVM激活**: `vgchange -ay` → `/dev/mapper/trim_*/0`
5. **文件系统挂载**: `mount` → `/mnt/usb_backup`

---

## 🔧 高级配置

### 修改备份源

编辑 `auto_backup_to_usb.sh`:

```bash
SOURCE_DIR="/vol1"  # 改为你要备份的目录
```

### 修改备份保留数量

编辑 `auto_backup_to_usb.sh`:

```bash
# 清理旧备份（保留最近5个）
ls -t | grep "^backup_" | tail -n +6 | xargs -r rm -rf
                                    # ↑ 改这里的数字
```

### 添加排除规则

编辑 `auto_backup_to_usb.sh` 中的 `rsync` 命令：

```bash
rsync -avh --progress \
    --exclude="lost+found" \
    --exclude="@apptemp/*" \
    --exclude="新的排除规则" \
    "$SOURCE_DIR/" "$BACKUP_DIR/"
```

---

## 📅 定时备份（可选）

### 创建cron任务

```bash
# 编辑crontab
crontab -e

# 每天凌晨2点自动备份
0 2 * * * /usr/local/bin/mount_usb_backup.sh && /usr/local/bin/auto_backup_to_usb.sh && /usr/local/bin/umount_usb_backup.sh
```

### 使用systemd timer（推荐）

创建 `/etc/systemd/system/usb-backup.service`:

```ini
[Unit]
Description=USB Backup Service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mount_usb_backup.sh
ExecStart=/usr/local/bin/auto_backup_to_usb.sh
ExecStop=/usr/local/bin/umount_usb_backup.sh
```

创建 `/etc/systemd/system/usb-backup.timer`:

```ini
[Unit]
Description=USB Backup Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

启用定时器：

```bash
systemctl daemon-reload
systemctl enable usb-backup.timer
systemctl start usb-backup.timer
```

---

## 📝 脚本文件清单

| 文件名 | 功能 | 位置 |
|--------|------|------|
| `mount_usb_backup.sh` | 挂载移动硬盘 | `/usr/local/bin/` |
| `umount_usb_backup.sh` | 安全卸载 | `/usr/local/bin/` |
| `auto_backup_to_usb.sh` | 自动备份 | `/usr/local/bin/` |
| `usb_backup_manager.sh` | 图形化管理器 | `/usr/local/bin/` |
| `install_usb_backup.sh` | 安装脚本 | `/tmp/` |
| `usb-backup` | 快捷命令（软链接） | `/usr/local/bin/` |

---

## ❓ 常见问题

**Q: 第一次使用需要格式化移动硬盘吗？**  
A: 不需要。你的移动硬盘已经包含完整的数据结构（RAID+LVM+btrfs），可以直接使用。

**Q: 备份会覆盖移动硬盘原有数据吗？**  
A: 不会。备份会创建在 `/mnt/usb_backup/fnos_backups/` 目录下，不影响原有的用户数据（如 `/mnt/usb_backup/1000/画画`）。

**Q: 可以同时连接多个移动硬盘吗？**  
A: 当前脚本设计为单个移动硬盘。如需支持多个，需要修改挂载点配置。

**Q: 增量备份是如何工作的？**  
A: 使用 `rsync`，只传输变化的文件，大幅减少备份时间和空间占用。

**Q: 如何查看备份进度？**  
A: 使用 `usb-backup` 菜单启动备份，会实时显示 `rsync` 进度。

---

## 🎉 总结

现在你拥有了一套完整的USB备份解决方案：

✅ **已完成**:
- 移动硬盘成功挂载（238GB，已用136GB，可用101GB）
- 自动识别RAID+LVM结构
- 备份脚本已部署
- 图形化管理工具可用

🚀 **立即使用**:
```bash
ssh root@192.168.31.104
usb-backup
```

---

*生成时间: 2025年10月30日*  
*目标系统: 飞牛OS*  
*移动硬盘: EAGET 238GB (RAID + LVM + btrfs)*

