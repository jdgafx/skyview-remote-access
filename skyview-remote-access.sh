#!/bin/bash

set -euo pipefail

# ==============================================================================
# SKYVIEW UNIVERSAL REMOTE ACCESS v5.6 - FULLY AUTOMATED
# RDP + VNC + SSH - Works with ANY Desktop (X11 or Wayland)
# ==============================================================================

# --- Configuration ---
SSH_PORT="${SSH_PORT:-2277}"
RDP_PORT="${RDP_PORT:-3389}"
VNC_PORT="${VNC_PORT:-5900}"
MODE="${MODE:-auto}"
VERBOSE="${VERBOSE:-false}"
FORCE_X11="${FORCE_X11:-false}"

# --- Password for sudo (set from environment or use default) ---
SUDOPWD="${SUDOPWD:-qrdemon1}"

# --- Helper for sudo commands ---
as_root() {
    echo "$SUDOPWD" | sudo -S bash -c "$*" 2>/dev/null || bash -c "$*"
}

log() { echo -e "[$(date '+%H:%M:%S')] $*"; }
log_info() { log "${BLUE}[INFO]${NC} $*"; }
log_warn() { log "${YELLOW}[WARN]${NC} $*"; }
log_error() { log "${RED}[ERROR]${NC} $*" >&2; }
log_success() { log "${GREEN}[✔]${NC} $*"; }

# --- Colors ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GOLD='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${CYAN}┃${NC}${GOLD}  S K Y V I E W   U N I V E R S A L   R E M O T E   A C C E S S  ${NC}${CYAN}┃${NC}"
    echo -e "${CYAN}┃${NC}${MAGENTA}  RDP + VNC + SSH - Fully Automated Setup                    ${NC}${CYAN}┃${NC}"
    echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo ""
}

detect_system() {
    local de="Unknown" session_type="unknown"

    # Check Wayland indicator first (reliable)
    [ -n "${WAYLAND_DISPLAY:-}" ] && session_type="wayland"

    # Check X11 indicator
    [ -n "${DISPLAY:-}" ] && [ "$session_type" != "wayland" ] && session_type="x11"

    # Check session type from loginctl as backup
    if [ "$session_type" = "unknown" ]; then
        local session_id=$(loginctl list-sessions --no-legend 2>/dev/null | head -1 | awk '{print $1}')
        if [ -n "$session_id" ]; then
            local session_info=$(loginctl show-session "$session_id" 2>/dev/null)
            echo "$session_info" | grep -q "Type=wayland" && session_type="wayland"
            echo "$session_info" | grep -q "Type=x11" && session_type="x11"
        fi
    fi

    # Detect desktop environment by running processes (most reliable)
    # Priority: most specific → least specific
    if pgrep -x "plasmashell" >/dev/null 2>&1; then
        de="KDE"
    elif pgrep -x "gnome-shell" >/dev/null 2>&1; then
        de="GNOME"
    elif pgrep -f "xfce4-session" >/dev/null 2>&1; then
        de="XFCE"
    elif pgrep -x "cinnamon-session" >/dev/null 2>&1; then
        de="Cinnamon"
    elif pgrep -x "mate-session" >/dev/null 2>&1; then
        de="MATE"
    else
        # Fallback to environment variables
        [ -n "${XDG_CURRENT_DESKTOP:-}" ] && de="$XDG_CURRENT_DESKTOP"
        [ -n "${DESKTOP_SESSION:-}" ] && [ "$de" = "Unknown" ] && de="$DESKTOP_SESSION"
    fi

    echo "${de}:${session_type}"
}

install_packages() {
    local packages=("$@") missing=()
    for pkg in "${packages[@]}"; do
        dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" || missing+=("$pkg")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log_info "Installing: ${missing[*]}"
        if ! as_root "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ${missing[*]} 2>&1"; then
            log_warn "Some packages could not be installed due to dependency issues"
            log_info "Available services:"
            ss -tlnp 2>/dev/null | grep -E "3389|5900|2277" || echo "  None listening yet"
        fi
    fi
}

