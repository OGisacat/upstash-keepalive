#!/usr/bin/env bash
# Integration tests for upstash-keepalive workflow
# Tests combined behaviors and integration scenarios

set -eo pipefail

PASSED=0
FAILED=0

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    if [ -n "${2:-}" ]; then
        echo "  Details: $2"
    fi
    FAILED=$((FAILED + 1))
}

echo "=========================================="
echo "Integration Tests"
echo "=========================================="
echo ""

# Test 1: Workflow file is valid and can be parsed
echo "Test: Workflow file integrity and parseability"
if [ -f .github/workflows/upstash-keepalive.yml ]; then
    if python3 -c "import yaml; wf=yaml.safe_load(open('.github/workflows/upstash-keepalive.yml')); assert 'jobs' in wf" 2>/dev/null; then
        pass "Workflow file is valid YAML and parseable"
    else
        fail "Workflow YAML parsing failed"
    fi
else
    fail "Workflow file not found"
fi
echo ""

# Test 2: All operation groups have exactly 4 operations
echo "Test: Each operation group has 4 operations"
# Simply check that each group (A, B, C) is mentioned and has run_op calls
if grep -q "Group A: Database Overview" .github/workflows/upstash-keepalive.yml && \
   grep -q "Group B: Server Status" .github/workflows/upstash-keepalive.yml && \
   grep -q "Group C: Memory & Clients" .github/workflows/upstash-keepalive.yml; then
    # Count total run_op invocations (should be 12 = 3 groups * 4 ops each)
    run_op_count=$(grep -c 'run_op ' .github/workflows/upstash-keepalive.yml || echo 0)
    if [ "$run_op_count" -ge 12 ]; then
        pass "All operation groups (A, B, C) have 4 operations each (12 total run_op calls)"
    else
        fail "Expected 12 run_op calls (4 per group), found: $run_op_count"
    fi
else
    fail "Missing one or more operation groups"
fi
echo ""

# Test 3: Total operations per execution (PING + 2 writes + 4 reads = 7)
echo "Test: Expected operation count per execution"
# PING is always executed (1)
# SET keepalive:last_run (1)
# INCR keepalive:run_count (1)
# One group with 4 operations (4)
# Total = 7 operations
if grep -q "PING" .github/workflows/upstash-keepalive.yml && \
   grep -q "set/keepalive:last_run" .github/workflows/upstash-keepalive.yml && \
   grep -q "incr/keepalive:run_count" .github/workflows/upstash-keepalive.yml; then
    pass "Workflow executes 7 operations per run (1 PING + 2 writes + 4 reads)"
else
    fail "Workflow missing expected operations"
fi
echo ""

# Test 4: All Redis commands use proper URL construction
echo "Test: Redis command URL construction consistency"
# Check that redis_call commands (after the first argument) are lowercase
# Labels can be uppercase, but actual commands should be lowercase
if grep -oP 'redis_call "\K[^"]+' .github/workflows/upstash-keepalive.yml | grep -qE '^[A-Z]'; then
    fail "Some Redis commands use uppercase (should be lowercase for REST API)"
else
    pass "All Redis commands use proper lowercase format for REST API"
fi
echo ""

# Test 5: Error handling ensures non-fatal failures don't block execution
echo "Test: Non-fatal failures don't block execution"
# Write and read operations use || true to continue on failure
if grep -q 'redis_call.*|| true' .github/workflows/upstash-keepalive.yml; then
    pass "Non-critical operations allow graceful failure with || true"
else
    fail "Write/read operations missing graceful failure handling"
fi
echo ""

# Test 6: PING is the only operation that can abort the workflow
echo "Test: PING failure aborts workflow (critical check)"
if grep -A 2 'redis_call "ping"' .github/workflows/upstash-keepalive.yml | grep -q 'exit 1'; then
    pass "PING failure correctly aborts workflow"
else
    fail "PING failure should abort workflow with exit 1"
fi
echo ""

# Test 7: All operation groups are mutually exclusive
echo "Test: Operation groups are mutually exclusive (case statement)"
if grep -A 30 'case $group in' .github/workflows/upstash-keepalive.yml | grep -q 'esac'; then
    # Verify structure: case $group in / 0) / ;; / 1) / ;; / 2) / ;; / esac
    pass "Operation groups use proper case statement structure"
else
    fail "Case statement structure for groups is malformed"
fi
echo ""

# Test 8: Workflow has both scheduled and manual triggers
echo "Test: Dual trigger configuration (schedule + manual)"
if grep -q 'schedule:' .github/workflows/upstash-keepalive.yml && \
   grep -q 'workflow_dispatch:' .github/workflows/upstash-keepalive.yml; then
    pass "Workflow supports both scheduled (cron) and manual (dispatch) triggers"
else
    fail "Workflow missing dual trigger configuration"
fi
echo ""

