# GitHub Repository Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure `reyxdz/bananaCheck` as a protected, CI-gated,
project-managed two-developer GitHub repository.

**Architecture:** Commit reproducible workflows and contribution metadata
before applying hosted settings. Create `develop` from the verified foundation,
let all four CI jobs establish their check names, then apply repository
permissions, protection, security, and project-management state through the
authenticated GitHub CLI/API with read-after-write verification.

**Tech Stack:** GitHub Actions, GitHub REST/GraphQL APIs through `gh`, YAML,
Flutter 3.22.3, Python 3.11, Ruff, pytest, Dependabot

**Spec:**
`docs/superpowers/specs/2026-08-19-github-repository-governance-design.md`

## Global Constraints

- Keep `main` as the default branch and create `develop` from the verified
  foundation commit.
- Required check names are exactly `flutter-analyze`, `flutter-test`,
  `python-lint`, and `python-test`.
- Workflows receive read-only contents permission and no repository secrets.
- Pull requests use squash merging; direct/force pushes and deletion are
  blocked on protected branches.
- Python remains 3.11; Flutter remains pinned to 3.22.3.
- Do not change repository visibility, billing, or ownership automatically.
- Do not commit secrets, datasets, model binaries, or placeholder collaborator
  usernames.
- Do not auto-merge dependency changes because Flutter plugin versions are
  intentionally constrained.
- Hosted writes must be idempotent or preceded by a read that prevents
  duplicate labels, milestones, issues, projects, or rules.

---

### Task 1: Add GitHub CI Workflows

**Files:**

- Create: `.github/workflows/flutter-ci.yml`
- Create: `.github/workflows/python-ci.yml`

**Interfaces:**

- Produces the four stable check names consumed by branch protection.
- Uses `app/pubspec.lock`, `ml/requirements-dev.txt`,
  `backend/requirements-dev.txt`, and the existing pytest configurations.

- [ ] Confirm both workflow files are absent and capture the failing
  configuration assertion.
- [ ] Add Flutter CI for pushes and pull requests targeting `main`/`develop`,
  with separate analyze and test jobs, Flutter 3.22.3, read-only permissions,
  caching, and concurrency cancellation.
- [ ] Add Python CI for the same events, with Python 3.11 lint/test jobs,
  read-only permissions, pip caching, and concurrency cancellation.
- [ ] Parse both YAML files with the backend virtual environment's PyYAML and
  assert the four required job IDs, triggers, and permissions.
- [ ] Run `scripts\check.cmd`.
- [ ] Commit: `ci: add Flutter and Python quality gates`.

### Task 2: Add Contribution and Dependency Metadata

**Files:**

- Create: `.github/PULL_REQUEST_TEMPLATE.md`
- Create: `.github/ISSUE_TEMPLATE/bug.yml`
- Create: `.github/ISSUE_TEMPLATE/feature.yml`
- Create: `.github/ISSUE_TEMPLATE/model-experiment.yml`
- Create: `.github/ISSUE_TEMPLATE/config.yml`
- Create: `.github/CODEOWNERS`
- Create: `.github/dependabot.yml`

**Interfaces:**

- PR/issue templates enforce the documented testing, UI, device, and evidence
  requirements.
- `CODEOWNERS` starts with only `@reyxdz`; developer paths wait for real handles.
- Dependabot targets `develop` for pub, both pip workspaces, and Actions.

- [ ] Confirm the files are absent.
- [ ] Add the PR template and three structured issue forms.
- [ ] Disable blank issues and point contributors to the structured forms.
- [ ] Add root ownership for `@reyxdz` without fake path owners.
- [ ] Add weekly, grouped, non-auto-merge Dependabot update definitions.
- [ ] Parse every YAML file and assert required top-level fields and target
  branch.
- [ ] Run `git diff --check` and scan `.github/` for placeholder markers or
  secrets.
- [ ] Commit: `chore: add GitHub contribution metadata`.

### Task 3: Publish Workflow Files and Create `develop`

**Files:** None.

**Interfaces:**

- Publishes Tasks 1-2 to `origin/main`.
- Produces `origin/develop` at the same verified commit.

- [ ] Verify the worktree is clean and local tests are green.
- [ ] Push `main` without force.
- [ ] Read the remote `main` SHA and confirm it matches local HEAD.
- [ ] Create local `develop` from that commit and push it with upstream tracking.
- [ ] Return the working tree to `main`.
- [ ] Confirm both remote branches resolve to the intended commit.

### Task 4: Restore GitHub Administration Authentication

**Files:** None.

**Interfaces:**

- Produces authenticated `gh api`, Actions, project, and collaborator access.

- [ ] Run `gh auth status` and retain the existing failure as evidence.
- [ ] Start GitHub CLI web authentication with `repo`, `workflow`, and `project`
  scopes; let the user complete GitHub's authorization screen if prompted.