# ==============================================================================
# RDP SETUP
# ==============================================================================

setup_rdp() {
    log_info "=== RDP Configuration ==="
    local sys_info=$(detect_system)
    local de=$(echo "$sys_info" | cut -d: -f1)
    local session_type=$(echo "$sys_info" | cut -d: -f2)
    log_info "Desktop: $de, Session: $session_type"

    if [ "$session_type" = "wayland" ] && [ "$FORCE_X11" != "true" ]; then
        if [[ "$de" == *"GNOME"* ]]; then
            setup_gnome_rdp
        elif [[ "$de" == *"KDE"* ]]; then
            setup_kde_rdp
        else
            log_warn "Wayland desktop - using VNC fallback"
        fi
    else
        setup_xrdp_x11
    fi
}

setup_xrdp_x11() {
    log_info "Setting up xrdp (X11 mode)..."
    install_packages xrdp xorgxrdp openssl

    mkdir -p /etc/skyview/certs
    [ ! -f /etc/skyview/certs/rdp-cert.pem ] && {
        as_root "openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj '/C=US/ST=SkyView/L=Remote/O=SkyView/CN=SkyViewRDP' \
            -keyout /etc/skyview/certs/rdp-key.pem \
            -out /etc/skyview/certs/rdp-cert.pem"
    }
    as_root "chown xrdp:xrdp /etc/skyview/certs/rdp-key.pem && chmod 640 /etc/skyview/certs/rdp-key.pem"

    cat > /etc/xrdp/xrdp.ini << EOF
[Globals]
port=${RDP_PORT}
bind_address=0.0.0.0
max_bpp=32
crypt_level=high
security_layer=negotiate
tls_cert_file=/etc/skyview/certs/rdp-cert.pem
tls_key_file=/etc/skyview/certs/rdp-key.pem
EOF

    cat > /etc/xrdp/sesman.ini << 'EOF'
[Globals]
MaxSessions=50
[Sessions]
X11DisplayOffset=10
EOF

    cat > /etc/xrdp/startwm.sh << 'STARTWM'
#!/bin/bash
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="/run/user/${USER_ID:-1000}"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null
command -v startplasma-x11 >/dev/null && exec startplasma-x11
command -v gnome-session >/dev/null && exec gnome-session
command -v startxfce4 >/dev/null && exec startxfce4
[ -f /usr/bin/x-session-manager ] && exec /usr/bin/x-session-manager
exec xterm
STARTWM
    as_root "chmod +x /etc/xrdp/startwm.sh"

    as_root "systemctl stop gnome-remote-desktop 2>/dev/null; systemctl disable gnome-remote-desktop 2>/dev/null || true"
    as_root "systemctl enable xrdp xrdp-sesman && systemctl restart xrdp-sesman && sleep 1 && systemctl restart xrdp"

    sleep 2
    if ss -tlnp 2>/dev/null | grep -q ":${RDP_PORT}"; then
        log_success "RDP listening on port ${RDP_PORT}"
    else
        log_error "RDP failed to start"
    fi
}

setup_gnome_rdp() {
    log_info "Setting up GNOME Remote Desktop..."
    install_packages gnome-remote-desktop
    as_root "systemctl enable --now gnome-remote-desktop 2>/dev/null || true"
    log_success "GNOME Remote Desktop enabled"
}

