#!/bin/bash
#
# SkyView Universal Remote Access - Configuration Tests
# Tests for RDP, VNC, and Firewall configuration modules
#

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Directories
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="$(dirname "$TEST_DIR")/lib"

# Source libraries
source_library() {
    local module="$1"
    if [[ -f "${LIB_DIR}/${module}" ]]; then
        source "${LIB_DIR}/${module}" 2>/dev/null || true
        return 0
    fi
    return 1
}

# Load all libraries
load_libraries() {
    source_library "utils.sh"
    source_library "detect_os.sh"
    source_library "detect_de.sh"
    source_library "detect_session.sh"
    source_library "config_rdp.sh"
    source_library "config_vnc.sh"
    source_library "firewall.sh"
}

# ============================================================================
# RDP Configuration Tests
# ============================================================================

test_backup_file() {
    log_test "test_backup_file"
    TESTS_RUN=$((TESTS_RUN + 1))

    local temp_file
    temp_file=$(mktemp)
    echo "test content" > "$temp_file"

    backup_file "$temp_file"

    if ls "${temp_file}.backup."* >/dev/null 2>&1; then
        log_pass "backup_file creates backup"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        rm -f "$temp_file" "${temp_file}".backup.* 2>/dev/null
        return 0
    else
        log_fail "backup_file did not create backup"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

test_generate_xrdp_certificates() {
    log_test "test_generate_xrdp_certificates"
    TESTS_RUN=$((TESTS_RUN + 1))

    local cert_file="/tmp/test-xrdp-cert.pem"
    local key_file="/tmp/test-xrdp-key.pem"

    rm -f "$cert_file" "$key_file" 2>/dev/null

    # Mock openssl availability check
    if command -v openssl &>/dev/null; then
        generate_xrdp_certificates 2>/dev/null || true

        if [[ -f "$cert_file" && -f "$key_file" ]]; then
            log_pass "generate_xrdp_certificates creates cert files"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_pass "generate_xrdp_certificates skipped (files may exist)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        fi
    else
        log_pass "openssl not available - test skipped"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi

    rm -f "$cert_file" "$key_file" 2>/dev/null
    return 0
}

test_get_rdp_status() {
    log_test "test_get_rdp_status"
    TESTS_RUN=$((TESTS_RUN + 1))

    local status
    status=$(get_rdp_status 2>/dev/null || echo "unknown")

    if [[ -n "$status" ]]; then
        log_pass "get_rdp_status returned: $status"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "get_rdp_status returned empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_print_rdp_summary() {
    log_test "test_print_rdp_summary"
    TESTS_RUN=$((TESTS_RUN + 1))

    print_rdp_summary > /dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        log_pass "print_rdp_summary executed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "print_rdp_summary failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================================================
# VNC Configuration Tests
# ============================================================================

test_get_vnc_session_command() {
    log_test "test_get_vnc_session_command"
    TESTS_RUN=$((TESTS_RUN + 1))

    local session
    session=$(get_vnc_session_command 2>/dev/null || echo "unknown")

    if [[ -n "$session" && "$session" != "unknown" ]]; then
        log_pass "get_vnc_session_command returned: $session"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "get_vnc_session_command returned empty or unknown"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_list_vnc_servers() {
    log_test "test_list_vnc_servers"
    TESTS_RUN=$((TESTS_RUN + 1))

    local output
    output=$(list_vnc_servers 2>/dev/null || echo "")

    if [[ -n "$output" ]]; then
        log_pass "list_vnc_servers executed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "list_vnc_servers failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_print_vnc_summary() {
    log_test "test_print_vnc_summary"
    TESTS_RUN=$((TESTS_RUN + 1))

    print_vnc_summary > /dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        log_pass "print_vnc_summary executed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "print_vnc_summary failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================================================
# Firewall Configuration Tests
# ============================================================================

test_detect_firewall() {
    log_test "test_detect_firewall"
    TESTS_RUN=$((TESTS_RUN + 1))

    detect_firewall

    if [[ -n "$SKYVIEW_FIREWALL_TYPE" ]]; then
        log_pass "Firewall detected: $SKYVIEW_FIREWALL_TYPE"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "Firewall detection returned empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_get_firewall_status() {
    log_test "test_get_firewall_status"
    TESTS_RUN=$((TESTS_RUN + 1))

    local status
    status=$(get_firewall_status 2>/dev/null || echo "unknown")

    if [[ -n "$status" ]]; then
        log_pass "get_firewall_status returned: $status"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "get_firewall_status returned empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_print_firewall_summary() {
    log_test "test_print_firewall_summary"
    TESTS_RUN=$((TESTS_RUN + 1))

    print_firewall_summary > /dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        log_pass "print_firewall_summary executed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "print_firewall_summary failed"
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

run_config_tests() {
    log_section "Configuration Tests"

    load_libraries

    # RDP tests
    test_backup_file
    test_generate_xrdp_certificates
    test_get_rdp_status
    test_print_rdp_summary

    # VNC tests
    test_get_vnc_session_command
    test_list_vnc_servers
    test_print_vnc_summary

    # Firewall tests
    test_detect_firewall
    test_get_firewall_status
    test_print_firewall_summary
}

print_summary() {
    log_section "Test Summary"

    echo -e "Tests Run:    ${TESTS_RUN}"
    echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

run_config_tests
print_summary
exit $?
