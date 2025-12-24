#!/bin/sh
# nfqws-keenetic-auto-RU v1.1 — BusyBox Совместимый
# curl -fsSL https://raw.githubusercontent.com/bizneslmv-wq/nfqws_auto/master/install.sh | sh

echo "🚀 nfqws-keenetic-auto-RU v1.1 — РФ DPI обход..."

# Проверка Entware
if [ ! -f /opt/etc/profile ]; then
    echo "❌ Требуется Entware на Keenetic!"
    exit 1
fi

echo "✅ Keenetic Entware OK"

# Зависимости (БЕЗ -y)
echo "📦 Зависимости..."
opkg update
opkg install ca-certificates wget-ssl coreutils-readlink coreutils-dirname

# Репозиторий NFQWS (фикс слеш)
echo "🔧 Репозиторий NFQWS..."
mkdir -p /opt/etc/opkg
echo "src/gz nfqws-keenetic https://anonym-tsk.github.io/nfqws-keenetic/all/" > /opt/etc/opkg/nfqws-keenetic.conf
opkg update

# Установка NFQWS (БЕЗ -y)
echo "🔧 Установка NFQWS + веб..."
opkg install nfqws-keenetic nfqws-keenetic-web

# Создание папок
mkdir -p /opt/etc/nfqws

# РФ домены
echo "📝 РФ домены..."
cat > /opt/etc/nfqws/user.list << EOF
youtube.com
googlevideo.com
ytimg.com
discord.com
discordapp.com
t.me
telegram.org
instagram.com
cdninstagram.com
vk.com
ntc.party
meduza.io
speedtest.net
EOF

# Остановка сервиса
echo "🛑 Остановка NFQWS..."
/opt/etc/init.d/S51nfqws stop

# ISP интерфейс
ISP_IFACE=`ip route | grep default | awk '{print \$3}' | head -1`
if [ -z "$ISP_IFACE" ]; then
    ISP_IFACE="eth3"
fi

# РФ конфиг
echo "⚙️  Конфигурация..."
cat > /opt/etc/nfqws/nfqws.conf << EOF
ISP_INTERFACE="$ISP_IFACE"
NFQWS_ARGS="--dpi-desync=fake,split2 --split-pos=1"
NFQWS_ARGS_QUIC="--dpi-desync=fake --filter-udp=443"
NFQWS_ARGS_UDP="--dpi-desync=fake"
NFQWS_EXTRA_ARGS="list"
TCP_PORTS="443,80"
UDP_PORTS="443,50000:50099"
IPV6_ENABLED=1
POLICY_NAME="nfqws"
POLICY_EXCLUDE=0
LOG_LEVEL=1
EOF

# Автозапуск
echo "▶️  Автозапуск..."
/opt/etc/init.d/S51nfqws enable
/opt/etc/init.d/S51nfqws restart
sleep 5

# Проверка сайтов
echo "✅ Проверка РФ сайтов..."
OK=0
for SITE in youtube.com discord.com t.me ntc.party; do
    if curl -k -m 5 "https://$SITE" 2>/dev/null | grep -q "200"; then
        echo "✅ $SITE - OK"
        OK=`expr $OK + 1`
    else
        echo "⚠️  $SITE - проблемы"
    fi
done

# IP адрес
IP=`ifconfig | grep "inet addr:" | grep -v 127.0.0.1 | awk '{print \$2}' | cut -d: -f2 | head -1`
if [ -z "$IP" ]; then
    IP="192.168.1.1"
fi

# Финал
echo ""
echo "🎉 УСТАНОВКА УСПЕШНА! $OK/4 сайтов OK"
echo "🌐 Веб NFQWS: http://$IP:90 (root/keenetic)"
echo "📱 Keenetic: Политика 'nfqws' → Интерфейс провай
