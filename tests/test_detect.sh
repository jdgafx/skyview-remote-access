#!/bin/bash
#
# SkyView Universal Remote Access - OS Detection Tests
# Tests for lib/detect_os.sh
#

set -euo pipefail

# Colors for test output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="$(dirname "$TEST_DIR")/lib"

# Source the library
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

# Test functions
test_source_library() {
    log_test "test_source_library"
    TESTS_RUN=$((TESTS_RUN + 1))

    if source_library "utils.sh" && source_library "detect_os.sh"; then
        log_pass "Library sourcing works"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "Library sourcing failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_detect_architecture() {
    log_test "test_detect_architecture"
    TESTS_RUN=$((TESTS_RUN + 1))

    detect_architecture

    if [[ -n "$SKYVIEW_ARCH" ]]; then
        log_pass "Architecture detected: $SKYVIEW_ARCH"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "Architecture detection returned empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_detect_package_manager() {
    log_test "test_detect_package_manager"
    TESTS_RUN=$((TESTS_RUN + 1))

    detect_package_manager

    if [[ -n "$SKYVIEW_PACKAGE_MANAGER" ]]; then
        log_pass "Package manager detected: $SKYVIEW_PACKAGE_MANAGER"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "Package manager detection returned empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_detect_service_manager() {
    log_test "test_detect_service_manager"
    TESTS_RUN=$((TESTS_RUN + 1))

    detect_service_manager

    if [[ -n "$SKYVIEW_SERVICE_MANAGER" ]]; then
        log_pass "Service manager detected: $SKYVIEW_SERVICE_MANAGER"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "Service manager detection returned empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_get_packages_for_method_xrdp() {
    log_test "test_get_packages_for_method_xrdp"
    TESTS_RUN=$((TESTS_RUN + 1))

    local packages
    packages=$(get_packages_for_method "xrdp")

    if [[ -n "$packages" ]]; then
        log_pass "xrdp packages: $packages"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "get_packages_for_method xrdp returned empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_get_packages_for_method_vnc() {
    log_test "test_get_packages_for_method_vnc"
    TESTS_RUN=$((TESTS_RUN + 1))

    local packages
    packages=$(get_packages_for_method "vnc")

    if [[ -n "$packages" ]]; then
        log_pass "VNC packages: $packages"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "get_packages_for_method vnc returned empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_is_package_installed() {
    log_test "test_is_package_installed"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Test with a package that should exist
    is_package_installed "bash"
    local result=$?

    if [[ $result -eq 0 ]]; then
        log_pass "is_package_installed bash: true"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "is_package_installed bash: false (unexpected)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_get_os_support_level() {
    log_test "test_get_os_support_level"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Detect OS first
    detect_os || true

    local level
    level=$(get_os_support_level)

    if [[ -n "$level" ]]; then
        log_pass "Support level for $SKYVIEW_OS_NAME: $level"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "get_os_support_level returned empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_print_os_summary() {
    log_test "test_print_os_summary"
    TESTS_RUN=$((TESTS_RUN + 1))

    # This should not fail
    print_os_summary > /dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        log_pass "print_os_summary executed successfully"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "print_os_summary failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_export_os_info() {
    log_test "test_export_os_info"
    TESTS_RUN=$((TESTS_RUN + 1))

    local temp_file
    temp_file=$(mktemp)

    export_os_info "$temp_file"

    if [[ -f "$temp_file" ]]; then
        log_pass "export_os_info created file"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        rm -f "$temp_file"
        return 0
    else
        log_fail "export_os_info did not create file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Helper functions
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

# Main test runner
run_os_detection_tests() {
    log_section "OS Detection Tests"

    test_source_library
    test_detect_architecture
    test_detect_package_manager
    test_detect_service_manager
    test_get_packages_for_method_xrdp
    test_get_packages_for_method_vnc
    test_is_package_installed
    test_get_os_support_level
    test_print_os_summary
    test_export_os_info
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

# Run tests
run_os_detection_tests
print_summary
exit $?
