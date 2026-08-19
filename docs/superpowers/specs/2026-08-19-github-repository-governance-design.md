# GitHub Repository Governance Design

**Date:** 2026-08-19

**Status:** Approved for implementation

**Repository:** `reyxdz/bananaCheck`

**Source:** `PROJECT_PLAN.md` and the project-lead configuration approved in
conversation

## Purpose

Turn the initialized Banana Check repository into a safe two-developer delivery
workspace. GitHub must run the same quality gates developers run locally,
prevent unreviewed changes to stable branches, provide usable issue tracking,
and protect dependencies and secrets without introducing deployment
infrastructure the offline mobile product does not need.

## Current State

- `main` is the only branch and contains the verified local foundation.
- No `.github/` workflows, templates, ownership file, or Dependabot
  configuration exist yet.
- The repository is owned by the personal account `reyxdz`, so collaborators
  receive the personal-repository collaborator permission set rather than
  organization-level granular roles.
- The installed GitHub CLI has an expired credential. Git push authentication
  works, but GitHub API and web administration require fresh authorization.
- Emanuel's and Marc Paul's exact GitHub usernames are not present in the
  repository and must be provided or discovered from accepted invitations
  before they can be added as collaborators or path-specific code owners.

## Repository Files

Create the following hosted-workflow files:

