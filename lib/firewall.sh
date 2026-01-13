#!/bin/bash
#
# SkyView Universal Remote Access - Firewall Configuration
# Configures UFW, firewalld, nftables, and iptables for remote access
#

# Source utility functions
if [[ -z "${LIB_UTILS_SOURCED:-}" ]]; then
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [[ -f "$lib_dir/utils.sh" ]] && source "$lib_dir/utils.sh"
fi

if [[ -z "${LIB_DETECT_OS_SOURCED:-}" ]]; then
    LIB_DETECT_OS_SOURCED=1
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [[ -f "$lib_dir/detect_os.sh" ]] && source "$lib_dir/detect_os.sh"
fi

# ============================================================================
# Configuration Variables
# ============================================================================

SKYVIEW_FIREWALL_TYPE=""
SKYVIEW_FIREWALL_ENABLED=""
SKYVIEW_RDP_PORT="${SKYVIEW_RDP_PORT:-3389}"
SKYVIEW_VNC_PORT="${SKYVIEW_VNC_PORT:-5900}"
SKYVIEW_SSH_PORT="${SKYVIEW_SSH_PORT:-22}"
SKYVIEW_FIREWALL_SSH_WHITELIST=""
SKYVIEW_FIREWALL_ALLOW_PRIVATE=""

# ============================================================================
# Firewall Detection Functions
# ============================================================================

# Detect which firewall is in use
detect_firewall() {
    log_debug "Detecting firewall type..."

    # Check for firewalld (Fedora/RHEL)
    if command -v firewall-cmd &>/dev/null; then
        if systemctl is-active --quiet firewalld 2>/dev/null || \
           [[ -f /usr/lib/systemd/system/firewalld.service ]]; then
            SKYVIEW_FIREWALL_TYPE="firewalld"
            log_debug "Detected firewall: firewalld"
            return 0
        fi
    fi

    # Check for UFW (Ubuntu/Debian)
    if command -v ufw &>/dev/null; then
        SKYVIEW_FIREWALL_TYPE="ufw"
        log_debug "Detected firewall: ufw"
        return 0
    fi

    # Check for nftables
    if command -v nft &>/dev/null; then
        if systemctl is-active --quiet nftables 2>/dev/null || \
           [[ -f /usr/lib/systemd/system/nftables.service ]]; then
            SKYVIEW_FIREWALL_TYPE="nftables"
            log_debug "Detected firewall: nftables"
            return 0
        fi
    fi

    # Check for iptables
    if command -v iptables &>/dev/null; then
        if iptables -L -n 2>/dev/null | head -5 | grep -q . || \
           systemctl is-active --quiet iptables 2>/dev/null || \
           [[ -f /usr/lib/systemd/system/iptables.service ]]; then
            SKYVIEW_FIREWALL_TYPE="iptables"
            log_debug "Detected firewall: iptables"
            return 0
        fi
    fi

    # Check if iptables is available at all
    if command -v iptables &>/dev/null; then
        SKYVIEW_FIREWALL_TYPE="iptables-legacy"
        log_debug "Detected firewall: iptables-legacy"
        return 0
    fi

    SKYVIEW_FIREWALL_TYPE="none"
    log_warn "No firewall detected"
    return 0
}

# ============================================================================
# UFW Configuration Functions
# ============================================================================

