#!/usr/bin/env bash
# Master test runner for upstash-keepalive workflow tests
# Runs all test suites and reports results

set -eo pipefail

echo "=========================================="
echo "Upstash Keep-Alive Workflow Test Suite"
echo "=========================================="
echo ""

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_PASSED=0
TOTAL_FAILED=0
SUITE_FAILURES=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

run_test_suite() {
    local name="$1"
    local command="$2"

    echo -e "${BLUE}Running: $name${NC}"
    echo "----------------------------------------"

    if eval "$command"; then
        echo -e "${GREEN}✓ $name passed${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ $name failed${NC}"
        echo ""
        SUITE_FAILURES=$((SUITE_FAILURES + 1))
        return 1
    fi
}

# Test Suite 1: Bash Logic Tests
run_test_suite "Bash Logic Tests" "bash '$TESTS_DIR/test_bash_logic.sh'"

# Test Suite 2: YAML Validation Tests
run_test_suite "YAML Validation Tests" "bash '$TESTS_DIR/test_workflow_yaml.sh'"

# Test Suite 3: GitHub Script Tests
run_test_suite "GitHub Script Tests" "node '$TESTS_DIR/test_github_script.js'"

# Test Suite 4: Integration Tests
run_test_suite "Integration Tests" "bash '$TESTS_DIR/test_integration.sh'"

# Summary
echo "=========================================="
echo "Overall Test Results"
echo "=========================================="
echo ""
echo "Test Suites Run: 4"
echo "Test Suites Passed: $((4 - SUITE_FAILURES))"
echo "Test Suites Failed: $SUITE_FAILURES"
echo ""

if [ $SUITE_FAILURES -eq 0 ]; then
    echo -e "${GREEN}✓ All test suites passed!${NC}"
    echo ""
    echo "Coverage Summary:"
    echo "  - Bash Logic: 48 tests (secret validation, retry logic, validation patterns, etc.)"
    echo "  - YAML Structure: 35 tests (workflow structure, triggers, steps, security, etc.)"
    echo "  - GitHub Script: 15 tests (workflow auto-enable logic, edge cases, etc.)"
    echo "  - Integration: 20 tests (end-to-end behavior, security, consistency, etc.)"
    echo "  - Total: 118 comprehensive tests"
    exit 0
else
    echo -e "${RED}✗ $SUITE_FAILURES test suite(s) failed${NC}"
    exit 1
fi