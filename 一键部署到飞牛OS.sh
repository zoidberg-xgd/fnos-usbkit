#!/bin/bash
#
# 一键部署到飞牛OS
# 在你的Mac上运行这个脚本，会自动上传并部署到飞牛OS
#

set -e

echo "=========================================="
echo "USB磁盘监控系统 - 一键部署到飞牛OS"
echo "=========================================="
echo ""

# 获取飞牛OS的IP
read -p "请输入飞牛OS的IP地址: " FNOS_IP

if [ -z "$FNOS_IP" ]; then
    echo "错误: IP地址不能为空"
    exit 1
fi

# 检测用户名
read -p "请输入SSH用户名 [root]: " FNOS_USER
FNOS_USER=${FNOS_USER:-root}

echo ""
echo "目标: $FNOS_USER@$FNOS_IP"
echo ""

# 测试连接
echo "1. 测试SSH连接..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes $FNOS_USER@$FNOS_IP "echo '连接成功'" 2>/dev/null; then
    echo "SSH连接失败，请检查："
    echo "  - IP地址是否正确"
    echo "  - 飞牛OS是否已开启SSH"
    echo "  - 网络是否连通"
    echo ""
    echo "如果还没配置SSH密钥，请先运行:"
    echo "  ssh-copy-id $FNOS_USER@$FNOS_IP"
    exit 1
fi

echo "✓ SSH连接正常"
echo ""

# 上传脚本
echo "2. 上传部署脚本..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

scp "$SCRIPT_DIR/scripts/auto_deploy.sh" $FNOS_USER@$FNOS_IP:/tmp/
echo "✓ 上传完成"
echo ""

# 远程执行部署
echo "3. 在飞牛OS上执行部署..."
echo "=========================================="
ssh -t $FNOS_USER@$FNOS_IP "sudo bash /tmp/auto_deploy.sh"
echo "=========================================="
echo ""

# 清理临时文件
echo "4. 清理临时文件..."
ssh $FNOS_USER@$FNOS_IP "rm -f /tmp/auto_deploy.sh"
echo "✓ 清理完成"
echo ""

echo "=========================================="
echo "🎉 部署完成！"
echo "=========================================="
echo ""
echo "现在USB监控服务已经在飞牛OS上运行了！"
echo ""
echo "你可以："
echo "  1. 关掉这台Mac，服务继续在飞牛OS上运行"
echo "  2. 飞牛OS重启后，服务会自动启动"
echo "  3. IP变了也没关系"
echo ""
echo "查看服务状态:"
echo "  ssh $FNOS_USER@$FNOS_IP usb-monitor status"
echo ""
echo "查看实时日志:"
echo "  ssh $FNOS_USER@$FNOS_IP usb-monitor logs"
echo ""

