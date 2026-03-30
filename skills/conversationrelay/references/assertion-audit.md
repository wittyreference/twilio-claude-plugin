---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit log for ConversationRelay skill. -->
<!-- ABOUTME: 280 assertions extracted, pressure-tested, and verdicted with SID evidence. -->

# Assertion Audit Log

**Skill**: conversationrelay
**Audit date**: 2026-03-28
**Account**: ACb4de2...
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 267 |
| CORRECTED | 2 |
| QUALIFIED | 8 |
| REMOVED | 3 |
| **Total** | **280** |

## High-Risk Assertions (Detailed Verdicts)

These assertions were flagged during extraction as most likely to be wrong and received focused scrutiny.

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 48 | Default TTS provider is `ElevenLabs` | Default | QUALIFIED | CA05cc0dab (64101 `block_elevenlabs`) | Docs say ElevenLabs but accounts without enablement get blocked. Added caveat: "effective default is account-dependent. Use explicit `ttsProvider` always." |
| 59 | Using `Google.en-US-Chirp3-HD-Aoede` causes error 64101 | Error | CORRECTED | CA11513868 (bare name works) | Only tested bare name working, NOT prefixed version failing. Softened to: "Bare name confirmed working. Deepgram skill and codebase patterns also document this convention." |
| 123 | `confidence` field is absent from prompt messages | Behavioral | CONFIRMED | CAb74ac380, CA9819c407, all 12 calls | Zero instances of `confidence` field across 12 test calls and hundreds of prompt messages. Domain CLAUDE.md referenced it but it is not in current protocol. |
| 32-33 | Default STT provider depends on account creation date (pre/post Sept 2025) | Default | QUALIFIED | — | Documented by Twilio but cannot be directly verified without accounts of different ages. Added note: "Code without explicit `transcriptionProvider` may behave differently across accounts." |
| 183 | 10 consecutive malformed messages terminate session | Error | QUALIFIED | — | Documented by Twilio, cross-referenced in error 64105 description. Not directly tested (would require sending 10 bad messages). Kept as doc-referenced claim. |
| 187 | WebSocket close code 1000 = normal close | Behavioral | CONFIRMED | Test 1-12 (all show `ws-close: {"code": 1000, "reason": "Closing websocket session"}`) | Observed on every clean call termination. |
| 188 | WebSocket close code 1007 = malformed messages | Error | QUALIFIED | — | Documented by Twilio, not directly tested. Kept with doc-reference caveat. |
| 40 | `<Connect>` blocks subsequent TwiML verbs | Architectural | CONFIRMED | All test calls (recording before Connect works; nothing after executes) | Standard TwiML behavior, confirmed by recording pattern working only when placed BEFORE `<Connect>`. |
| 27 | Cannot mix `<Connect><Stream>` and `<Connect><ConversationRelay>` | Scope | QUALIFIED | — | Documented as architectural constraint. Not tested (would require attempting both on same call). Kept as doc-referenced. |
| 234 | AI/ML Features Addendum must be enabled in Console | Scope | QUALIFIED | — | Documented prerequisite. Not testable without a fresh account. Kept as doc-referenced. |
| 242-244 | `console.error()` → 82005, `console.warn()` → 82004 | Error | QUALIFIED | — | Twilio Functions behavior, not ConversationRelay-specific. Cross-referenced from serverless-invariants.md. Kept as cross-reference. |

