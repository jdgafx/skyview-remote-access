#!/bin/bash

# ==============================================================================
# SKYVIEW UNIVERSAL REMOTE ORCHESTRATOR (SURO) v3.2 - WAYLAND + X11 SUPPORT
# Desktop-Agnostic RDP Server - Works with KDE, GNOME, XFCE, or ANY desktop
# ==============================================================================

set -e

# --- Credentials ---
SUDOPWD='qrdemon1'

# --- Aesthetics ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'
CYAN='\033[0;36m'
GOLD='\033[1;33m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'

# --- Configuration ---
RDP_PORT=3389
LOG_FILE="/tmp/skyview_setup.log"
CERT_DIR="/etc/xrdp"

# Initialize log
echo "=== SkyView Setup $(date) ===" > "$LOG_FILE"

as_root() {
    echo "$SUDOPWD" | sudo -S bash -c "$*" >> "$LOG_FILE" 2>&1
}

log() {
    echo -e "$@" | tee -a "$LOG_FILE"
}

banner() {
    echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${CYAN}┃${NC}${GOLD}    S K Y V I E W   U N I V E R S A L   R E M O T E   v3.2       ${NC}${CYAN}┃${NC}"
    echo -e "${CYAN}┃${NC}${MAGENTA}    Wayland + X11 Support | Auto-Detect Desktop                  ${NC}${CYAN}┃${NC}"
    echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo ""
}

detect_desktop() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP"
    elif [ -n "$DESKTOP_SESSION" ]; then
        echo "$DESKTOP_SESSION"
    elif pgrep -x "plasmashell" > /dev/null; then
        echo "KDE"
    elif pgrep -x "gnome-shell" > /dev/null; then
        echo "GNOME"
    elif pgrep -x "xfce4-session" > /dev/null; then
        echo "XFCE"
    else
        echo "Unknown"
    fi
}

detect_session_type() {
    if [ -n "$XDG_SESSION_TYPE" ]; then
        echo "$XDG_SESSION_TYPE"
    elif [ -n "$WAYLAND_DISPLAY" ]; then
        echo "wayland"
    else
        echo "x11"
    fi
}

check_wayland_support() {
    # Check if we can support Wayland-native remote desktop
    local desktop=$(detect_desktop)
    local session=$(detect_session_type)

    if [ "$session" = "wayland" ]; then
        case "$desktop" in
            "KDE"|"plasma")
                # KDE Plasma has KRdp for Wayland RDP
                if command -v krdp &> /dev/null; then
                    return 0  # Supported
                fi
                ;;
            "GNOME"|"ubuntu:GNOME")
                # GNOME has gnome-remote-desktop
                if command -v gnome-remote-desktop &> /dev/null; then
                    return 0  # Supported
                fi
                ;;
        esac
        return 1  # Not supported - will fall back to X11
    else
        return 0  # X11 is always supported
    fi
}

