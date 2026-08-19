const assert = require('node:assert/strict');
const test = require('node:test');

let automation = {};
try {
  automation = require('./close-develop-issues.cjs');
} catch (error) {
  if (
    error.code !== 'MODULE_NOT_FOUND' ||
    !error.message.includes('close-develop-issues.cjs')
  ) {
    throw error;
  }
}

const extractClosingIssueNumbers =
  automation.extractClosingIssueNumbers ?? (() => []);
const closeIssuesFromPullRequest =
  automation.closeIssuesFromPullRequest ?? (async () => {});

test('extracts only explicit same-repository closing keywords without duplicates', () => {
  const body = [
    'Closes #12',
    'Fixes: #15',
    'Resolves #12',
    'Related to #19',
    'Closes someone/another-repo#20',
    'Closes #0',
    'Closes #not-a-number',
  ].join('\n');

  assert.deepEqual(extractClosingIssueNumbers(body), [12, 15]);
});

test('closes only open issues named by the merged pull request', async () => {
  const issues = new Map([
    [12, { state: 'open' }],
    [13, { state: 'closed' }],
    [14, { state: 'open', pull_request: { url: 'https://example.test/pr/14' } }],
  ]);
  const updates = [];
  const github = {
    rest: {
      issues: {
        get: async ({ issue_number }) => ({ data: issues.get(issue_number) }),
        update: async (input) => updates.push(input),
      },
    },
  };
  const context = {
    repo: { owner: 'reyxdz', repo: 'bananaCheck' },
    payload: {
      pull_request: {
        body: 'Closes #12\nCloses #13\nCloses #14',
        merged: true,
      },
    },
  };
  const core = { info: () => {}, warning: () => {} };

  await closeIssuesFromPullRequest({ github, context, core });

  assert.deepEqual(updates, [
    {
      owner: 'reyxdz',
      repo: 'bananaCheck',
      issue_number: 12,
      state: 'closed',
      state_reason: 'completed',
    },
  ]);
});
