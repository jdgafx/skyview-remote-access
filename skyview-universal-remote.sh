#!/bin/bash
#
# =============================================================================
# SKYVIEW UNIVERSAL REMOTE ACCESS v6.0 - "IT JUST WORKS"
# =============================================================================
# 
# A truly universal remote access system that automatically detects,
# configures, and enables remote access on ANY Linux system.
#
# SUPPORTED:
#   - All major distributions (Ubuntu, Debian, Fedora, Arch, etc.)
#   - All major desktop environments (KDE, GNOME, XFCE, etc.)
#   - Wayland and X11 sessions
#   - Multiple remote access methods (RDP, VNC, SSH)
#
# USAGE:
#   sudo ./skyview-universal-remote.sh --auto    # Auto-detect and configure
#   sudo ./skyview-universal-remote.sh --status  # Show current status
#   sudo ./skyview-universal-remote.sh --test    # Test connectivity
#   sudo ./skyview-universal-remote.sh --help    # Show help
#
# =============================================================================

set -eo pipefail

# --- Version ---
VERSION="6.0.0"

# --- Configuration ---
readonly SSH_PORT="${SSH_PORT:-2277}"
readonly RDP_PORT="${RDP_PORT:-3389}"
readonly VNC_PORT="${VNC_PORT:-5900}"
readonly CONFIG_DIR="/etc/skyview"
readonly LOG_FILE="/var/log/skyview-remote.log"
readonly SUDOPWD="${SUDOPWD:-qrdemon1}"

# --- Colors ---
readonly BLUE='\033[0;34m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly GOLD='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log() { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$(date '+%H:%M:%S')] $*"; }
log_info() { log "${BLUE}[INFO]${NC} $*"; }
log_warn() { log "${YELLOW}[WARN]${NC} $*"; }
log_error() { log "${RED}[ERROR]${NC} $*" >&2; }
log_success() { log "${GREEN}[✔]${NC} $*"; }
log_debug() { [ "${VERBOSE:-false}" = "true" ] && log "${MAGENTA}[DEBUG]${NC} $*"; }

as_root() { echo "$SUDOPWD" | sudo -S bash -c "$*" 2>/dev/null || bash -c "$*"; }
is_root() { [ "$EUID" -eq 0 ]; }

# =============================================================================
# OS DETECTION
# =============================================================================

detect_os() {
    log_debug "Detecting operating system..."
    
    local os_id="" os_version="" os_name="" package_manager=""
    
    # Read /etc/os-release
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        os_id="${ID:-unknown}"
        os_version="${VERSION_ID:-unknown}"
        os_name="${NAME:-${PRETTY_NAME:-unknown}}"
    elif [ -f /etc/redhat-release ]; then
        os_name=$(cat /etc/redhat-release 2>/dev/null | head -1)
        os_id="rhel"
    elif [ -f /etc/arch-release ]; then
        os_id="arch"
        os_name="Arch Linux"
    elif [ -f /etc/debian_version ]; then
        os_id="debian"
        os_name="Debian"
    else
        os_id="unknown"
        os_name="Unknown Linux"
    fi
    
    # Detect package manager
    if command -v apt-get >/dev/null 2>&1; then
        package_manager="apt"
    elif command -v dnf >/dev/null 2>&1; then
        package_manager="dnf"
    elif command -v pacman >/dev/null 2>&1; then
        package_manager="pacman"
    elif command -v zypper >/dev/null 2>&1; then
        package_manager="zypper"
    elif command -v xbps-install >/dev/null 2>&1; then
        package_manager="xbps"
    elif command -v apk >/dev/null 2>&1; then
        package_manager="apk"
    else
        package_manager="unknown"
    fi
    
    # Detect init system
    local init_system="unknown"
    if [ -d /run/systemd/system ]; then
        init_system="systemd"
    elif [ -f /sbin/init ]; then
        init_system=$(readlink /sbin/init 2>/dev/null | xargs basename 2>/dev/null || echo "unknown")
    fi
    
    echo "${os_id}:${os_version}:${os_name}:${package_manager}:${init_system}"
}

get_os_info() {
    local os_info="$1"
    echo "$os_info" | cut -d: -f1
    # Usage: $(get_os_info "$os_info" 1) for os_id, 2 for version, etc.
}

# =============================================================================
# DESKTOP ENVIRONMENT DETECTION
# =============================================================================

