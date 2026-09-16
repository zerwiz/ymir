---
name: pr-ops
description: "Create and manage pull requests to the zerwiz/ymir main repo. Use when an agent needs to open a PR, update a PR description, or check PR status. Pairs with git-ops (branches/commits/sync) — pr-ops owns the PR lifecycle after the branch is ready."
version: "1.0"
allowed-tools: bash, read, write, edit
---

# pr-ops — pull requests — create, update, check status, request merge

Every agent in Ymir should have this skill. It handles the full PR lifecycle
to the main repo at `zerwiz/ymir`.

## Prerequisites

- `gh` CLI authenticated (`gh auth status` must show ✓)
- A feature branch already pushed (`git-ops` skill handles branch creation)
- The repo remote is set to `https://github.com/zerwiz/ymir.git`

## Commands

### `pr-create` — Open a new PR

```bash
pr-create <branch> [--title "Title"] [--body "Body"] [--reviewer <user>]
```

Creates a PR from `<branch>` → `main` on `zerwiz/ymir`.

- If no `--title` is given, derives one from the branch name.
- If no `--body` is given, generates one from the commit messages.
- Optional `--reviewer` assigns a reviewer (default: the Allfather).

### `pr-update` — Update an existing PR

```bash
pr-update <pr-number> [--title "New title"] [--body "New body"]
```

Updates the PR title and/or body.

### `pr-status` — Check PR status

```bash
pr-status [<pr-number>]
```

Shows CI status, reviews, and mergeability. If no PR number given, shows the
latest PR from the current branch.

### `pr-merge` — Request merge

```bash
pr-merge <pr-number>
```

Marks the PR as ready for merge. **Does not merge** — human approval required.

## Workflow

```
1. git-ops create_branch → feat/my-change
2. Make changes, commit (git-ops safe_commit)
3. git-ops sync_upstream → push + rebase
4. pr-ops pr-create feat/my-change → opens PR
5. pr-ops pr-status → check CI
6. pr-ops pr-merge → request human approval
```

## PR Template

Every PR should include:

```markdown
## What
<One-line description of the change>

## Why
<Why this change is needed>

## Changes
- File1: <what changed>
- File2: <what changed>

## Testing
<How this was tested>

## Checklist
- [ ] Follows Norse naming conventions
- [ ] No secrets in committed files
- [ ] Tests pass (if applicable)
- [ ] Docs updated (if applicable)
```

## Rules

1. **One thing per PR.** A PR does one focused thing.
2. **No secrets.** Never commit `.env.local`, `.env.realm`, API keys, tokens.
3. **Human approval.** No auto-merge. The Allfather must explicitly approve.
4. **Follow git-ops.** Branch creation and commits go through git-ops scripts.
5. **Norse naming.** Name subsystems for the figure whose role matches its work.

## Integration with git-ops

| Skill | Owns |
|-------|------|
| `git-ops` | Branch creation, commits, sync/push |
| `pr-ops` | PR creation, status, merge request |

They are complementary — git-ops prepares the branch, pr-ops opens the PR.
