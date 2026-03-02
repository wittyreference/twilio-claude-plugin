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

Add entries to the learnings file using the standard format:
```markdown
## [YYYY-MM-DD] Topic

**Discoveries:**

1. **Finding**: What was learned
   - Context and details
```

If a learning is stable and broadly applicable, promote it directly to the target doc (CLAUDE.md, design docs, etc.) and note "Promoted to: [target]" in the learnings entry.

### 3. Update Documentation

For each changed file, determine if documentation needs updating:

| Changed Area | Check These Docs |
|--------------|------------------|
| hooks | relevant documentation |
| voice handlers | voice documentation |
| messaging handlers | messaging documentation |
| ConversationRelay handlers | ConversationRelay documentation |
| MCP server | MCP documentation |
| scripts | scripts documentation |
| Architecture changes | design documentation |
| New slash commands or skills | Root CLAUDE.md slash command table |
| New invariants | project invariants documentation section |

Only update docs where the session's changes actually warrant it. Don't touch docs for unrelated areas.

### 4. Sync Auto-Memory ↔ Shipped Docs

**Promote outward**: Check auto-memory for entries that should be in shipped docs:

| Entry Type | Promote To |
|------------|------------|
| API/SDK gotcha (clear domain) | Domain CLAUDE.md Gotchas section |
| Cross-cutting gotcha | operational gotchas documentation |
| CLI quirk | CLI reference documentation |
| High-impact rule | project invariants documentation |
| Architectural decision (why X over Y) | design documentation |
| Per-developer convention | Keep in auto-memory |

After promoting, replace the detailed item with a pointer (e.g., "See voice docs Gotchas section"). Don't delete — pointers prevent re-discovery of the same gotcha.

**Cross-check learnings ↔ auto-memory**: Ensure nothing fell through the cracks:
- Read the session learnings file — are there entries that should also be in auto-memory (for cross-session persistence)?
- Read auto-memory — are there entries from this session that should also be in the learnings file (for the promote/clear flywheel)?
- Are there auto-memory entries that represent an architectural choice worth recording in design documentation? Signs: "we chose X over Y", "US1 is default because...", "regional requires explicit opt-in".

**Capture inward**: Add session learnings that should persist across sessions to auto-memory at the auto-memory file.

### 5. Update Todo

If the session completed or progressed a tracked task, update the todo file.

### 6. Summary

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
