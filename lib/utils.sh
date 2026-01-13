#!/bin/bash
#
# SkyView Universal Remote Access - Utility Functions
# Provides common functions used across all modules
#

# ============================================================================
# Logging Functions
# ============================================================================

# Log levels (only define if not already defined)
if [[ -z "${LOG_DEBUG:-}" ]]; then
  readonly LOG_DEBUG=0
  readonly LOG_INFO=1
  readonly LOG_WARN=2
  readonly LOG_ERROR=3
fi

# Current log level (default: INFO)
LOG_LEVEL="${LOG_LEVEL:-1}"

# Color codes for terminal output (only define if not already defined)
if [[ -z "${COLOR_RESET:-}" ]]; then
  readonly COLOR_RED='\033[0;31m'
  readonly COLOR_GREEN='\033[0;32m'
  readonly COLOR_YELLOW='\033[0;33m'
  readonly COLOR_BLUE='\033[0;34m'
  readonly COLOR_CYAN='\033[0;36m'
  readonly COLOR_WHITE='\033[1;37m'
  readonly COLOR_RESET='\033[0m'
  readonly COLOR_BOLD='\033[1m'
fi

# Check if terminal supports colors
supports_color() {
    if [[ -t 1 ]]; then
        if command -v tput &>/dev/null && tput colors &>/dev/null; then
            [[ $(tput colors) -ge 8 ]] && return 0
        fi
    fi
    return 1
}

# Get timestamp in ISO 8601 format
timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

# Log message with level and color
log_message() {
    local level="$1"
    local message="$2"
    local color="$3"

    # Skip if below log level threshold
    [[ $level -lt $LOG_LEVEL ]] && return

    local timestamp_str
    timestamp_str=$(timestamp)

    # Format based on whether colors are supported
    if supports_color; then
        echo -e "${color}[${timestamp_str}] [${level^^}] ${message}${COLOR_RESET}"
    else
        echo "[${timestamp_str}] [${level^^}] ${message}"
    fi

    # Also write to log file if configured
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp_str}] [${level^^}] ${message}" >> "$LOG_FILE"
    fi
}

# Convenience logging functions
log_debug() {
    log_message "$LOG_DEBUG" "$1" "${COLOR_BLUE}"
}

log_info() {
    log_message "$LOG_INFO" "$1" "${COLOR_GREEN}"
}

log_warn() {
    log_message "$LOG_WARN" "$1" "${COLOR_YELLOW}"
}

log_error() {
    log_message "$LOG_ERROR" "$1" "${COLOR_RED}"
}

# Print formatted header
print_header() {
    local title="$1"
    local width="${2:-60}"
    local char="${3:-=}"

    if supports_color; then
        echo -e "\n${COLOR_BOLD}${COLOR_CYAN}"
    fi

    echo "$char" repeated "$width"
    echo " $title "
    echo "$char" repeated "$width"

    if supports_color; then
        echo -e "${COLOR_RESET}\n"
    fi
}

# Print formatted box
print_box() {
    local title="$1"
    local content="$2"
    local width="${3:-50}"

    if supports_color; then
        echo -e "${COLOR_BOLD}${COLOR_WHITE}"
    fi

    echo "╔$(printf '═%.0s' $(seq 1 $((width - 2))))╗"
    printf "║ %-$((width - 3))s ║\n" "$title"
    echo "╠$(printf '═%.0s' $(seq 1 $((width - 2))))╣"

    while IFS= read -r line; do
        printf "║ %-$((width - 3))s ║\n" "$line"
    done <<< "$content"

    echo "╚$(printf '═%.0s' $(seq 1 $((width - 2))))╝"

    if supports_color; then
        echo -e "${COLOR_RESET}"
    fi
}

# ============================================================================
# String Functions
# ============================================================================

# Trim whitespace from string
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# Convert string to lowercase
lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Convert string to uppercase
uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Check if string starts with prefix
startswith() {
    [[ "$1" == "$2"* ]]
}

# Check if string ends with suffix
endswith() {
    [[ "$1" == *"$2" ]]
}

# Check if string contains substring
contains() {
    [[ "$1" == *"$2"* ]]
}