- [ ] Run `gh auth status` again and verify account `reyxdz` is active.
- [ ] Verify admin access with a read-only repository API request before any
  hosted write.

### Task 5: Configure Repository, Actions, and Security Settings

**Files:** None.

**Interfaces:**

- Mutates settings for `reyxdz/bananaCheck` only.

- [ ] Read current repository metadata, visibility, merge settings, Actions
  permissions, and security configuration.
- [ ] Set the approved description, topics, Issues/Wiki state, squash-only
  merging, squash title behavior, and automatic head-branch deletion.
- [ ] Enable Actions, keep default workflow permission read-only, and prevent
  workflows from creating/approving pull requests.
- [ ] Enable dependency graph, vulnerability alerts, automated security fixes,
  secret scanning, and push protection where available.
- [ ] Record any feature rejected due to plan/visibility without changing
  billing or visibility.
- [ ] Read every setting back and compare it with the approved values.

### Task 6: Establish CI and Protect Branches

**Files:** None unless a workflow failure requires a scoped correction.

**Interfaces:**

- Consumes the four CI check names from Task 1.
- Protects `main` and `develop` after those names exist.

- [ ] Inspect Actions runs triggered by the branch pushes.
- [ ] Wait for the Flutter and Python workflows on `main` to complete.
- [ ] If a workflow fails, use systematic debugging, reproduce locally where
  possible, patch only the cause, rerun local checks, commit, and push.
- [ ] Verify successful check runs named `flutter-analyze`, `flutter-test`,
  `python-lint`, and `python-test`.
- [ ] Attempt active branch rulesets with the spec's rules; if unavailable for
  the account, apply equivalent classic protection.
- [ ] Read back `main` protection: one approval, stale-review dismissal,
  last-push approval, conversation resolution, strict four checks, linear
  history, admin enforcement/no routine bypass, no force push, no deletion.
- [ ] Read back `develop` protection: pull request, strict four checks,
  conversation resolution, zero approvals, no force push, no deletion.

### Task 7: Create Labels, Milestones, Issues, and Project

**Files:** None.

**Interfaces:**

- Translates `PROJECT_PLAN.md` roadmap tasks into GitHub planning objects.

- [ ] Read existing labels, milestones, roadmap issues, and user projects to
  establish an idempotent baseline.
- [ ] Create the approved area, type, priority, blocked, and week labels with
  consistent colors/descriptions.
- [ ] Create open Week 1 through Week 8 milestones with no invented deadline
  dates.
- [ ] Parse A1-A24 and B1-B18 from `PROJECT_PLAN.md`; create one issue per task
  with track, week, dependencies, estimate, and acceptance outcome.
- [ ] Close only A1-A4, B1, B3, and B16 when their issue scope exactly matches
  the verified scaffold; leave product-feature issues open.
- [ ] Create or reuse the personal project `Banana Check Delivery`.
- [ ] Configure statuses Backlog, Ready, In Progress, Review, and Done where the
  available project API supports custom options.
- [ ] Add all roadmap issues to the project without duplicates.
- [ ] Verify counts, milestone mappings, issue state, and project membership.

### Task 8: Add Collaborators and Finalize Code Ownership

**Files:**

- Modify after handles are known: `.github/CODEOWNERS`

**Interfaces:**

- Requires exact GitHub usernames for Emanuel and Marc Paul.

- [ ] Read current collaborators and pending invitations; use accepted matching
  accounts if they unambiguously identify the two developers.
- [ ] If either identity is ambiguous or absent, request the exact username and
  complete all other tasks without guessing.
- [ ] Invite each confirmed username as a collaborator.
- [ ] Update CODEOWNERS for `app/`, `ml/`, shared model artifacts, and root
  governance; add no nonexistent username.
- [ ] Run configuration validation, commit the ownership update, and push via a
  pull request if branch protection is already active.
- [ ] Verify invitations or accepted collaborator state and CODEOWNERS syntax.

### Task 9: Final Verification and Handoff

**Files:** None unless verification finds a scoped defect.

**Interfaces:** Verifies both local repository state and hosted GitHub state.

- [ ] Invoke `superpowers:verification-before-completion`.
- [ ] Run `scripts\check.cmd`, YAML parsing, `git diff --check`, artifact audit,
  and clean-worktree checks.
- [ ] Verify local `main`, `origin/main`, and the GitHub default-branch SHA.
- [ ] Verify both protected branches, required checks, Actions permissions,
  merge policy, available security features, labels, milestones, issue count,
  and project existence through read-only API calls.
- [ ] Verify no secrets, data/model artifacts, placeholder owners, duplicate
  planning objects, or uncommitted files exist.
- [ ] Report exact CI run URLs, project URL, collaborator invitations, settings
  unavailable due to account capability, and any single user action still
  required.
