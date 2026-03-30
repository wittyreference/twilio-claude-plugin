---
name: "ivr-migrator"
description: "Twilio development skill: ivr-migrator"
---

---
name: ivr-migrator
description: Generate Twilio Serverless Functions from an IVR crawler tree JSON. Use when migrating an IVR to Twilio, rebuilding an IVR from a crawl, or generating IVR functions from structured data.
---

# IVR Migrator

Takes an IVR tree JSON (produced by `/ivr-crawler`) and generates Twilio Serverless Functions that replicate the original IVR. The migrator feeds the tree as requirements into the standard pipeline — `/architect` → `/spec` → `/test-gen` → `/dev` → `/review` → `/docs`.

This is NOT a template engine. Claude Code writes all functions using the full twilio-feature-factory tooling: voice skill, serverless invariants, TwiML patterns, hooks, learnings, and testing conventions.

## Scope

### CAN
- Read an IvrTree JSON file and understand its structure
- Accept VoiceXML documents as input (parsed via `vxml-parser.ts` into IvrTree IR)
- Generate Twilio Serverless Functions for each menu/node in the tree
- Produce `<Gather>`, `<Say>`, `<Play>`, `<Record>`, `<Redirect>`, `<Hangup>` TwiML
- Handle multi-language IVRs (per-node voice selection)
- Generate business hours helpers from `hours_check` nodes
- Generate retry/timeout logic matching the original IVR behavior
- Generate unit tests for all handlers via TDD pipeline
- Deploy the migrated IVR via `twilio serverless:deploy`
- Generate VXML from crawl output for customer verification (via `vxml-generator.ts`)

### CANNOT
- Replicate authentication flows (account number entry, PIN verification)
- Reproduce exact hold music (uses generic Twilio hold music URL)
- Clone agent transfer destinations (generates placeholder `<Dial>` or CR TwiML)
- Handle IVR nodes marked as `error` or `unknown` in the crawl
- Generate code without going through the pipeline (architect → spec → test-gen → dev)

## Workflow

### Step 1: Load the IVR Tree

```
/ivr-migrator path/to/ivr-tree.json
# or from VXML:
/ivr-migrator path/to/ivr.vxml
```

Accepts two input formats:
1. **IvrTree JSON** (from `/ivr-crawler`) — used directly
2. **VoiceXML document** — parsed via `vxml-parser.ts` into IvrTree IR first

Read the input and present a summary:
- Total nodes and node types
- Languages detected
- Max depth
- Estimated files to generate

### Step 2: Plan the Migration (via /architect)

Feed the tree to `/architect` with these requirements:

> Generate Twilio Serverless Functions that replicate this IVR tree.
> Follow existing patterns from `ivr-welcome.js` and `ivr-menu.protected.js`.
> Place files under `migrated-ivr/` (or user-specified path).
> Each `menu` node becomes a handler with `<Gather>` and `classifyMenuSelection()`.
> Each `information`/`dead_end` node becomes a `<Say>` + `<Hangup>` handler.
> Each `transfer` node becomes a `<Dial>` or placeholder handler.
> Each `hours_check` node gets business hours logic via a private helper.
> Each `callback` node gets `<Record>` with proper action URL.
> Root handler is `.js` (public), all sub-handlers are `.protected.js`.

The architect produces a file inventory and routing table.

### Step 3: Generate Tests and Implementation (via pipeline)

Run the standard pipeline:
1. `/spec` — Detailed spec per handler from the architect output
2. `/test-gen` — Failing tests for all handlers (TDD Red)
3. `/dev` — Implement handlers to pass tests (TDD Green)
4. `/review` — Code review
5. `/docs` — CLAUDE.md for the migrated IVR directory

### Step 4: Deploy and Validate

1. `twilio serverless:deploy`
2. Configure a phone number to point to the migrated IVR's welcome handler
3. Call it manually to verify
4. Optionally, run `/ivr-crawler` against the migrated IVR and compare trees

## Node-to-TwiML Mapping

| IvrNode.nodeType | Generated TwiML | File Pattern |
|------------------|----------------|--------------|
| `root` / `menu` | `<Gather input="dtmf speech"><Say>` | `welcome.js` / `*.protected.js` |
| `information` | `<Say>` message + `<Hangup>` or `<Redirect>` | `*.protected.js` |
| `dead_end` | `<Say>` + `<Hangup>` | inline in parent handler |
| `transfer` | `<Say>` hold + `<Dial>` or CR connect | `agent-transfer.protected.js` |
| `hold_music` | `<Play>` + timeout `<Say>` + `<Hangup>` | inline in parent |
| `callback` | `<Say>` + `<Record action="?afterRecord=true">` | `*.protected.js` |
| `hours_check` | JS time logic → open/closed branch | `*.protected.js` + helper |
| `voicemail` | `<Record>` + action handler | `*.protected.js` |

## Voice Selection

Map the `language` field from each node to a Polly voice:

| Language | Voice | TwiML language |
|----------|-------|---------------|
| `en` | `Polly.Amy` | `en-GB` |
| `es` | `Polly.Lupe` | `es-US` |
| `fr` | `Polly.Lea` | `fr-FR` |
| other | `Polly.Amy` | `en-US` |

## Handling Edge Cases in the Tree

| Tree Condition | Migration Strategy |
|----------------|-------------------|
| Node with `confidence < 0.5` | Add a `// LOW CONFIDENCE` comment, implement best-guess |
| `error` type node | Skip — add comment noting the crawl error |
| `unknown` type node | Generate a `<Say>` with the raw prompt text + `<Hangup>` |
| Cycle (node with empty edges + redirect summary) | Generate `<Redirect>` to the referenced node's handler |
| Very deep tree (>5 levels) | Flatten where possible; menus with single options can be inlined |

## Gotchas

1. **Prompt text is transcribed, not exact**: The crawler captures STT output, not the original TTS text. The migrated `<Say>` content will be a close approximation, not verbatim.
2. **Business hours are detected, not replicated**: `hours_check` nodes note that business hours logic exists, but the exact schedule comes from the `businessHoursInfo` field if Claude detected it. May need manual verification.
3. **Hold music URLs**: The original IVR's hold music is not captured. Use `https://api.twilio.com/cowbell.mp3` or ask the user for their music URL.
4. **Agent transfers need configuration**: `transfer` nodes generate placeholder `<Dial>` TwiML. The actual agent phone number or ConversationRelay URL must be configured by the user.
5. **Pipeline enforcement**: The pre-write hook blocks new `functions/*.js` without tests. The migrator MUST go through `/test-gen` → `/dev`. No shortcuts.

## Related Resources

- **IVR Crawler**: `/ivr-crawler` — produces the input tree JSON
- **Tree Schema**: `skills/ivr-crawler/references/tree-schema.md` — IvrTree JSON format
- **Voice Patterns**: `ivr-welcome.js`, `ivr-menu.protected.js` — existing IVR patterns to follow
- **Test IVR**: `test-ivr/CLAUDE.md` — reference implementation of a complex IVR

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| IvrTree JSON schema | `skills/ivr-crawler/references/tree-schema.md` | Before reading crawl output |
| Node-to-TwiML rules | `references/generation-rules.md` | During architect/spec phase |
