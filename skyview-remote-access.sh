#!/bin/bash
#
# SkyView Universal Remote Access - Main Entry Point
# "IT JUST WORKS" - Auto-detects, configures, and enables remote access
#
# Usage: ./skyview-remote-access.sh [OPTIONS]
#   --install          Install required packages
#   --configure        Configure remote access
#   --start            Start services
#   --stop             Stop services
#   --restart          Restart services
#   --enable           Enable on boot
#   --disable          Disable on boot
#   --status           Show service status
#   --verify           Verify configuration
#   --detect           Detect system info only
#   --verbose          Verbose output
#   --debug            Debug mode
#   --help             Show this help
#
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - Invalid arguments
#  10 - OS not supported
#  11 - Desktop not supported
#  20 - Package installation failed
#  21 - Service start failed
#  30 - Permission denied
#

set -euo pipefail

# ============================================================================
# Version and Configuration
# ============================================================================

readonly SKYVIEW_VERSION="7.0.0"
readonly SKYVIEW_NAME="SkyView Universal Remote Access"

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/lib"

# ============================================================================
# Global State
# ============================================================================

VERBOSE="${VERBOSE:-false}"
DEBUG="${DEBUG:-false}"
DRY_RUN="${DRY_RUN:-false}"
SKYVIEW_SKIP_PACKAGES="${SKYVIEW_SKIP_PACKAGES:-false}"
SKYVIEW_SKIP_FIREWALL="${SKYVIEW_SKIP_FIREWALL:-false}"
SKYVIEW_SKIP_SERVICES="${SKYVIEW_SKIP_SERVICES:-false}"
SKYVIEW_SSH_PORT="${SKYVIEW_SSH_PORT:-2277}"
SKYVIEW_RDP_PORT="${SKYVIEW_RDP_PORT:-3389}"
SKYVIEW_VNC_PORT="${SKYVIEW_VNC_PORT:-5900}"

# ============================================================================
# Source Library Modules
# ============================================================================

source_library() {
    local module="$1"

    if [[ -f "${LIB_DIR}/${module}" ]]; then
        # shellcheck source=lib/utils.sh
        source "${LIB_DIR}/${module}"
        return 0
    else
        echo "ERROR: Library file not found: ${LIB_DIR}/${module}" >&2
        return 1
    fi
}

# Load core libraries
load_libraries() {
    source_library "utils.sh" || exit 1
    source_library "detect_os.sh" || exit 1
    source_library "detect_de.sh" || exit 1
    source_library "detect_session.sh" || exit 1
    source_library "config_rdp.sh" || exit 1
    source_library "config_vnc.sh" || exit 1
    source_library "config_ssh.sh" || exit 1
    source_library "config_native.sh" || exit 1
    source_library "firewall.sh" || exit 1
}

# ============================================================================
# Help and Usage
# ============================================================================

show_help() {
    cat << EOF
${SKYVIEW_NAME} v${SKYVIEW_VERSION}

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --install          Install required packages
    --configure        Configure remote access
    --start            Start services
    --stop             Stop services
    --restart          Restart services
    --enable           Enable services on boot
    --disable          Disable services on boot
    --status           Show service status
    --verify           Verify configuration
    --detect           Detect system info only
    --verbose          Verbose output
    --debug            Enable debug mode
    --dry-run          Show what would be done
    --help             Show this help

ENVIRONMENT VARIABLES:
    SKYVIEW_SSH_PORT       SSH port (default: 22)
    SKYVIEW_RDP_PORT       RDP port (default: 3389)
    SKYVIEW_VNC_PORT       VNC port (default: 5900)
    SKYVIEW_SKIP_PACKAGES  Skip package installation (true/false)
    SKYVIEW_SKIP_FIREWALL  Skip firewall configuration (true/false)
    SKYVIEW_SKIP_SERVICES  Skip service management (true/false)

EXAMPLES:
    $(basename "$0") --install --configure --start
    $(basename "$0") --detect
    $(basename "$0") --status
    $(basename "$0") --verbose --restart

For more information, see: ${SCRIPT_DIR}/REQUIREMENTS.md
EOF
}

# ============================================================================
# Detection Functions
# ============================================================================

