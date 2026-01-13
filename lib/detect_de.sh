#!/bin/bash
#
# SkyView Universal Remote Access - Desktop Environment Detection
# Detects desktop environments, window managers, and their capabilities
#

# Source utility functions and OS detection
if [[ -z "${LIB_UTILS_SOURCED:-}" ]]; then
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$lib_dir/utils.sh" ]]; then
        # shellcheck source=utils.sh
        source "$lib_dir/utils.sh"
    fi
fi

if [[ -z "${LIB_DETECT_OS_SOURCED:-}" ]]; then
    LIB_DETECT_OS_SOURCED=1
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$lib_dir/detect_os.sh" ]]; then
        # shellcheck source=detect_os.sh
        source "$lib_dir/detect_os.sh"
    fi
fi

# ============================================================================
# Desktop Environment Variables
# ============================================================================

SKYVIEW_DE=""
SKYVIEW_DE_VERSION=""
SKYVIEW_WM=""
SKYVIEW_WM_TYPE=""  # tiling, floating, hybrid
SKYVIEW_DE_NATIVE_RDP=""  # Does this DE support native RDP?
SKYVIEW_DE_RDP_METHOD=""  # Recommended RDP method for this DE
SKYVIEW_SESSION_TYPE=""   # wayland, x11, tty, unknown
SKYVIEW_DISPLAY_MANAGER=""

# Desktop environment process names
readonly DE_PROCESSES=(
    "plasmashell:KDE Plasma"
    "gnome-shell:GNOME"
    "xfce4-session:XFCE"
    "cinnamon-session:Cinnamon"
    "mate-session:MATE"
    "lxqt-session:LXQt"
    "lxsession:LXDE"
    "budgie-session:Budgie"
    "pantheon-session:Pantheon"
    "deepin-session:Deepin"
)

# Window manager process names
readonly WM_PROCESSES=(
    "sway:sway:wayland:tiling"
    "i3:i3:x11:tiling"
    "i3-msg:i3:x11:tiling"
    "bspwm:bspwm:x11:tiling"
    "awesome:awesome:x11:tiling"
    "dwm:dwm:x11:tiling"
    "qtile:qtile:x11:tiling"
    "openbox:openbox:x11:floating"
    "fluxbox:fluxbox:x11:floating"
    "enlightenment:Enlightenment:x11:floating"
    "herbstluftwm:herbstluftwm:x11:tiling"
    "xmonad:xmonad:x11:tiling"
    "spectrwm:spectrwm:x11:tiling"
    "awesome:awesome:x11:tiling"
)

# ============================================================================
# Desktop Environment Detection Functions
# ============================================================================

# Main detection function - detects DE, WM, and session type
detect_desktop_environment() {
    log_debug "Starting desktop environment detection..."

    # Reset all variables
    SKYVIEW_DE=""
    SKYVIEW_DE_VERSION=""
    SKYVIEW_WM=""
    SKYVIEW_WM_TYPE=""
    SKYVIEW_DE_NATIVE_RDP=""
    SKYVIEW_DE_RDP_METHOD=""
    SKYVIEW_SESSION_TYPE=""
    SKYVIEW_DISPLAY_MANAGER=""

    # Detect display manager
    detect_display_manager

    # Detect session type first (Wayland vs X11)
    detect_session_type

    # Detect desktop environment
    detect_de

    # Detect window manager
    detect_wm

    # Determine recommended RDP method
    determine_rdp_method

    # Export for child processes
    export SKYVIEW_DE SKYVIEW_DE_VERSION SKYVIEW_WM SKYVIEW_WM_TYPE \
           SKYVIEW_DE_NATIVE_RDP SKYVIEW_DE_RDP_METHOD \
           SKYVIEW_SESSION_TYPE SKYVIEW_DISPLAY_MANAGER

    if [[ -n "$SKYVIEW_DE" ]]; then
        log_info "Desktop detected: $SKYVIEW_DE ($SKYVIEW_SESSION_TYPE, RDP method: $SKYVIEW_DE_RDP_METHOD)"
    elif [[ -n "$SKYVIEW_WM" ]]; then
        log_info "Window manager detected: $SKYVIEW_WM ($SKYVIEW_WM_TYPE, RDP method: $SKYVIEW_DE_RDP_METHOD)"
    else
        log_warn "No desktop environment or window manager detected"
    fi

    return 0
}

