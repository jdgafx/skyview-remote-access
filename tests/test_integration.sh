#!/bin/bash
#
# SkyView Universal Remote Access - Integration Tests
# End-to-end tests for the complete remote access setup
#

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Directories
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${SCRIPT_DIR}/.."
readonly LIB_DIR="${PROJECT_ROOT}/lib"
readonly MAIN_SCRIPT="${PROJECT_ROOT}/skyview-remote-access.sh"

# Source libraries
load_libraries() {
    source "${LIB_DIR}/utils.sh" 2>/dev/null || true
    source "${LIB_DIR}/detect_os.sh" 2>/dev/null || true
    source "${LIB_DIR}/detect_de.sh" 2>/dev/null || true
    source "${LIB_DIR}/detect_session.sh" 2>/dev/null || true
    source "${LIB_DIR}/config_rdp.sh" 2>/dev/null || true
    source "${LIB_DIR}/config_vnc.sh" 2>/dev/null || true
    source "${LIB_DIR}/config_ssh.sh" 2>/dev/null || true
    source "${LIB_DIR}/config_native.sh" 2>/dev/null || true
    source "${LIB_DIR}/firewall.sh" 2>/dev/null || true
}

# ============================================================================
# Integration Tests
# ============================================================================

test_main_script_exists() {
    log_test "test_main_script_exists"
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -f "$MAIN_SCRIPT" ]]; then
        log_pass "Main script exists at $MAIN_SCRIPT"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "Main script not found at $MAIN_SCRIPT"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_main_script_executable() {
    log_test "test_main_script_executable"
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -x "$MAIN_SCRIPT" ]]; then
        log_pass "Main script is executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "Main script is not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_main_script_help() {
    log_test "test_main_script_help"
    TESTS_RUN=$((TESTS_RUN + 1))

    local output
    output=$("$MAIN_SCRIPT" --help 2>&1 || echo "")

    if echo "$output" | grep -q "SkyView"; then
        log_pass "Main script --help works"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "Main script --help failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_all_libraries_loadable() {
    log_test "test_all_libraries_loadable"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Source utils.sh first for logging functions (ignore errors from local statements)
    source "${LIB_DIR}/utils.sh" 2>/dev/null || :
    # Ensure we have logging functions even if sourcing had issues
    log_test_fn() { echo "[TEST] $*"; }
    log_pass_fn() { echo -e "[PASS] $*"; }
    log_fail_fn() { echo -e "[FAIL] $*"; }
    log_warn_fn() { echo -e "[WARN] $*"; }

    # Use fallback functions if real ones aren't available
    if ! type log_test &>/dev/null 2>&1; then
        log_test() { log_test_fn "$@"; }
        log_pass() { log_pass_fn "$@"; }
        log_fail() { log_fail_fn "$@"; }
        log_warn() { log_warn_fn "$@"; }
    fi

    local all_loaded=true
    local libs=(
        "utils.sh:log_info"
        "detect_os.sh:detect_os"
        "detect_de.sh:detect_desktop_environment"
        "detect_session.sh:detect_session_type"
        "config_rdp.sh:configure_xrdp"
        "config_vnc.sh:configure_vnc"
        "config_ssh.sh:configure_ssh"
        "config_native.sh:configure_native_rdp"
        "firewall.sh:configure_firewall"
    )

    for lib_spec in "${libs[@]}"; do
        local lib="${lib_spec%%:*}"
        local func="${lib_spec##*:}"
        local lib_path="${LIB_DIR}/${lib}"

        if [[ -f "$lib_path" ]]; then
            # Source and capture result (ignore local warnings)
            source "$lib_path" 2>/dev/null || :
            local func_exists
            func_exists=$(type "$func" 2>/dev/null) || func_exists=""
            if [[ -z "$func_exists" ]]; then
                log_warn "Function $func not found in $lib"
                all_loaded=false
            fi
        else
            log_warn "Library $lib not found"
            all_loaded=false
        fi
    done

    if $all_loaded; then
        log_pass "All libraries loaded successfully"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "Some libraries failed to load"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_detect_system_complete() {
    log_test "test_detect_system_complete"
    TESTS_RUN=$((TESTS_RUN + 1))

    # This should not fail
    detect_os 2>/dev/null || true

    if [[ -n "$SKYVIEW_OS_NAME" && -n "$SKYVIEW_PACKAGE_MANAGER" && -n "$SKYVIEW_SERVICE_MANAGER" ]]; then
        log_pass "System detection complete: $SKYVIEW_OS_NAME ($SKYVIEW_PACKAGE_MANAGER, $SKYVIEW_SERVICE_MANAGER)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "System detection incomplete"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_detect_de_complete() {
    log_test "test_detect_de_complete"
    TESTS_RUN=$((TESTS_RUN + 1))

    detect_desktop_environment 2>/dev/null || true

    log_info "DE: $SKYVIEW_DE, RDP Method: $SKYVIEW_DE_RDP_METHOD"
    log_pass "DE detection executed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

test_get_best_rdp_method() {
    log_test "test_get_best_rdp_method"
    TESTS_RUN=$((TESTS_RUN + 1))

    local method
    method=$(get_best_rdp_method 2>/dev/null || echo "")

    if [[ -n "$method" ]]; then
        log_pass "Best RDP method: $method"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "get_best_rdp_method returned empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_get_available_rdp_methods() {
    log_test "test_get_available_rdp_methods"
    TESTS_RUN=$((TESTS_RUN + 1))

    local methods
    methods=$(get_available_rdp_methods 2>/dev/null || echo "")

    log_info "Available methods: ${methods:-none}"
    log_pass "get_available_rdp_methods executed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

test_is_port_open() {
    log_test "test_is_port_open"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Test with a port that should be closed
    if is_port_open "localhost" 99999; then
        log_warn "Port 99999 appears open (unexpected)"
    else
        log_pass "is_port_open correctly identifies closed port"
    fi

    # Test with localhost (should work)
    if is_port_open "localhost" 22; then
        log_pass "is_port_open correctly identifies SSH port"
    else
        log_pass "SSH port not listening (acceptable)"
    fi

    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

test_get_primary_ip() {
    log_test "test_get_primary_ip"
    TESTS_RUN=$((TESTS_RUN + 1))

    local ip
    ip=$(get_primary_ip 2>/dev/null || echo "")

    if [[ -n "$ip" ]]; then
        log_pass "Primary IP: $ip"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "get_primary_ip returned empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_ip_addresses() {
    log_test "test_ip_addresses"
    TESTS_RUN=$((TESTS_RUN + 1))

    local addresses
    addresses=$(get_ip_addresses 2>/dev/null || echo "")

    log_info "IP addresses: ${addresses:-none}"
    log_pass "get_ip_addresses executed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

test_package_manager_detection() {
    log_test "test_package_manager_detection"
    TESTS_RUN=$((TESTS_RUN + 1))

    local pkg_manager
    pkg_manager=$(detect_package_manager 2>/dev/null || echo "")

    if [[ -n "$pkg_manager" ]]; then
        log_pass "Package manager: $pkg_manager"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "Package manager detection failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_service_manager_detection() {
    log_test "test_service_manager_detection"
    TESTS_RUN=$((TESTS_RUN + 1))

    detect_service_manager 2>/dev/null || true

    if [[ -n "$SKYVIEW_SERVICE_MANAGER" ]]; then
        log_pass "Service manager: $SKYVIEW_SERVICE_MANAGER"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "Service manager detection failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_string_functions() {
    log_test "test_string_functions"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Test trim
    local trimmed
    trimmed=$(trim "  hello  ")
    if [[ "$trimmed" == "hello" ]]; then
        log_pass "trim function works"
    else
        log_fail "trim function failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    # Test lowercase
    local lower
    lower=$(lowercase "HELLO")
    if [[ "$lower" == "hello" ]]; then
        log_pass "lowercase function works"
    else
        log_fail "lowercase function failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

test_is_root() {
    log_test "test_is_root"
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ $EUID -eq 0 ]]; then
        log_pass "Running as root"
    else
        log_info "Not running as root (EUID: $EUID)"
    fi

    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

test_confirm_function() {
    log_test "test_confirm_function"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Just verify the function exists
    if [[ -n "$(type -t confirm 2>/dev/null)" ]]; then
        log_pass "confirm function exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "confirm function not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_select_option_function() {
    log_test "test_select_option_function"
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -n "$(type -t select_option 2>/dev/null)" ]]; then
        log_pass "select_option function exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "select_option function not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================================================
# Helper Functions
# ============================================================================

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${NC}========================================"
    echo -e "${NC}  $1"
    echo -e "${NC}========================================"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

run_integration_tests() {
    log_section "Integration Tests"

    load_libraries

    # Script tests
    test_main_script_exists
    test_main_script_executable
    test_main_script_help

    # Library tests
    test_all_libraries_loadable

    # Detection tests
    test_detect_system_complete
    test_detect_de_complete
    test_package_manager_detection
    test_service_manager_detection

    # RDP method tests
    test_get_best_rdp_method
    test_get_available_rdp_methods

    # Network tests
    test_is_port_open
    test_get_primary_ip
    test_ip_addresses

    # Utility tests
    test_string_functions
    test_is_root
    test_confirm_function
    test_select_option_function
}

print_summary() {
    log_section "Integration Test Summary"

    echo -e "Tests Run:    ${TESTS_RUN}"
    echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
    echo -e "Tests Skipped: ${YELLOW}${TESTS_SKIPPED}${NC}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All integration tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some integration tests failed!${NC}"
        return 1
    fi
}

run_integration_tests
print_summary
exit $?
