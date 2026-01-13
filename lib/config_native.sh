#!/bin/bash
#
# SkyView Universal Remote Access - Native Desktop RDP Configuration
# Configures native Wayland RDP for KDE and GNOME
#

# Source dependencies
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

if [[ -z "${LIB_DETECT_DE_SOURCED:-}" ]]; then
    LIB_DETECT_DE_SOURCED=1
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [[ -f "$lib_dir/detect_de.sh" ]] && source "$lib_dir/detect_de.sh"
fi

# ============================================================================
# Configuration Variables
# ============================================================================

SKYVIEW_NATIVE_RDP_PORT="${SKYVIEW_NATIVE_RDP_PORT:-3389}"
SKYVIEW_NATIVE_RDP_ENABLED="${SKYVIEW_NATIVE_RDP_ENABLED:-true}"

# ============================================================================
# Installation Functions
# ============================================================================

# Install native RDP packages based on DE
install_native_rdp_packages() {
    log_info "Installing native RDP packages for $SKYVIEW_DE..."

    local packages=""

    case "$SKYVIEW_DE" in
        KDE|KDE_Plasma|plasma)
            packages=$(get_kde_rdp_packages)
            ;;
        GNOME)
            packages=$(get_gnome_rdp_packages)
            ;;
        *)
            log_warn "Native RDP not supported for $SKYVIEW_DE"
            return 1
            ;;
    esac

    if [[ -n "$packages" ]]; then
        if install_packages "$packages"; then
            log_info "Native RDP packages installed successfully"
            return 0
        else
            log_error "Failed to install native RDP packages"
            return 1
        fi
    fi

    return 1
}

# Get KDE RDP packages
get_kde_rdp_packages() {
    case "$SKYVIEW_PACKAGE_MANAGER" in
        apt)
            echo "krfb krdc"
            ;;
        dnf|yum)
            echo "krfb krdc"
            ;;
        pacman)
            echo "krfb krdc"
            ;;
        zypper)
            echo "krfb krdc"
            ;;
        *)
            echo "krfb"
            ;;
    esac
}

# Get GNOME RDP packages
get_gnome_rdp_packages() {
    case "$SKYVIEW_PACKAGE_MANAGER" in
        apt)
            echo "gnome-remote-desktop"
            ;;
        dnf|yum)
            echo "gnome-remote-desktop"
            ;;
        pacman)
            echo "gnome-remote-desktop"
            ;;
        zypper)
            echo "gnome-remote-desktop"
            ;;
        *)
            echo "gnome-remote-desktop"
            ;;
    esac
}

# ============================================================================
# Configuration Functions
# ============================================================================

# Configure native RDP based on detected DE
configure_native_rdp() {
    log_info "Configuring native RDP for $SKYVIEW_DE..."

    require_root || return 1

    # Check if we're on Wayland
    if [[ "$SKYVIEW_SESSION_TYPE" != "wayland" ]]; then
        log_warn "Native Wayland RDP requires Wayland session (current: $SKYVIEW_SESSION_TYPE)"
        log_info "Falling back to xrdp or VNC recommended"
        return 0
    fi

    case "$SKYVIEW_DE" in
        KDE|KDE_Plasma|plasma)
            configure_kde_rdp
            ;;
        GNOME)
            configure_gnome_rdp
            ;;
        *)
            log_warn "Native RDP not supported for $SKYVIEW_DE"
            return 1
            ;;
    esac
}

# Configure KDE RDP (KRdp via krfb)
configure_kde_rdp() {
    log_info "Configuring KDE Remote Desktop (KRdp)..."

    # Install packages
    local packages
    packages=$(get_kde_rdp_packages)
    install_packages "$packages" || log_warn "Some KDE RDP packages may not be installed"

    # Configure krfb via kconfig
    local kde_config_dir
    kde_config_dir="$HOME/.config"

    if [[ -n "$SUDO_USER" ]]; then
        kde_config_dir="/home/$SUDO_USER/.config"
    fi

    mkdir -p "$kde_config_dir"

    # Create krfb configuration
    local krfb_config="$kde_config_dir/krfbrc"

    cat > "$krfb_config" << EOF
[General]
AutoAccept=true
IdleTimeout=3600
Port=$SKYVIEW_NATIVE_RDP_PORT
UnattendedMode=false
WakeOnLAN=true
EOF

    # Create systemd user service for krfb
    local service_dir="$kde_config_dir/systemd/user"
    mkdir -p "$service_dir"

    local service_file="$service_dir/skyview-kde-rdp.service"

    cat > "$service_file" << EOF
[Unit]
Description=SkyView KDE RDP Service
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/krfb --port $SKYVIEW_NATIVE_RDP_PORT
Restart=on-failure
RestartSec=5
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=

[Install]
WantedBy=default.target
EOF

    # Enable and start service
    if command -v systemctl &>/dev/null; then
        # Reload user daemon
        systemctl --user daemon-reload 2>/dev/null || true

        # Enable service
        systemctl --user enable skyview-kde-rdp.service 2>/dev/null || true

        # Try to start service
        systemctl --user start skyview-kde-rdp.service 2>/dev/null || {
            log_warn "Could not start KDE RDP service (may require graphical session)"
        }
    fi

    # Configure firewall
    configure_firewall_for_native_rdp

    log_info "KDE RDP configured on port $SKYVIEW_NATIVE_RDP_PORT"
    return 0
}