# Detect the display manager
detect_display_manager() {
    # Check for common display managers
    if command -v lightdm &>/dev/null; then
        SKYVIEW_DISPLAY_MANAGER="lightdm"
    elif command -v gdm &>/dev/null; then
        SKYVIEW_DISPLAY_MANAGER="gdm"
    elif command -v sddm &>/dev/null; then
        SKYVIEW_DISPLAY_MANAGER="sddm"
    elif command -v lxdm &>/dev/null; then
        SKYVIEW_DISPLAY_MANAGER="lxdm"
    elif command -v xdm &>/dev/null; then
        SKYVIEW_DISPLAY_MANAGER="xdm"
    elif command -v kdm &>/dev/null; then
        SKYVIEW_DISPLAY_MANAGER="kdm"
    fi

    # Also check running processes
    if [[ -z "$SKYVIEW_DISPLAY_MANAGER" ]]; then
        for dm in lightdm gdm sddm lxdm xdm kdm; do
            if pgrep -x "$dm" &>/dev/null; then
                SKYVIEW_DISPLAY_MANAGER="$dm"
                break
            fi
        done
    fi

    log_debug "Display manager: $SKYVIEW_DISPLAY_MANAGER"
}

# Detect the session type (Wayland, X11, or headless)
detect_session_type() {
    # Check environment variables first
    if [[ -n "$XDG_SESSION_TYPE" ]]; then
        SKYVIEW_SESSION_TYPE="$XDG_SESSION_TYPE"
        log_debug "Session type from XDG_SESSION_TYPE: $SKYVIEW_SESSION_TYPE"
        return 0
    fi

    # Check WAYLAND_DISPLAY
    if [[ -n "$WAYLAND_DISPLAY" ]]; then
        SKYVIEW_SESSION_TYPE="wayland"
        log_debug "Session type from WAYLAND_DISPLAY: wayland"
        return 0
    fi

    # Check DISPLAY
    if [[ -n "$DISPLAY" ]]; then
        SKYVIEW_SESSION_TYPE="x11"
        log_debug "Session type from DISPLAY: x11"
        return 0
    fi

    # Check systemd-logind for session info
    if command -v loginctl &>/dev/null; then
        local session_type
        session_type=$(loginctl show-session "$(loginctl | grep -E '^\s*[0-9]+\s' | awk '{print $1}' | head -1)" 2>/dev/null | grep "Type=" | cut -d= -f2)
        if [[ -n "$session_type" ]]; then
            SKYVIEW_SESSION_TYPE="$session_type"
            log_debug "Session type from loginctl: $SKYVIEW_SESSION_TYPE"
            return 0
        fi
    fi

    # Check for Wayland socket
    if [[ -d "/run/user" ]] && find /run/user -maxdepth 1 -name "*wayland*" 2>/dev/null | grep -q .; then
        SKYVIEW_SESSION_TYPE="wayland"
        log_debug "Session type from Wayland socket: wayland"
        return 0
    fi

    # Check for X11 socket
    if [[ -d "/tmp/.X11-unix" ]] && [[ -n "$(ls -A /tmp/.X11-unix 2>/dev/null)" ]]; then
        SKYVIEW_SESSION_TYPE="x11"
        log_debug "Session type from X11 socket: x11"
        return 0
    fi

    # Check for display manager running
    if [[ -n "$SKYVIEW_DISPLAY_MANAGER" ]]; then
        if [[ "$SKYVIEW_DISPLAY_MANAGER" == "gdm" || "$SKYVIEW_DISPLAY_MANAGER" == "sddm" ]]; then
            SKYVIEW_SESSION_TYPE="wayland"
        else
            SKYVIEW_SESSION_TYPE="x11"
        fi
        log_debug "Session type inferred from DM ($SKYVIEW_DISPLAY_MANAGER): $SKYVIEW_SESSION_TYPE"
        return 0
    fi

    # Default to unknown
    SKYVIEW_SESSION_TYPE="unknown"
    log_warn "Could not determine session type"
}