## Live-Tested Assertions (Representative Sample)

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 1 | CR provides real-time bidirectional text communication | Behavioral | CONFIRMED | All 12 test calls |
| 5 | Welcome greeting with configurable interruptibility | Behavioral | CONFIRMED | CA8afda66f (Test 3) |
| 6 | `partialPrompts` delivers progressive transcripts | Behavioral | CONFIRMED | CA9819c407 (Test 5) — 49 events |
| 7 | Audio playback via `play` message works | Behavioral | CONFIRMED | CAf68b4236 (Test 11) — 0 errors |
| 9 | `intelligenceService` creates transcript from CR session | Behavioral | CONFIRMED | CAb46f3db6 → GTa86955e6 |
| 10 | Debug telemetry produces `type: "info"` messages | Behavioral | CONFIRMED | CA235cd451 (Test 2) — 46 events |
| 11 | X-Twilio-Signature on WebSocket handshake | Behavioral | CONFIRMED | CA (all) — header present on every upgrade |
| 13 | Session handoff with `handoffData` to action callback | Behavioral | CONFIRMED | CA92eb48b1 (Test 10) |
| 30 | ElevenLabs requires account enablement | Error | CONFIRMED | CA05cc0dab (Test 4) — `block_elevenlabs` |
| 84 | `reportInputDuringAgentSpeech` delivers prompts during TTS | Behavioral | CONFIRMED | CAeebc1434 (Test 7) |
| 86 | `preemptible` attribute accepted | Behavioral | CONFIRMED | CA890fc3d2 (Test 8) — 0 errors |
| 89 | `intelligenceService` accepts GA SID | Behavioral | CONFIRMED | CAb46f3db6 (Test 9) |
| 92-96 | `debug` three channels: roundTripDelayMs, speaker-events, tokens-played | Behavioral | CONFIRMED | CA235cd451 (Test 2) |
| 107 | Setup `sessionId` is VX SID | Behavioral | CONFIRMED | All calls — VX prefix observed |
| 121 | Prompt `lang` field present | Behavioral | CONFIRMED | All calls — `"lang": "en-US"` |
| 166 | `sendDigits` works | Behavioral | CONFIRMED | CAec5f70f5 (Test 12) — 0 errors |
| 265-267 | `SessionStatus` differs by end reason | Behavioral | CONFIRMED | Test 1 (`completed`) vs Test 10 (`ended`) |

## Corrections Applied

### Correction 1: Chirp3-HD prefix error claim (Assertion #59)

- **Original text**: "Using `Google.en-US-Chirp3-HD-Aoede` causes error 64101."
- **Corrected text**: "Bare name `en-US-Chirp3-HD-Aoede` confirmed working. The Deepgram skill and codebase patterns also document this convention."
- **Why**: We only tested the bare name succeeding (CA11513868), not the prefixed version failing. The original claimed a specific error without evidence of that error.

### Correction 2: SKILL.md Gotcha #2 wording

- **Original text**: "Use `en-US-Chirp3-HD-Aoede`, NOT `Google.en-US-Chirp3-HD-Aoede`."
- **Corrected text**: Left as recommendation based on confirmed working pattern and cross-referenced convention, but noted evidence is for bare name working, not prefixed failing.
- **Why**: Same as Correction 1. The recommendation is sound (bare name IS the documented convention), but the negative claim lacked direct evidence.

## Qualifications Applied

### Qualification 1: Default TTS provider (Assertion #48)

- **Original text**: "Default is `ElevenLabs`"
- **Qualified text**: "`ElevenLabs` (per docs; see caveat) — accounts without access get `block_elevenlabs` (64101), so effective default is account-dependent. Use explicit `ttsProvider` always."
- **Condition**: Accounts without ElevenLabs enablement cannot use the documented default.

### Qualification 2: Default STT provider account-age dependency (Assertions #32-33)

- **Original text**: "Deepgram (post-Sept 2025 accounts)"
- **Qualified text**: Added explicit note in SKILL.md Gotcha #5 about cross-account behavior differences.
- **Condition**: Cannot verify account creation date dependency without multiple accounts of different ages.

### Qualification 3: `<Connect><Stream>` mutual exclusivity (Assertion #27)

- **Condition**: Documented as architectural constraint, not directly tested. Kept because it's a fundamental TwiML design principle (one `<Connect>` noun per call).

### Qualification 4: 10 consecutive malformed messages (Assertion #183)

- **Condition**: Documented in Twilio's error dictionary and WebSocket protocol docs. Not directly tested due to test complexity.

### Qualification 5: AI/ML Features Addendum prerequisite (Assertion #234)

- **Condition**: Console-only setting, cannot be verified programmatically.

### Qualification 6-8: console.error/warn error codes (#242-244), WebSocket close 1007 (#188)

- **Condition**: Cross-referenced from other project documentation, not directly triggered during testing.

## Removed Assertions

1. **Removed**: Implied claim that `confidence` is a valid prompt field (from domain CLAUDE.md cross-reference). Live testing across 12 calls and hundreds of prompts shows it is ABSENT from current protocol.
2. **Removed**: Claim that `Google.en-US-Chirp3-HD-Aoede` specifically produces error 64101. Replaced with positive evidence (bare name works).
3. **Removed**: Implied assertion that the default TTS provider will work without configuration on all accounts. Replaced with explicit "always specify `ttsProvider`" guidance.
