# Session Wrap-Up

Review the current session's work and update all relevant documentation before committing.

## Steps

### 1. Gather Session Context

Collect what changed this session:
```bash
git diff --name-only HEAD  # unstaged + staged changes vs last commit
git diff --cached --name-only  # staged changes only
```

### 2. Capture Learnings

Review the session's changes and identify anything worth recording:
- Debugging insights or root causes discovered
- API quirks or gotchas encountered
- Patterns that worked (or didn't)
- Configuration pitfalls

Add entries to the project's learnings or documentation using a structured format:
```markdown
## [YYYY-MM-DD] Topic

**Discoveries:**

1. **Finding**: What was learned
   - Context and details
```

If a learning is stable and broadly applicable, promote it directly to the target doc (CLAUDE.md, README, design docs, etc.) and note "Promoted to: [target]" in the learnings entry.

### 3. Update Documentation

For each changed file, determine if documentation needs updating:

| Changed Area | Check These Docs |
|--------------|------------------|
| Voice handlers | Voice-related CLAUDE.md or README |
| Messaging handlers | Messaging docs |
| ConversationRelay | ConversationRelay docs |
| Configuration | README or setup guides |
| Architecture changes | Design docs |
| New commands or skills | README command/skill tables |
| New invariants | Project CLAUDE.md or invariants doc |

Only update docs where the session's changes actually warrant it. Don't touch docs for unrelated areas.

### 4. Update Todo

If the session completed or progressed a tracked task, update the project's todo or task tracker.

### 5. Summary

Output what was updated:

```markdown
## Session Wrap-Up Complete

### Learnings Captured
- [list of entries added]

### Docs Updated
- [list of files modified with brief reason]

### Todo
- [items checked off or updated]

### Ready to Commit
[yes/no — and what to commit]
```

## Notes

- This is a review-and-update pass, not a rewrite. Make targeted edits.
- If nothing meaningful was learned or no docs need updating, say so — don't manufacture busywork.
- The user should review the changes before committing.

## Scope

$ARGUMENTS
