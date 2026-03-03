---
name: twilio-invariants
description: Proven debugging gotchas from real Twilio development. Load at session start to avoid common pitfalls with TwiML, Functions, ConversationRelay, and deployment.
---

# Twilio Architectural Invariants

Rules that have each caused real debugging time loss. These are proven gotchas that affect any Twilio developer. Load this skill at the start of any Twilio development session.

---

Rules that have each caused real debugging time loss. These exist in domain-specific CLAUDE.md files — this index ensures they're loaded every session.

- **`Twilio.Response.setBody()` requires strings** — Passing objects causes `Buffer.from(object)` TypeError. Always `JSON.stringify()` + Content-Type header. (~29 latent instances across voice/ and conversation-relay/)
- **`console.error()` → 82005 alerts** — Use `console.log()` for operational logging. Only `console.error()` in catch blocks. `console.warn()` → 82004.
- **ConversationRelay uses `last`, not `isFinal`** — Protocol sends `{ last: true }`. Checking `isFinal` silently drops all follow-up utterances.
- **Env vars can reset on deploy** — `twilio serverless:deploy` doesn't preserve runtime env vars. Always verify after deployment.
- **CLI profile and `.env` are independent** — CLI profile can point to main account while `.env` has subaccount SID. Check both before operations.
- **TwiML: one document controls a call at a time** — Updating a participant's TwiML exits their current state (conference, queue). Exception: `<Start><Stream>`, `<Start><Recording>`, `<Start><Siprec>` fork background processes.
- **Voice Intelligence: `source_sid`, not `media_url`** — Use Recording SID for transcript creation. `media_url` requires auth the Intelligence API can't provide.
- **Google Neural voices for ConversationRelay** — Polly voices may be blocked (error 64101). Use `Google.en-US-Neural2-F` as default.
- **`<Start><Recording>` syntax is `.recording()`, not `.record()`** — `twiml.start().recording({...})` is correct.
- **MCP server inherits env at launch, not runtime** — Changing `.env` or exporting variables mid-session does NOT update MCP tools. Must restart Claude Code entirely.
- **`source .env` doesn't undo commented-out vars** — Shell retains values after commenting out lines. Must explicitly `unset` each variable before re-sourcing.
- **SDK auto-reads `TWILIO_REGION`/`TWILIO_EDGE` from env** — Setting these in `.env` silently routes all API calls to regional endpoints even when not passed to the constructor. US1 auth tokens fail with 401 on regional endpoints. Comment out when not actively testing regions.
- **Empty `voiceUrl` on a Twilio number = silent instant call failure** — Calling a number with `voiceUrl: ""` produces `status: failed, duration: 0` with ZERO diagnostics (no debugger alerts, no notifications, no error codes). Indistinguishable from auth failures or account blocks. Always verify destination webhooks via `list_phone_numbers` before debugging call routing.
- **dotenv default mode doesn't override shell vars** — `require('dotenv').config()` skips vars already in `process.env`. Use `{ override: true }` so `.env` always wins over inherited shell vars. Without this, users with pre-existing Twilio env vars from other projects hit silent auth failures.

# Session discipline

- Do not convert lazy/conditional `require()` calls to static `import` statements without verifying the conditional logic still works. Node.js conditional requires exist for a reason (optional dependencies, environment-specific loading).
- Run the full relevant test suite before presenting work as complete. A passing subset is not sufficient — regressions in unrelated tests still need to be caught.
- After modifying TypeScript files, run `tsc --noEmit` in the relevant package to verify compilation before committing.

# Testing

- Tests MUST cover the functionality being implemented.
- NEVER ignore the output of the system or the tests - Logs and messages often contain CRITICAL information.
- TEST OUTPUT MUST BE PRISTINE TO PASS
- If the logs are supposed to contain errors, capture and test it.
- NO EXCEPTIONS POLICY: Under no circumstances should you mark any test type as "not applicable". Every project, regardless of size or complexity, MUST have unit tests, integration tests, AND end-to-end tests. If you believe a test type doesn't apply, you need the human to say exactly "I AUTHORIZE YOU TO SKIP WRITING TESTS THIS TIME"
- We practice TDD: write tests first, make them pass, refactor.

---

## When to Reference This Document

- **Session start**: Skim the full list as a refresh
- **Debugging silent failures**: Check if your issue matches an invariant
- **Code review**: Verify none of these patterns appear in new code
- **ConversationRelay work**: `last` vs `isFinal` and Google voices are critical
- **Deployment**: Env var reset and CLI/env independence are critical
- **Voice Intelligence**: `source_sid` vs `media_url` is critical
- **TwiML generation**: `setBody()` strings, one-doc-at-a-time, `.recording()` syntax are critical