detect_system() {
    print_header "System Detection"

    detect_os || {
        log_error "OS detection failed"
        return $EXIT_OS_NOT_SUPPORTED
    }

    print_os_summary

    if ! is_os_supported; then
        log_warn "Operating system may not be fully supported: $SKYVIEW_OS_NAME"
        log_info "Continuing anyway (some features may not work)..."
    fi

    detect_desktop_environment || true

    if [[ -n "$SKYVIEW_DE" ]]; then
        print_de_summary
    else
        log_warn "No desktop environment detected"
        log_info "Continuing in headless/server mode..."
    fi

    detect_session || true

    if [[ -n "$SKYVIEW_SESSION_TYPE" ]]; then
        print_session_summary
    fi

    return 0
}

# ============================================================================
# Installation Functions
# ============================================================================

install_packages() {
    print_header "Installing Packages"

    log_info "Installing remote access packages..."

    local errors=0

    if [[ "$SKYVIEW_SKIP_PACKAGES" != "true" ]]; then
        install_xrdp || ((errors++))
    else
        log_info "Skipping RDP package installation"
    fi

    if [[ "$SKYVIEW_SKIP_PACKAGES" != "true" ]]; then
        install_vnc || ((errors++))
    else
        log_info "Skipping VNC package installation"
    fi

    if ! command -v sshd &>/dev/null; then
        log_info "Installing SSH server..."
        local packages
        packages=$(get_packages_for_method "ssh")
        install_packages $packages || ((errors++))
    else
        log_info "SSH server already installed"
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Some packages failed to install"
        return $EXIT_PACKAGE_INSTALL_FAILED
    fi

    log_info "Package installation complete"
    return 0
}

# ============================================================================
# Configuration Functions
# ============================================================================

configure_remote_access() {
    print_header "Configuring Remote Access"

    local errors=0

    # Detect system first
    detect_system || true

    # Configure SSH (new module)
    log_info "Configuring SSH on port ${SKYVIEW_SSH_PORT}..."
    if configure_ssh; then
        log_info "SSH configured successfully"
    else
        log_warn "SSH configuration failed"
        ((errors++))
    fi

    # Configure RDP
    log_info "Configuring RDP..."
    if configure_xrdp; then
        log_info "RDP configured successfully"
    else
        log_warn "RDP configuration failed"
        ((errors++))
    fi

    # Configure Native RDP (Wayland - new module)
    if [[ "$SKYVIEW_SESSION_TYPE" == "wayland" ]]; then
        log_info "Configuring Native RDP for Wayland..."
        if configure_native_rdp; then
            log_info "Native RDP configured successfully"
        else
            log_warn "Native RDP configuration failed (may not be supported for this DE)"
        fi
    fi

    # Configure VNC
    log_info "Configuring VNC..."
    if configure_vnc; then
        log_info "VNC configured successfully"
    else
        log_warn "VNC configuration failed"
        ((errors++))
    fi

    # Configure firewall
    if [[ "$SKYVIEW_SKIP_FIREWALL" != "true" ]]; then
        log_info "Configuring firewall..."
        if configure_firewall; then
            log_info "Firewall configured successfully"
        else
            log_warn "Firewall configuration failed"
            ((errors++))
        fi
    else
        log_info "Skipping firewall configuration"
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Some configurations failed"
        return $EXIT_CONFIG_VERIFICATION_FAILED
    fi

    log_info "Configuration complete"
    return 0
}

# ============================================================================
# Service Management Functions
# ============================================================================

start_services() {
    print_header "Starting Services"

    if [[ "$SKYVIEW_SKIP_SERVICES" == "true" ]]; then
        log_info "Skipping service management"
        return 0
    fi

    local errors=0

    # Start SSH
    log_info "Starting SSH on port ${SKYVIEW_SSH_PORT}..."
    if start_ssh; then
        log_info "SSH started successfully"
    else
        log_warn "SSH failed to start"
        ((errors++))
    fi

    # Start RDP
    log_info "Starting xrdp..."
    if start_xrdp; then
        log_info "xrdp started successfully"
    else
        log_warn "xrdp failed to start"
        ((errors++))
    fi

    # Start Native RDP if Wayland
    if [[ "$SKYVIEW_SESSION_TYPE" == "wayland" ]]; then
        log_info "Starting Native RDP..."
        if start_native_rdp; then
            log_info "Native RDP started successfully"
        else
            log_warn "Native RDP failed to start"
        fi
    fi

    # Start VNC
    if [[ -f "$HOME/.config/systemd/user/skyview-vnc.service" ]]; then
        log_info "Starting VNC service..."
        start_vnc_service
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Some services failed to start"
        return $EXIT_SERVICE_START_FAILED
    fi

    log_info "All services started"
    return 0
}