install_dependencies() {
    log "${BOLD}>>> CHECKING DEPENDENCIES...${NC}"

    local session_type=$(detect_session_type)
    local desktop=$(detect_desktop)
    local packages_needed=""

    if [ "$session_type" = "wayland" ]; then
        log "${YELLOW}[*]${NC} Wayland session detected, checking for native remote desktop..."

        case "$desktop" in
            "KDE"|"plasma")
                # KDE Wayland: use KRdp
                if ! dpkg -l krdp 2>/dev/null | grep -q "^ii"; then
                    packages_needed="$packages_needed krdp"
                    log "${YELLOW}[*]${NC} Will install KRdp for KDE Wayland RDP support"
                else
                    log "${GREEN}[✔]${NC} KRdp already installed for KDE Wayland"
                fi
                ;;
            "GNOME"|"ubuntu:GNOME")
                # GNOME Wayland: use gnome-remote-desktop
                if ! dpkg -l gnome-remote-desktop 2>/dev/null | grep -q "^ii"; then
                    packages_needed="$packages_needed gnome-remote-desktop"
                    log "${YELLOW}[*]${NC} Will install gnome-remote-desktop for GNOME Wayland RDP support"
                else
                    log "${GREEN}[✔]${NC} gnome-remote-desktop already installed for GNOME Wayland"
                fi
                ;;
            *)
                log "${YELLOW}[!]${NC} Wayland detected but no native RDP support for $desktop. Falling back to X11/xrdp."
                session_type="x11"  # Force X11 mode
                ;;
        esac
    fi

    # Always check for xrdp/xorgxrdp as fallback for X11
    if ! dpkg -l xrdp 2>/dev/null | grep -q "^ii"; then
        packages_needed="$packages_needed xrdp"
    fi

    # Check for xorgxrdp (needed for X11 session support)
    if ! dpkg -l xorgxrdp 2>/dev/null | grep -q "^ii"; then
        packages_needed="$packages_needed xorgxrdp"
    fi

    if [ -n "$packages_needed" ]; then
        log "${YELLOW}[*]${NC} Installing required packages:$packages_needed"
        as_root "apt-get update -qq"
        as_root "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $packages_needed"
        log "${GREEN}[✔]${NC} Dependencies installed"
    else
        log "${GREEN}[✔]${NC} All dependencies already installed"
    fi
}

# REST OF THE SCRIPT REMAINS THE SAME...
# (Copying the rest of the original script here for completeness)

setup_certificates() {
    log "${BOLD}>>> SETTING UP TLS CERTIFICATES...${NC}"

    # Use xrdp's default cert location and generate if needed
    if [ ! -f "$CERT_DIR/cert.pem" ] || [ ! -f "$CERT_DIR/key.pem" ]; then
        log "${YELLOW}[*]${NC} Generating new TLS certificates..."
        as_root "openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj '/C=US/ST=SkyView/L=Remote/O=SkyView/CN=SkyViewRDP' \
            -keyout $CERT_DIR/key.pem \
            -out $CERT_DIR/cert.pem 2>/dev/null"
    fi

    # CRITICAL: xrdp user must be able to read the key
    as_root "chown xrdp:xrdp $CERT_DIR/key.pem $CERT_DIR/cert.pem"
    as_root "chmod 640 $CERT_DIR/key.pem"
    as_root "chmod 644 $CERT_DIR/cert.pem"

    # Also add xrdp to ssl-cert group as backup
    as_root "usermod -a -G ssl-cert xrdp 2>/dev/null || true"

    log "${GREEN}[✔]${NC} TLS certificates ready"
}

configure_xrdp() {
    log "${BOLD}>>> CONFIGURING XRDP (Universal RDP Server)...${NC}"

    # Backup original config
    if [ ! -f /etc/xrdp/xrdp.ini.bak.skyview ]; then
        as_root "cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak.skyview"
    fi

    # Configure xrdp.ini for better performance and security
    as_root "sed -i 's/^port=.*/port=$RDP_PORT/' /etc/xrdp/xrdp.ini"
    as_root "sed -i 's/^max_bpp=.*/max_bpp=32/' /etc/xrdp/xrdp.ini"
    as_root "sed -i 's/^xserverbpp=.*/xserverbpp=24/' /etc/xrdp/xrdp.ini"

    # Use default certificate location
    as_root "sed -i 's|^certificate=.*|certificate=$CERT_DIR/cert.pem|' /etc/xrdp/xrdp.ini"
    as_root "sed -i 's|^key_file=.*|key_file=$CERT_DIR/key.pem|' /etc/xrdp/xrdp.ini"

    # Set security layer to negotiate for maximum compatibility
    as_root "sed -i 's/^security_layer=.*/security_layer=negotiate/' /etc/xrdp/xrdp.ini"
    as_root "sed -i 's/^crypt_level=.*/crypt_level=high/' /etc/xrdp/xrdp.ini"

    # Enable TLS 1.2 and 1.3 for modern clients, but also allow fallback
    as_root "sed -i 's/^ssl_protocols=.*/ssl_protocols=TLSv1.2, TLSv1.3/' /etc/xrdp/xrdp.ini"

    # Ensure tcp_nodelay for better responsiveness
    as_root "sed -i 's/^tcp_nodelay=.*/tcp_nodelay=true/' /etc/xrdp/xrdp.ini"

    log "${GREEN}[✔]${NC} XRDP configuration updated"
}