# Configure GNOME Remote Desktop
configure_gnome_rdp() {
    log_info "Configuring GNOME Remote Desktop..."

    # Install packages
    local packages
    packages=$(get_gnome_rdp_packages)
    install_packages "$packages" || {
        log_error "Failed to install gnome-remote-desktop"
        return 1
    }

    # Enable via gsettings/dconf
    if command -v gsettings &>/dev/null; then
        # Enable RDP
        gsettings set org.gnome.desktop.remote-desktop.rdp enable true 2>/dev/null || true

        # Set port
        gsettings set org.gnome.desktop.remote-desktop.rdp port "$SKYVIEW_NATIVE_RDP_PORT" 2>/dev/null || true

        # Enable view-only mode option
        gsettings set org.gnome.desktop.remote-desktop.rdp view-only false 2>/dev/null || true

        log_info "GNOME RDP settings configured via gsettings"
    fi

    # Create systemd service for headless access
    local service_file="/etc/systemd/system/skyview-gnome-rdp.service"

    cat > "$service_file" << EOF
[Unit]
Description=SkyView GNOME Remote Desktop Service
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=dbus
BusName=org.gnome.RemoteDesktop
ExecStart=/usr/libexec/gnome-remote-desktop-daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    if command -v systemctl &>/dev/null; then
        systemctl daemon-reload

        # Try to enable native GNOME RDP
        systemctl enable --now gnome-remote-desktop.service 2>/dev/null || {
            log_warn "Could not enable GNOME RDP service"
        }
    fi

    # Configure firewall
    configure_firewall_for_native_rdp

    log_info "GNOME Remote Desktop configured on port $SKYVIEW_NATIVE_RDP_PORT"
    return 0
}

# Configure firewall for native RDP
configure_firewall_for_native_rdp() {
    log_info "Configuring firewall for native RDP on port $SKYVIEW_NATIVE_RDP_PORT..."

    local firewall_script="/usr/local/bin/skyview-native-rdp-firewall.sh"

    cat > "$firewall_script" << EOF
#!/bin/bash
# SkyView Native RDP Firewall Configuration
# Generated by skyview-remote-access

SKYVIEW_RDP_PORT=${SKYVIEW_NATIVE_RDP_PORT}

case "\$(detect_firewall 2>/dev/null)" in
    ufw)
        ufw allow \$SKYVIEW_RDP_PORT/tcp comment 'SkyView Native RDP' 2>/dev/null || true
        ;;
    firewalld)
        firewall-cmd --permanent --add-port=\$SKYVIEW_RDP_PORT/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        ;;
    iptables)
        iptables -C INPUT -p tcp --dport \$SKYVIEW_RDP_PORT -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p tcp --dport \$SKYVIEW_RDP_PORT -j ACCEPT 2>/dev/null || true
        ;;
esac
EOF

    chmod +x "$firewall_script"
    "$firewall_script" 2>/dev/null || log_warn "Firewall configuration failed"

    log_debug "Firewall configured for native RDP"
}

# ============================================================================
# Service Management Functions
# ============================================================================

# Start native RDP service
start_native_rdp() {
    log_info "Starting native RDP service for $SKYVIEW_DE..."

    case "$SKYVIEW_DE" in
        KDE|KDE_Plasma|plasma)
            if command -v systemctl &>/dev/null; then
                systemctl --user start skyview-kde-rdp.service 2>/dev/null || {
                    log_warn "Could not start KDE RDP service"
                    return 1
                }
            fi
            ;;
        GNOME)
            if command -v systemctl &>/dev/null; then
                systemctl start gnome-remote-desktop.service 2>/dev/null || {
                    log_warn "Could not start GNOME RDP service"
                    return 1
                }
            fi
            ;;
        *)
            log_warn "Native RDP not supported for $SKYVIEW_DE"
            return 1
            ;;
    esac

    log_info "Native RDP service started"
    return 0
}

