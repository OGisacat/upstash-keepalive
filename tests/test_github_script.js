#!/usr/bin/env node
/**
 * Tests for GitHub Actions script that prevents workflow auto-disable
 * This tests the JavaScript logic used in the actions/github-script step
 */

const assert = require('assert');

// Mock GitHub API client
class MockGitHub {
    constructor(workflows, enabledWorkflows = []) {
        this.workflows = workflows;
        this.enabledWorkflows = enabledWorkflows;
        this.rest = {
            actions: {
                listRepoWorkflows: async ({ owner, repo }) => {
                    return {
                        data: {
                            workflows: this.workflows
                        }
                    };
                },
                enableWorkflow: async ({ owner, repo, workflow_id }) => {
                    this.enabledWorkflows.push(workflow_id);
                    return { status: 204 };
                }
            }
        };
    }

    getEnabledWorkflows() {
        return this.enabledWorkflows;
    }
}

// Mock context
const mockContext = {
    repo: {
        owner: 'testowner',
        repo: 'testrepo'
    }
};

// The actual script logic from the workflow (slightly adapted for testing)
async function preventWorkflowDisable(github, context) {
    const workflows = await github.rest.actions.listRepoWorkflows({
        owner: context.repo.owner,
        repo: context.repo.repo,
    });

    for (const wf of workflows.data.workflows) {
        if (wf.state !== 'active') {
            console.log(`Re-enabling workflow: ${wf.name} (${wf.id})`);
            await github.rest.actions.enableWorkflow({
                owner: context.repo.owner,
                repo: context.repo.repo,
                workflow_id: wf.id,
            });
        }
    }
    console.log('All workflows are active.');
}

