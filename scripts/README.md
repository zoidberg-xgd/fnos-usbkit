# 飞牛OS USB备份工具

简洁高效的USB移动硬盘备份解决方案，支持RAID+LVM结构。

## 📦 包含脚本

| 脚本 | 功能 | 用途 |
|------|------|------|
| `mount_usb_backup.sh` | 挂载移动硬盘 | 自动识别RAID+LVM并挂载到 `/mnt/usb_backup` |
| `umount_usb_backup.sh` | 安全卸载 | 正确停用LVM和RAID，避免数据损坏 |
| `auto_backup_to_usb.sh` | 自动备份 | 增量备份 `/vol1` 到移动硬盘 |
| `usb_backup_manager.sh` | 图形化管理器 | 交互式菜单，整合所有功能 |
| `diagnose_usb_disk.sh` | 🆕 健康诊断 | 检测SATA松动、USB不稳定等问题 |

## 🚀 快速使用

### 在服务器上（已安装）

```bash
# 方法1：图形化菜单（推荐）
usb-backup

# 方法2：命令行
mount_usb_backup.sh      # 挂载
auto_backup_to_usb.sh    # 备份
umount_usb_backup.sh     # 卸载

# 🆕 故障诊断（移动硬盘无法识别时）
diagnose_usb_disk.sh     # 自动检测问题
```

### 重新安装

```bash
# 1. 上传脚本
scp scripts/*.sh root@192.168.31.104:/usr/local/bin/

# 2. 设置权限
ssh root@192.168.31.104 'chmod +x /usr/local/bin/*.sh && ln -sf /usr/local/bin/usb_backup_manager.sh /usr/local/bin/usb-backup'
```

## 📖 详细文档

查看根目录的 `USB备份工具使用指南.md` 获取完整说明。

## ⚠️ 重要提醒

1. **挂载前检查物理连接**：确保硬盘盒内SATA线连接牢固
2. **使用专用挂载脚本**：不要用 `mount /dev/sda1`，必须用 `mount_usb_backup.sh`
3. **安全卸载**：拔出USB前务必运行 `umount_usb_backup.sh`

## 🔧 你的硬盘结构

```
/dev/sda (JMicron JMS567 SATA桥接)
└── /dev/sda1 (分区)
    └── /dev/md126 (RAID linear)
        └── /dev/trim_8ed93b3b.../0 (LVM逻辑卷)
            └── btrfs文件系统 (238GB)
```

## ✅ 功能特性

- ✅ 自动检测和组装RAID（linear/0/1/5/6/10）
- ✅ 自动激活LVM逻辑卷
- ✅ 支持多种文件系统（Btrfs/ext4/xfs）
- ✅ 增量备份（rsync），节省时间和空间
- ✅ 安全卸载，防止数据损坏
- 🆕 智能诊断，自动识别硬件问题（SATA松动等）

---

*最后更新: 2025-10-30*