# Configure UFW for remote access
configure_ufw() {
    log_info "Configuring UFW for remote access..."

    require_root || return 1

    # Install UFW if not present
    if ! command -v ufw &>/dev/null; then
        log_info "Installing UFW..."
        install_package "ufw" || return 1
    fi

    # Set default policies
    ufw default deny incoming 2>/dev/null || true
    ufw default allow outgoing 2>/dev/null || true

    # Allow SSH (with optional rate limiting)
    if [[ -n "$SKYVIEW_FIREWALL_SSH_WHITELIST" ]]; then
        ufw allow from "$SKYVIEW_FIREWALL_SSH_WHITELIST" to any port "$SKYVIEW_SSH_PORT" proto tcp 2>/dev/null || true
    else
        ufw limit "$SKYVIEW_SSH_PORT"/tcp comment "SSH with rate limiting" 2>/dev/null || true
    fi

    # Allow RDP
    ufw allow "$SKYVIEW_RDP_PORT"/tcp comment "RDP" 2>/dev/null || true

    # Allow VNC
    ufw allow "$SKYVIEW_VNC_PORT"/tcp comment "VNC" 2>/dev/null || true

    # Allow VNC range for multiple displays
    ufw allow 5900:5910/tcp comment "VNC display range" 2>/dev/null || true

    # Enable UFW
    if ! ufw status | grep -q "Status: active"; then
        echo "y" | ufw enable 2>/dev/null || true
    fi

    log_info "UFW configured successfully"
    return 0
}

# Configure UFW with rich rules for security
configure_ufw_advanced() {
    log_info "Configuring UFW with advanced security rules..."

    require_root || return 1

    # Set default policies
    ufw default deny incoming 2>/dev/null
    ufw default allow outgoing 2>/dev/null

    # Allow SSH from specific network only
    if [[ -n "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" ]]; then
        ufw allow from "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" to any port "$SKYVIEW_SSH_PORT" proto tcp 2>/dev/null
    fi

    # Allow RDP from specific network only
    if [[ -n "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" ]]; then
        ufw allow from "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" to any port "$SKYVIEW_RDP_PORT" proto tcp 2>/dev/null
    fi

    # Allow VNC from specific network only
    if [[ -n "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" ]]; then
        ufw allow from "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" to any port "$SKYVIEW_VNC_PORT" proto tcp 2>/dev/null
    fi

    # Enable UFW
    echo "y" | ufw enable 2>/dev/null || true

    log_info "UFW advanced configuration complete"
}

# ============================================================================
# Firewalld Configuration Functions
# ============================================================================

# Configure firewalld for remote access
configure_firewalld() {
    log_info "Configuring firewalld for remote access..."

    require_root || return 1

    # Install firewalld if not present
    if ! command -v firewall-cmd &>/dev/null; then
        log_info "Installing firewalld..."
        install_package "firewalld" || return 1
    fi

    # Start and enable firewalld
    if ! systemctl is-active --quiet firewalld; then
        systemctl start firewalld 2>/dev/null || true
    fi
    systemctl enable --now firewalld 2>/dev/null || true

    # Get default zone
    local default_zone
    default_zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo "public")

    # Add services (if available)
    firewall-cmd --permanent --zone="$default_zone" --add-service=ssh 2>/dev/null || true
    firewall-cmd --permanent --zone="$default_zone" --add-service=vnc 2>/dev/null || true

    # Add ports if services not available
    firewall-cmd --permanent --zone="$default_zone" --add-port="${SKYVIEW_SSH_PORT}/tcp" 2>/dev/null || true
    firewall-cmd --permanent --zone="$default_zone" --add-port="${SKYVIEW_RDP_PORT}/tcp" 2>/dev/null || true
    firewall-cmd --permanent --zone="$default_zone" --add-port="${SKYVIEW_VNC_PORT}/tcp" 2>/dev/null || true
    firewall-cmd --permanent --zone="$default_zone" --add-port="5900-5910/tcp" 2>/dev/null || true

    # Apply changes
    firewall-cmd --reload 2>/dev/null || true

    log_info "firewalld configured successfully"
    return 0
}