setup_kde_rdp() {
    log_info "Setting up KDE Remote Desktop (native Wayland RDP)..."
    install_packages krfb krdc

    # Configure KDE RDP for password-less access with custom password
    local krfb_config="$HOME/.config/krfbrc"

    # Create krfb config
    cat > "$krfb_config" << 'KRFBCONF'
[General]
acceptConnections=true
useAutostart=true
KRFBCONF

    # Create systemd user service for KDE RDP
    mkdir -p "$HOME/.config/systemd/user"

    cat > "$HOME/.config/systemd/user/skyview-kde-rdp.service" << 'KDEEOF'
[Unit]
Description=KDE Remote Desktop
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/krfb --port %i --password qrdemon1
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
KDEEOF

    # Try to start krfb via dbus if desktop session is active
    if command -v dbus-send >/dev/null 2>&1; then
        log_info "Attempting to start KDE RDP via D-Bus..."
        # Start krfb in sharing mode
        dbus-send --session --print-reply --dest=org.kde.krfb "/MainApplication" \
            org.qt.QWidgets.QApplication.mainWindow 2>/dev/null || true
    fi

    # Enable the systemd user service for future sessions
    as_root "systemctl --user daemon-reload 2>/dev/null || true"
    as_root "systemctl --user enable skyview-kde-rdp.service 2>/dev/null || true"
    as_root "systemctl --user start skyview-kde-rdp.service 2>/dev/null || true"

    log_info "KDE RDP configured"
    log_info "For Wayland KDE, RDP is available via krfb on port 5900"
    log_info "Alternatively, use VNC (port 5900) which works universally"
    log_success "KDE Remote Desktop ready"
}

# ==============================================================================
# VNC SETUP (Universal - works with any desktop)
# ==============================================================================

setup_vnc() {
    log_info "=== VNC Configuration ==="
    install_packages tigervnc-standalone-server

    mkdir -p /etc/skyview/vnc
    cat > /etc/skyview/vnc/vncsession << 'VNCINIT'
#!/bin/bash
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="/run/user/${USER_ID:-1000}"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null
eval $(dbus-launch --sh-syntax 2>/dev/null)
command -v startplasma-x11 >/dev/null && exec startplasma-x11
command -v gnome-session >/dev/null && exec gnome-session
command -v startxfce4 >/dev/null && exec startxfce4
[ -f /usr/bin/x-session-manager ] && exec /usr/bin/x-session-manager
exec xterm
VNCINIT
    as_root "chmod +x /etc/skyview/vnc/vncsession"

    mkdir -p ~/.vnc
    [ ! -f ~/.vnc/passwd ] && {
        echo "qrdemon1" | vncpasswd -f > ~/.vnc/passwd 2>/dev/null || true
        as_root "chmod 600 ~/.vnc/passwd"
    }

    mkdir -p ~/.config/systemd/user
    cat > ~/.config/systemd/user/skyview-vnc.service << 'VNCUSER'
[Unit]
Description=SkyView VNC Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/Xvnc :1 -geometry 1920x1080 -depth 24 -rfbport 5900 -localhost -securitytypes vncauth -rfbauth ~/.vnc/passwd -IdleTimeout 0
ExecStop=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=default.target
VNCUSER

    as_root "systemctl --user daemon-reload 2>/dev/null || true"
    as_root "systemctl --user enable --now skyview-vnc 2>/dev/null || true"

    sleep 2
    if ss -tlnp 2>/dev/null | grep -q ":${VNC_PORT}"; then
        log_success "VNC listening on port ${VNC_PORT}"
    else
        log_warn "VNC may need X session to start properly"
    fi
}

# ==============================================================================
# SSH SETUP (Port 2277 with hardening)
# ==============================================================================