detect_desktop_environment() {
    log_debug "Detecting desktop environment..."
    
    local de="Unknown"
    
    # Check running processes (most reliable)
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
    elif pgrep -x "lxsession" >/dev/null 2>&1; then
        de="LXDE"
    elif pgrep -x "openbox" >/dev/null 2>&1 && pgrep -f "pcmanfm" >/dev/null 2>&1; then
        de="LXDE"
    elif pgrep -x "budgie-daemon" >/dev/null 2>&1; then
        de="Budgie"
    elif pgrep -x "plank" >/dev/null 2>&1; then
        de="Pantheon"
    elif pgrep -x "dde-desktop" >/dev/null 2>&1; then
        de="Deepin"
    elif pgrep -x "i3" >/dev/null 2>&1 || pgrep -f "i3-" >/dev/null 2>&1; then
        de="i3"
    elif pgrep -x "sway" >/dev/null 2>&1; then
        de="sway"
    elif pgrep -x "bspwm" >/dev/null 2>&1; then
        de="bspwm"
    elif pgrep -x "awesome" >/dev/null 2>&1; then
        de="awesome"
    elif pgrep -x "dwm" >/dev/null 2>&1; then
        de="dwm"
    elif pgrep -x "qtile" >/dev/null 2>&1; then
        de="qtile"
    elif pgrep -x "openbox" >/dev/null 2>&1; then
        de="Openbox"
    elif pgrep -x "fluxbox" >/dev/null 2>&1; then
        de="Fluxbox"
    else
        # Fallback to environment variables
        [ -n "${XDG_CURRENT_DESKTOP:-}" ] && de="$XDG_CURRENT_DESKTOP"
        [ -n "${DESKTOP_SESSION:-}" ] && [ "$de" = "Unknown" ] && de="$DESKTOP_SESSION"
    fi
    
    echo "$de"
}

# =============================================================================
# SESSION TYPE DETECTION
# =============================================================================

detect_session_type() {
    log_debug "Detecting session type..."
    
    local session_type="unknown"
    
    # Check XDG session type FIRST (most reliable on modern Wayland systems)
    if [ -n "${XDG_SESSION_TYPE:-}" ]; then
        session_type="$XDG_SESSION_TYPE"
    fi
    
    # Check loginctl (most reliable, works with sudo)
    if [ "$session_type" = "unknown" ]; then
        # Use SUDO_USER if set (when running with sudo), otherwise current user
        local current_user="${SUDO_USER:-$(whoami)}"
        local session_id=$(loginctl list-sessions --no-legend 2>/dev/null | grep "$current_user" | awk '{print $1}' | head -1)
        if [ -n "$session_id" ]; then
            local session_info=$(loginctl show-session "$session_id" 2>/dev/null)
            echo "$session_info" | grep -q "Type=wayland" && session_type="wayland"
            echo "$session_info" | grep -q "Type=x11" && session_type="x11"
        fi
    fi
    
    # Check Wayland indicators (only if not already detected)
    if [ -n "${WAYLAND_DISPLAY:-}" ] && [ "$session_type" != "wayland" ]; then
        session_type="wayland"
    fi
    
    # Check X11 indicators (only if not already detected as Wayland)
    if [ -n "${DISPLAY:-}" ] && [ "$session_type" != "wayland" ]; then
        session_type="x11"
    fi
    
    # Headless detection (last resort)
    if [ "$session_type" = "unknown" ]; then
        if ! command -v Xorg >/dev/null 2>&1 && ! command -v wayland >/dev/null 2>&1; then
            session_type="headless"
        elif [ ! -S "/tmp/.X11-unix/X0" ] && [ ! -d "/run/user/$(id -u)/wayland-0" ]; then
            session_type="headless"
        fi
    fi
    
    echo "$session_type"
}

# =============================================================================
# DISPLAY SERVER DETECTION
# =============================================================================

detect_display_server() {
    local session_type="$1"
    local de="$2"
    
    if [ "$session_type" = "wayland" ]; then
        echo "wayland"
    elif [ "$session_type" = "x11" ]; then
        echo "x11"
    elif [ -n "${DISPLAY:-}" ]; then
        echo "x11"
    elif [ -n "${WAYLAND_DISPLAY:-}" ]; then
        echo "wayland"
    else
        echo "unknown"
    fi
}

# =============================================================================
# AVAILABLE METHODS DETECTION
# =============================================================================

detect_available_methods() {
    local de="$1"
    local session_type="$2"
    local display_server="$3"
    
    local methods=""
    
    # Check xrdp
    if command -v xrdp >/dev/null 2>&1; then
        methods="${methods}xrdp,"
    fi
    
    # Check TigerVNC
    if command -v Xvnc >/dev/null 2>&1; then
        methods="${methods}vnc,"
    fi
    
    # Check gnome-remote-desktop
    if command -v gnome-remote-desktop >/dev/null 2>&1; then
        methods="${methods}gnome-rdp,"
    fi
    
    # Check KDE krfb
    if command -v krfb >/dev/null 2>&1; then
        methods="${methods}kde-rdp,"
    fi
    
    # Check SSH
    if command -v sshd >/dev/null 2>&1 || [ -f /usr/sbin/sshd ]; then
        methods="${methods}ssh,"
    fi
    
    echo "${methods%,}"
}

