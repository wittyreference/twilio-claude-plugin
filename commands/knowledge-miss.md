---
description: Log a knowledge miss event for tracking. Use when Claude should have known something but didn't.
allowed-tools: Bash, Read, Grep
argument-hint: [description of what was missed]
---

# Knowledge Miss Logger

Log a knowledge miss event — when Claude should have had context from prior work but didn't.

## Input

<user_request>
$ARGUMENTS
</user_request>

## Behavior

1. **Classify the miss** into one of these categories:
   - `semantic_gap` — Content exists in the codebase but keyword search wouldn't find it (e.g., searched for "auth" but answer was in a file about "identity verification")
   - `not_in_memory` — Content was never captured in memory files or docs
   - `cross_repo` — Content exists in a sibling repo
   - `stale` — A memory entry exists but is outdated or wrong
   - `plan_archaeology` — The answer was in a plan file but the plan wasn't discoverable

2. **Identify the resolution** — briefly note where the information was eventually found (or if it wasn't found at all).

3. **Log the event** — record the knowledge miss with timestamp, category, description, and resolution to a local log file:

```bash
mkdir -p .claude/logs
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"type\":\"knowledge_miss\",\"category\":\"CATEGORY\",\"description\":\"DESCRIPTION\",\"resolution\":\"RESOLUTION\"}" >> .claude/logs/knowledge-misses.jsonl
```

4. **Confirm** to the user: "Knowledge miss logged: [category] — [description]"

## Query

To review collected data, run:
```bash
cat .claude/logs/knowledge-misses.jsonl 2>/dev/null | jq -s 'group_by(.category) | map({category: .[0].category, count: length})' 2>/dev/null || echo "No knowledge misses logged yet"
```

## Purpose

This data helps identify gaps in project documentation. If knowledge misses are frequent, it signals that documentation needs improvement. Categories help identify whether the issue is missing docs, stale docs, or poor discoverability.
