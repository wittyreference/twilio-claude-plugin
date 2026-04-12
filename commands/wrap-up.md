---
description: End-of-session cleanup and documentation. Use when wrapping up, ending a session, or capturing learnings and pending actions before stopping.
---

# Session Wrap-Up

Review the current session's work and update all relevant documentation before committing.

## Steps

### 1. Gather Session Context

Collect what changed this session:
```bash
git diff --name-only HEAD  # unstaged + staged changes vs last commit
git diff --cached --name-only  # staged changes only
```

### 1b. Mine Commit Messages for Un-Captured Learnings

Check this session's commits for discovery signals that may not have been recorded:

```bash
# Get session start timestamp (check per-session file first, then legacy shared file)
SESSION_DIR={session-dir}
SESSION_START=$(ls -t "$SESSION_DIR"/.sessions/*.start 2>/dev/null | head -1 | xargs cat 2>/dev/null)
if [ -z "$SESSION_START" ]; then
    SESSION_START=$(cat "$SESSION_DIR/.session-start" 2>/dev/null)
fi
# List commits made this session
git log --since="@${SESSION_START}" --format='%h %s' 2>/dev/null
```

Scan commit subjects for learning signal words: `fix`, `discover`, `gotcha`, `quirk`, `workaround`, `bug`, `edge case`, `actually`, `found that`, `regression`, `broken`, `issue`.

For each flagged commit:
1. Check if the topic already appears in the learnings file
2. If not, flag it as a potential un-captured learning

Report flagged commits (if any) before proceeding to step 2:
```
Potential un-captured learnings from commits:
- abc1234: "fix: Verify FriendlyName rejects 5+ digits" — not found in learnings
```

Skip this step if no commits were made this session or none match signal words.

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

### 2b. Learnings Archival (if clearing)

If learnings.md will be cleared (partially or fully):

1. **First**: Append entries being removed to `learnings-archive.md` (same directory, insert below header, above existing entries)
2. **Then**: Remove them from `learnings.md`

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

### 4. Sync Auto-Memory and Shipped Docs

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

**Tag stale entries for auto-removal**: Entries that meet ANY of these criteria should be tagged with `<!-- prune -->` above their `##` header:

- **Session implementation history**: Sections with "(Session N)" that document WHAT was built, not operational patterns needed going forward. The scripts/code they describe are self-documenting.
- **Duplicate of shipped docs**: Content that exists word-for-word in CLAUDE.md or a references file. Replace with a one-line pointer before tagging.
- **Obsolete pointers**: References to plans, roadmaps, or state files that no longer exist.

Example:
```markdown
<!-- prune -->
## Some Stale Section (Session 42)
- Details that are now in shipped docs...
```

**Cross-check learnings and auto-memory**: Ensure nothing fell through the cracks:
- Read the session learnings file — are there entries that should also be in auto-memory (for cross-session persistence)?
- Read auto-memory — are there entries from this session that should also be in the learnings file (for the promote/clear flywheel)?
- Are there auto-memory entries that represent an architectural choice worth recording in design documentation? Signs: "we chose X over Y", "US1 is default because...", "regional requires explicit opt-in".

**Capture inward**: Add session learnings that should persist across sessions to auto-memory at the auto-memory file.

### 5. Update Todo

If the session completed or progressed a tracked task, update the todo file.

### 6. Context Budget Check

Quick health check on auto-loaded context size:

```bash
MEMORY_PATH="$HOME/.claude/projects/$(pwd | sed 's|/|-|g')/memory/MEMORY.md"
wc -l CLAUDE.md "$MEMORY_PATH" 2>/dev/null
```

Report the MEMORY.md line count in the summary. If over 150 lines, flag it — entries beyond 200 are truncated and never seen. Prune by replacing promoted entries with pointers.

### 7. Infrastructure Health Checks

Quick checks that hooks and automation are still working:

**Plan archiving:**
```bash
# Check for recent archived plans
ls -lt .claude/archive/plans/ 2>/dev/null | head -3
```
If plans are not being archived after plan mode exits, verify the `archive-plan.sh` hook is registered under `Stop` in `.claude/settings.json`.

Report any issues in the summary. Skip if healthy.

### 7b. Knowledge Loop Closure

Check the health of the knowledge system and close any open loops:

**Plan index freshness:**
Verify the plan index was updated this session:
```bash
ls -la ~/.claude/plans/INDEX.md 2>/dev/null | head -1
```
If INDEX.md doesn't exist or is older than today, run: `bash hooks/index-plans.sh`

**Feedback loop health:**
Quick check — did this session's pipeline commands use prior knowledge?
- If pipeline commands were run (/architect, /spec, /dev, /test-gen, /review), check if they reported prior knowledge findings in their output
- If no prior knowledge was reported during pipeline runs, note it — the prior knowledge checks may not be firing

### 8. Summary

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

<user_request>
$ARGUMENTS
</user_request>