# =============================================================================
# BEST METHOD SELECTION
# =============================================================================

select_best_method() {
    local de="$1"
    local session_type="$2"
    local display_server="$3"
    local available_methods="$4"
    
    # Priority 1: Native Wayland RDP for KDE/GNOME
    if [[ "$de" == *"KDE"* ]] && [[ "$session_type" == "wayland"* ]]; then
        if echo "$available_methods" | grep -q "kde-rdp"; then
            echo "kde-rdp"
            return
        fi
    fi
    
    if [[ "$de" == *"GNOME"* ]] && [[ "$session_type" == "wayland"* ]]; then
        if echo "$available_methods" | grep -q "gnome-rdp"; then
            echo "gnome-rdp"
            return
        fi
    fi
    
    # Priority 2: xrdp for X11 sessions
    if [[ "$session_type" == "x11"* ]] || [[ "$display_server" == "x11" ]]; then
        if echo "$available_methods" | grep -q "xrdp"; then
            echo "xrdp"
            return
        fi
    fi
    
    # Priority 3: VNC (universal fallback)
    if echo "$available_methods" | grep -q "vnc"; then
        echo "vnc"
        return
    fi
    
    # Priority 4: Try any RDP we can
    if echo "$available_methods" | grep -q "xrdp"; then
        echo "xrdp"
        return
    fi
    
    # Nothing available
    echo "none"
}

# =============================================================================
# PACKAGE INSTALLATION
# =============================================================================

# =============================================================================
# PACKAGE INSTALLATION (with conflict resolution)
# =============================================================================

install_packages() {
    local os_info="$1"
    shift
    local packages=("$@")
    local package_manager=$(echo "$os_info" | cut -d: -f4)
    
    local missing=()
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" && \
           ! rpm -q "$pkg" 2>/dev/null | grep -q "^"; then
            missing+=("$pkg")
        fi
    done
    
    if [ ${#missing[@]} -eq 0 ]; then
        log_debug "All packages already installed"
        return 0
    fi
    
    log_info "Installing: ${missing[*]}"
    
    case "$package_manager" in
        apt)
            install_packages_apt "${missing[@]}"
            ;;
        dnf)
            install_packages_dnf "${missing[@]}"
            ;;
        pacman)
            install_packages_pacman "${missing[@]}"
            ;;
        zypper)
            install_packages_zypper "${missing[@]}"
            ;;
        *)
            log_warn "Unknown package manager, trying apt..."
            install_packages_apt "${missing[@]}" || return 1
            ;;
    esac
}

install_packages_apt() {
    local packages=("$@")
    local pkg_str="${packages[*]}"
    local max_wait=60
    local waited=0
    
    # Wait for apt lock
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
          fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
          fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
        if [ $waited -ge $max_wait ]; then
            log_warn "Apt lock timeout, trying to continue..."
            break
        fi
        log_info "Waiting for apt lock... ($waited/${max_wait}s)"
        sleep 2
        waited=$((waited + 2))
    done
    
    # Kill stalled apt process if waiting too long
    if [ $waited -ge $max_wait ]; then
        local lock_pid=$(fuser /var/lib/dpkg/lock-frontend 2>/dev/null | grep -oP '\d+' | head -1 || true)
        if [ -n "$lock_pid" ]; then
            log_warn "Killing stalled apt process $lock_pid"
            as_root "kill -9 $lock_pid 2>/dev/null" || true
            sleep 1
            as_root "rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock 2>/dev/null" || true
            as_root "dpkg --configure -a 2>/dev/null" || true
        fi
    fi
    
    # Strategy 1: Standard install
    log_info "APT Strategy 1: Standard install..."
    if as_root "DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-broken $pkg_str 2>&1"; then
        return 0
    fi
    
    # Strategy 2: Update and fix broken
    log_info "APT Strategy 2: Update and fix dependencies..."
    if as_root "DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null && apt-get install -y --fix-broken 2>&1"; then
        if as_root "DEBIAN_FRONTEND=noninteractive apt-get install -y $pkg_str 2>&1"; then
            return 0
        fi
    fi
    
    # Strategy 3: Remove conflicting packages
    log_info "APT Strategy 3: Remove conflicting packages..."
    local conflicts=$(apt-get install -y --simulate $pkg_str 2>&1 | grep -oP '(?<=Breaks\s)\S+|\S+(?=\s*Breaks)' | tr ' ' '\n' | sort -u | grep -E '^[a-z0-9]' | tr '\n' ' ' || true)
    if [ -n "$conflicts" ]; then
        log_info "Removing conflicts: $conflicts"
        as_root "DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge $conflicts 2>&1" || true
        as_root "DEBIAN_FRONTEND=noninteractive apt-get autoremove -y 2>&1" || true
        as_root "DEBIAN_FRONTEND=noninteractive apt-get install -y $pkg_str 2>&1" && return 0
    fi
    
    # Strategy 4: Force install with dpkg
    log_info "APT Strategy 4: Force dpkg configuration..."
    as_root "dpkg --configure -a 2>&1" || true
    if as_root "DEBIAN_FRONTEND=noninteractive apt-get install -y -f $pkg_str 2>&1"; then
        return 0
    fi
    
    # Strategy 5: Download .deb files directly and force install
    log_info "APT Strategy 5: Force install with dpkg..."
    as_root "mkdir -p /var/cache/apt/archives/ 2>/dev/null"
    for pkg in "${packages[@]}"; do
        as_root "apt-get download $pkg 2>/dev/null" || true
    done
    as_root "dpkg -i --force-confnew /var/cache/apt/archives/*.deb 2>&1" || true
    as_root "apt-get install -y -f 2>&1" || true
    
    # Verify
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            log_warn "Failed to install: $pkg"
            return 1
        fi
    done
    return 0
}

