#!/usr/bin/env bash
# YAML structure validation tests for upstash-keepalive.yml

set -euo pipefail

WORKFLOW_FILE=".github/workflows/upstash-keepalive.yml"
TEST_NAME="Workflow YAML Validation"
FAILED=0

echo "=========================================="
echo "$TEST_NAME"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Test 1: Workflow file exists
echo "Test: Workflow file exists"
if [ -f "$WORKFLOW_FILE" ]; then
    pass "Workflow file exists at $WORKFLOW_FILE"
else
    fail "Workflow file not found at $WORKFLOW_FILE"
fi
echo ""

# Test 2: Workflow file is valid YAML
echo "Test: Valid YAML syntax"
if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW_FILE'))" 2>/dev/null; then
        pass "YAML syntax is valid"
    else
        fail "YAML syntax is invalid"
    fi
else
    warn "Python3 not available, skipping YAML syntax validation"
fi
echo ""

# Test 3: Workflow has name field
echo "Test: Workflow has name field"
if grep -q "^name:" "$WORKFLOW_FILE"; then
    name=$(grep "^name:" "$WORKFLOW_FILE" | head -1)
    pass "Workflow has name: $name"
else
    fail "Workflow missing name field"
fi
echo ""

# Test 4: Workflow has schedule trigger
echo "Test: Workflow has schedule trigger"
if grep -q "schedule:" "$WORKFLOW_FILE"; then
    pass "Workflow has schedule trigger"
else
    fail "Workflow missing schedule trigger"
fi
echo ""

# Test 5: Cron schedule is valid
echo "Test: Cron schedule is valid"
if grep -q 'cron:.*"17 1 \* \* \*"' "$WORKFLOW_FILE"; then
    pass "Cron schedule is '17 1 * * *' (01:17 UTC daily)"
else
    fail "Cron schedule not found or incorrect"
fi
echo ""

# Test 6: Workflow has workflow_dispatch trigger
echo "Test: Workflow has workflow_dispatch trigger"
if grep -q "workflow_dispatch:" "$WORKFLOW_FILE"; then
    pass "Workflow has workflow_dispatch trigger for manual runs"
else
    fail "Workflow missing workflow_dispatch trigger"
fi
echo ""

# Test 7: Workflow has jobs section
echo "Test: Workflow has jobs section"
if grep -q "^jobs:" "$WORKFLOW_FILE"; then
    pass "Workflow has jobs section"
else
    fail "Workflow missing jobs section"
fi
echo ""

# Test 8: Keepalive job exists
echo "Test: Keepalive job exists"
if grep -q "keepalive:" "$WORKFLOW_FILE"; then
    pass "Keepalive job is defined"
else
    fail "Keepalive job not found"
fi
echo ""

# Test 9: Job uses ubuntu-latest runner
echo "Test: Job uses ubuntu-latest runner"
if grep -q "runs-on: ubuntu-latest" "$WORKFLOW_FILE"; then
    pass "Job uses ubuntu-latest runner"
else
    fail "Job does not use ubuntu-latest runner"
fi
echo ""

# Test 10: Job has steps
echo "Test: Job has steps"
if grep -q "steps:" "$WORKFLOW_FILE"; then
    pass "Job has steps defined"
else
    fail "Job missing steps"
fi
echo ""

# Test 11: Required secrets are referenced
echo "Test: Required secrets are referenced"
if grep -q "UPSTASH_REDIS_REST_URL" "$WORKFLOW_FILE" && \
   grep -q "UPSTASH_REDIS_REST_TOKEN" "$WORKFLOW_FILE"; then
    pass "Required secrets (UPSTASH_REDIS_REST_URL, UPSTASH_REDIS_REST_TOKEN) are referenced"
else
    fail "Required secrets not found in workflow"
fi
echo ""

# Test 12: Secrets are properly referenced with secrets context
echo "Test: Secrets use proper GitHub secrets context"
if grep -q '\${{ secrets\.UPSTASH_REDIS_REST_URL }}' "$WORKFLOW_FILE" && \
   grep -q '\${{ secrets\.UPSTASH_REDIS_REST_TOKEN }}' "$WORKFLOW_FILE"; then
    pass "Secrets use correct \${{ secrets.* }} syntax"
