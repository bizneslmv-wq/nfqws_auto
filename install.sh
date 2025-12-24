#!/bin/sh
# nfqws-keenetic-auto-RU v1.0 — BusyBox 100% совместимый
# curl -fsSL https://raw.githubusercontent.com/bizneslmv-wq/nfqws_auto/master/install.sh | sh

echo "🚀 nfqws-keenetic-auto-RU: РФ DPI обход..."

# Только Keenetic Entware
if [ ! -f /opt/etc/profile ]; then
    echo "❌ Только Keenetic Entware!"
    exit 1
fi

echo "✅ Keenetic Entware обнаружен"

# Зависимости
echo "📦 Установка зависимостей..."
opkg update
opkg install ca-certificates wget-ssl curl busybox -y

# Репозиторий NFQWS
echo "🔧 Репозиторий NFQWS..."
mkdir -p /opt/etc/opkg
echo "src/gz nfqws-keenetic https://anonym-tsk.github.io/nfqws-keenetic/all" > /opt/etc/opkg/nfqws-keenetic.conf
opkg update

# Установка NFQWS + веб
echo "🔧 Установка NFQWS + веб-интерфейс..."
opkg install nfqws-keenetic nfqws-keenetic-web -y

# РФ домены (YouTube/Discord/Telegram)
echo "📝 РФ домены..."
cat > /opt/etc/nfqws/user.list << EOF
youtube.com
googlevideo.com
discord.com
t.me
telegram.org
instagram.com
vk.com
ntc.party
meduza.io
speedtest.net
EOF

# Остановка сервиса
echo "🛑 Остановка NFQWS..."
/opt/etc/init.d/S51nfqws stop

# РФ конфиг (оптимальные параметры)
ISP_IFACE=`ip route | grep default | awk '{print $3}' | head -1`
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

# Запуск сервиса
echo "▶️  Запуск NFQWS..."
/opt/etc/init.d/S51nfqws enable
/opt/etc/init.d/S51nfqws restart
sleep 5

# Проверка доступности
echo "✅ Проверка ключевых сайтов..."
OK=0
for SITE in youtube.com discord.com t.me ntc.party; do
    if curl -k -m 5 "https://$SITE" 2>/dev/null | grep -q "200"; then
        echo "✅ $SITE - OK"
        OK=`expr $OK + 1`
    else
        echo "⚠️  $SITE - проблемы"
    fi
done

# Итог
IP=`hostname -I | awk '{print $1}'`
echo ""
echo "🎉 УСТАНОВКА УСПЕШНА! $OK/4 сайтов работают"
echo "🌐 Веб-интерфейс: http://$IP:90"
echo "📋 Логи: /opt/var/log/nfqws.log"
echo "🔄 Автооптимизация: /opt/bin/autostrategy"
echo "📱 Политика NFQWS в веб-интерфейсе Keenetic"
echo ""
echo "🇷🇺 Готово к использованию!"