install_packages_dnf() {
    local packages=("$@")
    local pkg_str="${packages[*]}"
    
    # Strategy 1: Standard install
    log_info "DNF Strategy 1: Standard install..."
    if as_root "dnf install -y --best --allowerasing $pkg_str 2>&1"; then
        return 0
    fi
    
    # Strategy 2: Clean and retry
    log_info "DNF Strategy 2: Clean cache and retry..."
    as_root "dnf clean all 2>/dev/null"
    if as_root "dnf install -y --best --allowerasing $pkg_str 2>&1"; then
        return 0
    fi
    
    # Strategy 3: Force remove conflicting
    log_info "DNF Strategy 3: Remove conflicts and reinstall..."
    as_root "dnf remove -y --noautoremove \$(dnf repoquery --duplicates 2>/dev/null | head -20) 2>/dev/null" || true
    if as_root "dnf install -y --best --allowerasing $pkg_str 2>&1"; then
        return 0
    fi
    
    # Strategy 4: Downgrade and upgrade
    log_info "DNF Strategy 4: Distribution sync..."
    as_root "dnf distro-sync -y 2>&1" || true
    as_root "dnf install -y --best $pkg_str 2>&1" && return 0
    
    log_warn "DNF installation failed for some packages"
    return 1
}

install_packages_pacman() {
    local packages=("$@")
    local pkg_str="${packages[*]}"
    
    # Strategy 1: Standard install
    log_info "Pacman Strategy 1: Standard install..."
    if as_root "pacman -Sy --noconfirm --needed $pkg_str 2>&1"; then
        return 0
    fi
    
    # Strategy 2: Force refresh and install
    log_info "Pacman Strategy 2: Force refresh..."
    as_root "pacman -Syyu --noconfirm 2>&1" || true
    if as_root "pacman -Sy --noconfirm --needed $pkg_str 2>&1"; then
        return 0
    fi
    
    # Strategy 3: Remove conflicts
    log_info "Pacman Strategy 3: Remove conflicts..."
    local conflicts=$(pacman -Qq 2>/dev/null | grep -E "^($(echo "${packages[@]}" | tr ' ' '|'))" || true)
    if [ -n "$conflicts" ]; then
        as_root "pacman -Rdd -y --noconfirm $conflicts 2>/dev/null" || true
        as_root "pacman -Sy --noconfirm --needed $pkg_str 2>&1" && return 0
    fi
    
    # Strategy 4: Overwrite files
    log_info "Pacman Strategy 4: Force overwrite..."
    as_root "pacman -Sydd --overwrite '*' --noconfirm --needed $pkg_str 2>&1" && return 0
    
    log_warn "Pacman installation failed for some packages"
    return 1
}

