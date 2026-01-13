#!/bin/bash
#
# SkyView Universal Remote Access - Session Type Detection
# Detects detailed session information (Wayland, X11, headless)
#

# Source utility functions and DE detection
if [[ -z "${LIB_UTILS_SOURCED:-}" ]]; then
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [[ -f "$lib_dir/utils.sh" ]] && source "$lib_dir/utils.sh"
fi

if [[ -z "${LIB_DETECT_DE_SOURCED:-}" ]]; then
    LIB_DETECT_DE_SOURCED=1
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [[ -f "$lib_dir/detect_de.sh" ]] && source "$lib_dir/detect_de.sh"
fi

# ============================================================================
# Session Information Variables
# ============================================================================

SKYVIEW_SESSION_TYPE=""
SKYVIEW_SESSION_ID=""
SKYVIEW_SESSION_CLASS=""
SKYVIEW_SESSION_STATE=""
SKYVIEW_SESSION_ACTIVE=""
SKYVIEW_DISPLAY=""
SKYVIEW_WAYLAND_DISPLAY=""
SKYVIEW_X11_DISPLAY=""
SKYVIEW_IS_HEADLESS=""
SKYVIEW_IS_REMOTE=""
SKYVIEW_X11_SOCKET=""
SKYVIEW_WAYLAND_SOCKET_DIR=""

# ============================================================================
# Session Detection Functions
# ============================================================================

# Detect complete session information
detect_session() {
    log_debug "Starting detailed session detection..."

    # Reset all variables
    SKYVIEW_SESSION_TYPE=""
    SKYVIEW_SESSION_ID=""
    SKYVIEW_SESSION_CLASS=""
    SKYVIEW_SESSION_STATE=""
    SKYVIEW_SESSION_ACTIVE=""
    SKYVIEW_DISPLAY=""
    SKYVIEW_WAYLAND_DISPLAY=""
    SKYVIEW_X11_DISPLAY=""
    SKYVIEW_IS_HEADLESS="false"
    SKYVIEW_IS_REMOTE="false"
    SKYVIEW_X11_SOCKET=""
    SKYVIEW_WAYLAND_SOCKET_DIR=""

    # Run basic DE detection first
    detect_session_type
    detect_session_details
    detect_display_info
    detect_headless_mode

    # Export for child processes
    export SKYVIEW_SESSION_TYPE SKYVIEW_SESSION_ID SKYVIEW_SESSION_CLASS \
           SKYVIEW_SESSION_STATE SKYVIEW_SESSION_ACTIVE \
           SKYVIEW_DISPLAY SKYVIEW_WAYLAND_DISPLAY SKYVIEW_X11_DISPLAY \
           SKYVIEW_IS_HEADLESS SKYVIEW_IS_REMOTE \
           SKYVIEW_X11_SOCKET SKYVIEW_WAYLAND_SOCKET_DIR

    log_info "Session: $SKYVIEW_SESSION_TYPE (display: $SKYVIEW_DISPLAY, headless: $SKYVIEW_IS_HEADLESS)"

    return 0
}

# Enhanced session type detection
detect_session_type() {
    # Check XDG_SESSION_TYPE first (most reliable)
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

    # Check systemd-logind for detailed session info
    if command -v loginctl &>/dev/null; then
        local session_info
        session_info=$(loginctl 2>/dev/null | grep -E '^\s*[0-9]+\s' | awk '{print $1}' | head -1)
        if [[ -n "$session_info" ]]; then
            local session_type session_state
            session_type=$(loginctl show-session "$session_info" 2>/dev/null | grep "^Type=" | cut -d= -f2)
            session_state=$(loginctl show-session "$session_info" 2>/dev/null | grep "^State=" | cut -d= -f2)
            SKYVIEW_SESSION_ID="$session_info"

            if [[ -n "$session_type" ]]; then
                SKYVIEW_SESSION_TYPE="$session_type"
                log_debug "Session type from loginctl: $SKYVIEW_SESSION_TYPE (state: $session_state)"
                return 0
            fi
        fi
    fi

    # Check Wayland socket
    if [[ -d "/run/user" ]]; then
        local wayland_sockets
        wayland_sockets=$(find /run/user -maxdepth 1 -name "*wayland*" 2>/dev/null)
        if [[ -n "$wayland_sockets" ]]; then
            SKYVIEW_SESSION_TYPE="wayland"
            log_debug "Session type from Wayland socket: wayland"
            return 0
        fi
    fi

    # Check X11 socket
    if [[ -d "/tmp/.X11-unix" ]] && [[ -n "$(ls -A /tmp/.X11-unix 2>/dev/null)" ]]; then
        SKYVIEW_SESSION_TYPE="x11"
        log_debug "Session type from X11 socket: x11"
        return 0
    fi

    # Check for active X server
    if command -v X &>/dev/null || command -v Xorg &>/dev/null; then
        SKYVIEW_SESSION_TYPE="x11"
        log_debug "Session type from X server binary: x11"
        return 0
    fi

    # Check for Wayland compositor
    if command -v weston &>/dev/null || \
       command -v wayland-session &>/dev/null || \
       pgrep -x "weston" &>/dev/null; then
        SKYVIEW_SESSION_TYPE="wayland"
        log_debug "Session type from Wayland compositor: wayland"
        return 0
    fi

    # Default to unknown
    SKYVIEW_SESSION_TYPE="unknown"
    log_warn "Could not determine session type"
}

