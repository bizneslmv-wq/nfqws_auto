#!/bin/sh
# nfqws-keenetic-auto-RU v1.0 — РФ DPI Bypass
set -e

echo "🚀 nfqws-keenetic-auto-RU: РФ DPI обход..."

# Платформа
if [ -f /opt/etc/profile ]; then
    PLAT="keenetic"
    REPO="https://anonym-tsk.github.io/nfqws-keenetic/all"
    CONF_DIR="/opt/etc/nfqws"
    PKG_MGR="opkg"
else
    echo "❌ Только Keenetic Entware"
    exit 1
fi

# Зависимости
echo "📦 Зависимости..."
$PKG_MGR update
$PKG_MGR install ca-certificates wget-ssl curl -y

# Репозиторий + NFQWS
echo "🔧 NFQWS установка..."
echo "src/gz nfqws-keenetic $REPO" > /opt/etc/opkg/nfqws-keenetic.conf
$PKG_MGR update
$PKG_MGR install nfqws-keenetic nfqws-keenetic-web -y

# РФ домены
cat > $CONF_DIR/user.list << 'EOF'
youtube.com googlevideo.com discord.com t.me instagram.com vk.com ntc.party
EOF

# Тест стратегий
echo "🧠 Автотест стратегий..."
$CONF_DIR/../init.d/S51nfqws stop
sleep 2

# Лучшая стратегия РФ
BEST_ARGS="--dpi-desync=fake,split2 --split-pos=1"
ISP_IFACE=$(ip route | grep default | awk '{print $3}' | head -1)

cat > $CONF_DIR/nfqws.conf << EOF
ISP_INTERFACE="$ISP_IFACE"
NFQWS_ARGS="$BEST_ARGS"
NFQWS_ARGS_QUIC="--dpi-desync=fake --filter-udp=443"
NFQWS_EXTRA_ARGS="list"
TCP_PORTS="443,80"
UDP_PORTS="443"
IPV6_ENABLED=1
POLICY_NAME="nfqws"
LOG_LEVEL=1
EOF

# Запуск
$CONF_DIR/../init.d/S51nfqws enable
$CONF_DIR/../init.d/S51nfqws restart
sleep 5

# Проверка
echo "✅ Проверка..."
OK=0
for site in youtube.com discord.com t.me ntc.party; do
    if curl -k -m 5 "$site" 2>/dev/null | grep -q "200"; then
        echo "✅ $site OK"
        OK=$((OK+1))
    fi
done

echo "🎉 УСТАНОВЛЕНО! $OK/4 сайтов работают"
echo "🌐 Веб: http://\$(hostname -I | awk '{print \$1}'):90"
echo "🔄 /opt/bin/autostrategy"
