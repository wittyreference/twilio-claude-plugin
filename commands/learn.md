---
description: Knowledge synthesis and articulation practice. Use when user wants to catch up on recent changes, practice explaining decisions, test gotcha knowledge, or build elevator-pitch fluency.
argument-hint: [briefing|decision|gotcha|list|skip|review|generate]
---

# Learning & Knowledge System

Build and maintain deep comprehension of your project — its architecture, decisions, gotchas, capabilities, and evolution.

## Two Mindsets

**Catch-up**: "I've been away. What happened?" → `/learn briefing`
**Depth**: "I need to deeply understand and articulate X." → `/learn decision`, `/learn gotcha`

## Rules

- **Code exercises** (no-args mode): Max 2 per session
- **All other modes**: No session cap — these serve information retrieval and articulation practice
- **Exercise-first, answer-second**: For decision and gotcha modes — pose the challenge BEFORE revealing the answer. This is the generation effect.
- **Source-grounded feedback**: Every piece of feedback cites the actual source document and path
- **Decline = suppress**: Only applies to code exercises, not other modes

## Arguments

<user_request>
$ARGUMENTS
</user_request>

## Mode Dispatch

Parse the first word of `$ARGUMENTS`:

| First word | Mode |
|------------|------|
| *(empty)* | Code exercises (existing behavior) |
| `briefing` or `catch-up` or `catchup` | Briefing |
| `decision` | Decision deep-dive |
| `gotcha` | Gotcha scenario exercise |
| `quiz` | Rapid-fire knowledge check |
| `list` | List pending exercises |
| `skip` | Suppress code exercises |
| `review` | Retrieval practice |
| `generate` | Generate exercises |

---

## Mode: Code Exercises (no arguments)

1. Look for recent commits from autonomous work (subagents, orchestrate, headless)
2. Identify 2-3 interesting design decisions, patterns, or non-obvious code in the changed files
3. Generate exercise questions on the spot from the most recent autonomous changes
4. Present the list and ask which one to work on
5. When the user picks one, present the exercise question and STOP. Wait for their response.
6. After their response, provide feedback:
   - Read the actual file referenced in the exercise
   - Compare their prediction/understanding to what the code actually does
   - If they were wrong, say so directly, explain the gap, explore why
   - If they were right, confirm and optionally add deeper context

---

## Mode: Briefing

"What happened while I was away?"

### Parse arguments

After the `briefing` keyword, check for:
- `Nd` (e.g., `5d`) → use N days as the window
- `since YYYY-MM-DD` → use that date as the start
- Nothing → default to 3 days ago

### Gather (read-only)

1. **Git log**: Run `git log --oneline --since="YYYY-MM-DD" --no-merges`. Group commits by conventional prefix:
   - `feat:` → Features
   - `fix:` → Fixes
   - `docs:` → Documentation
   - `refactor:` / `chore:` / `style:` / `test:` → Maintenance
   - Unprefixed → Other

2. **New design decisions**: Check for changes to `DESIGN_DECISIONS.md` if it exists.

3. **New learnings**: Check learnings file for entries within the window.

### Synthesize and present

```markdown
## Briefing: [start date] → [today]

### Headlines
- [most significant change — a feature, decision, or finding]
- [second most significant]
- [third if warranted]

### Commits ([N] total)
**Features**: [one line per feat: commit]
**Fixes**: [one line per fix: commit]
**Docs/Maintenance**: [one line per remaining commit, or "N docs, N refactors"]

### New Design Decisions
- D[N]: [title] — [one-line rationale]
(or "None in this period")

### New Learnings
- [date]: [topic] — [one-line summary]
(or "None captured")
```

After presenting: "Want to drill into any of these? Pick a number, topic, or decision."

---

## Mode: Decision Deep-Dive

"Help me deeply understand and explain a design decision."

### Parse arguments

After the `decision` keyword:
- A number (e.g., `1`, `13`, `45`) → look up that specific decision
- A keyword (e.g., `mcp`, `risk`, `tdd`) → grep `DESIGN_DECISIONS.md` for matching decision titles
- Nothing → show the full decision index

### Specific decision: Teaching Format

1. Read the specific decision section from `DESIGN_DECISIONS.md`
2. Restructure into teaching format:

```markdown
## Decision [N]: [Title]

### The Problem
[Restate the Context section in plain language — what situation forced this choice?]

### What We Chose
[The Decision, stated succinctly]

### Why (The Trade-Off)
[The Rationale — emphasize what we GAVE UP by choosing this. Every decision has a cost.]

### What This Means in Practice
[The Consequences section, with concrete examples of how this decision shows up in the codebase]

### Elevator Pitch (2 sentences)
[A concise articulation suitable for explaining to an SME in a hallway conversation]
```

3. Pose a comprehension exercise. Pick one:
   - "If someone asked you [scenario that tests understanding of the trade-off], what would you say?"
   - "Someone proposes [alternative that this decision rejected]. What's your counterargument?"
   - "When would this decision be WRONG? Under what circumstances should we revisit it?"

4. **STOP and wait for the user's response.**

5. After the user responds, provide feedback:
   - Compare their answer to the documented rationale and consequences
   - Cite specific passages from the decision document
   - If they missed the key trade-off, highlight it directly
   - If they nailed it, confirm and add nuance from related decisions

---

## Mode: Gotcha Scenario Exercise

"Test whether I've internalized our operational gotchas."

### Parse arguments

After the `gotcha` keyword:
- A domain name (e.g., `voice`, `sip`, `verify`, `serverless`, `cli`, `mcp`, `sync`, `taskrouter`, `video`) → scope to that domain
- A specific topic keyword → search across gotcha sources for matches
- Nothing → pick a random gotcha

### Gather gotchas

Search project documentation for gotcha entries — skill files, invariant rules, operational references.

### Present as scenario

DO NOT reveal the gotcha. Instead, construct a realistic debugging scenario:

1. Read the gotcha entry fully to understand the mechanism
2. Frame it as a situation the user might encounter:
   - "You just deployed [X] and [symptom]. The code looks correct. What's happening?"
   - "A customer reports [symptom] but only on [condition]. Where would you look?"
   - "Your [operation] returns [error code]. The docs say this means [X], but that doesn't match your setup. What's actually going on?"
3. **STOP and wait for the user's response.**

### Provide feedback

After the user responds:
- If they identified the gotcha (or close enough): Confirm, add the deeper context and mechanism from the source
- If they missed it: Reveal the gotcha directly, explain the mechanism, quote the relevant source
- Cross-reference: If related gotchas exist, mention them
- Cite the source document and path

---

## Mode: Quiz

"Quick self-test across knowledge areas."

### Parse arguments

After `quiz`: optional topic keyword to scope questions. No argument = sample across all sources.

### Generate 5 questions

Draw from multiple knowledge sources:
1. A design decision question: "What did we decide about [X] and why?"
2. A gotcha question: "What happens if [scenario]?"
3. A quantitative question: "How many [X] does the project have?"
4. A capability question: "What does [feature] do?"
5. A recent-change question: "What changed in the last week regarding [area]?" (requires git log)

Present all 5 at once. STOP. Wait for the user to answer (brief answers are fine).

Score and provide corrections for each miss. Cite sources.

---

## Mode: List

Show potential exercises derived from recent autonomous commits without starting one. Include:
- Exercise type (Prediction, Generation, Trace, Debug)
- File path
- What changed

---

## Mode: Skip

Suppress code exercises for this session. Confirm: "Code exercises suppressed for this session. Other modes still available: `/learn briefing`, `/learn decision`, `/learn gotcha`."

---

## Mode: Review

Retrieval practice on code you've worked with before:
1. Pick a file the user has modified or reviewed recently
2. Ask a recall question about its behavior — NOT a reading comprehension question, a prediction question
3. STOP and wait for the user's response
4. Provide feedback by reading the actual code

---

## Mode: Generate

Force generation of exercises from recent git history:
1. Read recent commits for autonomous work patterns
2. Identify design decisions, non-obvious patterns, edge cases
3. Present generated exercise questions

---

## Important

- The exercise question is the point of engagement. Never dilute it with hints or partial answers before the user responds.
- Be direct in feedback. If the user's understanding is wrong, say so. Genuine correction is more valuable than false validation.
- Always cite the source document and path when providing feedback.
- For `/learn briefing`, prefer concise synthesis over exhaustive data dumps.