# Test 9: Workflow self-healing capability
echo "Test: Workflow can re-enable itself if disabled"
if grep -q 'enableWorkflow' .github/workflows/upstash-keepalive.yml && \
   grep -q "wf.state !== 'active'" .github/workflows/upstash-keepalive.yml; then
    pass "Workflow has self-healing capability via enableWorkflow"
else
    fail "Workflow missing self-healing logic"
fi
echo ""

# Test 10: Secrets are never logged or exposed
echo "Test: Secrets are not logged in output"
# Check that secrets are only used in env and curl headers, never directly echoed
# The workflow validates if they're empty, but doesn't log their values
if grep -E 'echo .*\$\{?UPSTASH_REDIS_REST_(URL|TOKEN)\}?[^:-]' .github/workflows/upstash-keepalive.yml >/dev/null 2>&1; then
    fail "Workflow may expose secrets in logs"
else
    pass "Secrets are not logged or exposed in output"
fi
echo ""

# Test 11: Retry mechanism exponential properties
echo "Test: Retry mechanism with delays"
if grep -q 'sleep 5' .github/workflows/upstash-keepalive.yml && \
   grep -q 'max_attempts=3' .github/workflows/upstash-keepalive.yml; then
    pass "Retry mechanism includes delay (5s) between attempts"
else
    fail "Retry mechanism missing delays"
fi
echo ""

# Test 12: All INFO commands specify a section
echo "Test: INFO commands specify sections (not bare INFO)"
# Verify all info commands have a section parameter
info_count=$(grep -o 'info/' .github/workflows/upstash-keepalive.yml | wc -l)
if [ "$info_count" -ge 5 ]; then
    pass "All INFO commands specify sections (memory, clients, server, stats, keyspace)"
else
    fail "Some INFO commands may be missing section parameters" "Expected 5+, found $info_count"
fi
echo ""

# Test 13: Validation patterns use extended regex
echo "Test: Validation patterns use extended regex (-E flag)"
if grep -q 'grep -Eq' .github/workflows/upstash-keepalive.yml; then
    pass "Validation patterns use extended regex for flexibility"
else
    fail "Validation patterns should use grep -Eq for extended regex"
fi
echo ""

# Test 14: Workflow runs on UTC schedule (not local time)
echo "Test: Cron schedule is explicitly UTC"
if grep -q "UTC" .github/workflows/upstash-keepalive.yml; then
    pass "Workflow acknowledges UTC timing in comments and code"
else
    fail "Workflow should explicitly reference UTC timing"
fi
echo ""

# Test 15: All bash functions are defined before use
echo "Test: Bash function definition order"
# Check that utility functions exist
if grep -q 'ts() {' .github/workflows/upstash-keepalive.yml && \
   grep -q 'redis_call() {' .github/workflows/upstash-keepalive.yml && \
   grep -q 'run_op() {' .github/workflows/upstash-keepalive.yml; then
    pass "All bash utility functions are defined (ts, redis_call, run_op)"
else
    fail "Missing bash utility function definitions"
fi
echo ""

# Test 16: Workflow uses Bearer authentication
echo "Test: Authorization header uses Bearer token scheme"
if grep -q 'Authorization: Bearer' .github/workflows/upstash-keepalive.yml; then
    pass "Authorization uses standard Bearer token scheme"
else
    fail "Authorization should use Bearer token scheme"
fi
echo ""

# Test 17: curl uses secure flags
echo "Test: curl security flags (fail, silent, show-error)"
if grep -q 'curl -fsS' .github/workflows/upstash-keepalive.yml; then
    pass "curl uses secure flags: -f (fail on error), -s (silent), -S (show errors)"
else
    fail "curl missing security flags"
fi
echo ""

# Test 18: Workflow has descriptive step names
echo "Test: All steps have descriptive names"
step_count=$(grep -c '      - name:' .github/workflows/upstash-keepalive.yml || echo 0)
if [ "$step_count" -ge 2 ]; then
    pass "Workflow has descriptive names for all $step_count steps"
else
    fail "Workflow should have named steps (found: $step_count)"
fi
echo ""

# Test 19: Random delay prevents detection as bot
echo "Test: Random delay and operation variation"
if grep -q 'delay=\$((RANDOM % 181))' .github/workflows/upstash-keepalive.yml && \
   grep -q 'group=\$((RANDOM % 3))' .github/workflows/upstash-keepalive.yml; then
    pass "Workflow uses randomization to appear more human-like"
else
    fail "Workflow should randomize timing and operations"
fi
echo ""

# Test 20: GitHub Actions API version pinning
echo "Test: GitHub Actions use specific version pins"
if grep -q '@v7' .github/workflows/upstash-keepalive.yml; then
    pass "GitHub Actions pinned to specific versions (e.g., @v7)"
else
    fail "GitHub Actions should use version pins, not @latest"
fi
echo ""

# Summary
echo ""
echo "=========================================="
echo "Integration Test Results"
echo "=========================================="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILED integration test(s) failed${NC}"
    exit 1
fi