# Detect the desktop environment
detect_de() {
    # Method 1: Check environment variables
    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        SKYVIEW_DE="$XDG_CURRENT_DESKTOP"
        log_debug "DE from XDG_CURRENT_DESKTOP: $SKYVIEW_DE"
        get_de_version
        return 0
    fi

    if [[ -n "$DESKTOP_SESSION" ]]; then
        SKYVIEW_DE="$DESKTOP_SESSION"
        log_debug "DE from DESKTOP_SESSION: $SKYVIEW_DE"
        get_de_version
        return 0
    fi

    # Method 2: Check for DE-specific processes
    for entry in "${DE_PROCESSES[@]}"; do
        IFS=':' read -r process de_name <<< "$entry"
        if pgrep -x "$process" &>/dev/null; then
            SKYVIEW_DE="$de_name"
            log_debug "DE from process $process: $SKYVIEW_DE"
            get_de_version
            return 0
        fi
    done

    # Method 3: Check for KDE-specific processes
    if pgrep -x "plasma-desktop" &>/dev/null || \
       pgrep -x "plasma" &>/dev/null || \
       pgrep -x "kded5" &>/dev/null; then
        SKYVIEW_DE="KDE Plasma"
        get_de_version
        return 0
    fi

    # Method 4: Check for GNOME-specific processes
    if pgrep -x "mutter" &>/dev/null || \
       pgrep -x "gnome-shell" &>/dev/null; then
        SKYVIEW_DE="GNOME"
        get_de_version
        return 0
    fi

    log_debug "No desktop environment detected"
}

# Get version of the detected desktop environment
get_de_version() {
    case "$SKYVIEW_DE" in
        *"KDE"*|*"Plasma"*)
            if command -v plasmashell &>/dev/null; then
                SKYVIEW_DE_VERSION=$(plasmashell --version 2>/dev/null | grep -oP '\d+(\.\d+)*' | head -1)
            elif [[ -f /usr/share/kde-version ]]; then
                SKYVIEW_DE_VERSION=$(cat /usr/share/kde-version)
            fi
            ;;
        *"GNOME"*)
            if command -v gnome-shell &>/dev/null; then
                SKYVIEW_DE_VERSION=$(gnome-shell --version 2>/dev/null | grep -oP '[\d.]+')
            fi
            ;;
        *"XFCE"*)
            if command -v xfce4-session &>/dev/null; then
                SKYVIEW_DE_VERSION=$(xfce4-session --version 2>&1 | grep -oP '[\d.]+')
            fi
            ;;
        *"Cinnamon"*)
            if command -v cinnamon &>/dev/null; then
                SKYVIEW_DE_VERSION=$(cinnamon --version 2>/dev/null | grep -oP '[\d.]+')
            fi
            ;;
        *"MATE"*)
            if command -v mate-session &>/dev/null; then
                SKYVIEW_DE_VERSION=$(mate-session --version 2>&1 | grep -oP '[\d.]+')
            fi
            ;;
    esac

    log_debug "DE version: $SKYVIEW_DE_VERSION"
}

