#!/bin/bash
#
# SkyView Universal Remote Access - OS Detection Module
# Detects Linux distribution, version, package manager, and service manager
#

# Source utility functions
if [[ -z "${LIB_UTILS_SOURCED:-}" ]]; then
    LIB_UTILS_SOURCED=1
    # Try to source utils.sh relative to this script's location
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$lib_dir/utils.sh" ]]; then
        # shellcheck source=utils.sh
        source "$lib_dir/utils.sh"
    fi
fi

# ============================================================================
# OS Information Variables (set by detect_os)
# ============================================================================

# Detected OS family
SKYVIEW_OS_FAMILY=""
SKYVIEW_OS_NAME=""
SKYVIEW_OS_VERSION=""
SKYVIEW_OS_VERSION_ID=""
SKYVIEW_OS_ID_LIKE=""
SKYVIEW_OS_PRETTY_NAME=""

# Package manager
SKYVIEW_PACKAGE_MANAGER=""
SKYVIEW_PACKAGE_CMD=""

# Service manager
SKYVIEW_SERVICE_MANAGER=""

# Architecture
SKYVIEW_ARCH=""

# Supported distributions (from REQUIREMENTS.md)
readonly SUPPORTED_DISTROS=(
    "ubuntu"
    "debian"
    "fedora"
    "rhel"
    "centos"
    "rocky"
    "alma"
    "arch"
    "manjaro"
    "opensuse"
    "neon"
    "pop"
    "mint"
    "void"
    "alpine"
    "gentoo"
)

# ============================================================================
# OS Detection Functions
# ============================================================================

# Detect the operating system and populate all SKYVIEW_OS_* variables
detect_os() {
    log_debug "Starting OS detection..."

    # Reset all variables
    SKYVIEW_OS_FAMILY=""
    SKYVIEW_OS_NAME=""
    SKYVIEW_OS_VERSION=""
    SKYVIEW_OS_VERSION_ID=""
    SKYVIEW_OS_ID_LIKE=""
    SKYVIEW_OS_PRETTY_NAME=""
    SKYVIEW_PACKAGE_MANAGER=""
    SKYVIEW_PACKAGE_CMD=""
    SKYVIEW_SERVICE_MANAGER=""
    SKYVIEW_ARCH=""

    # Detect architecture first
    detect_architecture

    # Primary method: Parse /etc/os-release
    if [[ -f /etc/os-release ]]; then
        parse_os_release
        log_debug "OS detected from /etc/os-release: $SKYVIEW_OS_NAME $SKYVIEW_OS_VERSION"
    fi

    # Fallback: Distribution-specific files
    if [[ -z "$SKYVIEW_OS_NAME" ]]; then
        detect_os_fallback
    fi

    # Detect package manager
    detect_package_manager

    # Detect service manager
    detect_service_manager

    # Validate detection
    if [[ -z "$SKYVIEW_OS_NAME" ]]; then
        log_error "Could not detect operating system"
        return $EXIT_OS_NOT_SUPPORTED
    fi

    # Export for child processes
    export SKYVIEW_OS_FAMILY SKYVIEW_OS_NAME SKYVIEW_OS_VERSION \
           SKYVIEW_OS_VERSION_ID SKYVIEW_OS_ID_LIKE SKYVIEW_OS_PRETTY_NAME \
           SKYVIEW_PACKAGE_MANAGER SKYVIEW_PACKAGE_CMD \
           SKYVIEW_SERVICE_MANAGER SKYVIEW_ARCH

    log_info "OS detected: $SKYVIEW_OS_PRETTY_NAME ($SKYVIEW_PACKAGE_MANAGER, $SKYVIEW_SERVICE_MANAGER)"

    return 0
}

# Detect system architecture
detect_architecture() {
    SKYVIEW_ARCH=$(uname -m 2>/dev/null)

    # Normalize architecture names
    case "$SKYVIEW_ARCH" in
        x86_64)
            SKYVIEW_ARCH="amd64"
            ;;
        aarch64|arm64)
            SKYVIEW_ARCH="arm64"
            ;;
        armv7l|armhf)
            SKYVIEW_ARCH="armhf"
            ;;
    esac

    log_debug "Architecture detected: $SKYVIEW_ARCH"
}