configure_session_manager() {
    log "${BOLD}>>> CONFIGURING SESSION MANAGER...${NC}"

    local startwm_file="/etc/xrdp/startwm.sh"

    # Backup original
    if [ ! -f "${startwm_file}.bak.skyview" ]; then
        as_root "cp $startwm_file ${startwm_file}.bak.skyview"
    fi

    # Create a smart session starter that auto-detects and launches the right desktop
    as_root "tee $startwm_file > /dev/null" << 'STARTWM_EOF'
#!/bin/bash

# SkyView Universal Session Manager v3.2
# Automatically detects and launches the appropriate desktop environment

# Unset problematic session variables
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

# Set up D-Bus
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Detect installed desktop environments (in order of preference)
start_desktop() {
    # KDE Plasma
    if command -v startplasma-x11 &> /dev/null; then
        exec startplasma-x11
    elif command -v startkde &> /dev/null; then
        exec startkde
    # GNOME
    elif command -v gnome-session &> /dev/null; then
        export XDG_SESSION_TYPE=x11
        export GDK_BACKEND=x11
        exec gnome-session
    # XFCE
    elif command -v startxfce4 &> /dev/null; then
        exec startxfce4
    # MATE
    elif command -v mate-session &> /dev/null; then
        exec mate-session
    # Cinnamon
    elif command -v cinnamon-session &> /dev/null; then
        exec cinnamon-session
    # LXQt
    elif command -v startlxqt &> /dev/null; then
        exec startlxqt
    # LXDE
    elif command -v startlxde &> /dev/null; then
        exec startlxde
    # i3
    elif command -v i3 &> /dev/null; then
        exec i3
    # Fallback to any available session
    elif [ -f /usr/bin/x-session-manager ]; then
        exec /usr/bin/x-session-manager
    else
        # Ultimate fallback - just start a terminal
        exec xterm
    fi
}

# Check for user's .xsession or .xinitrc preference
if [ -f "$HOME/.xsession" ]; then
    . "$HOME/.xsession"
elif [ -f "$HOME/.xinitrc" ]; then
    . "$HOME/.xinitrc"
else
    start_desktop
fi
STARTWM_EOF

    as_root "chmod +x $startwm_file"

    log "${GREEN}[✔]${NC} Session manager configured for auto-detection"
}

configure_firewall() {
    log "${BOLD}>>> CONFIGURING FIREWALL...${NC}"

    # Check if ufw is active and add rule
    if echo "$SUDOPWD" | sudo -S ufw status 2>/dev/null | grep -q "Status: active"; then
        as_root "ufw allow $RDP_PORT/tcp"
        log "${GREEN}[✔]${NC} Firewall rule added for port $RDP_PORT"
    else
        log "${YELLOW}[*]${NC} UFW not active, skipping firewall configuration"
    fi
}

start_services() {
    log "${BOLD}>>> STARTING RDP SERVICES...${NC}"

    # Stop any conflicting services first
    as_root "systemctl stop gnome-remote-desktop.service 2>/dev/null || true"
    as_root "systemctl disable gnome-remote-desktop.service 2>/dev/null || true"

    # Enable and start xrdp
    as_root "systemctl enable xrdp"
    as_root "systemctl enable xrdp-sesman"
    as_root "systemctl restart xrdp-sesman"
    sleep 1
    as_root "systemctl restart xrdp"

    log "${GREEN}[✔]${NC} XRDP services started"
}