// Test suite
async function runTests() {
    console.log('==========================================');
    console.log('GitHub Script Logic Tests');
    console.log('==========================================');
    console.log('');

    let passed = 0;
    let failed = 0;

    // Helper function to run a test
    async function test(name, fn) {
        try {
            await fn();
            console.log('✓', name);
            passed++;
        } catch (error) {
            console.log('✗', name);
            console.log('  Error:', error.message);
            failed++;
        }
    }

    // Test 1: Does nothing when all workflows are active
    await test('Does nothing when all workflows are active', async () => {
        const workflows = [
            { id: 1, name: 'Test Workflow 1', state: 'active' },
            { id: 2, name: 'Test Workflow 2', state: 'active' },
        ];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        assert.strictEqual(github.getEnabledWorkflows().length, 0, 'Should not enable any workflows');
    });

    // Test 2: Enables a single inactive workflow
    await test('Enables a single inactive workflow', async () => {
        const workflows = [
            { id: 1, name: 'Active Workflow', state: 'active' },
            { id: 2, name: 'Inactive Workflow', state: 'disabled_manually' },
        ];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        assert.strictEqual(enabled.length, 1, 'Should enable exactly one workflow');
        assert.strictEqual(enabled[0], 2, 'Should enable workflow with id 2');
    });

    // Test 3: Enables multiple inactive workflows
    await test('Enables multiple inactive workflows', async () => {
        const workflows = [
            { id: 1, name: 'Active Workflow', state: 'active' },
            { id: 2, name: 'Disabled Workflow 1', state: 'disabled_manually' },
            { id: 3, name: 'Disabled Workflow 2', state: 'disabled_inactivity' },
            { id: 4, name: 'Disabled Workflow 3', state: 'disabled_manually' },
        ];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        assert.strictEqual(enabled.length, 3, 'Should enable three workflows');
        assert.deepStrictEqual(enabled.sort(), [2, 3, 4], 'Should enable workflows 2, 3, and 4');
    });

    // Test 4: Handles disabled_inactivity state
    await test('Handles disabled_inactivity state', async () => {
        const workflows = [
            { id: 1, name: 'Workflow', state: 'disabled_inactivity' },
        ];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        assert.strictEqual(enabled.length, 1, 'Should enable workflow disabled by inactivity');
        assert.strictEqual(enabled[0], 1, 'Should enable workflow with id 1');
    });

    // Test 5: Handles disabled_manually state
    await test('Handles disabled_manually state', async () => {
        const workflows = [
            { id: 1, name: 'Workflow', state: 'disabled_manually' },
        ];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        assert.strictEqual(enabled.length, 1, 'Should enable manually disabled workflow');
        assert.strictEqual(enabled[0], 1, 'Should enable workflow with id 1');
    });

    // Test 6: Handles empty workflow list
    await test('Handles empty workflow list', async () => {
        const workflows = [];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        assert.strictEqual(enabled.length, 0, 'Should not enable any workflows when list is empty');
    });

    // Test 7: Preserves active workflows
    await test('Preserves active workflows without calling enable', async () => {
        const workflows = [
            { id: 1, name: 'Active 1', state: 'active' },
            { id: 2, name: 'Active 2', state: 'active' },
            { id: 3, name: 'Active 3', state: 'active' },
        ];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        assert.strictEqual(enabled.length, 0, 'Should not call enable on already active workflows');
    });

    // Test 8: Handles mixed states
    await test('Correctly handles mix of active and various disabled states', async () => {
        const workflows = [
            { id: 1, name: 'Active', state: 'active' },
            { id: 2, name: 'Disabled by inactivity', state: 'disabled_inactivity' },
            { id: 3, name: 'Active 2', state: 'active' },
            { id: 4, name: 'Disabled manually', state: 'disabled_manually' },
            { id: 5, name: 'Active 3', state: 'active' },
        ];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        assert.strictEqual(enabled.length, 2, 'Should enable exactly two disabled workflows');
        assert.deepStrictEqual(enabled.sort(), [2, 4], 'Should enable workflows 2 and 4');
    });

    // Test 9: Processes workflows in order
    await test('Processes workflows in order they appear', async () => {
        const workflows = [
            { id: 5, name: 'Workflow 5', state: 'disabled_manually' },
            { id: 3, name: 'Workflow 3', state: 'disabled_inactivity' },
            { id: 1, name: 'Workflow 1', state: 'disabled_manually' },
        ];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        assert.deepStrictEqual(enabled, [5, 3, 1], 'Should enable workflows in order received');
    });

    // Test 10: Idempotent - can be run multiple times safely
    await test('Is idempotent - can run multiple times safely', async () => {
        const workflows = [
            { id: 1, name: 'Active', state: 'active' },
        ];
        const github = new MockGitHub(workflows);

        // Run twice
        await preventWorkflowDisable(github, mockContext);
        await preventWorkflowDisable(github, mockContext);

        const enabled = github.getEnabledWorkflows();
        assert.strictEqual(enabled.length, 0, 'Should not enable active workflow on repeated runs');
    });

    // Test 11: Context object is used correctly
    await test('Uses context.repo.owner and context.repo.repo', async () => {
        const workflows = [];
        let capturedOwner = null;
        let capturedRepo = null;

        const github = {
            rest: {
                actions: {
                    listRepoWorkflows: async ({ owner, repo }) => {
                        capturedOwner = owner;
                        capturedRepo = repo;
                        return { data: { workflows: [] } };
                    }
                }
            }
        };

        await preventWorkflowDisable(github, mockContext);
        assert.strictEqual(capturedOwner, 'testowner', 'Should use correct owner from context');
        assert.strictEqual(capturedRepo, 'testrepo', 'Should use correct repo from context');
    });

    // Test 12: Handles workflow with special characters in name
    await test('Handles workflows with special characters in name', async () => {
        const workflows = [
            { id: 1, name: 'Test & Deploy (Production) [v2]', state: 'disabled_manually' },
        ];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        assert.strictEqual(enabled.length, 1, 'Should enable workflow with special characters');
    });

    // Test 13: Verifies state check is strict (not equals 'active')
    await test('Only processes workflows where state !== "active"', async () => {
        const workflows = [
            { id: 1, name: 'Active', state: 'active' },
            { id: 2, name: 'Pending', state: 'pending' },  // Any non-active state
            { id: 3, name: 'Unknown', state: 'unknown' },  // Any non-active state
        ];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        assert.strictEqual(enabled.length, 2, 'Should enable any workflow not in active state');
        assert.deepStrictEqual(enabled.sort(), [2, 3], 'Should enable workflows 2 and 3');
    });

    // Test 14: Large number of workflows
    await test('Handles large number of workflows', async () => {
        const workflows = [];
        for (let i = 1; i <= 100; i++) {
            workflows.push({
                id: i,
                name: `Workflow ${i}`,
                state: i % 3 === 0 ? 'disabled_manually' : 'active'
            });
        }
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        // Every 3rd workflow should be disabled (100/3 = 33)
        assert.strictEqual(enabled.length, 33, 'Should enable all disabled workflows');
    });

    // Test 15: Self-healing - re-enables the keepalive workflow itself
    await test('Can re-enable the keepalive workflow itself if disabled', async () => {
        const workflows = [
            { id: 1, name: 'Upstash Keep Alive', state: 'disabled_inactivity' },
            { id: 2, name: 'Other Workflow', state: 'active' },
        ];
        const github = new MockGitHub(workflows);
        await preventWorkflowDisable(github, mockContext);
        const enabled = github.getEnabledWorkflows();
        assert.strictEqual(enabled.length, 1, 'Should re-enable itself if disabled');
        assert.strictEqual(enabled[0], 1, 'Should enable the keepalive workflow');
    });

    // Summary
    console.log('');
    console.log('==========================================');
    console.log('Test Results');
    console.log('==========================================');
    console.log(`Passed: ${passed}`);
    console.log(`Failed: ${failed}`);
    console.log('');

    if (failed === 0) {
        console.log('✓ All tests passed!');
        process.exit(0);
    } else {
        console.log(`✗ ${failed} test(s) failed`);
        process.exit(1);
    }
}

// Run tests
runTests().catch(error => {
    console.error('Test runner error:', error);
    process.exit(1);
});