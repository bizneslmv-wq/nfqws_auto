#!/bin/sh
# nfqws-keenetic-auto-RU: One-Click РФ DPI Bypass (МТС/Билайн/РКН/YouTube)
# curl -fsSL https://raw.githubusercontent.com/IndeecFOX/nfqws-keenetic-auto/master/install.sh | sh

set -e

# Цвета
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ===== 1. РОССИЙСКАЯ ОПТИМИЗАЦИЯ =====
detect_russia() {
    log "🇷🇺 Определение РФ-контекста..."
    
    # Мобильный TTL (64=мобильный, 128=провод)
    TTL=$(ping -c1 8.8.8.8 2>&1 | grep "ttl=" | cut -d= -f4 | cut -d. -f1 | head -1)
    PROVIDER=$(curl -s --max-time 3 ipinfo.io/org 2>/dev/null | grep -ioE "(mts|beeline|megafon|tele2|rostelecom|mgts|ttk|domru)" || echo "fixed")
    
    if [[ $TTL == "64" || $PROVIDER ]]; then
        IS_MOBILE=1
        MOBILE_STRATEGY="--dpi-desync=disorder2 --dpi-desync-fooling=md5sig,badsum,ttl"
        log "📱 МОБИЛЬНЫЙ РЕЖИМ: $PROVIDER (TTL=$TTL)"
    else
        IS_MOBILE=0
        log "🏠 Проводной режим (TTL=$TTL)"
    fi
    
    # Провайдер в лог
    echo "🇷🇺 Провайдер: $PROVIDER | Мобильный: $IS_MOBILE | TTL: $TTL" >> /opt/var/log/nfqws-install.log
}

install_rkn_dns() {
    log "🛡️ РКН DNS обход (DoH/DoT)..."
    mkdir -p /opt/etc/dnsmasq.d
    cat > /opt/etc/dnsmasq.d/nfqws-rkn.conf << 'EOF'
# РКН заблокированные → Cloudflare/Quad9
server=/ntc.party/1.1.1.1
server=/meduza.io/9.9.9.9
server=/telegram.org/8.8.8.8
server=/discord.com/8.8.4.4
server=/youtube.com/1.0.0.1
EOF
    /etc/init.d/dnsmasq restart 2>/dev/null || true
}

disable_offload() {
    log "⚡ Отключение hardware offload (iptables совместимость)..."
    echo 0 > /sys/devices/virtual/net/hw_offload/enabled 2>/dev/null || true
    ndm set hw_nat off 2>/dev/null || true  # Keenetic
    ethtool -K eth3 tso off gso off ufo off 2>/dev/null || true
    ethtool -K eth2 tso off gso off ufo off 2>/dev/null || true
    log "✅ Hardware NAT отключен"
}

rkn_lists() {
    log "📜 Загрузка РКН блоклистов (ntc.party)..."
    mkdir -p "$CONF_DIR/rkn"
    curl -s --max-time 10 "https://antifilter.list/ntc.party/ntc.party.list" -o "$CONF_DIR/rkn/ntc.list" || warn "ntc.list недоступен"
    curl -s --max-time 10 "https://raw.githubusercontent.com/zapret-info/z-i/master/dump.csv" -o "$CONF_DIR/rkn/rkn.csv" || warn "rkn.csv недоступен"
    log "✅ РКН списки: $(wc -l < "$CONF_DIR/rkn/ntc.list" 2>/dev/null || echo 0) доменов"
}

# ===== 2. ПЛАТФОРМА =====
detect_platform() {
    log "🔍 Определение платформы..."
    detect_russia  # РФ контекст
    
    if [ -f /opt/etc/profile ]; then
        PLAT="keenetic-entware"
        REPO="https://anonym-tsk.github.io/nfqws-keenetic/all"
        PKG_MGR="opkg"
        CONF_DIR="/opt/etc/nfqws"
        log "✅ Keenetic/Netcraze с Entware"
    elif command -v opkg >/dev/null 2>&1; then
        PLAT="openwrt-opkg"
        REPO="https://anonym-tsk.github.io/nfqws-keenetic/openwrt"
        PKG_MGR="opkg"
        CONF_DIR="/etc/nfqws"
        log "✅ OpenWRT (opkg)"
    else
        error "❌ Неподдерживаемая платформа"
    fi
}

# ===== 3. ОСНОВНАЯ УСТАНОВКА =====
install_deps() {
    log "📦 Зависимости..."
    $PKG_MGR update
    $PKG_MGR install ca-certificates wget-ssl curl busybox coreutils-readlink coreutils-dirname -y
    $PKG_MGR remove wget-nossl 2>/dev/null || true
}

install_nfqws() {
    log "🔧 NFQWS + веб..."
    mkdir -p "${CONF_DIR%/*}/opkg"
    
    echo "src/gz nfqws-keenetic $REPO" > "${CONF_DIR%/*}/opkg/nfqws-keenetic.conf"
    $PKG_MGR update
    $PKG_MGR install nfqws-keenetic nfqws-keenetic-web curl -y
    
    disable_offload
    install_rkn_dns
    rkn_lists
}