install_packages_zypper() {
    local packages=("$@")
    local pkg_str="${packages[*]}"
    
    # Strategy 1: Standard install
    log_info "Zypper Strategy 1: Standard install..."
    if as_root "zypper install -y --no-recommends $pkg_str 2>&1"; then
        return 0
    fi
    
    # Strategy 2: Update and install
    log_info "Zypper Strategy 2: Update repos and retry..."
    as_root "zypper refresh 2>/dev/null" || true
    if as_root "zypper install -y --no-recommends --force-resolution $pkg_str 2>&1"; then
        return 0
    fi
    
    # Strategy 3: Remove conflicts
    log_info "Zypper Strategy 3: Remove conflicts..."
    as_root "zypper remove -y --clean-deps 2>&1" || true
    if as_root "zypper install -y --no-recommends $pkg_str 2>&1"; then
        return 0
    fi
    
    # Strategy 4: Force install
    log_info "Zypper Strategy 4: Force install..."
    as_root "zypper install -y --force --no-recommends $pkg_str 2>&1" && return 0
    
    log_warn "Zypper installation failed for some packages"
    return 1
}

# =============================================================================
# RDP CONFIGURATION (xrdp)
# =============================================================================

configure_xrdp() {
    log_info "Configuring xrdp..."
    
    install_packages "$os_info" xrdp xorgxrdp openssl || {
        log_warn "Could not install xrdp packages"
        return 1
    }
    
    mkdir -p "$CONFIG_DIR/certs"
    
    # Generate certificates if needed
    if [ ! -f "$CONFIG_DIR/certs/rdp-cert.pem" ]; then
        as_root "openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj '/C=US/ST=SkyView/L=Remote/O=SkyView/CN=SkyViewRDP' \
            -keyout $CONFIG_DIR/certs/rdp-key.pem \
            -out $CONFIG_DIR/certs/rdp-cert.pem 2>/dev/null"
    fi
    
    as_root "chown xrdp:xrdp $CONFIG_DIR/certs/rdp-key.pem && chmod 640 $CONFIG_DIR/certs/rdp-key.pem"
    
    # Configure xrdp.ini
    cat > /etc/xrdp/xrdp.ini << EOF
[Globals]
port=${RDP_PORT}
bind_address=0.0.0.0
max_bpp=32
crypt_level=high
security_layer=negotiate
tls_cert_file=$CONFIG_DIR/certs/rdp-cert.pem
tls_key_file=$CONFIG_DIR/certs/rdp-key.pem
ssl_protocols=TLSv1.2,TLSv1.3
EOF
    
    # Configure sesman
    cat > /etc/xrdp/sesman.ini << 'EOF'
[Globals]
MaxSessions=50
[Sessions]
X11DisplayOffset=10
EOF
    
    # Configure startwm.sh for universal desktop support
    cat > /etc/xrdp/startwm.sh << 'STARTWM'
#!/bin/bash
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="/run/user/${USER_ID:-1000}"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null

# Try desktop environments in order of preference
command -v startplasma-x11 >/dev/null && exec startplasma-x11
command -v gnome-session >/dev/null && exec gnome-session
command -v startxfce4 >/dev/null && exec startxfce4
command -v mate-session >/dev/null && exec mate-session
command -v cinnamon-session >/dev/null && exec cinnamon-session
command -v startlxqt >/dev/null && exec startlxqt
command -v startlxde >/dev/null && exec startlxde

# Fallback to any session manager
[ -f /usr/bin/x-session-manager ] && exec /usr/bin/x-session-manager
exec xterm
STARTWM
    as_root "chmod +x /etc/xrdp/startwm.sh"
    
    # Stop conflicting services
    as_root "systemctl stop gnome-remote-desktop 2>/dev/null || true"
    as_root "systemctl disable gnome-remote-desktop 2>/dev/null || true"
    
    # Enable and start
    as_root "systemctl enable xrdp xrdp-sesman"
    as_root "systemctl restart xrdp-sesman"
    sleep 1
    as_root "systemctl restart xrdp"
    
    sleep 2
    if ss -tlnp 2>/dev/null | grep -q ":${RDP_PORT}"; then
        log_success "xrdp listening on port ${RDP_PORT}"
        return 0
    else
        log_error "xrdp failed to start"
        return 1
    fi
}

# =============================================================================
# GNOME REMOTE DESKTOP CONFIGURATION
# =============================================================================

configure_gnome_rdp() {
    log_info "Configuring GNOME Remote Desktop..."
    
    install_packages "$os_info" gnome-remote-desktop || {
        log_warn "Could not install gnome-remote-desktop"
        return 1
    }
    
    # Create config directory
    mkdir -p ~/.config/gnome-remote-desktop
    
    # Enable RDP via D-Bus
    as_root "systemctl enable --now gnome-remote-desktop 2>/dev/null || true"
    
    log_success "GNOME Remote Desktop configured"
    return 0
}

# =============================================================================
# KDE RDP CONFIGURATION
# =============================================================================

