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

## Orange Migration Reference (2026-04-06)

The Orange Utility IVR migration serves as the canonical reference for migrating a real-world payment IVR. 22 handlers, 247 tests, deployed to `prototype-orange` service.

### Key Architectural Decisions

1. **Single handler set with `variant` query parameter** — Both DTMF and Voice+DTMF variants share identical flow logic. A `variant=dtmf|voice` param controls Gather config and prompt text. Produces 22 handlers instead of 44.

2. **Entry+confirm as one handler with `phase` parameter** — Account, ZIP, amount, card, routing, and bank account entry all follow an enter→readback→confirm/re-enter loop. `phase=entry|confirm` keeps each unit in one file. `enteredValue` passes between phases via query string.

3. **PPM via `ppm=true` query parameter** — Pre-paid meter variant skips the payment-method handler. Structural hook for phone-number-specific behavior.

4. **Top-level `` directory** — `services.json` only supports single-level directory names. URL paths: `/orange/welcome`. Do NOT use `orange/`.

5. **Even/odd amount logic** — `payment-result.protected.js` checks `parseInt(amount) % 2 === 0` to determine success vs decline. Matches the test system's behavior.

### Handler Inventory (22 total)

Core: welcome, account-entry, zip-entry, balance-info, payment-menu, amount-entry, payment-method
Card: card-entry, card-expiry, card-cvv, card-zip
Bank: bank-notice, bank-type, bank-routing, bank-account
Shared: payment-confirm, payment-processing, payment-result
Error: account-not-found, card-blocked, error-max-retries, transfer

### Reference Files
- Handlers: ``
- Tests: `__tests__/unit/orange/`
- Crawl data: `ivr-maps/orange-*.json`
- CLAUDE.md: `CLAUDE.md`

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

| `input_entry` | `<Gather finishOnKey="#"><Say>` + confirm phase | `*.protected.js` (phase=entry/confirm) |
| `payment_auth` | `<Gather numDigits=1><Say>` (press 1/2/9) | `payment-confirm.protected.js` |
| `payment_processing` | `<Say>` + `<Pause>` + `<Redirect>` | `payment-processing.protected.js` |
| `payment_result` | JS amount parity check → success `<Say>` or decline `<Gather>` | `payment-result.protected.js` |
| `bank_menu` | `<Gather numDigits=1><Say>` (multi-step via `step` param) | `bank-type.protected.js` |

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
6. **`services.json` directory depth**: Only single-level directory names work. `voice/orange` fails because the deploy script can't create nested symlinks. Use `orange` (→ ``) as a top-level directory.
7. **Deploy env var size limit**: Twilio Serverless has a 3583-byte context size limit for environment variables. Services that don't need env vars (pure TwiML generators) should deploy with a minimal `.env` containing only `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN`.
8. **classifyConfirmation must check 'incorrect' before 'correct'**: The word "incorrect" contains "correct" as a substring. If you check `includes('correct')` first, speech like "no that is incorrect" matches the wrong branch. Always check negative keywords before positive ones.
9. **Query parameter propagation**: Every handler must propagate `variant`, `ppm`, `amount`, and other state through redirect and Gather action URLs. Use a `buildQs()` helper that filters empty values.
10. **Voice variant Gather config**: DTMF uses `input: 'dtmf'`, `numDigits: N`. Voice uses `input: 'dtmf speech'`, `speechTimeout: 'auto'`, plus `hints` for each Gather. Both share the same handler logic.

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