# Parse /etc/os-release for distribution information
parse_os_release() {
    # Source the os-release file safely
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        # Remove leading/trailing quotes from value
        value="${value#\"}"
        value="${value%\"}"

        case "$key" in
            NAME)
                SKYVIEW_OS_NAME="$value"
                ;;
            VERSION)
                SKYVIEW_OS_VERSION="$value"
                ;;
            VERSION_ID)
                SKYVIEW_OS_VERSION_ID="$value"
                ;;
            ID)
                SKYVIEW_OS_NAME="$value"
                ;;
            ID_LIKE)
                SKYVIEW_OS_ID_LIKE="$value"
                ;;
            PRETTY_NAME)
                SKYVIEW_OS_PRETTY_NAME="$value"
                ;;
        esac
    done < /etc/os-release

    # If VERSION_ID is not set but VERSION is, try to extract it
    if [[ -z "$SKYVIEW_OS_VERSION_ID" && -n "$SKYVIEW_OS_VERSION" ]]; then
        SKYVIEW_OS_VERSION_ID=$(echo "$SKYVIEW_OS_VERSION" | grep -oP '^\d+(\.\d+)*' | head -1)
    fi

    # Set family based on ID_LIKE or ID
    if [[ -n "$SKYVIEW_OS_ID_LIKE" ]]; then
        SKYVIEW_OS_FAMILY=$(echo "$SKYVIEW_OS_ID_LIKE" | awk '{print $1}')
    elif [[ -n "$SKYVIEW_OS_NAME" ]]; then
        SKYVIEW_OS_FAMILY="$SKYVIEW_OS_NAME"
    fi

    # If pretty name is not set, construct one
    if [[ -z "$SKYVIEW_OS_PRETTY_NAME" ]]; then
        SKYVIEW_OS_PRETTY_NAME="$SKYVIEW_OS_NAME ${SKYVIEW_OS_VERSION:-}"
    fi
}

# Fallback OS detection for systems without /etc/os-release
detect_os_fallback() {
    # Check for distribution-specific files
    if [[ -f /etc/redhat-release ]]; then
        local content
        content=$(cat /etc/redhat-release 2>/dev/null)
        parse_redhat_release "$content"
    elif [[ -f /etc/debian_version ]]; then
        SKYVIEW_OS_NAME="debian"
        SKYVIEW_OS_VERSION=$(cat /etc/debian_version 2>/dev/null)
        SKYVIEW_OS_FAMILY="debian"
        SKYVIEW_OS_PRETTY_NAME="Debian ${SKYVIEW_OS_VERSION}"
    elif [[ -f /etc/arch-release ]]; then
        SKYVIEW_OS_NAME="arch"
        SKYVIEW_OS_FAMILY="arch"
        SKYVIEW_OS_PRETTY_NAME="Arch Linux"
    elif [[ -f /etc/fedora-release ]]; then
        SKYVIEW_OS_NAME="fedora"
        SKYVIEW_OS_FAMILY="rhel"
        SKYVIEW_OS_PRETTY_NAME="Fedora"
    elif [[ -f /etc/SuSE-release ]]; then
        SKYVIEW_OS_NAME="opensuse"
        SKYVIEW_OS_FAMILY="opensuse"
        SKYVIEW_OS_PRETTY_NAME="openSUSE"
    fi

    # Additional checks via package managers
    if [[ -z "$SKYVIEW_OS_NAME" ]]; then
        if command -v apt-get &>/dev/null; then
            SKYVIEW_OS_FAMILY="debian"
        elif command -v dnf &>/dev/null; then
            SKYVIEW_OS_FAMILY="rhel"
        elif command -v pacman &>/dev/null; then
            SKYVIEW_OS_FAMILY="arch"
        elif command -v zypper &>/dev/null; then
            SKYVIEW_OS_FAMILY="opensuse"
        fi
    fi
}