configure_kde_rdp() {
    log_info "Configuring KDE Remote Desktop..."
    
    install_packages "$os_info" krfb krdc || {
        log_warn "Could not install krfb"
        # Not a fatal error - VNC will work
    }
    
    # Create systemd user service for KDE RDP
    mkdir -p ~/.config/systemd/user
    
    cat > ~/.config/systemd/user/skyview-kde-rdp.service << 'KDEEOF'
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
    
    as_root "systemctl --user daemon-reload 2>/dev/null || true"
    as_root "systemctl --user enable skyview-kde-rdp.service 2>/dev/null || true"
    as_root "systemctl --user start skyview-kde-rdp.service 2>/dev/null || true"
    
    log_success "KDE Remote Desktop configured"
    return 0
}

# =============================================================================
# VNC CONFIGURATION (Universal)
# =============================================================================

configure_vnc() {
    log_info "Configuring TigerVNC..."
    
    install_packages "$os_info" tigervnc-standalone-server || {
        log_warn "Could not install TigerVNC"
        return 1
    }
    
    # Create VNC session script
    mkdir -p "$CONFIG_DIR/vnc"
    cat > "$CONFIG_DIR/vnc/vncsession" << 'VNCINIT'
#!/bin/bash
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="/run/user/${USER_ID:-1000}"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null
eval $(dbus-launch --sh-syntax 2>/dev/null)

# Try desktop environments
command -v startplasma-x11 >/dev/null && exec startplasma-x11
command -v gnome-session >/dev/null && exec gnome-session
command -v startxfce4 >/dev/null && exec startxfce4
command -v mate-session >/dev/null && exec mate-session
command -v cinnamon-session >/dev/null && exec cinnamon-session
[ -f /usr/bin/x-session-manager ] && exec /usr/bin/x-session-manager
exec xterm
VNCINIT
    as_root "chmod +x $CONFIG_DIR/vnc/vncsession"
    
    # Setup VNC password
    mkdir -p ~/.vnc
    [ ! -f ~/.vnc/passwd ] && {
        echo "qrdemon1" | vncpasswd -f > ~/.vnc/passwd 2>/dev/null || true
        as_root "chmod 600 ~/.vnc/passwd"
    }
    
    # Create systemd user service
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
        log_warn "VNC server started but not listening (may need X session)"
    fi
    
    return 0
}

# =============================================================================
# SSH CONFIGURATION
# =============================================================================

configure_ssh() {
    log_info "Configuring SSH on port ${SSH_PORT}..."
    
    # Check if SSH server is already installed
    if ! dpkg -l openssh-server 2>/dev/null | grep -q "^ii"; then
        log_info "Installing openssh-server..."
        if ! install_packages "$os_info" openssh-server; then
            log_warn "Could not install openssh-server (dependency issues)"
            log_info "Fix with: sudo apt --fix-broken install"
            return 1
        fi
    fi
    
    # Configure port
    as_root "sed -i '/^Port /d' /etc/ssh/sshd_config 2>/dev/null || true"
    echo "Port ${SSH_PORT}" | as_root "tee -a /etc/ssh/sshd_config"
    
    # Add hardening
    if ! grep -q "SKYVIEW SSH HARDENING" /etc/ssh/sshd_config; then
        cat >> /etc/ssh/sshd_config << 'EOF'

# SKYVIEW SSH HARDENING
PermitRootLogin no
MaxAuthTries 3
MaxSessions 10
PubkeyAuthentication yes
PasswordAuthentication no
KexAlgorithms curve25519-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
AllowTcpForwarding no
X11Forwarding no
UseDNS no
EOF
    fi
    
    # Create banner
    cat > /etc/ssh/banner.txt << 'EOF'
******************************************
*   SKYVIEW REMOTE ACCESS - AUTHORIZED   *
*   All connections are monitored        *
*   Unauthorized access is prohibited    *
******************************************
EOF
    
    # Enable and start
    as_root "systemctl enable sshd"
    as_root "systemctl restart sshd"
    
    sleep 2
    if ss -tlnp 2>/dev/null | grep -q ":${SSH_PORT}"; then
        log_success "SSH listening on port ${SSH_PORT}"
    else
        log_error "SSH failed to start"
        return 1
    fi
    
    return 0
}

# =============================================================================
# FIREWALL CONFIGURATION
# =============================================================================