setup_ssh() {
    log_info "=== SSH Configuration (Port ${SSH_PORT}) ==="

    # Check if SSH server is already installed
    if ! dpkg -l openssh-server 2>/dev/null | grep -q "^ii"; then
        log_info "Installing openssh-server..."
        if ! as_root "apt-get install -y openssh-server 2>&1"; then
            log_warn "Could not install openssh-server due to dependency issues"
            log_info "Fix apt: sudo apt --fix-broken install"
            log_info "Then run: sudo apt install openssh-server"
            return 0
        fi
    else
        log_success "openssh-server already installed"
    fi

    # Change port
    as_root "sed -i '/^Port /d' /etc/ssh/sshd_config && echo 'Port ${SSH_PORT}' >> /etc/ssh/sshd_config"

    # Add hardening
    cat >> /etc/ssh/sshd_config << 'EOF'

# SKYVIEW SSH HARDENING
PermitRootLogin no
MaxAuthTries 3
MaxSessions 10
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no

KexAlgorithms curve25519-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com
HostKeyAlgorithms ssh-ed25519

ClientAliveInterval 300
ClientAliveCountMax 2

Protocol 2
X11Forwarding no
AllowTcpForwarding no
PermitTunnel no
PermitUserEnvironment no

SyslogFacility AUTH
LogLevel INFO
RateLimit 10 60

AllowUsers skyview_user admin
AllowGroups sudo admin
IgnoreRhosts yes
StrictModes yes
UseDNS no

Banner /etc/ssh/banner.txt
EOF

    # Banner
    cat > /tmp/banner.txt << 'EOF'
******************************************
*   SKYVIEW REMOTE ACCESS - AUTHORIZED   *
*   All connections are monitored        *
*   Unauthorized access is prohibited    *
******************************************
EOF
    as_root "mv /tmp/banner.txt /etc/ssh/banner.txt"

    # Create user
    if ! id skyview_user >/dev/null 2>&1; then
        as_root "useradd -m -s /bin/bash -G sudo skyview_user"
        log_warn "Set skyview_user password: sudo passwd skyview_user"
    fi

    # SSH keys
    local user_home=$(getent passwd skyview_user | cut -d: -f6)
    as_root "mkdir -p ${user_home}/.ssh && chmod 700 ${user_home}/.ssh"
    if [ ! -f "${user_home}/.ssh/id_ed25519" ]; then
        as_root "sudo -u skyview_user ssh-keygen -t ed25519 -f ${user_home}/.ssh/id_ed25519 -N '' -C 'skyview_remote'"
    fi
    if [ -f "${user_home}/.ssh/id_ed25519.pub" ]; then
        as_root "cat ${user_home}/.ssh/id_ed25519.pub >> ${user_home}/.ssh/authorized_keys && chmod 600 ${user_home}/.ssh/authorized_keys && chown -R skyview_user:skyview_user ${user_home}/.ssh"
    fi

    # Start SSH
    as_root "systemctl enable sshd && systemctl restart sshd"

    sleep 2
    if ss -tlnp 2>/dev/null | grep -q ":${SSH_PORT}"; then
        log_success "SSH listening on port ${SSH_PORT}"
    else
        log_error "SSH failed to start"
    fi
}

# ==============================================================================
# FIREWALL SETUP - Auto-detect and configure
# =============================================================================

