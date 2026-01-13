#!/bin/bash

# ==============================================================================
# SKYVIEW UNIVERSAL REMOTE ORCHESTRATOR (SURO) v3.1
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
LOG_FILE="$HOME/.skyview_setup.log"
CERT_DIR="/etc/xrdp"
SSH_KEY_TYPE="ed25519"
SSH_KEY_PATH="$HOME/.ssh/id_${SSH_KEY_TYPE}_skyview"
SSH_REMOTE_USER="${SSH_REMOTE_USER:-}"
SSH_REMOTE_HOST="${SSH_REMOTE_HOST:-}"
SSH_PORT="${SSH_PORT:-2277}"
SSH_PASSWORD_AUTH="${SSH_PASSWORD_AUTH:-yes}"

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
    echo -e "${CYAN}┃${NC}${GOLD}    S K Y V I E W   U N I V E R S A L   R E M O T E   v3.1       ${NC}${CYAN}┃${NC}"
    echo -e "${CYAN}┃${NC}${MAGENTA}    Works with ANY Desktop: KDE, GNOME, XFCE, etc.              ${NC}${CYAN}┃${NC}"
    echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo ""
}

# =============================================================================
# SSH KEY SETUP (Auto-configuration for remote access)
# =============================================================================

setup_ssh_keys() {
    log "${BOLD}>>> CONFIGURING SSH KEY AUTHENTICATION...${NC}"
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # Check for existing keys (prefer ed25519, fall back to rsa)
    local key_found=""
    local pub_key=""
    
    # Check for existing skyview key first
    if [ -f "$SSH_KEY_PATH" ]; then
        key_found="$SSH_KEY_PATH"
        pub_key="${SSH_KEY_PATH}.pub"
        log "${GREEN}[✔]${NC} Found existing SkyView SSH key: $key_found"
    # Check for other ed25519 keys
    elif [ -f "$HOME/.ssh/id_ed25519" ]; then
        key_found="$HOME/.ssh/id_ed25519"
        pub_key="$HOME/.ssh/id_ed25519.pub"
        log "${GREEN}[✔]${NC} Found existing ED25519 key: $key_found"
    elif [ -f "$HOME/.ssh/id_ed25519_encryption" ]; then
        key_found="$HOME/.ssh/id_ed25519_encryption"
        pub_key="$HOME/.ssh/id_ed25519_encryption.pub"
        log "${GREEN}[✔]${NC} Found existing encryption key: $key_found"
    # Check for RSA keys
    elif [ -f "$HOME/.ssh/id_rsa" ]; then
        key_found="$HOME/.ssh/id_rsa"
        pub_key="$HOME/.ssh/id_rsa.pub"
        log "${GREEN}[✔]${NC} Found existing RSA key: $key_found"
    elif [ -f "$HOME/.ssh/id_rsa_gpg" ]; then
        key_found="$HOME/.ssh/id_rsa_gpg"
        pub_key="$HOME/.ssh/id_rsa_gpg.pub"
        log "${GREEN}[✔]${NC} Found existing GPG-RSA key: $key_found"
    fi
    
    # Generate new key if none found
    if [ -z "$key_found" ]; then
        log "${YELLOW}[*]${NC} No SSH key found. Generating new ED25519 key..."
        ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "SkyView Remote Access - $(whoami)@$(hostname)"
        key_found="$SSH_KEY_PATH"
        pub_key="${SSH_KEY_PATH}.pub"
        log "${GREEN}[✔]${NC} Generated new SSH key: $key_found"
    fi
    
    # Ensure key is in ssh-agent
    if ! pgrep -u "$USER" ssh-agent > /dev/null; then
        eval "$(ssh-agent -s)" >> "$LOG_FILE" 2>&1
        log "${GREEN}[✔]${NC} Started SSH agent"
    fi
    
    # Add key to agent (suppress errors if already added)
    ssh-add "$key_found" 2>/dev/null || true
    log "${GREEN}[✔]${NC} SSH key loaded into agent"
    
    # Create/update SSH config for easier connections
    setup_ssh_config "$key_found"
    
    # Store the public key for display
    SSH_PUBLIC_KEY=$(cat "$pub_key")
    SSH_ACTIVE_KEY="$key_found"
    
    log "${GREEN}[✔]${NC} SSH key authentication configured"
}

configure_ssh_server() {
    log "${BOLD}>>> CONFIGURING SSH SERVER...${NC}"
    
    local sshd_config="/etc/ssh/sshd_config"
    
    if [ ! -f "$sshd_config" ]; then
        log "${YELLOW}[*]${NC} SSH server not installed, skipping"
        return 0
    fi
    
    as_root "cp $sshd_config ${sshd_config}.bak.skyview 2>/dev/null || true"
    
    as_root "sed -i 's/^#Port .*/Port $SSH_PORT/' $sshd_config"
    as_root "sed -i 's/^Port .*/Port $SSH_PORT/' $sshd_config"
    
    if [ "$SSH_PASSWORD_AUTH" = "yes" ]; then
        as_root "sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' $sshd_config"
        as_root "sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' $sshd_config"
        log "${GREEN}[✔]${NC} Password authentication enabled"
    else
        as_root "sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' $sshd_config"
        as_root "sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' $sshd_config"
        log "${GREEN}[✔]${NC} Password authentication disabled (key-only)"
    fi
    
    as_root "systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true"
    as_root "systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true"
    
    if ss -tlnp 2>/dev/null | grep -q ":$SSH_PORT"; then
        log "${GREEN}[✔]${NC} SSH server running on port $SSH_PORT"
    else
        log "${RED}[✗]${NC} SSH server failed to start"
    fi
}