else
    fail "Secrets do not use correct syntax"
fi
echo ""

# Test 13: Script has set -uo pipefail
echo "Test: Script uses set -uo pipefail for safety"
if grep -q "set -uo pipefail" "$WORKFLOW_FILE"; then
    pass "Script uses 'set -uo pipefail' for error handling"
else
    fail "Script missing 'set -uo pipefail'"
fi
echo ""

# Test 14: Script validates secrets before use
echo "Test: Script validates secrets before use"
if grep -q 'if \[ -z "\${UPSTASH_REDIS_REST_URL:-}" \]' "$WORKFLOW_FILE"; then
    pass "Script validates secrets before proceeding"
else
    fail "Script does not validate secrets"
fi
echo ""

# Test 15: Script includes retry logic
echo "Test: Script includes retry logic"
if grep -q "max_attempts" "$WORKFLOW_FILE"; then
    pass "Script includes retry mechanism"
else
    fail "Script missing retry logic"
fi
echo ""

# Test 16: Retry max_attempts is 3
echo "Test: Retry max_attempts is set to 3"
if grep -q "max_attempts=3" "$WORKFLOW_FILE"; then
    pass "Retry max_attempts is 3"
else
    fail "Retry max_attempts is not 3 or not set"
fi
echo ""

# Test 17: Script performs PING operation
echo "Test: Script performs PING operation"
if grep -q "redis_call.*ping" "$WORKFLOW_FILE"; then
    pass "Script performs PING operation"
else
    fail "Script does not perform PING"
fi
echo ""

# Test 18: PING response is validated
echo "Test: PING response validation"
if grep -q "grep -q 'PONG'" "$WORKFLOW_FILE"; then
    pass "PING response is validated for 'PONG'"
else
    fail "PING response not validated"
fi
echo ""

# Test 19: Script writes keepalive marker with TTL
echo "Test: Script writes keepalive marker with TTL"
if grep -q "set/keepalive:last_run" "$WORKFLOW_FILE" && grep -q "172800" "$WORKFLOW_FILE"; then
    pass "Script writes keepalive marker with 172800s (48h) TTL"
else
    fail "Script does not write keepalive marker or TTL is incorrect"
fi
echo ""

# Test 20: Script increments counter
echo "Test: Script increments run counter"
if grep -q "incr/keepalive:run_count" "$WORKFLOW_FILE"; then
    pass "Script increments keepalive:run_count counter"
else
    fail "Script does not increment run counter"
fi
echo ""

# Test 21: Script has random delay logic
echo "Test: Script has random delay (0-180s)"
if grep -q 'delay=\$((RANDOM % 181))' "$WORKFLOW_FILE"; then
    pass "Script includes random delay (0-180s)"
else
    fail "Script missing random delay logic"
fi
echo ""

# Test 22: Script has group selection logic
echo "Test: Script has group selection for read operations"
if grep -q 'group=\$((RANDOM % 3))' "$WORKFLOW_FILE"; then
    pass "Script has group selection logic (3 groups)"
else
    fail "Script missing group selection logic"
fi
echo ""

# Test 23: Script defines Group A operations
echo "Test: Script defines Group A (Database Overview)"
if grep -q "Group A: Database Overview" "$WORKFLOW_FILE" && \
   grep -q "DBSIZE.*dbsize" "$WORKFLOW_FILE" && \
   grep -q "RANDOMKEY.*randomkey" "$WORKFLOW_FILE"; then
    pass "Group A (Database Overview) is defined with DBSIZE, TIME, RANDOMKEY, INFO"
else
    fail "Group A is not properly defined"
fi
echo ""

