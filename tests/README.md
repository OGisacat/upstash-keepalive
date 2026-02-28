# Test Suite for Upstash Keep-Alive Workflow

Comprehensive test coverage for `.github/workflows/upstash-keepalive.yml`.

## Overview

This test suite validates the GitHub Actions workflow that keeps Upstash Redis active and prevents workflow auto-disable. It includes 118 tests across four test suites covering bash script logic, YAML structure, GitHub Actions script behavior, and end-to-end integration scenarios.

## Test Suites

### 1. Bash Logic Tests (`test_bash_logic.sh`)
**48 tests** covering the bash script embedded in the workflow:

- **Timestamp Functions**: UTC timestamp generation and format validation
- **Secret Validation**: Environment variable presence, empty string handling
- **Random Delay Logic**: 0-180 second delay range validation
- **Group Selection**: Random operation group selection (0-2)
- **Retry Mechanism**: Max attempts (3), failure handling, success on retry
- **PING Validation**: Response format, case sensitivity, PONG detection
- **Pattern Validation**: DBSIZE, TIME, INFO, RANDOMKEY response patterns
- **TTL Calculations**: 48-hour (172800s) TTL verification
- **Date Formats**: ISO 8601 UTC timestamp format
- **Counter Logic**: Failed operation tracking, increment behavior
- **Shell Options**: `set -uo pipefail` error handling
- **Cron Schedule**: UTC timing and timezone conversion validation
- **Redis API Paths**: Command URL construction (PING, SET, INCR, GET, INFO)
- **Edge Cases**: Large numbers, empty patterns, multiple failures

### 2. YAML Structure Tests (`test_workflow_yaml.sh`)
**35 tests** validating workflow structure and configuration:

- **File Structure**: Existence, valid YAML syntax
- **Workflow Metadata**: Name, description
- **Triggers**: Schedule (cron), workflow_dispatch
- **Cron Configuration**: `17 1 * * *` (01:17 UTC daily)
- **Jobs**: Keepalive job definition, ubuntu-latest runner
- **Steps**: Presence and ordering
- **Secrets**: Proper referencing with `${{ secrets.* }}` syntax
- **Security**: Secret validation before use, Bearer token format
- **Error Handling**: `set -uo pipefail`, retry logic, PING failure abort
- **Operations**: PING, write operations (SET, INCR), read operation groups
- **Group Definitions**: Group A (Database), B (Server), C (Memory)
- **Timeouts**: curl 15-second timeout
- **Auto-disable Prevention**: GitHub Actions script presence and configuration
- **Exit Behavior**: Non-fatal failure handling (exit 0)

### 3. GitHub Script Tests (`test_github_script.js`)
**15 tests** for the workflow auto-enable JavaScript logic:

- **Active Workflows**: No-op when all workflows are active
- **Single Inactive**: Enables one disabled workflow
- **Multiple Inactive**: Enables multiple disabled workflows
- **State Handling**: `disabled_inactivity`, `disabled_manually`, other states
- **Empty List**: Handles zero workflows gracefully
- **Mixed States**: Correctly processes mix of active and disabled
- **Ordering**: Processes workflows in received order
- **Idempotency**: Safe to run multiple times
- **Context Usage**: Uses `context.repo.owner` and `context.repo.repo`
- **Special Characters**: Handles workflow names with special chars
- **State Check**: Strict inequality check (state !== 'active')
- **Scale**: Handles large numbers of workflows (100+)
- **Self-healing**: Can re-enable keepalive workflow itself

### 4. Integration Tests (`test_integration.sh`)
**20 tests** for end-to-end integration and cross-cutting concerns:

- **YAML Parseability**: Valid YAML structure and integrity
- **Operation Groups**: Each group has exactly 4 operations
- **Operation Count**: 7 total operations per run (PING + 2 writes + 4 reads)
- **URL Construction**: Redis commands use proper lowercase REST API format
- **Error Handling**: Non-fatal failures don't block execution
- **Critical Failures**: PING failure correctly aborts workflow
- **Group Exclusivity**: Case statement ensures mutually exclusive groups
- **Dual Triggers**: Schedule and manual dispatch both configured
- **Self-healing**: Workflow can re-enable itself if disabled
- **Secret Security**: Secrets never logged or exposed in output
- **Retry Delays**: 5-second delays between retry attempts
- **INFO Sections**: All INFO commands specify sections (not bare INFO)
- **Extended Regex**: Validation patterns use grep -Eq
- **UTC Timing**: Explicit UTC references in code and comments
- **Function Definitions**: All bash functions properly defined
- **Bearer Auth**: Authorization header uses Bearer token scheme
- **Curl Security**: Uses -fsS flags for proper error handling
- **Step Names**: All workflow steps have descriptive names
- **Randomization**: Random delays and operation groups prevent bot detection
- **Version Pinning**: GitHub Actions use specific version pins (@v7)

## Running Tests

### Run All Tests
```bash
bash tests/run_all_tests.sh
```

This runs all three test suites and provides a comprehensive summary.

### Run Individual Test Suites

**Bash Logic Tests:**
```bash
bash tests/test_bash_logic.sh
```

**YAML Validation Tests:**
```bash
bash tests/test_workflow_yaml.sh
```

**GitHub Script Tests:**
```bash
node tests/test_github_script.js
```

**Integration Tests:**
```bash
bash tests/test_integration.sh
```

## Requirements

- **Bash**: 4.0+ (for array operations and regex)
- **Node.js**: 12+ (for JavaScript tests)
- **Python 3**: Optional, for YAML syntax validation

All tests are designed to run without external dependencies beyond standard system tools.

## Test Coverage

| Category | Tests | Coverage |
|----------|-------|----------|
| Bash Script Logic | 48 | Core functionality, error handling, validation |
| YAML Structure | 35 | Workflow configuration, security, triggers |
| GitHub Script | 15 | Auto-enable logic, edge cases, idempotency |
| Integration | 20 | End-to-end behavior, security, consistency |
| **Total** | **118** | **Comprehensive end-to-end validation** |

## Test Design Philosophy

1. **No External Dependencies**: Tests use only bash, node, and standard utilities
2. **Fast Execution**: All tests complete in seconds
3. **Clear Output**: Pass/fail indicators with descriptive messages
4. **Edge Case Coverage**: Boundary conditions, error states, unusual inputs
5. **Security Focus**: Validates secret handling and authorization
6. **Regression Prevention**: Covers all critical workflow behaviors

## Continuous Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow for running tests
- name: Run tests
  run: bash tests/run_all_tests.sh
```

## Troubleshooting

**Tests fail with "command not found":**
- Ensure bash and node are installed
- Check that scripts are executable: `chmod +x tests/*.sh`

**YAML validation warnings:**
- Python3 is optional; YAML syntax validation will be skipped if unavailable

**Permission errors:**
- Ensure test scripts have execute permissions
- Run from repository root: `bash tests/run_all_tests.sh`

## Contributing

When modifying the workflow, ensure:
1. All existing tests pass
2. New functionality is covered by tests
3. Edge cases are considered
4. Security implications are tested

Run the full test suite before committing changes:
```bash
bash tests/run_all_tests.sh
```