configure_firewall() {
    log_info "Configuring firewall..."
    
    local configured=false
    
    # UFW
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            log_info "Configuring UFW..."
            as_root "ufw allow ${RDP_PORT}/tcp 2>/dev/null || true"
            as_root "ufw allow ${VNC_PORT}/tcp 2>/dev/null || true"
            as_root "ufw allow ${SSH_PORT}/tcp 2>/dev/null || true"
            as_root "ufw reload 2>/dev/null || true"
            configured=true
            log_success "UFW configured"
        fi
    fi
    
    # firewalld
    if command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            log_info "Configuring firewalld..."
            as_root "firewall-cmd --permanent --add-port=${RDP_PORT}/tcp 2>/dev/null || true"
            as_root "firewall-cmd --permanent --add-port=${VNC_PORT}/tcp 2>/dev/null || true"
            as_root "firewall-cmd --permanent --add-port=${SSH_PORT}/tcp 2>/dev/null || true"
            as_root "firewall-cmd --reload 2>/dev/null || true"
            configured=true
            log_success "firewalld configured"
        fi
    fi
    
    # iptables (fallback)
    if [ "$configured" = "false" ]; then
        log_info "Configuring iptables..."
        as_root "iptables -C INPUT -p tcp --dport ${RDP_PORT} -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport ${RDP_PORT} -j ACCEPT"
        as_root "iptables -C INPUT -p tcp --dport ${VNC_PORT} -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport ${VNC_PORT} -j ACCEPT"
        as_root "iptables -C INPUT -p tcp --dport ${SSH_PORT} -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport ${SSH_PORT} -j ACCEPT"
        configured=true
        log_success "iptables configured"
        log_warn "Consider installing UFW or firewalld for persistent rules"
    fi
}

# =============================================================================
# SYSTEMD SERVICE CREATION
# =============================================================================

create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > /etc/systemd/system/skyview-remote.service << 'EOF'
[Unit]
Description=SkyView Universal Remote Access
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/home/chris/dev/skyview-remote-access/skyview-universal-remote.sh --auto
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
    
    as_root "systemctl daemon-reload"
    as_root "systemctl enable skyview-remote.service"
    
    log_success "Systemd service created and enabled"
}

# =============================================================================
# SHOW STATUS
# =============================================================================

show_status() {
    local ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}')
    local os_info="$1"
    local de="$2"
    local session_type="$3"
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}SKYVIEW UNIVERSAL REMOTE ACCESS${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Version ${VERSION}                                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BLUE}System:${NC}  $(echo "$os_info" | cut -d: -f3) ($(echo "$os_info" | cut -d: -f1))"
    echo -e "  ${BLUE}Desktop:${NC} ${de} (${session_type})"
    echo -e "  ${BLUE}IP:${NC}      ${ip}"
    echo ""
    echo -e "  ${GREEN}Services Status:${NC}"
    
    local rdp_status="❌ Not configured"
    ss -tlnp 2>/dev/null | grep -q ":${RDP_PORT}" && rdp_status="✅ RDP ${RDP_PORT}"
    
    local vnc_status="❌ Not configured"
    ss -tlnp 2>/dev/null | grep -q ":${VNC_PORT}" && vnc_status="✅ VNC ${VNC_PORT}"
    
    local ssh_status="❌ Not configured"
    ss -tlnp 2>/dev/null | grep -q ":${SSH_PORT}" && ssh_status="✅ SSH ${SSH_PORT}"
    
    echo -e "    ${rdp_status}"
    echo -e "    ${vnc_status}"
    echo -e "    ${ssh_status}"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}CONNECTION GUIDE${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}RDP:${NC}  Microsoft Remote Desktop → ${ip}:${RDP_PORT}"
    echo -e "  ${GREEN}VNC:${NC}  TigerVNC Viewer → ${ip}:${VNC_PORT}"
    echo -e "  ${GREEN}SSH:${NC}  ssh -p ${SSH_PORT} skyview_user@${ip}"
    echo ""
}

# =============================================================================
# MAIN AUTO MODE
# =============================================================================

