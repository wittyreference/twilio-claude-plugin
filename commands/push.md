---
description: Push changes via pull request. Use when user wants to push, upload, or sync changes to GitHub.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(npm:*), Read, Grep, AskUserQuestion
---

# Push via Pull Request

Push changes to remote through a PR workflow. Never pushes directly to main — always creates a PR, waits for CI, and merges.

## Pre-Push Checks

Run these checks before pushing. Stop and report if any fail.

### 1. Uncommitted Changes

```bash
git status
```

If there are uncommitted changes, warn the user and suggest `/commit` first.

### 2. Test Suite

```bash
npm test
```

All tests must pass before pushing.

### 3. gh CLI

Verify `gh` is installed and authenticated:

```bash
gh auth status
```

If not authenticated, tell the user to run `! gh auth login`.

## Determine Push Strategy

Check the current branch and unpushed commits:

```bash
BRANCH=$(git branch --show-current)
git fetch origin main
UNPUSHED=$(git log --oneline origin/main..HEAD)
```

### If on main with unpushed commits

1. **Show the commits** and ask the user: push all as one PR (default), or specify a subset?
2. **Create PR branch** from `origin/main`:
   ```bash
   git checkout -b <branch-name> origin/main
   git cherry-pick <commit1> <commit2> ...
   ```
   Branch naming: derive from commit messages using conventional format (`feat/thing`, `fix/thing`, `docs/thing`). For mixed types, use the dominant one.
3. **Push the branch**: `git push -u origin <branch-name>`
4. **Switch back to main**: `git checkout main`
5. Continue to **Create PR** below.

### If on a feature/worktree branch

1. **Push the branch**: `git push -u origin <branch-name>`
2. **Check for existing PR**:
   ```bash
   gh pr view --json number,state 2>/dev/null
   ```
   If a PR already exists and is open, skip to **Wait for CI**.
3. Continue to **Create PR** below.

### If no unpushed commits

Report "Nothing to push" and stop.

## Create PR

Generate a PR title and body from the commits:

```bash
gh pr create \
  --title "<title>" \
  --body "<body>" \
  --base main
```

**Title**: For 1-commit PRs, use the commit message. For multi-commit, write a summary in conventional commit style.

**Body**: Include:
- `## What` — brief description of changes
- `## Why` — motivation (derive from commit messages)
- Commit list if multi-commit

## Wait for CI

```bash
gh pr checks <pr-number>
```

Report results. If checks are still running, tell the user and ask if they want to check again. Do NOT poll in a loop.

- All pass → proceed to **Merge**
- Any fail → report failures, stop

## Merge

Ask the user for confirmation, then:

```bash
gh pr merge <pr-number> --merge --delete-branch
```

After merge, sync local main:

```bash
git stash          # if needed (check git status first)
git pull --rebase origin main
git stash pop      # if stashed
```

## Output

```
## Push Complete

PR: #<number> (<url>)
Branch: <branch-name>
CI: <all passed / N checks passed>
Status: <merged / awaiting CI / awaiting merge>

Commits:
- <sha> <message>

Total: <count> commits

In a worktree? Use /ship next time to handle commit → PR → merge → worktree exit in one step.
```

## Push Target

<user_request>
$ARGUMENTS
</user_request>