# Detect detailed session information
detect_session_details() {
    if ! command -v loginctl &>/dev/null; then
        return 0
    fi

    local session_info
    session_info=$(loginctl 2>/dev/null | grep -E '^\s*[0-9]+\s' | awk '{print $1}' | head -1)
    if [[ -z "$session_info" ]]; then
        return 0
    fi

    SKYVIEW_SESSION_ID="$session_info"

    # Get session properties
    local session_props
    session_props=$(loginctl show-session "$session_info" 2>/dev/null)

    SKYVIEW_SESSION_CLASS=$(echo "$session_props" | grep "^Class=" | cut -d= -f2)
    SKYVIEW_SESSION_STATE=$(echo "$session_props" | grep "^State=" | cut -d= -f2)
    SKYVIEW_SESSION_ACTIVE=$(echo "$session_props" | grep "^Active=" | cut -d= -f2)

    # Check if this is a remote session
    local remote
    remote=$(echo "$session_props" | grep "^Remote=" | cut -d= -f2)
    [[ "$remote" == "yes" ]] && SKYVIEW_IS_REMOTE="true"

    log_debug "Session details: class=$SKYVIEW_SESSION_CLASS, state=$SKYVIEW_SESSION_STATE, active=$SKYVIEW_SESSION_ACTIVE"
}

# Detect display information
detect_display_info() {
    case "$SKYVIEW_SESSION_TYPE" in
        wayland)
            # Get Wayland display
            if [[ -n "$WAYLAND_DISPLAY" ]]; then
                SKYVIEW_WAYLAND_DISPLAY="$WAYLAND_DISPLAY"
                SKYVIEW_DISPLAY="$WAYLAND_DISPLAY"
                log_debug "Wayland display: $SKYVIEW_WAYLAND_DISPLAY"
            else
                # Try to find from socket directory
                local wayland_sock
                wayland_sock=$(find /run/user -maxdepth 1 -name "*wayland*" 2>/dev/null | head -1)
                if [[ -n "$wayland_sock" ]]; then
                    SKYVIEW_WAYLAND_DISPLAY="$wayland_sock"
                    SKYVIEW_DISPLAY="$wayland_sock"
                fi
            fi
            ;;
        x11)
            # Get X11 display
            if [[ -n "$DISPLAY" ]]; then
                SKYVIEW_X11_DISPLAY="$DISPLAY"
                SKYVIEW_DISPLAY="$DISPLAY"
                # Find the X11 socket
                local display_num
                display_num=$(echo "$DISPLAY" | grep -oP ':\K[0-9]+' | head -1)
                if [[ -n "$display_num" ]]; then
                    SKYVIEW_X11_SOCKET="/tmp/.X11-unix/X${display_num}"
                    if [[ -e "$SKYVIEW_X11_SOCKET" ]]; then
                        log_debug "X11 socket: $SKYVIEW_X11_SOCKET"
                    fi
                fi
                log_debug "X11 display: $SKYVIEW_X11_DISPLAY"
            fi
            ;;
    esac
}

