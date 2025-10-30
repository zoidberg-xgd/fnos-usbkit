# 🚀 快速开始 - 一键部署

## 最简单的方法（推荐）

### 在飞牛OS上直接运行

只需要一条命令，系统就会自动配置好：

```bash
# SSH登录你的飞牛OS
ssh root@你的飞牛OS的IP

# 下载并运行（如果scripts文件夹已经上传到飞牛OS）
cd /path/to/scripts
sudo bash auto_deploy.sh
```

**就这样！完成了！** 🎉

系统现在会：
- ✅ 自动监控所有USB存储设备
- ✅ 自动修复识别问题
- ✅ 开机自动启动
- ✅ 适应IP变化
- ✅ 适应USB口变化
- ✅ 适应设备变化

---

## 详细步骤

### 步骤1: 上传脚本到飞牛OS

选择以下任一方法：

#### 方法A: 使用SCP（从你的电脑）

```bash
# 在你的电脑上运行
cd /Users/yaoxiaohang/Documents/fnos
scp -r scripts root@飞牛OS的IP:/root/
```

#### 方法B: 使用飞牛OS的Web界面

1. 打开飞牛OS的文件管理器
2. 上传整个 `scripts` 文件夹

#### 方法C: 使用U盘

1. 把 `scripts` 文件夹复制到U盘
2. U盘插到飞牛OS
3. 复制到飞牛OS的某个目录

### 步骤2: 运行部署脚本

```bash
# SSH登录飞牛OS
ssh root@你的飞牛OS的IP

# 进入scripts目录
cd /root/scripts  # 或你上传到的位置

# 运行自动部署
bash auto_deploy.sh
```

### 步骤3: 完成！

脚本会自动：
1. ✓ 检测系统环境
2. ✓ 安装监控脚本
3. ✓ 配置systemd服务
4. ✓ 设置开机自启
5. ✓ 启动服务
6. ✓ 验证安装

看到 "🎉 部署完成！" 就大功告成了！

---

## 验证安装

### 查看服务状态

```bash
usb-monitor status
```

### 查看实时日志

```bash
usb-monitor logs
```

### 查看当前USB设备

```bash
usb-monitor devices
```

### 查看服务信息和最近日志

```bash
usb-monitor info
```

---

## 使用场景

### 场景1: IP地址变了

**无需操作** - 服务在本地运行，不受IP影响

### 场景2: 换了路由器/网络

**无需操作** - 服务不依赖网络

### 场景3: USB设备插到其他口

**无需操作** - 自动监控所有USB口

### 场景4: 换了新的移动硬盘

**无需操作** - 默认监控所有USB存储设备

### 场景5: 重启飞牛OS

**无需操作** - 服务自动启动

---

## 常用命令

```bash
usb-monitor status    # 查看服务状态
usb-monitor logs      # 查看实时日志（Ctrl+C退出）
usb-monitor info      # 快速查看信息
usb-monitor devices   # 查看USB设备
usb-monitor restart   # 重启服务
usb-monitor config    # 编辑配置（高级）
usb-monitor test      # 测试模式（5分钟调试日志）
usb-monitor          # 查看所有命令
```

---

## 配置（可选）

如果你想自定义配置：

```bash
# 编辑配置文件
usb-monitor config

# 可以修改：
# - CHECK_INTERVAL: 检查间隔（默认30秒）
# - LOG_LEVEL: 日志级别（debug/info/warn/error）
# - MONITOR_MODE: all或whitelist模式

# 修改后重启服务
usb-monitor restart
```

---

## 故障排除

### 问题1: 服务没有运行

```bash
# 查看详细状态
systemctl status usb_disk_monitor.service

# 查看日志
journalctl -u usb_disk_monitor -n 50
```

### 问题2: 设备还是没有自动修复

```bash
# 开启调试模式查看详细信息
usb-monitor test

# 查看当前USB设备
lsusb
lsblk
```

### 问题3: 想要重新部署

```bash
# 先卸载
usb-monitor uninstall

# 再重新部署
bash auto_deploy.sh
```

---

## 卸载

如果不想用了：

```bash
usb-monitor uninstall
```

---

## 工作原理

1. **监控**: 每30秒扫描所有USB存储设备
2. **检测**: 发现USB设备存在但没有 /dev/sdX 块设备
3. **修复**: 通过sysfs重置USB设备（模拟拔插）
4. **保护**: 5分钟冷却期，避免频繁重置同一设备
5. **自动**: 完全自动化，无需人工干预

---

## 技术细节

- **服务名称**: usb_disk_monitor.service
- **监控脚本**: /usr/local/bin/usb_disk_monitor.sh
- **管理命令**: /usr/local/bin/usb-monitor
- **配置文件**: /etc/usb_disk_monitor.conf
- **日志文件**: /var/log/usb_disk_monitor.log
- **状态文件**: /var/run/usb_disk_monitor.state

---

## 优势

✅ **完全自动** - 一次部署，永久使用  
✅ **零配置** - 开箱即用  
✅ **自适应** - 适应各种环境变化  
✅ **轻量级** - 占用资源极少（<50MB内存，<10% CPU）  
✅ **可靠** - systemd管理，服务崩溃自动重启  
✅ **通用** - 支持所有USB存储设备品牌  

---

## 支持的设备

- ✅ JMicron USB桥接器
- ✅ 机械硬盘
- ✅ 固态硬盘
- ✅ U盘
- ✅ 读卡器
- ✅ NVMe USB适配器
- ✅ 所有USB Mass Storage设备

---

## 下一步

1. 试试拔插USB设备，看看是否自动修复
2. 运行 `usb-monitor logs` 观察日志
3. 重启飞牛OS，确认服务自动启动
4. 享受无忧的USB存储体验！ 🎉

---

## 问题反馈

如果遇到问题：

1. 运行 `usb-monitor test` 收集调试信息
2. 查看 `/var/log/usb_disk_monitor.log`
3. 运行 `lsusb` 和 `lsblk` 查看设备状态

---

**就这么简单！祝使用愉快！** 😊