stop_services() {
    print_header "Stopping Services"

    if [[ "$SKYVIEW_SKIP_SERVICES" == "true" ]]; then
        log_info "Skipping service management"
        return 0
    fi

    stop_ssh
    stop_xrdp
    stop_native_rdp
    stop_vnc_service

    log_info "All services stopped"
    return 0
}

restart_services() {
    stop_services
    sleep 1
    start_services
}

enable_services() {
    print_header "Enabling Services on Boot"

    if [[ "$SKYVIEW_SKIP_SERVICES" == "true" ]]; then
        log_info "Skipping service management"
        return 0
    fi

    enable_ssh
    enable_xrdp
    enable_native_rdp
    enable_vnc_service

    log_info "Services enabled on boot"
}

disable_services() {
    print_header "Disabling Services on Boot"

    disable_xrdp
    stop_vnc_service

    log_info "Services disabled on boot"
}

show_status() {
    print_header "Service Status"

    echo "SSH Status:"
    get_ssh_status

    echo ""
    echo "RDP Status:"
    get_rdp_status

    echo ""
    if [[ "$SKYVIEW_SESSION_TYPE" == "wayland" ]]; then
        echo "Native RDP Status:"
        get_native_rdp_status
    fi

    echo ""
    echo "VNC Status:"
    get_vnc_status

    echo ""
    echo "Firewall Status:"
    get_firewall_status

    echo ""
    echo "Quick Connect Commands:"
    local ip
    ip=$(get_primary_ip)
    echo "  SSH:  ssh -p ${SKYVIEW_SSH_PORT} user@${ip}"
    echo "  RDP:  rdp://${ip}:${SKYVIEW_RDP_PORT}"
    echo "  VNC:  vnc://${ip}:${SKYVIEW_VNC_PORT}"
}

verify_configuration() {
    print_header "Verifying Configuration"

    local errors=0

    log_info "Running verification checks..."

    log_info "Checking SSH..."
    verify_ssh || ((errors++))

    log_info "Checking RDP..."
    verify_xrdp || ((errors++))

    if [[ "$SKYVIEW_SESSION_TYPE" == "wayland" ]]; then
        log_info "Checking Native RDP..."
        verify_native_rdp || ((errors++))
    fi

    log_info "Checking VNC..."
    verify_vnc || ((errors++))

    log_info "Checking firewall..."
    verify_firewall || ((errors++))

    if [[ $errors -gt 0 ]]; then
        log_warn "Verification found $errors issue(s)"
        return $EXIT_CONFIG_VERIFICATION_FAILED
    fi

    log_info "All verification checks passed!"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    local action="help"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install)
                action="install"
                shift
                ;;
            --configure)
                action="configure"
                shift
                ;;
            --start)
                action="start"
                shift
                ;;
            --stop)
                action="stop"
                shift
                ;;
            --restart)
                action="restart"
                shift
                ;;
            --enable)
                action="enable"
                shift
                ;;
            --disable)
                action="disable"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
            --verify)
                action="verify"
                shift
                ;;
            --detect)
                action="detect"
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                LOG_LEVEL=$LOG_INFO
                shift
                ;;
            --debug|-d)
                DEBUG=true
                LOG_LEVEL=$LOG_DEBUG
                set -x
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit $EXIT_INVALID_ARGS
                ;;
        esac
    done

    case "$action" in
        install|configure|start|stop|restart|enable|disable)
            require_root || exit $EXIT_PERMISSION_DENIED
            ;;
    esac

    load_libraries

    if [[ "$VERBOSE" == "true" ]]; then
        LOG_LEVEL=$LOG_INFO
    fi
    if [[ "$DEBUG" == "true" ]]; then
        LOG_LEVEL=$LOG_DEBUG
    fi

    print_header "${SKYVIEW_NAME} v${SKYVIEW_VERSION}"

    case "$action" in
        help)
            show_help
            ;;
        detect)
            detect_system
            ;;
        install)
            detect_system
            install_packages
            ;;
        configure)
            configure_remote_access
            ;;
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        enable)
            enable_services
            ;;
        disable)
            disable_services
            ;;
        status)
            detect_system
            show_status
            ;;
        verify)
            detect_system
            verify_configuration
            ;;
        *)
            echo "ERROR: Unknown action: $action" >&2
            exit $EXIT_INVALID_ARGS
            ;;
    esac

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        print_box "OPERATION COMPLETE" "Remote access has been configured successfully.\n\nUse --status to check service status." 50
    fi

    exit $exit_code
}

main "$@"