verify_listener() {
    log "${BOLD}>>> VERIFYING RDP LISTENER...${NC}"

    # Wait for service to fully start
    sleep 3

    local max_attempts=10
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if ss -tlnp 2>/dev/null | grep -q ":$RDP_PORT"; then
            log "${GREEN}[HEALTH: OK]${NC} RDP is listening on port $RDP_PORT"
            return 0
        fi
        log "${YELLOW}[*]${NC} Waiting for RDP listener... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done

    log "${RED}[HEALTH: FAIL]${NC} No listener on port $RDP_PORT after $max_attempts attempts"
    log "${YELLOW}[DEBUG]${NC} Checking xrdp status..."
    systemctl status xrdp --no-pager 2>&1 | tail -10 | tee -a "$LOG_FILE"
    return 1
}

get_ip_address() {
    ip route get 1 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}'
}

get_external_ip() {
    curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "unknown"
}

# DDNS Configuration
DDNS_HOSTNAME="cgs1.tplinkdns.com"
EXTERNAL_RDP_PORT="${EXTERNAL_RDP_PORT:-3389}"

show_summary() {
    local ip_addr=$(get_ip_address)
    local external_ip=$(get_external_ip)
    local desktop=$(detect_desktop)
    local session=$(detect_session_type)
    local target_user=$(logname 2>/dev/null || echo "$USER")

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "   ${BOLD}SKYVIEW REMOTE ACCESS READY${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "   ${BLUE}LAN IP:${NC}         ${GOLD}${ip_addr}${NC}"
    echo -e "   ${BLUE}External IP:${NC}    ${GOLD}${external_ip}${NC}"
    echo -e "   ${BLUE}DDNS:${NC}           ${GOLD}${DDNS_HOSTNAME}${NC}"
    echo -e "   ${BLUE}Port:${NC}           ${GOLD}${RDP_PORT}${NC} (internal) / ${GOLD}${EXTERNAL_RDP_PORT}${NC} (external)"
    echo -e "   ${BLUE}Protocol:${NC}       RDP (Universal)"
    echo -e "   ${BLUE}Desktop:${NC}        ${CYAN}${desktop}${NC} (${session})"
    echo -e "   ${BLUE}Username:${NC}       ${CYAN}${target_user}${NC}"
    echo -e "   ${BLUE}Password:${NC}       Use your Linux login password"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "   ${BOLD}CONNECTION (Local LAN):${NC}"
    echo -e "   ${GOLD}${ip_addr}:${RDP_PORT}${NC}"
    echo -e ""
    echo -e "   ${BOLD}CONNECTION (Remote/Internet):${NC}"
    echo -e "   ${GOLD}${DDNS_HOSTNAME}:${EXTERNAL_RDP_PORT}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "   ${YELLOW}NOTE:${NC} Ensure router port forwarding is configured:"
    echo -e "   External ${EXTERNAL_RDP_PORT} -> ${ip_addr}:${RDP_PORT} (TCP)"
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

banner

log "${BOLD}>>> SYSTEM DETECTION${NC}"
DESKTOP=$(detect_desktop)
SESSION_TYPE=$(detect_session_type)
log "   Desktop: ${CYAN}${DESKTOP}${NC}"
log "   Session: ${CYAN}${SESSION_TYPE}${NC}"
echo ""

# Run setup steps
install_dependencies
setup_certificates
configure_xrdp
configure_session_manager "$DESKTOP"
configure_firewall
start_services

# Verify and show results
if verify_listener; then
    show_summary

    # Update systemd status if running as a service
    if [ -n "$NOTIFY_SOCKET" ]; then
        systemd-notify --status="RDP listening on port $RDP_PORT"
    fi
    exit 0
else
    log "${RED}[ERROR]${NC} Setup completed but RDP listener failed to start"
    log "Check logs at: $LOG_FILE"
    exit 1
fi