# Stop native RDP service
stop_native_rdp() {
    log_info "Stopping native RDP service..."

    case "$SKYVIEW_DE" in
        KDE|KDE_Plasma|plasma)
            if command -v systemctl &>/dev/null; then
                systemctl --user stop skyview-kde-rdp.service 2>/dev/null || true
            fi
            ;;
        GNOME)
            if command -v systemctl &>/dev/null; then
                systemctl stop gnome-remote-desktop.service 2>/dev/null || true
            fi
            ;;
    esac

    log_info "Native RDP service stopped"
}

# Enable native RDP on boot
enable_native_rdp() {
    log_info "Enabling native RDP on boot..."

    case "$SKYVIEW_DE" in
        KDE|KDE_Plasma|plasma)
            if command -v systemctl &>/dev/null; then
                systemctl --user enable skyview-kde-rdp.service 2>/dev/null || true
            fi
            ;;
        GNOME)
            if command -v systemctl &>/dev/null; then
                systemctl enable gnome-remote-desktop.service 2>/dev/null || true
            fi
            ;;
    esac
}

# ============================================================================
# Verification Functions
# ============================================================================

# Verify native RDP configuration
verify_native_rdp() {
    log_info "Verifying native RDP configuration..."

    local errors=0

    # Check if on Wayland
    if [[ "$SKYVIEW_SESSION_TYPE" != "wayland" ]]; then
        log_warn "Native RDP requires Wayland session"
        ((errors++))
        return $errors
    fi

    # Check DE support
    case "$SKYVIEW_DE" in
        KDE|KDE_Plasma|plasma)
            if ! command -v krfb &>/dev/null; then
                log_error "krfb is not installed"
                ((errors++))
            fi
            ;;
        GNOME)
            if ! command -v gnome-remote-desktop &>/dev/null; then
                log_error "gnome-remote-desktop is not installed"
                ((errors++))
            fi
            ;;
        *)
            log_error "Native RDP not supported for $SKYVIEW_DE"
            ((errors++))
            ;;
    esac

    # Check port
    if is_port_open "localhost" "$SKYVIEW_NATIVE_RDP_PORT"; then
        log_info "Native RDP port $SKYVIEW_NATIVE_RDP_PORT is listening"
    else
        log_warn "Native RDP port $SKYVIEW_NATIVE_RDP_PORT is not listening"
    fi

    return $errors
}

# Get native RDP status
get_native_rdp_status() {
    local status="unknown"
    local port_status="closed"

    if is_port_open "localhost" "$SKYVIEW_NATIVE_RDP_PORT"; then
        port_status="open"
    fi

    case "$SKYVIEW_DE" in
        KDE|KDE_Plasma|plasma)
            if command -v systemctl &>/dev/null; then
                if systemctl --user is-active skyview-kde-rdp.service 2>/dev/null; then
                    status="active"
                fi
            fi
            ;;
        GNOME)
            if command -v systemctl &>/dev/null; then
                if systemctl is-active gnome-remote-desktop.service 2>/dev/null; then
                    status="active"
                fi
            fi
            ;;
    esac

    echo "Status: $status, Port: $port_status"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Print native RDP configuration summary
print_native_rdp_summary() {
    print_header "Native RDP Configuration (Wayland)"

    cat << EOF
Desktop Environment: $SKYVIEW_DE
Session Type:        $SKYVIEW_SESSION_TYPE
RDP Port:            $SKYVIEW_NATIVE_RDP_PORT

$(get_native_rdp_status)
EOF
}

# ============================================================================
# Bridge API Functions (for frontend integration)
# ============================================================================

# Get native RDP status as JSON
get_native_rdp_status_json() {
    local status port_enabled running de_supported

    status="unknown"
    port_enabled="false"
    running="false"
    de_supported="false"

    case "$SKYVIEW_DE" in
        KDE|KDE_Plasma|plasma)
            de_supported="true"
            ;;
        GNOME)
            de_supported="true"
            ;;
    esac

    if is_port_open "localhost" "$SKYVIEW_NATIVE_RDP_PORT"; then
        port_enabled="true"
    fi

    case "$SKYVIEW_DE" in
        KDE|KDE_Plasma|plasma)
            if command -v systemctl &>/dev/null; then
                if systemctl --user is-active skyview-kde-rdp.service 2>/dev/null; then
                    running="true"
                    status="active"
                fi
            fi
            ;;
        GNOME)
            if command -v systemctl &>/dev/null; then
                if systemctl is-active gnome-remote-desktop.service 2>/dev/null; then
                    running="true"
                    status="active"
                fi
            fi
            ;;
    esac

    cat << EOF
{
  "service": "native-rdp",
  "status": "$status",
  "port": $SKYVIEW_NATIVE_RDP_PORT,
  "enabled": $port_enabled,
  "running": $running,
  "desktopEnvironment": "$SKYVIEW_DE",
  "sessionType": "$SKYVIEW_SESSION_TYPE",
  "deSupported": $de_supported,
  "requiresWayland": true
}
EOF
}
