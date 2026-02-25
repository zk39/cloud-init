#!/bin/bash
set -e

# ===== 参数检查 =====
if [ $# -lt 2 ]; then
    echo "使用方法: ./deploy.sh <用户名> <密码> <默认端口9922>"
    echo ""
    echo "示例:"
    echo "  ./deploy.sh userName passwd"
    echo "  ./deploy.sh userName passwd 2222"
    echo ""
    exit 1
fi

USER=$1
PASSWORD=$2
SSH_PORT=${3:-9922}
CURRENT_USER=$(logname 2>/dev/null || whoami)

echo "开始部署..."
echo "用户: $USER"
echo "密码: $PASSWORD"
echo "SSH 端口: $SSH_PORT"
echo "当前用户: $CURRENT_USER"
echo ""

# ===== 1. 创建用户和权限 =====
echo "创建用户 $USER..."

sudo useradd -m -s /bin/bash "$USER"
echo "$USER:$PASSWORD" | sudo chpasswd
sudo usermod -aG sudo "$USER"
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/"$USER" > /dev/null

echo "[OK] 用户创建完成"

# ===== 2. 配置 SSH =====
echo "配置 SSH..."

sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sudo tee /etc/ssh/sshd_config.d/99-"$USER".conf > /dev/null << EOL
Port $SSH_PORT
PermitRootLogin no
AllowUsers $CURRENT_USER $USER
PubkeyAuthentication yes

Match User $USER
    PasswordAuthentication yes
EOL

sudo systemctl restart ssh

echo "[OK] SSH 配置完成"

# ===== 3. 配置防火墙 =====
echo "配置防火墙放行端口 $SSH_PORT..."

# iptables
REJECT_LINE=$(sudo iptables -L INPUT -n --line-numbers | grep -i "reject" | head -1 | awk '{print $1}')

if [ -n "$REJECT_LINE" ]; then
    sudo iptables -I INPUT "$REJECT_LINE" -p tcp --dport "$SSH_PORT" -m state --state NEW -j ACCEPT
else
    sudo iptables -A INPUT -p tcp --dport "$SSH_PORT" -m state --state NEW -j ACCEPT
fi

# 持久化 iptables
if command -v netfilter-persistent &> /dev/null; then
    sudo netfilter-persistent save
else
    sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null
fi

echo "[OK] iptables 配置完成"

# ufw
if command -v ufw &> /dev/null; then
    sudo ufw allow "$SSH_PORT"/tcp comment "Custom SSH"
    sudo ufw --force enable
    echo "[OK] ufw 配置完成"
else
    echo "[跳过] ufw 未安装"
fi

echo "[OK] 防火墙配置完成"

# ===== 4. 为新用户安装 Node.js =====
echo "为用户 $USER 安装 Node.js..."

sudo -i -u "$USER" bash << 'NODESCRIPT'
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install 24
echo "Node.js: $(node -v)"
echo "npm: $(npm -v)"
NODESCRIPT

echo "[OK] Node.js 为 $USER 安装完成"

# ===== 验证 =====
echo ""
echo "======================================"
echo "[OK] 部署完成！"
echo "======================================"
echo ""
echo "用户信息："
echo "  用户名: $USER"
echo "  密码: $PASSWORD"
echo ""
echo "SSH 连接："
echo "  ssh $USER@SERVER_IP -p $SSH_PORT"
echo "  ssh $CURRENT_USER@SERVER_IP -p $SSH_PORT -i 你的私钥"
echo ""