# Parse Red Hat-style release file
parse_redhat_release() {
    local content="$1"

    if [[ "$content" =~ "Fedora" ]]; then
        SKYVIEW_OS_NAME="fedora"
        SKYVIEW_OS_FAMILY="rhel"
    elif [[ "$content" =~ "CentOS" ]]; then
        SKYVIEW_OS_NAME="centos"
        SKYVIEW_OS_FAMILY="rhel"
    elif [[ "$content" =~ "Rocky" ]]; then
        SKYVIEW_OS_NAME="rocky"
        SKYVIEW_OS_FAMILY="rhel"
    elif [[ "$content" =~ "AlmaLinux" ]]; then
        SKYVIEW_OS_NAME="alma"
        SKYVIEW_OS_FAMILY="rhel"
    elif [[ "$content" =~ "Red Hat" ]]; then
        SKYVIEW_OS_NAME="rhel"
        SKYVIEW_OS_FAMILY="rhel"
    fi

    SKYVIEW_OS_PRETTY_NAME="$content"
    SKYVIEW_OS_VERSION=$(echo "$content" | grep -oP '\d+(\.\d+)*' | head -1)
}

# Detect the available package manager
detect_package_manager() {
    local pkg_manager
    local pkg_cmd

    # Check for available package managers in order of preference
    if command -v apt-get &>/dev/null; then
        pkg_manager="apt"
        pkg_cmd="apt-get"
    elif command -v dnf &>/dev/null; then
        pkg_manager="dnf"
        pkg_cmd="dnf"
    elif command -v yum &>/dev/null; then
        pkg_manager="yum"
        pkg_cmd="yum"
    elif command -v pacman &>/dev/null; then
        pkg_manager="pacman"
        pkg_cmd="pacman"
    elif command -v zypper &>/dev/null; then
        pkg_manager="zypper"
        pkg_cmd="zypper"
    elif command -v xbps-install &>/dev/null; then
        pkg_manager="xbps"
        pkg_cmd="xbps-install"
    elif command -v apk &>/dev/null; then
        pkg_manager="apk"
        pkg_cmd="apk"
    elif command -v emerge &>/dev/null; then
        pkg_manager="emerge"
        pkg_cmd="emerge"
    else
        pkg_manager="unknown"
        pkg_cmd=""
    fi

    SKYVIEW_PACKAGE_MANAGER="$pkg_manager"
    SKYVIEW_PACKAGE_CMD="$pkg_cmd"

    log_debug "Package manager detected: $pkg_manager"
}

# Detect the init system/service manager
detect_service_manager() {
    # Check for systemd (modern systems)
    if [[ -d /run/systemd/system ]] && command -v systemctl &>/dev/null; then
        SKYVIEW_SERVICE_MANAGER="systemd"
        return 0
    fi

    # Check for OpenRC (Gentoo, Alpine, some Debian)
    if [[ -f /etc/init.d/rc ]]; then
        # Additional check for OpenRC
        if command -v rc-service &>/dev/null || [[ -d /run/openrc ]]; then
            SKYVIEW_SERVICE_MANAGER="openrc"
            return 0
        fi
    fi

    # Check for runit (Void Linux)
    if command -v sv &>/dev/null && [[ -d /etc/runit ]]; then
        SKYVIEW_SERVICE_MANAGER="runit"
        return 0
    fi

    # Check for sysvinit (fallback)
    if command -v service &>/dev/null && [[ ! -d /run/systemd/system ]]; then
        SKYVIEW_SERVICE_MANAGER="sysvinit"
        return 0
    fi

    # Default to systemd if we can't determine
    SKYVIEW_SERVICE_MANAGER="unknown"

    log_warn "Could not detect service manager, defaulting to unknown"
}

# ============================================================================
# Distribution Support Check
# ============================================================================

# Check if the detected distribution is supported
is_os_supported() {
    local os_name
    os_name=$(lowercase "$SKYVIEW_OS_NAME")

    for distro in "${SUPPORTED_DISTROS[@]}"; do
        if [[ "$os_name" == "$distro" ]]; then
            log_debug "OS is supported: $SKYVIEW_OS_NAME"
            return 0
        fi
    done

    # Also check ID_LIKE for derivative distributions
    if [[ -n "$SKYVIEW_OS_ID_LIKE" ]]; then
        for distro in "${SUPPORTED_DISTROS[@]}"; do
            if [[ "$SKYVIEW_OS_ID_LIKE" == *"$distro"* ]]; then
                log_debug "OS is supported (via ID_LIKE): $SKYVIEW_OS_NAME ($SKYVIEW_OS_ID_LIKE)"
                return 0
            fi
        done
    fi

    log_warn "OS is not officially supported: $SKYVIEW_OS_NAME"
    return 1
}