# Split string by delimiter into array
split() {
    local delimiter="$1"
    local string="$2"
    local -n result="$3"

    IFS="$delimiter" read -ra result <<< "$string"
}

# Join array elements with delimiter
join() {
    local delimiter="$1"
    shift
    local -a args=("$@")

    local result=""
    local first=true
    for arg in "${args[@]}"; do
        if $first; then
            result="$arg"
            first=false
        else
            result="${result}${delimiter}${arg}"
        fi
    done

    echo -n "$result"
}

# ============================================================================
# File Functions
# ============================================================================

# Check if file exists and is readable
file_exists() {
    [[ -f "$1" && -r "$1" ]]
}

# Check if directory exists
dir_exists() {
    [[ -d "$1" ]]
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        if mkdir -p "$dir" 2>/dev/null; then
            log_debug "Created directory: $dir"
            return 0
        else
            log_error "Failed to create directory: $dir"
            return 1
        fi
    fi

    return 0
}

# Get file size in bytes
file_size() {
    stat -c%s "$1" 2>/dev/null || echo 0
}

# Get file size in human-readable format
file_size_human() {
    local size
    size=$(file_size "$1")

    if [[ $size -ge 1073741824 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1073741824}")GB"
    elif [[ $size -ge 1048576 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1048576}")MB"
    elif [[ $size -ge 1024 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1024}")KB"
    else
        echo "${size}B"
    fi
}

# Read file and trim lines
read_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        echo "$line"
    done < "$file"
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Require root privileges
require_root() {
    if ! is_root; then
        log_error "This operation requires root privileges. Please run with sudo."
        return 1
    fi
    return 0
}

# ============================================================================
# Network Functions
# ============================================================================

# Check if a port is open
is_port_open() {
    local host="${1:-localhost}"
    local port="$2"

    if command -v nc &>/dev/null; then
        nc -z -w 2 "$host" "$port" 2>/dev/null
        return $?
    elif command -v timeout &>/dev/null && command -v bash &>/dev/null; then
        timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
        return $?
    else
        # Fallback: use /dev/tcp directly
        (echo >/dev/tcp/"$host"/"$port") 2>/dev/null
        return $?
    fi
}

# Get IP addresses of the system
get_ip_addresses() {
    local addresses=()

    # Get all IPv4 addresses
    while IFS= read -r ip; do
        [[ -n "$ip" ]] && addresses+=("$ip")
    done < <(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.')

    # Get all IPv6 addresses
    while IFS= read -r ip; do
        [[ -n "$ip" ]] && addresses+=("$ip")
    done < <(ip -6 addr show 2>/dev/null | grep -oP '(?<=inet6\s)[a-f0-9:]+' | grep -v '^::1')

    printf '%s\n' "${addresses[@]}"
}

# Get primary IP address (non-loopback)
get_primary_ip() {
    local primary_ip=""

    # Try to get the IP used for external connections
    if command -v ip &>/dev/null; then
        primary_ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP '(?<=src\s)\d+(\.\d+){3}' | head -1)
    fi

    # Fallback: get first non-loopback IPv4
    if [[ -z "$primary_ip" ]]; then
        primary_ip=$(get_ip_addresses | head -1)
    fi

    echo -n "${primary_ip:-127.0.0.1}"
}

# Check if hostname resolves
check_hostname_resolution() {
    local hostname="$1"

    if getent hosts "$hostname" &>/dev/null; then
        return 0
    elif getent ahostsv4 "$hostname" &>/dev/null; then
        return 0
    fi

    return 1
}

# ============================================================================
# Process Functions
# ============================================================================

# Check if a process is running
is_process_running() {
    local pid="$1"

    if [[ -d "/proc/$pid" ]]; then
        return 0
    elif kill -0 "$pid" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Get PID by process name
get_pid_by_name() {
    local name="$1"
    pgrep -x "$name" 2>/dev/null
}

# Check if a service is active/running
is_service_active() {
    local service="$1"

    if command -v systemctl &>/dev/null; then
        systemctl is-active "$service" &>/dev/null
        return $?
    elif command -v service &>/dev/null; then
        service "$service" status &>/dev/null
        return $?
    fi

    return 1
}

# Check if a service is enabled
is_service_enabled() {
    local service="$1"

    if command -v systemctl &>/dev/null; then
        systemctl is-enabled "$service" &>/dev/null
        return $?
    fi

    return 1
}

# ============================================================================
# Package Manager Functions
# ============================================================================

# Detect available package manager
detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v xbps-install &>/dev/null; then
        echo "xbps"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v emerge &>/dev/null; then
        echo "emerge"
    else
        echo "unknown"
    fi
}

# Check if package is installed
is_package_installed() {
    local package="$1"
    local pkg_manager
    pkg_manager=$(detect_package_manager)

    case "$pkg_manager" in
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        dnf|yum)
            rpm -q "$package" &>/dev/null
            ;;
        pacman)
            pacman -Q "$package" &>/dev/null
            ;;
        zypper)
            rpm -q "$package" &>/dev/null
            ;;
        xbps)
            xbps-query "$package" &>/dev/null
            ;;
        apk)
            apk info -e "$package" &>/dev/null
            ;;
        emerge)
            emerge -pv "$package" 2>/dev/null | grep -q "Total"
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# User Interaction Functions
# ============================================================================