# Detect the window manager
detect_wm() {
    # Method 1: Check _NET_WM_NAME property (X11)
    if command -v xprop &>/dev/null && [[ -n "$DISPLAY" ]]; then
        local wm_name
        wm_name=$(xprop -root _NET_WM_NAME 2>/dev/null | sed 's/_NET_WM_NAME(UTF8_STRING) = "//' | tr -d '"')
        if [[ -n "$wm_name" ]]; then
            SKYVIEW_WM="$wm_name"
            SKYVIEW_WM_TYPE="unknown"
            normalize_wm_type
            log_debug "WM from xprop: $SKYVIEW_WM ($SKYVIEW_WM_TYPE)"
            return 0
        fi
    fi

    # Method 2: Check for WM processes
    for entry in "${WM_PROCESSES[@]}"; do
        IFS=':' read -r process wm_name server type <<< "$entry"
        if pgrep -x "$process" &>/dev/null; then
            SKYVIEW_WM="$wm_name"
            SKYVIEW_WM_TYPE="$type"
            # Verify it matches current session type
            if [[ "$server" == "wayland" && "$SKYVIEW_SESSION_TYPE" != "wayland" ]]; then
                continue
            fi
            log_debug "WM from process $process: $SKYVIEW_WM ($SKYVIEW_WM_TYPE)"
            return 0
        fi
    done

    # Method 3: Check for compositor processes
    if pgrep -x "picom" &>/dev/null || pgrep -x "compton" &>/dev/null; then
        if [[ -z "$SKYVIEW_WM" ]]; then
            SKYVIEW_WM="unknown (with compositor)"
            SKYVIEW_WM_TYPE="unknown"
        fi
    fi

    log_debug "No window manager detected"
}

# Normalize WM type based on known window managers
normalize_wm_type() {
    case "$SKYVIEW_WM" in
        *i3*|*sway*|*bspwm*|*awesome*|*dwm*|*qtile*|*xmonad*|*herbstluftwm*|*spectrwm*)
            SKYVIEW_WM_TYPE="tiling"
            ;;
        *Openbox*|*Fluxbox*|*Enlightenment*|*Sawfish*)
            SKYVIEW_WM_TYPE="floating"
            ;;
        *Mutter*|*Muffin*|*Marco*)
            SKYVIEW_WM_TYPE="floating"
            ;;
    esac
}

# Determine the best RDP method for the detected DE
determine_rdp_method() {
    local de_lower
    de_lower=$(lowercase "$SKYVIEW_DE")
    local wm_lower
    wm_lower=$(lowercase "$SKYVIEW_WM")

    # KDE Plasma
    if [[ "$de_lower" == *"kde"* || "$de_lower" == *"plasma"* ]]; then
        if [[ "$SKYVIEW_SESSION_TYPE" == "wayland" ]]; then
            SKYVIEW_DE_NATIVE_RDP="true"
            SKYVIEW_DE_RDP_METHOD="krdp"
        else
            SKYVIEW_DE_NATIVE_RDP="false"
            SKYVIEW_DE_RDP_METHOD="xrdp"
        fi
        return 0
    fi

    # GNOME
    if [[ "$de_lower" == *"gnome"* ]]; then
        if [[ "$SKYVIEW_SESSION_TYPE" == "wayland" ]]; then
            SKYVIEW_DE_NATIVE_RDP="true"
            SKYVIEW_DE_RDP_METHOD="gnome-remote-desktop"
        else
            SKYVIEW_DE_NATIVE_RDP="false"
            SKYVIEW_DE_RDP_METHOD="xrdp"
        fi
        return 0
    fi

    # XFCE
    if [[ "$de_lower" == *"xfce"* ]]; then
        SKYVIEW_DE_NATIVE_RDP="false"
        SKYVIEW_DE_RDP_METHOD="xrdp"
        return 0
    fi

    # MATE
    if [[ "$de_lower" == *"mate"* ]]; then
        SKYVIEW_DE_NATIVE_RDP="false"
        SKYVIEW_DE_RDP_METHOD="xrdp"
        return 0
    fi

    # Cinnamon
    if [[ "$de_lower" == *"cinnamon"* ]]; then
        SKYVIEW_DE_NATIVE_RDP="false"
        SKYVIEW_DE_RDP_METHOD="xrdp"
        return 0
    fi

    # LXQt/LXDE
    if [[ "$de_lower" == *"lxqt"* || "$de_lower" == *"lxde"* ]]; then
        SKYVIEW_DE_NATIVE_RDP="false"
        SKYVIEW_DE_RDP_METHOD="xrdp"
        return 0
    fi

    # Budgie
    if [[ "$de_lower" == *"budgie"* ]]; then
        SKYVIEW_DE_NATIVE_RDP="false"
        SKYVIEW_DE_RDP_METHOD="xrdp"
        return 0
    fi

    # Pantheon
    if [[ "$de_lower" == *"pantheon"* ]]; then
        SKYVIEW_DE_NATIVE_RDP="false"
        SKYVIEW_DE_RDP_METHOD="vnc"
        return 0
    fi

    # Deepin
    if [[ "$de_lower" == *"deepin"* ]]; then
        SKYVIEW_DE_NATIVE_RDP="false"
        SKYVIEW_DE_RDP_METHOD="vnc"
        return 0
    fi

    # Window managers - use VNC for tiling WMs
    if [[ -n "$wm_lower" ]]; then
        SKYVIEW_DE_NATIVE_RDP="false"
        SKYVIEW_DE_RDP_METHOD="vnc"
        return 0
    fi

    # Default fallback
    SKYVIEW_DE_NATIVE_RDP="false"
    SKYVIEW_DE_RDP_METHOD="vnc"
}