# Get support level for the current distribution
get_os_support_level() {
    local os_name
    os_name=$(lowercase "$SKYVIEW_OS_NAME")

    case "$os_name" in
        ubuntu|debian|fedora|rhel|centos|arch|manjaro|opensuse|neon|pop|mint)
            echo "full"
            ;;
        void|alpine|gentoo)
            echo "partial"
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

# ============================================================================
# Package Installation Functions
# ============================================================================

# Get the list of packages to install for a given remote access method
get_packages_for_method() {
    local method="$1"
    local packages=()

    case "$method" in
        xrdp)
            case "$SKYVIEW_PACKAGE_MANAGER" in
                apt)
                    packages=("xrdp" "xorgxrdp")
                    ;;
                dnf|yum)
                    packages=("xrdp")
                    ;;
                pacman)
                    packages=("xrdp")
                    ;;
                zypper)
                    packages=("xrdp")
                    ;;
                *)
                    packages=("xrdp")
                    ;;
            esac
            ;;
        vnc|tigervnc)
            case "$SKYVIEW_PACKAGE_MANAGER" in
                apt)
                    packages=("tigervnc-standalone-server" "tigervnc-common")
                    ;;
                dnf|yum)
                    packages=("tigervnc-server")
                    ;;
                pacman)
                    packages=("tigervnc")
                    ;;
                zypper)
                    packages=("tigervnc")
                    ;;
                xbps)
                    packages=("tigervnc")
                    ;;
                apk)
                    packages=("tigervnc")
                    ;;
                *)
                    packages=("tigervnc")
                    ;;
            esac
            ;;
        gnome-remote-desktop)
            case "$SKYVIEW_PACKAGE_MANAGER" in
                apt)
                    packages=("gnome-remote-desktop")
                    ;;
                dnf|yum)
                    packages=("gnome-remote-desktop")
                    ;;
                pacman)
                    packages=("gnome-remote-desktop")
                    ;;
                *)
                    packages=("gnome-remote-desktop")
                    ;;
            esac
            ;;
        krdp|krfb)
            case "$SKYVIEW_PACKAGE_MANAGER" in
                apt)
                    packages=("krfb" "kde-connect")
                    ;;
                dnf|yum)
                    packages=("krfb" "kde-connect")
                    ;;
                pacman)
                    packages=("krfb" "kdeconnect")
                    ;;
                zypper)
                    packages=("krfb" "kdeconnect5")
                    ;;
                *)
                    packages=("krfb")
                    ;;
            esac
            ;;
        ssh)
            case "$SKYVIEW_PACKAGE_MANAGER" in
                apt)
                    packages=("openssh-server")
                    ;;
                dnf|yum)
                    packages=("openssh-server")
                    ;;
                pacman)
                    packages=("openssh")
                    ;;
                zypper)
                    packages=("openssh")
                    ;;
                *)
                    packages=("openssh")
                    ;;
            esac
            ;;
    esac

    printf '%s\n' "${packages[@]}"
}

# Install a single package with error handling
install_package() {
    local package="$1"
    local cmd

    case "$SKYVIEW_PACKAGE_MANAGER" in
        apt)
            cmd="apt-get install -y --no-install-recommends $package"
            ;;
        dnf)
            cmd="dnf install -y $package"
            ;;
        yum)
            cmd="yum install -y $package"
            ;;
        pacman)
            cmd="pacman -S --noconfirm $package"
            ;;
        zypper)
            cmd="zypper install -y $package"
            ;;
        xbps)
            cmd="xbps-install -y $package"
            ;;
        apk)
            cmd="apk add --no-cache $package"
            ;;
        emerge)
            cmd="emerge --ask=n $package"
            ;;
        *)
            log_error "Unknown package manager: $SKYVIEW_PACKAGE_MANAGER"
            return 1
            ;;
    esac

    log_info "Installing package: $package ($SKYVIEW_PACKAGE_MANAGER)"

    if eval "$cmd" 2>&1; then
        log_debug "Successfully installed: $package"
        return 0
    else
        log_error "Failed to install package: $package"
        return 1
    fi
}