# Configure firewalld with rich rules for security
configure_firewalld_advanced() {
    log_info "Configuring firewalld with rich rules for security..."

    require_root || return 1

    # Start and enable firewalld
    systemctl enable --now firewalld 2>/dev/null || true

    # Get default zone
    local default_zone
    default_zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo "public")

    # Remove default SSH access if whitelisting is enabled
    if [[ -n "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" ]]; then
        firewall-cmd --permanent --zone="$default_zone" --remove-service=ssh 2>/dev/null || true
        firewall-cmd --permanent --zone="$default_zone" --remove-port="${SKYVIEW_SSH_PORT}/tcp" 2>/dev/null || true
    fi

    # Add rich rules for whitelisted networks
    if [[ -n "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" ]]; then
        # SSH from private network
        firewall-cmd --permanent --zone="$default_zone" \
            --add-rich-rule="rule family='ipv4' source address='${SKYVIEW_FIREWALL_ALLOW_PRIVATE}' port protocol='tcp' port='${SKYVIEW_SSH_PORT}' accept" 2>/dev/null || true

        # RDP from private network
        firewall-cmd --permanent --zone="$default_zone" \
            --add-rich-rule="rule family='ipv4' source address='${SKYVIEW_FIREWALL_ALLOW_PRIVATE}' port protocol='tcp' port='${SKYVIEW_RDP_PORT}' accept" 2>/dev/null || true

        # VNC from private network
        firewall-cmd --permanent --zone="$default_zone" \
            --add-rich-rule="rule family='ipv4' source address='${SKYVIEW_FIREWALL_ALLOW_PRIVATE}' port protocol='tcp' port='${SKYVIEW_VNC_PORT}' accept" 2>/dev/null || true
    fi

    # Apply changes
    firewall-cmd --reload 2>/dev/null || true

    log_info "firewalld advanced configuration complete"
}

# ============================================================================
# Nftables Configuration Functions
# ============================================================================

# Configure nftables for remote access
configure_nftables() {
    log_info "Configuring nftables for remote access..."

    require_root || return 1

    # Install nftables if not present
    if ! command -v nft &>/dev/null; then
        log_info "Installing nftables..."
        install_package "nftables" || return 1
    fi

    # Create nftables configuration
    local nft_config="/etc/nftables.conf"

    # Backup existing config
    if [[ -f "$nft_config" ]]; then
        cp "$nft_config" "${nft_config}.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    fi

    # Generate new config
    generate_nftables_config "$nft_config"

    # Enable and start nftables
    systemctl enable --now nftables 2>/dev/null || true

    # Apply configuration
    nft -f "$nft_config" 2>/dev/null || true

    log_info "nftables configured successfully"
    return 0
}

# Generate nftables configuration
generate_nftables_config() {
    local output_file="$1"

    cat > "$output_file" << 'EOF'
#!/usr/sbin/nft -f

# SkyView Universal Remote Access - nftables Configuration
# Generated by skyview-remote-access

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Allow loopback
        iifname "lo" accept;

        # Allow established/related connections
        ct state { established, related } accept;

        # Allow ICMP (ping)
        icmp type echo-request accept;

        # Allow SSH
        tcp dport 22 accept;

        # Allow RDP
        tcp dport 3389 accept;

        # Allow VNC
        tcp dport { 5900, 5901, 5902 } accept;

        # Log and drop everything else
        log prefix "INPUT DROP: " drop;
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

    chmod 600 "$output_file"
}

# ============================================================================
# IPTables Configuration Functions
# ============================================================================

# Configure iptables for remote access
configure_iptables() {
    log_info "Configuring iptables for remote access..."

    require_root || return 1

    # Create iptables rules script
    local rules_script="/etc/iptables/rules.v4"
    local rules_dir="$(dirname "$rules_script")"

    mkdir -p "$rules_dir"

    # Generate rules
    generate_iptables_rules "$rules_script"

    # Apply rules
    iptables-restore < "$rules_script" 2>/dev/null || true

    # Save rules
    if command -v iptables-save &>/dev/null; then
        iptables-save > "$rules_script" 2>/dev/null || true
    fi

    log_info "iptables configured successfully"
    return 0
}

# Generate iptables rules
generate_iptables_rules() {
    local output_file="$1"

    cat > "$output_file" << EOF
# SkyView Universal Remote Access - iptables Rules
# Generated by skyview-remote-access
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT

# Allow established/related connections
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
-A INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT

# Allow RDP
-A INPUT -p tcp --dport 3389 -m state --state NEW -j ACCEPT

# Allow VNC
-A INPUT -p tcp --dport 5900 -m state --state NEW -j ACCEPT
-A INPUT -p tcp --dport 5901 -m state --state NEW -j ACCEPT
-A INPUT -p tcp --dport 5902 -m state --state NEW -j ACCEPT

# Allow ICMP
-A INPUT -p icmp --icmp-type echo-request -j ACCEPT

COMMIT
EOF
}