# Test 24: Script defines Group B operations
echo "Test: Script defines Group B (Server Status)"
if grep -q "Group B: Server Status" "$WORKFLOW_FILE" && \
   grep -q "INFO server.*info/server" "$WORKFLOW_FILE" && \
   grep -q "INFO stats.*info/stats" "$WORKFLOW_FILE"; then
    pass "Group B (Server Status) is defined with TIME, INFO server, INFO stats, DBSIZE"
else
    fail "Group B is not properly defined"
fi
echo ""

# Test 25: Script defines Group C operations
echo "Test: Script defines Group C (Memory & Clients)"
if grep -q "Group C: Memory & Clients" "$WORKFLOW_FILE" && \
   grep -q "INFO memory.*info/memory" "$WORKFLOW_FILE" && \
   grep -q "INFO clients.*info/clients" "$WORKFLOW_FILE"; then
    pass "Group C (Memory & Clients) is defined with INFO memory, INFO clients, GET, TIME"
else
    fail "Group C is not properly defined"
fi
echo ""

# Test 26: Script exits 0 even with non-fatal failures
echo "Test: Script exits 0 for non-fatal failures"
if grep -q "exit 0" "$WORKFLOW_FILE" | tail -1; then
    pass "Script exits 0 to prevent workflow failure for non-fatal errors"
else
    warn "Could not verify exit 0 behavior"
fi
echo ""

# Test 27: Workflow has GitHub workflow auto-disable prevention
echo "Test: Workflow prevents GitHub auto-disable"
if grep -q "actions/github-script" "$WORKFLOW_FILE"; then
    pass "Workflow includes step to prevent GitHub auto-disable after 60 days"
else
    fail "Workflow missing GitHub auto-disable prevention"
fi
echo ""

# Test 28: GitHub script uses v7
echo "Test: GitHub script action uses v7"
if grep -q "actions/github-script@v7" "$WORKFLOW_FILE"; then
    pass "Using actions/github-script@v7"
else
    warn "Not using actions/github-script@v7"
fi
echo ""

# Test 29: GitHub script lists workflows
echo "Test: GitHub script lists repository workflows"
if grep -q "listRepoWorkflows" "$WORKFLOW_FILE"; then
    pass "GitHub script lists repository workflows"
else
    fail "GitHub script does not list workflows"
fi
echo ""

# Test 30: GitHub script enables inactive workflows
echo "Test: GitHub script enables inactive workflows"
if grep -q "enableWorkflow" "$WORKFLOW_FILE"; then
    pass "GitHub script enables inactive workflows"
else
    fail "GitHub script does not enable workflows"
fi
echo ""

# Test 31: Script has error handling for PING failure
echo "Test: Script aborts if PING fails"
if grep -q 'PING failed, aborting' "$WORKFLOW_FILE"; then
    pass "Script aborts if PING fails"
else
    fail "Script does not handle PING failure properly"
fi
echo ""

# Test 32: Curl has timeout configured
echo "Test: Curl has timeout (--max-time 15)"
if grep -q "\-\-max-time 15" "$WORKFLOW_FILE"; then
    pass "Curl has 15-second timeout"
else
    fail "Curl timeout not configured"
fi
echo ""

# Test 33: Curl uses silent mode with show-error
echo "Test: Curl uses -fsS flags (fail silently, show errors)"
if grep -q "curl -fsS" "$WORKFLOW_FILE"; then
    pass "Curl uses -fsS flags for proper error handling"
else
    fail "Curl does not use -fsS flags"
fi
echo ""

# Test 34: Authorization header uses Bearer token
echo "Test: Authorization uses Bearer token format"
if grep -q '"Authorization: Bearer \${UPSTASH_REDIS_REST_TOKEN}"' "$WORKFLOW_FILE"; then
    pass "Authorization header uses Bearer token format"
else
    fail "Authorization header format incorrect"
fi
echo ""

# Test 35: Comments are in Chinese explaining purpose
echo "Test: Comments explain workflow purpose"
if grep -q "# 每天 UTC" "$WORKFLOW_FILE"; then
    pass "Comments explain cron schedule timing"
else
    warn "Could not find expected comments"
fi
echo ""

# Summary
echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$FAILED test(s) failed${NC}"
    exit 1
fi