# Detect headless mode
detect_headless_mode() {
    # Check if running in a container/headless environment
    if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        log_debug "Running in Docker container"
        if [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
            SKYVIEW_IS_HEADLESS="true"
            return 0
        fi
    fi

    # Check for display manager running
    if [[ -z "$SKYVIEW_DISPLAY" ]]; then
        # No display - could be headless
        if command -v systemctl &>/dev/null; then
            local default_target
            default_target=$(systemctl get-default 2>/dev/null)
            if [[ "$default_target" == "multi-user.target" ]]; then
                SKYVIEW_IS_HEADLESS="true"
                log_debug "Headless mode detected: multi-user.target"
                return 0
            fi
        fi

        # Check if X/Wayland servers are not running
        if ! pgrep -x "Xorg" &>/dev/null && \
           ! pgrep -x "X" &>/dev/null && \
           ! pgrep -x "gnome-shell" &>/dev/null && \
           ! pgrep -x "plasmashell" &>/dev/null; then
            # No desktop session running
            SKYVIEW_IS_HEADLESS="true"
            log_debug "Headless mode detected: no desktop processes"
            return 0
        fi
    fi

    SKYVIEW_IS_HEADLESS="false"
}

# ============================================================================
# Wayland Detection Functions (from REQUIREMENTS.md)
# ============================================================================

# Check if Wayland is available
is_wayland_available() {
    [[ -n "$WAYLAND_DISPLAY" ]] || [[ -d "/run/user" ]] && find /run/user -maxdepth 1 -name "*wayland*" 2>/dev/null | grep -q .
}

# Get Wayland detection reliability
get_wayland_detection_reliability() {
    if [[ -n "$WAYLAND_DISPLAY" ]]; then
        echo "high"
        return
    fi

    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        echo "high"
        return
    fi

    if [[ -d "/run/user" ]] && find /run/user -maxdepth 1 -name "*wayland*" 2>/dev/null | grep -q .; then
        echo "medium"
        return
    fi

    if command -v weston-info &>/dev/null; then
        echo "medium"
        return
    fi

    echo "low"
}

# ============================================================================
# X11 Detection Functions (from REQUIREMENTS.md)
# ============================================================================

# Check if X11 is available
is_x11_available() {
    [[ -n "$DISPLAY" ]] || [[ -d "/tmp/.X11-unix" ]] && [[ -n "$(ls -A /tmp/.X11-unix 2>/dev/null)" ]]
}

# Get X11 detection reliability
get_x11_detection_reliability() {
    if [[ -n "$DISPLAY" ]]; then
        echo "high"
        return
    fi

    if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
        echo "high"
        return
    fi

    if [[ -d "/tmp/.X11-unix" ]] && [[ -n "$(ls -A /tmp/.X11-unix 2>/dev/null)" ]]; then
        echo "high"
        return
    fi

    if command -v loginctl &>/dev/null && loginctl show-session "$(loginctl | grep -E '^\s*[0-9]+\s' | awk '{print $1}' | head -1)" 2>/dev/null | grep -q "Type=x11"; then
        echo "high"
        return
    fi

    echo "low"
}

# ============================================================================
# Headless Detection Functions (from REQUIREMENTS.md)
# ============================================================================

# Check if headless mode is active
is_headless() {
    [[ "$SKYVIEW_IS_HEADLESS" == "true" ]]
}

# Get headless detection reliability
get_headless_detection_reliability() {
    if [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]] && ! pgrep -x "Xorg" &>/dev/null && ! pgrep -x "gnome-shell" &>/dev/null; then
        echo "high"
        return
    fi

    if command -v systemctl &>/dev/null; then
        local default_target
        default_target=$(systemctl get-default 2>/dev/null)
        if [[ "$default_target" == "multi-user.target" ]]; then
            echo "medium"
            return
        fi
    fi

    echo "low"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Print session summary
print_session_summary() {
    print_header "Session Detection"

    cat << EOF
Session Type:     $SKYVIEW_SESSION_TYPE
Session ID:       ${SKYVIEW_SESSION_ID:-N/A}
Session Class:    ${SKYVIEW_SESSION_CLASS:-N/A}
Session State:    ${SKYVIEW_SESSION_STATE:-N/A}
Session Active:   ${SKYVIEW_SESSION_ACTIVE:-N/A}
Display:          $SKYVIEW_DISPLAY
X11 Display:      ${SKYVIEW_X11_DISPLAY:-N/A}
Wayland Display:  ${SKYVIEW_WAYLAND_DISPLAY:-N/A}
Headless Mode:    $SKYVIEW_IS_HEADLESS
Remote Session:   $SKYVIEW_IS_REMOTE
X11 Socket:       ${SKYVIEW_X11_SOCKET:-N/A}
EOF
}

# Export session info as environment file
export_session_info() {
    local output_file="${1:-/tmp/skyview-session-info.env}"

    cat > "$output_file" << EOF
SKYVIEW_SESSION_TYPE=$SKYVIEW_SESSION_TYPE
SKYVIEW_SESSION_ID=$SKYVIEW_SESSION_ID
SKYVIEW_SESSION_CLASS=$SKYVIEW_SESSION_CLASS
SKYVIEW_SESSION_STATE=$SKYVIEW_SESSION_STATE
SKYVIEW_SESSION_ACTIVE=$SKYVIEW_SESSION_ACTIVE
SKYVIEW_DISPLAY=$SKYVIEW_DISPLAY
SKYVIEW_WAYLAND_DISPLAY=$SKYVIEW_WAYLAND_DISPLAY
SKYVIEW_X11_DISPLAY=$SKYVIEW_X11_DISPLAY
SKYVIEW_IS_HEADLESS=$SKYVIEW_IS_HEADLESS
SKYVIEW_IS_REMOTE=$SKYVIEW_IS_REMOTE
SKYVIEW_X11_SOCKET=$SKYVIEW_X11_SOCKET
SKYVIEW_WAYLAND_SOCKET_DIR=$SKYVIEW_WAYLAND_SOCKET_DIR
EOF

    log_debug "Session info exported to: $output_file"
}
