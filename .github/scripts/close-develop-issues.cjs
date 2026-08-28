function extractClosingIssueNumbers(body = '') {
  const issueNumbers = new Set();
  const closingKeyword =
    /\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s*:?\s*#(\d+)\b/gi;

  for (const match of body.matchAll(closingKeyword)) {
    const issueNumber = Number(match[1]);
    if (issueNumber > 0) {
      issueNumbers.add(issueNumber);
    }
  }

  return [...issueNumbers];
}

async function closeIssuesFromPullRequest({ github, context, core }) {
  const { owner, repo } = context.repo;
  const issueNumbers = extractClosingIssueNumbers(
    context.payload.pull_request?.body ?? '',
  );

  for (const issueNumber of issueNumbers) {
    const { data: issue } = await github.rest.issues.get({
      owner,
      repo,
      issue_number: issueNumber,
    });

    if (issue.pull_request) {
      core.warning(`#${issueNumber} is a pull request and was not closed.`);
      continue;
    }

    if (issue.state !== 'open') {
      core.info(`#${issueNumber} is already closed.`);
      continue;
    }

    await github.rest.issues.update({
      owner,
      repo,
      issue_number: issueNumber,
      state: 'closed',
      state_reason: 'completed',
    });
    core.info(`Closed issue #${issueNumber}.`);
  }
}

module.exports = { closeIssuesFromPullRequest, extractClosingIssueNumbers };