```text
.github/
|-- workflows/
|   |-- flutter-ci.yml
|   `-- python-ci.yml
|-- ISSUE_TEMPLATE/
|   |-- bug.yml
|   |-- feature.yml
|   |-- model-experiment.yml
|   `-- config.yml
|-- CODEOWNERS
|-- PULL_REQUEST_TEMPLATE.md
`-- dependabot.yml
```

### Flutter CI

`flutter-ci.yml` will run on pull requests and pushes targeting `main` or
`develop`. It will pin Flutter 3.22.3, resolve `app/pubspec.lock`, and expose two
stable required job names:

- `flutter-analyze`: formatting plus `flutter analyze`;
- `flutter-test`: `flutter test --coverage`.

Both jobs will run for every pull request rather than using workflow-level path
filters. This guarantees required check names are always reported and prevents
an unrelated-file pull request from remaining permanently pending.

### Python CI

`python-ci.yml` will run on the same branch events with Python 3.11 and expose:

- `python-lint`: Ruff across `ml/` and `backend/`;
- `python-test`: each workspace's pytest configuration and coverage floor.

The lint job installs Ruff only. The test job caches pip downloads and installs
the two development requirement sets. The existing `pytest.ini` files enforce
the 60 percent minimum coverage policy.

Every workflow will use explicit read-only repository permissions,
concurrency cancellation for superseded branch runs, and pinned major action
versions. No workflow will receive repository secrets or write permission.

### Contribution Metadata

The pull request template will require scope, linked task, change type, local
checks, tests for changed behavior, UI-guideline review, physical-device
testing when relevant, documentation updates, and screenshots for UI changes.

Issue forms will cover bugs, planned features/tasks, and model experiments.
They will collect acceptance criteria and reproduction/evaluation evidence
rather than accept unstructured issue bodies.

`CODEOWNERS` will initially assign the entire repository to `@reyxdz`. App and
ML path owners will be added once the two developer usernames are known; no
placeholder usernames will be committed.

Dependabot will check Flutter packages in `/app`, Python packages in `/ml` and
`/backend`, and GitHub Actions weekly. Version-update pull requests will target
`develop`. Dependency changes will never auto-merge because the current CameraX
and TFLite versions are intentionally constrained for Flutter 3.22.3.

## Branch Model

Create `develop` at the verified `main` commit. Keep `main` as the default
branch.

```text
feature/* ---\
fix/* --------> develop ---> main
experiment/*-/
```

Feature and fix work targets `develop`. Only a tested milestone or release
candidate moves from `develop` to `main`.

## Repository Settings

Configure repository metadata with an offline banana classification
description and the topics `flutter`, `tensorflow-lite`, `computer-vision`,
`banana-classification`, `fastapi`, and `python`.

Keep Issues enabled and the Wiki disabled. Keep `main` as the default branch.
Allow squash merging only, use the pull-request title for the squash commit,
and automatically delete merged head branches.

Keep the repository private until the project lead deliberately approves
publication. If the current visibility differs, do not change it automatically;
visibility changes require an explicit confirmation because they affect every
file and collaborator.

## Actions Settings

Enable GitHub Actions and the public actions used by the committed workflows.
Set default `GITHUB_TOKEN` permissions to read repository contents and packages.
Do not allow Actions to create or approve pull requests. Do not send write
tokens or secrets to fork pull-request workflows.

## Branch Protection

Prefer active repository branch rulesets when the account plan and repository
visibility support them. Fall back to classic branch protection rules when
rulesets are unavailable.

### `main`

- block deletions and force pushes;
- require a pull request;
- require one approval;
- dismiss stale approvals after new commits;
- require approval of the most recent reviewable push;
- require all conversations to be resolved;
- require `flutter-analyze`, `flutter-test`, `python-lint`, and `python-test`;
- require the branch to be up to date;
- require linear history; and
- configure no routine bypass actor, including the owner where GitHub exposes
  that control.

### `develop`

- block deletions and force pushes;
- require a pull request;
- require the same four status checks;
- require all conversations to be resolved;
- require the branch to be up to date; and
- require zero approvals so integration can move quickly while remaining
  test-gated.

Required status checks will be selected only after each workflow job has
reported once. Protection must not be activated with nonexistent required
checks.

## Security Settings

Enable every feature available to the account and repository visibility from
this set:

- dependency graph;
- Dependabot alerts;
- Dependabot security updates;
- secret scanning; and
- push protection.

Record features that GitHub makes unavailable rather than changing visibility
or billing to obtain them. Do not enable dependency auto-merge.

No repository secrets, deployment environments, GitHub Pages, packages,
webhooks, deploy keys, or release automation are required during this setup.

## Project Management

Create a GitHub Project named `Banana Check Delivery` with the statuses Backlog,
Ready, In Progress, Review, and Done.

Create labels for:

- area: `app`, `ml`, `backend`, `docs`;
- type: `feature`, `bug`, `experiment`, `task`;
- priority: `high`, `medium`, `low`;
- coordination: `blocked`; and
- schedule: `week: 1` through `week: 8`.

Create Week 1 through Week 8 milestones. Create issues from the A and B tasks in
`PROJECT_PLAN.md`, preserving the planned owner, week, dependencies, and
acceptance outcome. Add them to the project. Foundation tasks A1-A4, B1, B3,
and B16 may be closed as completed only when their issue wording matches the
already verified scaffold; placeholder screens must not be used to close later
feature issues.

## Collaborators and Ownership

Invite Emanuel and Marc Paul as collaborators after their exact GitHub
usernames are known. On this personal repository that grants the write access
needed for branches, issues, reviews, and pull requests. Rey remains the sole
repository owner and administrator.

After invitations are accepted, update `CODEOWNERS` so `app/` requests Emanuel,
`ml/` requests Marc Paul, shared inference/model artifacts request both, and
root governance files retain Rey. Because this is a personal repository,
organization teams and organization-only required reviewer rules are out of
scope unless the repository is deliberately transferred later.

## Execution Order

1. Commit the GitHub workflow and contribution files on `main`.
2. Push `main` and create `develop` from that exact commit.
3. Let all four CI jobs report successfully at least once.
4. Configure general, merge, and Actions permissions.
5. Enable security features that are available.
6. Create and activate branch protection for `main` and `develop`.
7. Create labels, milestones, roadmap issues, and the project board.
8. Invite known collaborators and finalize path-specific code ownership.

This order prevents protection rules from blocking their own initial workflow
installation or waiting for required status checks GitHub has never seen.

## Verification

The setup is complete when:

1. `.github/` files validate and the local quality gate still passes;
2. `main` and `develop` exist remotely at the intended commits;
3. the four named CI checks have successful runs;
4. direct pushes, deletion, and force pushes are blocked as designed;
5. a pull request cannot merge without the applicable checks and review;
6. Actions use read-only default permissions;
7. available security features are enabled;
8. labels, milestones, roadmap issues, and the project board exist without
   duplicate entries;
9. no secrets, datasets, models, deployment infrastructure, or placeholder
   collaborator handles are committed; and
10. any item blocked by account capability or missing usernames is reported
    explicitly with its exact required follow-up.