setup_firewall() {
    log_info "=== Configuring Firewall ==="

    local firewall_type="none"
    local firewall_active=false

    # Detect firewall type and status
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            firewall_type="ufw"
            firewall_active=true
            log_info "Detected: UFW (active)"
        fi
    fi

    if command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            firewall_type="firewalld"
            firewall_active=true
            log_info "Detected: firewalld (active)"
        fi
    fi

    if command -v iptables >/dev/null 2>&1 && [ "$firewall_active" = "false" ]; then
        # Check if iptables has rules
        if iptables -L INPUT -n 2>/dev/null | grep -q "policy DROP\|REJECT\|ACCEPT"; then
            firewall_type="iptables"
            firewall_active=true
            log_info "Detected: iptables (active)"
        fi
    fi

    # Configure based on firewall type
    case "$firewall_type" in
        ufw)
            log_info "Configuring UFW rules..."
            as_root "ufw allow ${RDP_PORT}/tcp comment 'RDP' 2>/dev/null || true"
            as_root "ufw allow ${VNC_PORT}/tcp comment 'VNC' 2>/dev/null || true"
            as_root "ufw allow ${SSH_PORT}/tcp comment 'SSH' 2>/dev/null || true"
            as_root "ufw reload 2>/dev/null || true"
            log_success "UFW rules added: RDP(${RDP_PORT}), VNC(${VNC_PORT}), SSH(${SSH_PORT})"
            ;;
        firewalld)
            log_info "Configuring firewalld rules..."
            as_root "firewall-cmd --permanent --add-port=${RDP_PORT}/tcp 2>/dev/null || true"
            as_root "firewall-cmd --permanent --add-port=${VNC_PORT}/tcp 2>/dev/null || true"
            as_root "firewall-cmd --permanent --add-port=${SSH_PORT}/tcp 2>/dev/null || true"
            as_root "firewall-cmd --reload 2>/dev/null || true"
            log_success "firewalld rules added: RDP(${RDP_PORT}), VNC(${VNC_PORT}), SSH(${SSH_PORT})"
            ;;
        iptables)
            log_info "Configuring iptables rules..."
            echo "$SUDOPWD" | sudo -S bash -c "
                iptables -C INPUT -p tcp --dport ${RDP_PORT} -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport ${RDP_PORT} -j ACCEPT
                iptables -C INPUT -p tcp --dport ${VNC_PORT} -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport ${VNC_PORT} -j ACCEPT
                iptables -C INPUT -p tcp --dport ${SSH_PORT} -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport ${SSH_PORT} -j ACCEPT
            "
            log_success "iptables rules added: RDP(${RDP_PORT}), VNC(${VNC_PORT}), SSH(${SSH_PORT})"
            log_warn "Note: iptables rules may not persist after reboot. Consider using UFW or firewalld."
            ;;
        *)
            log_info "No active firewall detected - ports are open by default"
            log_warn "For security, consider installing and configuring UFW or firewalld"
            ;;
    esac

    # Verify ports are listening
    echo ""
    log_info "Port Status:"
    ss -tlnp 2>/dev/null | grep -E ":${RDP_PORT}|:${VNC_PORT}|:${SSH_PORT}" | while read line; do
        echo "   $line"
    done
}

# ==============================================================================
# SYSTEMD SERVICE
# =============================================================================

create_systemd_service() {
    log_info "=== Creating Systemd Service ==="
    cat > /etc/systemd/system/skyview-remote.service << 'EOF'
[Unit]
Description=SkyView Universal Remote Access (RDP + VNC + SSH)
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/home/chris/dev/skyview-remote-access/skyview-remote-access.sh --auto
ExecStop=/bin/bash -c 'systemctl stop xrdp 2>/dev/null; systemctl stop gnome-remote-desktop 2>/dev/null; systemctl stop sshd 2>/dev/null'
Restart=on-failure
RestartSec=5

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/etc/skyview /var/log /run
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    as_root "systemctl daemon-reload && systemctl enable skyview-remote"
    log_success "Systemd service created and enabled"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    parse_args() {
        while [[ $# -gt 0 ]]; do
            case $1 in
                --ssh-port) SSH_PORT="$2"; shift 2 ;;
                --rdp-port) RDP_PORT="$2"; shift 2 ;;
                --vnc-port) VNC_PORT="$2"; shift 2 ;;
                --force-x11) FORCE_X11="true"; shift ;;
                --install-all) MODE="all"; shift ;;
                --auto) MODE="auto"; shift ;;
                *) shift ;;
            esac
        done
    }
    parse_args "$@"

    [ "$EUID" -ne 0 ] && { log_error "Run as: echo '$SUDOPWD' | sudo -S $0 --auto"; exit 1; }

    banner
    log_info "Mode: ${MODE}, SSH: ${SSH_PORT}, RDP: ${RDP_PORT}, VNC: ${VNC_PORT}"

    local sys_info=$(detect_system)
    log_info "System: ${sys_info}"

    setup_rdp
    setup_vnc
    setup_ssh
    setup_firewall
    create_systemd_service

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "   ${BOLD}SETUP COMPLETE${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}')
    echo ""
    echo -e "   ${GREEN}RDP:${NC}  Microsoft Remote Desktop → ${ip}:${RDP_PORT}"
    echo -e "   ${GREEN}VNC:${NC}  TigerVNC Viewer → ${ip}:${VNC_PORT}"
    echo -e "   ${GREEN}SSH:${NC}  ssh -p ${SSH_PORT} skyview_user@${ip}"
    echo ""
    log_success "All services configured and enabled!"
}

main "$@"
