#!/bin/sh
# nfqws-auto-RU v1.0 — BusyBox совместимый

echo "🚀 nfqws-auto-RU установка..."

# Только Keenetic
if [ ! -f /opt/etc/profile ]; then
    echo "❌ Только Keenetic Entware"
    exit 1
fi

# Зависимости
opkg update
opkg install ca-certificates wget-ssl curl -y

# Репозиторий
echo "src/gz nfqws-keenetic https://anonym-tsk.github.io/nfqws-keenetic/all" > /opt/etc/opkg/nfqws-keenetic.conf
opkg update
opkg install nfqws-keenetic nfqws-keenetic-web -y

# Домены РФ
echo "youtube.com googlevideo.com discord.com t.me ntc.party" > /opt/etc/nfqws/user.list

# Конфиг
/opt/etc/init.d/S51nfqws stop
ISP=`ip route | grep default | awk '{print $3}' | head -1`
cat > /opt/etc/nfqws/nfqws.conf << END
ISP_INTERFACE="$ISP"
NFQWS_ARGS="--dpi-desync=fake,split2 --split-pos=1"
NFQWS_EXTRA_ARGS="list"
TCP_PORTS="443,80"
UDP_PORTS="443"
IPV6_ENABLED=1
POLICY_NAME="nfqws"
LOG_LEVEL=1
END

# Запуск
/opt/etc/init.d/S51nfqws enable
/opt/etc/init.d/S51nfqws restart
sleep 5

# Проверка
echo "✅ Тест сайтов:"
for SITE in youtube.com discord.com t.me ntc.party; do
    if curl -k -m 5 "$SITE" 2>/dev/null | grep -q "200"; then
        echo "✅ $SITE"
    else
        echo "❌ $SITE"
    fi
done

echo "🌐 Веб: http://`hostname -I | awk '{print $1}'`:90"
echo "✅ УСТАНОВЛЕНО!"