# Install multiple packages
install_packages() {
    local packages=("$@")
    local failed=0

    for package in "${packages[@]}"; do
        if ! install_package "$package"; then
            ((failed++))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        log_error "Failed to install $failed package(s)"
        return 1
    fi

    return 0
}

# ============================================================================
# Service Management Functions
# ============================================================================

# Enable and start a systemd service
manage_systemd_service() {
    local service="$1"
    local action="${2:-enable-start}"

    if ! command -v systemctl &>/dev/null; then
        log_warn "systemctl not available, skipping service management for: $service"
        return 0
    fi

    case "$action" in
        enable-start)
            log_info "Enabling and starting service: $service"
            systemctl enable "$service" 2>/dev/null
            systemctl start "$service" 2>/dev/null
            ;;
        disable-stop)
            log_info "Disabling and stopping service: $service"
            systemctl disable "$service" 2>/dev/null || true
            systemctl stop "$service" 2>/dev/null || true
            ;;
        restart)
            log_info "Restarting service: $service"
            systemctl restart "$service" 2>/dev/null
            ;;
        status)
            systemctl is-active "$service" 2>/dev/null
            return $?
            ;;
    esac

    # Check if service is running
    if systemctl is-active "$service" &>/dev/null; then
        log_debug "Service is active: $service"
        return 0
    else
        log_warn "Service failed to start: $service"
        return 1
    fi
}

# Enable and start an OpenRC service
manage_openrc_service() {
    local service="$1"
    local action="${2:-enable-start}"

    if ! command -v rc-service &>/dev/null; then
        log_warn "rc-service not available, skipping service management for: $service"
        return 0
    fi

    case "$action" in
        enable-start)
            log_info "Enabling and starting service: $service (OpenRC)"
            rc-update add "$service" default 2>/dev/null || true
            rc-service "$service" start 2>/dev/null || true
            ;;
        disable-stop)
            log_info "Disabling and stopping service: $service (OpenRC)"
            rc-update del "$service" default 2>/dev/null || true
            rc-service "$service" stop 2>/dev/null || true
            ;;
        restart)
            log_info "Restarting service: $service (OpenRC)"
            rc-service "$service" restart 2>/dev/null
            ;;
        status)
            rc-service "$service" status 2>/dev/null
            return $?
            ;;
    esac
}

# ============================================================================
# Utility Functions
# ============================================================================

# Print OS detection summary
print_os_summary() {
    print_header "Operating System Detection"

    cat << EOF
Detected OS:      $SKYVIEW_OS_PRETTY_NAME
OS Family:        $SKYVIEW_OS_FAMILY
OS Name:          $SKYVIEW_OS_NAME
OS Version:       $SKYVIEW_OS_VERSION ($SKYVIEW_OS_VERSION_ID)
Architecture:     $SKYVIEW_ARCH
Package Manager:  $SKYVIEW_PACKAGE_MANAGER
Service Manager:  $SKYVIEW_SERVICE_MANAGER
Support Level:    $(get_os_support_level)
EOF
}

# Export OS information as environment file
export_os_info() {
    local output_file="${1:-/tmp/skyview-os-info.env}"

    cat > "$output_file" << EOF
SKYVIEW_OS_FAMILY=$SKYVIEW_OS_FAMILY
SKYVIEW_OS_NAME=$SKYVIEW_OS_NAME
SKYVIEW_OS_VERSION=$SKYVIEW_OS_VERSION
SKYVIEW_OS_VERSION_ID=$SKYVIEW_OS_VERSION_ID
SKYVIEW_OS_ID_LIKE=$SKYVIEW_OS_ID_LIKE
SKYVIEW_OS_PRETTY_NAME=$SKYVIEW_OS_PRETTY_NAME
SKYVIEW_PACKAGE_MANAGER=$SKYVIEW_PACKAGE_MANAGER
SKYVIEW_PACKAGE_CMD=$SKYVIEW_PACKAGE_CMD
SKYVIEW_SERVICE_MANAGER=$SKYVIEW_SERVICE_MANAGER
SKYVIEW_ARCH=$SKYVIEW_ARCH
EOF

    log_debug "OS info exported to: $output_file"
}