# ============================================================================
# Remote Access Capability Functions
# ============================================================================

# Check if native Wayland RDP is available
is_native_rdp_available() {
    local de_lower
    de_lower=$(lowercase "$SKYVIEW_DE")

    case "$de_lower" in
        *"kde"*|*"plasma"*)
            command -v krfb &>/dev/null || command -v krdp &>/dev/null
            return $?
            ;;
        *"gnome"*)
            command -v gnome-remote-desktop &>/dev/null
            return $?
            ;;
    esac

    return 1
}

# Check if RDP (xrdp) is available
is_xrdp_available() {
    command -v xrdp &>/dev/null && command -v xorgxrdp &>/dev/null
}

# Check if VNC is available
is_vnc_available() {
    command -v vncserver &>/dev/null || command -v Xvnc &>/dev/null || \
    command -v x0vncserver &>/dev/null
}

# Get list of available RDP methods
get_available_rdp_methods() {
    local methods=()

    # Check native Wayland RDP
    if is_native_rdp_available; then
        case "$SKYVIEW_DE_RDP_METHOD" in
            krdp) methods+=("krdp") ;;
            gnome-remote-desktop) methods+=("gnome-remote-desktop") ;;
        esac
    fi

    # Check xrdp
    if is_xrdp_available; then
        methods+=("xrdp")
    fi

    # VNC is always available as fallback
    if is_vnc_available; then
        methods+=("vnc")
    fi

    # If no methods found, add vnc as default
    if [[ ${#methods[@]} -eq 0 ]]; then
        methods+=("vnc")
    fi

    printf '%s\n' "${methods[@]}"
}

# Get the best RDP method for the current setup
get_best_rdp_method() {
    local methods
    methods=$(get_available_rdp_methods)

    # Priority order: native > xrdp > vnc
    local de_lower
    de_lower=$(lowercase "$SKYVIEW_DE")

    # KDE Wayland: prefer krdp
    if [[ "$de_lower" == *"kde"* && "$SKYVIEW_SESSION_TYPE" == "wayland" ]]; then
        if echo "$methods" | grep -q "krdp"; then
            echo "krdp"
            return
        fi
    fi

    # GNOME Wayland: prefer gnome-remote-desktop
    if [[ "$de_lower" == *"gnome"* && "$SKYVIEW_SESSION_TYPE" == "wayland" ]]; then
        if echo "$methods" | grep -q "gnome-remote-desktop"; then
            echo "gnome-remote-desktop"
            return
        fi
    fi

    # X11 DEs: prefer xrdp
    if echo "$methods" | grep -q "xrdp"; then
        echo "xrdp"
        return
    fi

    # Fallback to first available
    echo "$methods" | head -1
}

# ============================================================================
# Session Management Functions
# ============================================================================

# Get the default session command for the DE
get_session_command() {
    local de_lower
    de_lower=$(lowercase "$SKYVIEW_DE")
    local wm_lower
    wm_lower=$(lowercase "$SKYVIEW_WM")

    # Check XDG session desktop file
    if [[ -n "$DESKTOP_SESSION" ]]; then
        local desktop_file="/usr/share/xsessions/${DESKTOP_SESSION}.desktop"
        if [[ -f "$desktop_file" ]]; then
            grep -oP 'Exec=\K.*' "$desktop_file" 2>/dev/null | head -1
            return
        fi
    fi

    # Fallback to DE-specific commands
    case "$de_lower" in
        *"kde"*|*"plasma"*)
            echo "startplasma-x11"
            [[ "$SKYVIEW_SESSION_TYPE" == "wayland" ]] && echo "plasmawayland"
            ;;
        *"gnome"*)
            echo "gnome-session"
            ;;
        *"xfce"*)
            echo "xfce4-session"
            ;;
        *"cinnamon"*)
            echo "cinnamon-session"
            ;;
        *"mate"*)
            echo "mate-session"
            ;;
        *"lxqt"*)
            echo "lxqt-session"
            ;;
        *"lxde"*)
            echo "lxsession"
            ;;
        *"budgie"*)
            echo "budgie-session"
            ;;
        *"deepin"*)
            echo "deepin-session"
            ;;
    esac

    # Window manager fallback
    if [[ -n "$wm_lower" ]]; then
        case "$wm_lower" in
            *"sway"*) echo "sway" ;;
            *"i3"*) echo "i3" ;;
            *"bspwm"*) echo "bspwm" ;;
            *"awesome"*) echo "awesome" ;;
            *"openbox"*) echo "openbox" ;;
            *"qtile"*) echo "qtile" ;;
        esac
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