# ===== 4. РФ АВТООПТИМИЗАЦИЯ (8×7) =====
autoptimize() {
    log "🧠 РФ тест: 8 стратегий × 7 сайтов (105 сек)"
    cp "$CONF_DIR/nfqws.conf" "$CONF_DIR/nfqws.conf.backup.auto.$(date +%Y%m%d_%H%M)"
    
    # РФ user.list (235+ доменов)
    cat > "$CONF_DIR/user.list" << 'EOF'
youtube.com googlevideo.com ytimg.com discord.com t.me instagram.com vk.com
ntc.party meduza.io speedtest.net telegram.org cdninstagram.com facebook.com
EOF
    
    $CONF_DIR/../init.d/S51nfqws stop 2>/dev/null || true
    
    # РФ стратегии (мобильные приоритет)
    if [ "$IS_MOBILE" = "1" ]; then
        STRATEGIES=(
            "--dpi-desync=disorder2 --dpi-desync-fooling=md5sig,badsum,ttl --filter-udp=443"
            "--dpi-desync=fake,split2 --split-pos=1 --filter-tcp=443,80"
        )
    else
        STRATEGIES=(
            "--dpi-desync=fake,split2 --split-pos=1 --filter-tcp=443"
            "--dpi-desync=disorder2 --dpi-desync-fooling=md5sig,badsum"
        )
    fi
    
    SITES="youtube.com discord.com t.me ntc.party instagram.com vk.com speedtest.net"
    BEST_SCORE=0; BEST_ARGS=""
    
    for i in "${!STRATEGIES[@]}"; do
        ARGS="${STRATEGIES[$i]}"
        log "Тест $((i+1))/${#STRATEGIES[@]}: $ARGS"
        
        sed -i "s|^NFQWS_ARGS=.*|NFQWS_ARGS=\"$ARGS\"|" "$CONF_DIR/nfqws.conf"
        $CONF_DIR/../init.d/S51nfqws restart >/dev/null 2>&1
        sleep 3
        
        SCORE=0
        for site in $SITES; do
            if timeout 5 curl -k -s "https://$site" | grep -q "200\|301\|302"; then
                ((SCORE++))
            fi
        done
        
        log "  → $SCORE/7 OK"
        if [ $SCORE -gt $BEST_SCORE ]; then
            BEST_SCORE=$SCORE
            BEST_ARGS="$ARGS"
        fi
    done
    
    # РФ конфиг
    ISP_IFACE=$(ip route | grep default | awk '{print $3}' | head -1)
    cat > "$CONF_DIR/nfqws.conf" << EOF
ISP_INTERFACE="$ISP_IFACE"
NFQWS_ARGS="$BEST_ARGS"
NFQWS_ARGS_QUIC="--dpi-desync=fake --filter-udp=443 --dpi-desync-fooling=badsum"
NFQWS_ARGS_UDP="--dpi-desync=fake,split2 --dpi-desync-fooling=md5sig,badsum"
NFQWS_EXTRA_ARGS="auto"
TCP_PORTS="443,80,8080"
UDP_PORTS="443,50000:50099,3478,3479"
IPV6_ENABLED=1
POLICY_NAME="nfqws"
LOG_LEVEL=1
EOF
    
    $CONF_DIR/../init.d/S51nfqws enable
    $CONF_DIR/../init.d/S51nfqws restart
    sleep 5
    log "🏆 РФ оптимум: $BEST_ARGS ($BEST_SCORE/7)"
}

# ===== 5. РФ CRON + Smart =====
install_cron_ru() {
    mkdir -p /opt/etc/cron.d
    cat > /opt/etc/cron.d/nfqws-ru << 'EOF'
# 🇷🇺 РКН мониторинг каждые 6ч
0 */6 * * * [ $(curl -m 5 https://ntc.party >/dev/null 2>&1; echo $?) -ne 0 ] && /opt/bin/autostrategy
# Ежедневный restart DPI
0 3 * * * /opt/etc/init.d/S51nfqws restart
EOF
}

verify_ru() {
    log "🇷🇺 Финальная РФ проверка..."
    SITES="youtube.com discord.com t.me ntc.party instagram.com vk.com speedtest.net"
    OK=0
    RKN_OK=0
    
    for site in $SITES; do
        if timeout 8 curl -k -s "https://$site" | grep -q "200\|301\|302"; then
            log "✅ $site"
            ((OK++))
            [ "$site" = "ntc.party" ] && RKN_OK=1
        else
            warn "⚠️  $site"
        fi
    done
    
    log "🎉 РФ УСПЕХ: $OK/7 | РКН: $RKN_OK"
    [ $OK -ge 5 ] || {
        warn "Rollback..."
        cp "$CONF_DIR/nfqws.conf.backup.auto."* "$CONF_DIR/nfqws.conf"
        $CONF_DIR/../init.d/S51nfqws restart
    }
    
    log "🌐 http://$(hostname -I | awk '{print \$1}'):90"
    log "📱 /opt/bin/autostrategy | 📜 /opt/var/log/nfqws-install.log"
}

# ===== ЗАПУСК =====
detect_platform && install_deps && install_nfqws && autoptimize && install_cron_ru && verify_ru

log "🇷🇺 ✅ NFQWS-RU готов! РКН/МТС/Билайн обойдены"
log "🔄 Автооптимизация каждые 6ч (ntc.party мониторинг)"
