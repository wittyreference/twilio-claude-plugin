---
description: Land changes end-to-end — commit, PR, CI, merge, exit worktree. Use when work is done and ready to merge.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(npm:*), Bash(npx:*), Read, Grep, Edit, ExitWorktree
---

# Ship It

Full lifecycle: commit → push → PR → CI → merge → exit worktree. The "I'm done, land it" command.

## Prerequisites

### 1. Worktree Check

```bash
BRANCH=$(git branch --show-current)
```

If the branch is `main`, warn: "/ship is designed for worktree branches. Use /commit + /push for main, or start a worktree with /worktree-start."

### 2. gh CLI

```bash
gh auth status
```

If not authenticated, tell the user to run `! gh auth login`.

## Phase 1: Commit (if needed)

Check for uncommitted changes:

```bash
git status --porcelain
```

If there are staged or modified tracked files, run the `/commit` workflow:

1. **TypeScript check** (if applicable): `cd agents/mcp-servers/twilio && npx tsc --noEmit`
2. **Test suite**: `npm test --bail`
3. **ABOUTME comments** on new files
4. **Stage and commit** with conventional message

If the user provided arguments (e.g., `/ship fix the ngrok port`), use them as commit message context.

If there are no uncommitted changes, skip to Phase 2.

## Phase 2: Push and PR

### Push the branch

```bash
git push -u origin "$BRANCH"
```

### Check for existing PR

```bash
gh pr view --json number,state,url 2>/dev/null
```

If a PR already exists and is open, skip to Phase 3.

### Create PR

Generate title and body from the commits on this branch:

```bash
COMMITS=$(git log --oneline origin/main.."$BRANCH" 2>/dev/null || git log --oneline main.."$BRANCH")
```

```bash
gh pr create \
  --title "<conventional commit title>" \
  --body "<body>" \
  --base main
```

**Body** includes:
- `## What` — brief description
- `## Why` — motivation from commit messages
- Commit list if multi-commit

## Phase 3: Wait for CI

Enable auto-merge so we don't need to poll:

```bash
gh pr merge <pr-number> --auto --merge
```

Then check current CI status once:

```bash
gh pr checks <pr-number>
```

Report the status:
- **All passed + auto-merge enabled** → "PR will merge automatically when branch protection is satisfied."
- **Checks still running** → "Auto-merge enabled. CI is running — PR will merge when checks pass."
- **Any failed** → Report failures and stop. Do NOT exit the worktree on failure.

## Phase 4: Exit Worktree

Only proceed here if CI passed or auto-merge is enabled (no failures).

Exit the worktree cleanly:

```
ExitWorktree(action: "remove", discard_changes: true)
```

The `discard_changes: true` is safe because all commits are pushed and the PR has auto-merge enabled. The worktree-only artifacts (`.env` copy, `.meta` symlink, `.last-active`) are expected uncommitted files.

After exiting, pull the latest main:

```bash
git pull --rebase origin main
```

## Phase 5: Confirm

Wait briefly, then check if the PR merged:

```bash
gh pr view <pr-number> --json state,mergedAt
```

## Output

```
## Shipped

PR: #<number> (<url>)
Branch: <branch-name>
Commits: <count>
CI: <passed / auto-merge pending>
Status: <merged / auto-merge enabled>

Worktree: cleaned up
Local main: up to date
```

## Error Recovery

- **CI fails**: Stop before worktree exit. Report failures. User stays in worktree to fix.
- **Merge conflict**: Report conflict. User stays in worktree to resolve.
- **No commits**: "Nothing to ship — no commits on this branch."
- **Already on main**: Suggest `/commit` + `/push` instead.

## Ship Target

<user_request>
$ARGUMENTS
</user_request>