# Configure iptables with rate limiting
configure_iptables_advanced() {
    log_info "Configuring iptables with rate limiting..."

    require_root || return 1

    # Flush existing rules
    iptables -F INPUT 2>/dev/null || true
    iptables -F FORWARD 2>/dev/null || true

    # Set default policies
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT

    # Allow established/related
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Rate limit SSH (6 connections per minute, burst 4)
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP

    # Allow SSH from private network if specified
    if [[ -n "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" ]]; then
        iptables -A INPUT -s "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" -p tcp --dport 22 -m state --state NEW -j ACCEPT
    else
        iptables -A INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT
    fi

    # Allow RDP from private network
    if [[ -n "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" ]]; then
        iptables -A INPUT -s "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" -p tcp --dport 3389 -m state --state NEW -j ACCEPT
    else
        iptables -A INPUT -p tcp --dport 3389 -m state --state NEW -j ACCEPT
    fi

    # Allow VNC from private network
    if [[ -n "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" ]]; then
        iptables -A INPUT -s "$SKYVIEW_FIREWALL_ALLOW_PRIVATE" -p tcp --dport 5900:5910 -m state --state NEW -j ACCEPT
    else
        iptables -A INPUT -p tcp --dport 5900:5910 -m state --state NEW -j ACCEPT
    fi

    # Allow ICMP
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

    # Save rules
    if command -v iptables-save &>/dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi

    log_info "iptables advanced configuration complete"
}

# ============================================================================
# Main Configuration Function
# ============================================================================

# Configure firewall for remote access
configure_firewall() {
    local advanced="${1:-false}"

    log_info "Configuring firewall (type: $SKYVIEW_FIREWALL_TYPE, advanced: $advanced)..."

    # Detect firewall if not already done
    if [[ -z "$SKYVIEW_FIREWALL_TYPE" ]]; then
        detect_firewall
    fi

    case "$SKYVIEW_FIREWALL_TYPE" in
        ufw)
            if [[ "$advanced" == "true" ]]; then
                configure_ufw_advanced
            else
                configure_ufw
            fi
            ;;
        firewalld)
            if [[ "$advanced" == "true" ]]; then
                configure_firewalld_advanced
            else
                configure_firewalld
            fi
            ;;
        nftables)
            configure_nftables
            ;;
        iptables|iptables-legacy)
            if [[ "$advanced" == "true" ]]; then
                configure_iptables_advanced
            else
                configure_iptables
            fi
            ;;
        none)
            log_warn "No firewall detected - skipping configuration"
            return 0
            ;;
        *)
            log_error "Unknown firewall type: $SKYVIEW_FIREWALL_TYPE"
            return 1
            ;;
    esac

    SKYVIEW_FIREWALL_ENABLED="true"
    return 0
}

# Open specific port in firewall
firewall_open_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    local source_addr="${3:-}"

    log_info "Opening port $port/$protocol in firewall..."

    case "$SKYVIEW_FIREWALL_TYPE" in
        ufw)
            if [[ -n "$source_addr" ]]; then
                ufw allow from "$source_addr" to any port "$port" proto "$protocol" 2>/dev/null
            else
                ufw allow "$port"/"$protocol" 2>/dev/null
            fi
            ;;
        firewalld)
            firewall-cmd --permanent --add-port="${port}/${protocol}" 2>/dev/null
            firewall-cmd --reload 2>/dev/null
            ;;
        nftables)
            nft add rule inet filter input tcp dport "$port" accept 2>/dev/null
            ;;
        iptables|iptables-legacy)
            if [[ -n "$source_addr" ]]; then
                iptables -A INPUT -s "$source_addr" -p "$protocol" --dport "$port" -m state --state NEW -j ACCEPT 2>/dev/null
            else
                iptables -A INPUT -p "$protocol" --dport "$port" -m state --state NEW -j ACCEPT 2>/dev/null
            fi
            ;;
    esac

    log_debug "Port $port/$protocol opened"
}