# Ask user for confirmation (yes/no)
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    local valid_responses
    local response

    if [[ "$default" == "y" ]]; then
        valid_responses="[Y/n]"
    else
        valid_responses="[y/N]"
    fi

    while true; do
        read -r -p "$prompt $valid_responses: " response

        case "${response,,}" in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            "")
                if [[ "$default" == "y" ]]; then
                    return 0
                else
                    return 1
                fi
                ;;
            *)
                echo "Please enter 'y' or 'n'"
                ;;
        esac
    done
}

# Prompt user for input with default value
prompt() {
    local prompt="$1"
    local default="$2"
    local validation_regex="$3"

    while true; do
        read -r -p "$prompt" response

        # Use default if empty
        [[ -z "$response" ]] && response="$default"

        # Validate if regex provided
        if [[ -n "$validation_regex" ]]; then
            if [[ ! "$response" =~ $validation_regex ]]; then
                echo "Invalid input. Please try again."
                continue
            fi
        fi

        echo -n "$response"
        return 0
    done
}

# Select from a list of options
select_option() {
    local title="$1"
    shift
    local options=("$@")

    local num_options=${#options[@]}

    echo "$title"
    echo ""

    for i in "${!options[@]}"; do
        echo "$((i + 1))) ${options[$i]}"
    done
    echo ""

    while true; do
        read -r -p "Enter choice (1-$num_options): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -le $num_options ]]; then
            echo -n "$choice"
            return 0
        fi

        echo "Invalid choice. Please enter a number between 1 and $num_options."
    done
}

# ============================================================================
# Template Functions
# ============================================================================

# Render a template file with variables
render_template() {
    local template_file="$1"
    shift
    local -A variables=("$@")

    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        return 1
    fi

    local content
    content=$(cat "$template_file")

    # Replace all placeholders
    for key in "${!variables[@]}"; do
        local value="${variables[$key]}"
        # Replace ${VAR_NAME} and $VAR_NAME patterns
        content="${content//\$\{$key\}/$value}"
        content="${content//\$$key/$value}"
    done

    echo "$content"
}

# ============================================================================
# Exit Code Definitions
# ============================================================================

# Exit codes as defined in REQUIREMENTS.md (only define if not already defined)
if [[ -z "${EXIT_SUCCESS:-}" ]]; then
  readonly EXIT_SUCCESS=0
  readonly EXIT_GENERAL_ERROR=1
  readonly EXIT_INVALID_ARGS=2
  readonly EXIT_OS_NOT_SUPPORTED=10
  readonly EXIT_DESKTOP_NOT_SUPPORTED=11
  readonly EXIT_SESSION_NOT_SUPPORTED=12
  readonly EXIT_PACKAGE_INSTALL_FAILED=20
  readonly EXIT_SERVICE_START_FAILED=21
  readonly EXIT_CONFIG_VERIFICATION_FAILED=22
  readonly EXIT_PERMISSION_DENIED=30
fi