# Print DE detection summary
print_de_summary() {
    print_header "Desktop Environment Detection"

    cat << EOF
Desktop Environment: $SKYVIEW_DE
DE Version:          ${SKYVIEW_DE_VERSION:-N/A}
Window Manager:      $SKYVIEW_WM ($SKYVIEW_WM_TYPE)
Session Type:        $SKYVIEW_SESSION_TYPE
Display Manager:     $SKYVIEW_DISPLAY_MANAGER
Native RDP:          $SKYVIEW_DE_NATIVE_RDP
Recommended Method:  $SKYVIEW_DE_RDP_METHOD
EOF
}

# Export DE information as environment file
export_de_info() {
    local output_file="${1:-/tmp/skyview-de-info.env}"

    cat > "$output_file" << EOF
SKYVIEW_DE=$SKYVIEW_DE
SKYVIEW_DE_VERSION=$SKYVIEW_DE_VERSION
SKYVIEW_WM=$SKYVIEW_WM
SKYVIEW_WM_TYPE=$SKYVIEW_WM_TYPE
SKYVIEW_DE_NATIVE_RDP=$SKYVIEW_DE_NATIVE_RDP
SKYVIEW_DE_RDP_METHOD=$SKYVIEW_DE_RDP_METHOD
SKYVIEW_SESSION_TYPE=$SKYVIEW_SESSION_TYPE
SKYVIEW_DISPLAY_MANAGER=$SKYVIEW_DISPLAY_MANAGER
EOF

    log_debug "DE info exported to: $output_file"
}