setup_ssh_config() {
    local key_path="$1"
    local ssh_config="$HOME/.ssh/config"
    
    # Create config if doesn't exist
    touch "$ssh_config"
    chmod 600 "$ssh_config"
    
    # Add default settings if not present
    if ! grep -q "Host \*" "$ssh_config" 2>/dev/null; then
        cat >> "$ssh_config" << EOF

# SkyView Remote Access - Default Settings
Host *
    AddKeysToAgent yes
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3

EOF
        log "${GREEN}[✔]${NC} Added default SSH config settings"
    fi
}

deploy_ssh_key_to_remote() {
    local remote_host="$1"
    local remote_user="$2"
    local remote_port="${3:-22}"
    
    if [ -z "$remote_host" ] || [ -z "$remote_user" ]; then
        log "${YELLOW}[*]${NC} No remote host specified, skipping key deployment"
        return 0
    fi
    
    log "${BOLD}>>> DEPLOYING SSH KEY TO REMOTE HOST...${NC}"
    log "   Target: ${remote_user}@${remote_host}:${remote_port}"
    
    # Try ssh-copy-id first (easiest method)
    if command -v ssh-copy-id &> /dev/null; then
        log "${YELLOW}[*]${NC} Attempting to copy key using ssh-copy-id..."
        log "${YELLOW}[*]${NC} You may be prompted for the remote password (one time only)"
        
        if ssh-copy-id -i "${SSH_ACTIVE_KEY}.pub" -p "$remote_port" "${remote_user}@${remote_host}" 2>>"$LOG_FILE"; then
            log "${GREEN}[✔]${NC} SSH key successfully deployed to remote host"
            return 0
        else
            log "${YELLOW}[!]${NC} ssh-copy-id failed, trying manual method..."
        fi
    fi
    
    # Manual method as fallback
    log "${YELLOW}[*]${NC} Deploying key manually..."
    local pub_key=$(cat "${SSH_ACTIVE_KEY}.pub")
    
    ssh -p "$remote_port" "${remote_user}@${remote_host}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pub_key' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" 2>>"$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        log "${GREEN}[✔]${NC} SSH key manually deployed to remote host"
        return 0
    else
        log "${RED}[✗]${NC} Failed to deploy SSH key. You may need to add it manually."
        log "${YELLOW}[*]${NC} Add this key to remote ~/.ssh/authorized_keys:"
        log "${CYAN}$pub_key${NC}"
        return 1
    fi
}

verify_ssh_connection() {
    local remote_host="$1"
    local remote_user="$2"
    local remote_port="${3:-22}"
    
    if [ -z "$remote_host" ] || [ -z "$remote_user" ]; then
        return 0
    fi
    
    log "${BOLD}>>> VERIFYING SSH CONNECTION...${NC}"
    
    if ssh -o BatchMode=yes -o ConnectTimeout=10 -p "$remote_port" "${remote_user}@${remote_host}" "echo 'SSH connection successful'" 2>>"$LOG_FILE"; then
        log "${GREEN}[✔]${NC} SSH key authentication verified!"
        return 0
    else
        log "${RED}[✗]${NC} SSH key authentication failed"
        log "${YELLOW}[*]${NC} Please manually add your public key to the remote server:"
        log ""
        log "${CYAN}$SSH_PUBLIC_KEY${NC}"
        log ""
        log "Run on remote: ${GOLD}echo '$SSH_PUBLIC_KEY' >> ~/.ssh/authorized_keys${NC}"
        return 1
    fi
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

install_dependencies() {
    log "${BOLD}>>> CHECKING DEPENDENCIES...${NC}"
    
    local packages_needed=""
    
    # Check for xrdp
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

# SkyView Universal Session Manager
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
    echo -e "   ${BLUE}SSH Key:${NC}        ${CYAN}${SSH_ACTIVE_KEY:-~/.ssh/id_ed25519}${NC}"
    echo -e "   ${BLUE}SSH Port:${NC}       ${GOLD}${SSH_PORT}${NC}"
    echo -e "   ${BLUE}SSH Auth:${NC}       ${CYAN}Password: ${SSH_PASSWORD_AUTH}, Key: yes${NC}"
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
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "   ${BOLD}SSH PUBLIC KEY (add to remote ~/.ssh/authorized_keys):${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "   ${GOLD}${SSH_PUBLIC_KEY:-No key found}${NC}"
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
setup_ssh_keys
configure_ssh_server
install_dependencies
setup_certificates
configure_xrdp
configure_session_manager "$DESKTOP"
configure_firewall
start_services

# Deploy SSH key to remote if specified
if [ -n "$SSH_REMOTE_HOST" ] && [ -n "$SSH_REMOTE_USER" ]; then
    deploy_ssh_key_to_remote "$SSH_REMOTE_HOST" "$SSH_REMOTE_USER"
    verify_ssh_connection "$SSH_REMOTE_HOST" "$SSH_REMOTE_USER"
fi

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