run_auto() {
    echo "=== SkyView Universal Remote Access $(date) ===" > "$LOG_FILE"
    
    echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${CYAN}┃${NC}  ${GOLD}S K Y V I E W   U N I V E R S A L   R E M O T E   A C C E S S${NC}  ${CYAN}┃${NC}"
    echo -e "${CYAN}┃${NC}  Version ${VERSION} - \"IT JUST WORKS\" Edition                    ${CYAN}┃${NC}"
    echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo ""
    
    # Phase 1: Detection
    log_info "=== Phase 1: System Detection ==="
    
    local os_info=$(detect_os)
    local de=$(detect_desktop_environment)
    local session_type=$(detect_session_type)
    local display_server=$(detect_display_server "$session_type" "$de")
    local available_methods=$(detect_available_methods "$de" "$session_type" "$display_server")
    local best_method=$(select_best_method "$de" "$session_type" "$display_server" "$available_methods")
    
    log_info "OS: $(echo "$os_info" | cut -d: -f3)"
    log_info "Desktop: ${de}"
    log_info "Session: ${session_type}"
    log_info "Display: ${display_server}"
    log_info "Available: ${available_methods:-none}"
    log_info "Selected: ${best_method}"
    echo ""
    
    # Phase 2: Configure Remote Access
    log_info "=== Phase 2: Configuration ==="
    
    # Configure RDP (xrdp works with X11 sessions)
    if [[ "$session_type" == "x11"* ]] || [[ "$display_server" == "x11" ]]; then
        configure_xrdp || log_warn "xrdp configuration failed"
    fi
    
    # Configure native Wayland RDP for KDE/GNOME
    if [[ "$de" == *"KDE"* ]] && [[ "$session_type" == "wayland"* ]]; then
        configure_kde_rdp || log_warn "KDE RDP configuration failed"
    fi
    
    if [[ "$de" == *"GNOME"* ]] && [[ "$session_type" == "wayland"* ]]; then
        configure_gnome_rdp || log_warn "GNOME RDP configuration failed"
    fi
    
    # Configure VNC (universal fallback)
    configure_vnc || log_warn "VNC configuration failed"
    
    # Configure SSH
    configure_ssh || log_warn "SSH configuration failed"
    
    # Phase 3: Firewall
    log_info "=== Phase 3: Firewall ==="
    configure_firewall
    
    # Phase 4: Systemd
    log_info "=== Phase 4: Systemd Service ==="
    create_systemd_service
    
    # Show status
    show_status "$os_info" "$de" "$session_type"
    
    echo ""
    log_success "Setup complete!"
    log_info "Log file: ${LOG_FILE}"
}

# =============================================================================
# COMMAND HANDLERS
# =============================================================================

cmd_help() {
    cat << 'EOF'
SKYVIEW UNIVERSAL REMOTE ACCESS v6.0

USAGE:
    sudo ./skyview-universal-remote.sh [COMMAND]

COMMANDS:
    --auto       Auto-detect and configure remote access
    --status     Show current remote access status
    --test       Test connectivity to configured services
    --rdp        Configure only RDP (xrdp)
    --vnc        Configure only VNC
    --ssh        Configure only SSH
    --install    Install required packages
    --help       Show this help message

EXAMPLES:
    sudo ./skyview-universal-remote.sh --auto
    sudo ./skyview-universal-remote.sh --status
    sudo ./skyview-universal-remote.sh --rdp

SUPPORTED:
    - Distributions: Ubuntu, Debian, Fedora, Arch, openSUSE, etc.
    - Desktops: KDE, GNOME, XFCE, MATE, Cinnamon, etc.
    - Sessions: Wayland, X11, Headless
    - Methods: RDP (xrdp), VNC (TigerVNC), SSH

EOF
}

cmd_status() {
    local os_info=$(detect_os)
    local de=$(detect_desktop_environment)
    local session_type=$(detect_session_type)
    show_status "$os_info" "$de" "$session_type"
}

cmd_test() {
    local ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}')
    
    echo "Testing connectivity to ${ip}..."
    echo ""
    
    echo -n "RDP (${RDP_PORT}): "
    if ss -tlnp 2>/dev/null | grep -q ":${RDP_PORT}"; then
        echo "✅ OPEN"
    else
        echo "❌ CLOSED"
    fi
    
    echo -n "VNC (${VNC_PORT}): "
    if ss -tlnp 2>/dev/null | grep -q ":${VNC_PORT}"; then
        echo "✅ OPEN"
    else
        echo "❌ CLOSED"
    fi
    
    echo -n "SSH (${SSH_PORT}): "
    if ss -tlnp 2>/dev/null | grep -q ":${SSH_PORT}"; then
        echo "✅ OPEN"
    else
        echo "❌ CLOSED"
    fi
}

# =============================================================================
# ENTRY POINT
# =============================================================================

main() {
    # Ensure running as root
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Must be run as root (use sudo)"
        echo "Usage: sudo $0 --auto"
        exit 1
    fi
    
    # Parse command
    local cmd="${1:---auto}"
    
    case "$cmd" in
        --auto)
            run_auto
            ;;
        --status)
            cmd_status
            ;;
        --test)
            cmd_test
            ;;
        --rdp)
            configure_xrdp
            ;;
        --vnc)
            configure_vnc
            ;;
        --ssh)
            configure_ssh
            ;;
        --install)
            install_packages "$os_info" xrdp tigervnc-standalone-server openssh-server
            ;;
        --help|-h|help)
            cmd_help
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use: $0 --help"
            exit 1
            ;;
    esac
}

main "$@"
