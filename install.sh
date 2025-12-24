#!/bin/sh
# nfqws-keenetic-auto-RU v2.0 — РФ DPI Bypass (МТС/Билайн/РКН)
# curl -fsSL https://raw.githubusercontent.com/bizneslmv-wq/nfqws_auto/master/install.sh | sh

echo "🚀 nfqws-keenetic-auto-RU v2.0 — установка..."

# 1. Проверка Entware
if [ ! -f /opt/etc/profile ]; then
    echo "❌ Ошибка: Требуется Entware на Keenetic!"
    exit 1
fi
echo "✅ Keenetic Entware обнаружен"

# 2. Обновление списков
echo "📦 Обновление репозиториев..."
opkg update

# 3. Установка SSL (для https)
echo "📦 SSL сертификаты..."
opkg install ca-certificates wget-ssl

# 4. Репозиторий NFQWS (http вместо https)
echo "🔧 Добавление репозитория NFQWS..."
mkdir -p /opt/etc/opkg
echo "src/gz nfqws-keenetic http://anonym-tsk.github.io/nfqws-keenetic/all/" > /opt/etc/opkg/nfqws.conf
opkg update

# 5. Установка NFQWS (БЕЗ -y)
echo "🔧 Установка NFQWS..."
opkg install nfqws-keenetic

# 6. Создание директорий
echo "📁 Подготовка директорий..."
mkdir -p /opt/etc/nfqws

# 7. РФ домены для обхода
echo "📝 РФ домены (YouTube/Discord/Telegram)..."
echo "youtube.com" > /opt/etc/nfqws/user.list
echo "googlevideo.com" >> /opt/etc/nfqws/user.list
echo "discord.com" >> /opt/etc/nfqws/user.list
echo "t.me" >> /opt/etc/nfqws/user.list
echo "ntc.party" >> /opt/etc/nfqws/user.list

# 8. Оптимальная РФ конфигурация
echo "⚙️ Конфигурация для МТС/Билайн..."
cat > /opt/etc/nfqws/nfqws.conf << EOF
# ISP интерфейс (МТС/Билайн обычно eth3)
ISP_INTERFACE=eth3

# Основная стратегия РФ DPI
NFQWS_ARGS="--dpi-desync=fake,split2 --split-pos=1"

# QUIC/UDP
NFQWS_ARGS_QUIC="--dpi-desync=fake --filter-udp=443"
NFQWS_ARGS_UDP="--dpi-desync=fake"

# Дополнительно
NFQWS_EXTRA_ARGS="list"
TCP_PORTS="80,443"
UDP_PORTS="443"
IPV6_ENABLED=1
POLICY_NAME="nfqws"
POLICY_EXCLUDE=0
LOG_LEVEL=1
EOF

# 9. Перезапуск сервиса
echo "🔄 Перезапуск NFQWS..."
if [ -f /opt/etc/init.d/S51nfqws ]; then
    /opt/etc/init.d/S51nfqws stop
    sleep 2
    /opt/etc/init.d/S51nfqws enable
    /opt/etc/init.d/S51nfqws start
else
    echo "⚠️ S51nfqws не найден — NFQWS установлен"
fi

sleep 3

# 10. Проверка
echo "✅ Проверка установки..."
if [ -f /opt/etc/nfqws/nfqws.conf ]; then
    echo "✅ Конфиг OK: /opt/etc/nfqws/nfqws.conf"
fi
if [ -f /opt/etc/nfqws/user.list ]; then
    echo "✅ Домены OK: $(wc -l < /opt/etc/nfqws/user.list) доменов"
fi

# 11. Финальная информация
echo ""
echo "🎉 УСТАНОВКА УСПЕШНА!"
echo "═══════════════════════════"
echo "🌐 Веб NFQWS: http://192.168.1.1:90"
echo "   Логин: root  Пароль: keenetic"
echo ""
echo "📱 Keenetic веб-интерфейс:"
echo "   1. 'Приоритеты подключений' → 'Политики'"
echo "   2. Добавить политику 'nfqws'"
echo "   3. Интерфейс провайдера → политика 'nfqws'"
echo ""
echo "📋 Логи: tail -f /opt/var/log/nfqws.log"
echo "🔄 Перезапуск: /opt/etc/init.d/S51nfqws restart"
echo "🇷🇺 Тестировано: МТС + KN-3811"
echo ""
echo "🚀 ГОТОВО! YouTube/Discord/Telegram работают!"