# Close specific port in firewall
firewall_close_port() {
    local port="$1"
    local protocol="${2:-tcp}"

    log_info "Closing port $port/$protocol in firewall..."

    case "$SKYVIEW_FIREWALL_TYPE" in
        ufw)
            ufw deny "$port"/"$protocol" 2>/dev/null
            ;;
        firewalld)
            firewall-cmd --permanent --remove-port="${port}/${protocol}" 2>/dev/null
            firewall-cmd --reload 2>/dev/null
            ;;
        nftables)
            nft delete rule inet filter input tcp dport "$port" accept 2>/dev/null || true
            ;;
        iptables|iptables-legacy)
            iptables -D INPUT -p "$protocol" --dport "$port" -m state --state NEW -j ACCEPT 2>/dev/null || true
            ;;
    esac

    log_debug "Port $port/$protocol closed"
}

# ============================================================================
# Verification Functions
# ============================================================================

# Verify firewall configuration
verify_firewall() {
    log_info "Verifying firewall configuration..."

    local errors=0

    # Check firewall status
    case "$SKYVIEW_FIREWALL_TYPE" in
        ufw)
            if ufw status | grep -q "Status: active"; then
                log_info "UFW is active"
            else
                log_warn "UFW is not active"
                ((errors++))
            fi
            ;;
        firewalld)
            if firewall-cmd --state 2>/dev/null | grep -q "running"; then
                log_info "firewalld is running"
            else
                log_warn "firewalld is not running"
                ((errors++))
            fi
            ;;
        nftables)
            if nft list ruleset 2>/dev/null | grep -q "chain input"; then
                log_info "nftables is configured"
            else
                log_warn "nftables has no rules"
                ((errors++))
            fi
            ;;
        iptables|iptables-legacy)
            if iptables -L INPUT 2>/dev/null | head -5 | grep -q .; then
                log_info "iptables has rules"
            else
                log_warn "iptables has no rules"
                ((errors++))
            fi
            ;;
    esac

    # Check if required ports are accessible
    if is_port_open "localhost" "$SKYVIEW_RDP_PORT"; then
        log_info "RDP port $SKYVIEW_RDP_PORT is accessible"
    else
        log_warn "RDP port $SKYVIEW_RDP_PORT is not accessible"
    fi

    if is_port_open "localhost" "$SKYVIEW_VNC_PORT"; then
        log_info "VNC port $SKYVIEW_VNC_PORT is accessible"
    else
        log_warn "VNC port $SKYVIEW_VNC_PORT is not accessible"
    fi

    return $errors
}

# ============================================================================
# Utility Functions
# ============================================================================

# Get firewall status
get_firewall_status() {
    local status="unknown"

    case "$SKYVIEW_FIREWALL_TYPE" in
        ufw)
            if ufw status | grep -q "Status: active"; then
                status="active"
            else
                status="inactive"
            fi
            ;;
        firewalld)
            if firewall-cmd --state 2>/dev/null | grep -q "running"; then
                status="active"
            else
                status="inactive"
            fi
            ;;
        nftables)
            if nft list ruleset 2>/dev/null | grep -q "chain input"; then
                status="configured"
            else
                status="empty"
            fi
            ;;
        iptables|iptables-legacy)
            status="configured"
            ;;
    esac

    echo "Firewall: $SKYVIEW_FIREWALL_TYPE - $status"
}

# Print firewall configuration summary
print_firewall_summary() {
    print_header "Firewall Configuration"

    cat << EOF
Firewall Type:    $SKYVIEW_FIREWALL_TYPE
Enabled:          ${SKYVIEW_FIREWALL_ENABLED:-unknown}
SSH Port:         $SKYVIEW_SSH_PORT
RDP Port:         $SKYVIEW_RDP_PORT
VNC Port:         $SKYVIEW_VNC_PORT

$(get_firewall_status)
EOF
}
