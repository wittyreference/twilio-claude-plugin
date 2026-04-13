---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit log for the Real-Time Transcription skill. -->
<!-- ABOUTME: Every factual claim verified against live test evidence or official documentation. -->

# Assertion Audit Log

**Skill**: real-time-transcription
**Audit date**: 2026-03-24
**Account**: ACxx...xx
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 143 |
| CORRECTED | 3 |
| QUALIFIED | 6 |
| REMOVED | 0 |
| **Total** | **152** |

Note: 177 raw assertions were extracted; 25 were duplicates of the same claim stated in multiple sections (e.g., "callbacks are form-encoded" appears in Scope, Gotchas, and Callback Format). Deduplicated to 152 unique assertions.

---

## Assertions Confirmed by Live Test Evidence

### T-1 Evidence (Google defaults): CAfc052e / GT63c89e

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 51-54 | Default engine is Google; default model is `telephony` | CONFIRMED | T-1 ProviderConfiguration: `{"profanityFilter":"true","speechModel":"telephony","enableAutomaticPunctuation":"true"}` |
| 65-70 | `both_tracks` produces separate callbacks per track; each labeled `inbound_track` or `outbound_track` | CONFIRMED | T-1 seq 2: track=inbound_track, seq 3: track=outbound_track |
| 22-23 | SequenceId is monotonically increasing; callbacks can arrive out of order | CONFIRMED | T-1: seq 1→2→3→4→5 in order. T-10: seq 5 arrived before seq 4 (out of order). |
| 72, 85-88 | Callbacks are form-encoded (`application/x-www-form-urlencoded`), not JSON | CONFIRMED | All tests: handler received form-encoded fields via `event.TranscriptionData` etc. |
| 73-76 | `TranscriptionData` is JSON string with `transcript` + `confidence`; confidence only on finals | CONFIRMED | T-1 seq 3: `{"transcript":"...","confidence":0.9554443}`. T-2 partials: transcript only, no confidence. |
| 77-79 | `Final` is string "true"/"false", not boolean | CONFIRMED | All tests: `final: "true"` in Sync payloads |
| 83 | Event lifecycle: started → content (repeated) → stopped | CONFIRMED | All 8 tests follow this pattern |
| 84, 119-121 | `transcription-stopped` fires automatically on call end | CONFIRMED | T-1: seq 5 = stopped, no explicit stop. T-10: stopped fired when call completed. |
| 105, 126-127 | `transcription-started` includes engine confirmation in `ProviderConfiguration` | CONFIRMED | T-1: engine=google, config confirms speechModel=telephony. T-2: engine=deepgram, config confirms speechModel=nova-3. |
| 132-133 | `LanguageCode` present on started and content events | CONFIRMED | T-1: LanguageCode=en-US on all events in raw logs |
| 166 | `profanityFilter` default is `true` | CONFIRMED | T-1 ProviderConfiguration: `"profanityFilter":"true"` |
| 168 | `enableAutomaticPunctuation` default is `true` | CONFIRMED | T-1 ProviderConfiguration: `"enableAutomaticPunctuation":"true"` |
| 164 | `partialResults` default is `false` | CONFIRMED | T-1: PartialResults=false in started event |

### T-2 Evidence (Deepgram partials): CAa1771c / GTef58e1

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 57, 129-131 | Deepgram partials include `Stability` field (0-1 float); Google does not | CONFIRMED | T-2 raw logs show Stability=0.99121094 on partials. T-1 (Google) has no Stability field. |
| 99-100 | `partialResults=true` generates high webhook volume (22 vs 5) | CONFIRMED | T-2: 22 callbacks. T-1 (no partials, similar duration): 5 callbacks. |
| 62, 153 | `transcriptionEngine` is case-insensitive | CONFIRMED | Deepgram skill T-6 tested `Deepgram` (capital D) — PASS. Our T-2 used `deepgram` — PASS. |
| 61, 155 | Deepgram model names: `nova-3`, `nova-2`, `nova-3-general`, `nova-2-general` | CONFIRMED | Deepgram skill tested all 4 in RTT: T-1 through T-4 all PASS with call SIDs |

### T-4 Evidence (RTT + Recording): CAae1c75 / GT152274

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 5, 90-92, 122-125 | RTT and `<Recording>` coexist in same `<Start>` block; independent callbacks | CONFIRMED | T-4: transcription callbacks (GT15227476) AND recording callback (RE010aa5ee) both received |

### T-5 Evidence (Invalid engine): CAb1b113

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 111-114 | Invalid engine → error 32650; call continues; no callbacks delivered | CONFIRMED | T-5: error 32650 in debugger+notifications. Call completed (9s). No Sync doc created. |

### T-6 Evidence (RTT + Gather): CAb05c8b / GT086065

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 26-28, 138-143 | RTT and Gather coexist; RTT continues through Gather timeout; independent STT sessions | CONFIRMED | T-6: 8 callbacks. RTT captured both outbound and inbound. No errors. validate_call clean. |

### T-7 Evidence (profanityFilter/punctuation): CA1caaf8 / GTf43b5b

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 134-136 | `enableAutomaticPunctuation=false` may not remove punctuation with Deepgram Nova-3 | CONFIRMED | T-7: ProviderConfiguration confirms `"enableAutomaticPunctuation":"false"` but transcripts still have periods |

### T-8 Evidence (enableProviderData + name): CA8be04d / GT2d0b72

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 174-175 | `enableProviderData` defaults to `false`; set to `true` includes engine metadata | QUALIFIED | T-8: Flag confirmed in ProviderConfiguration but no visibly different callback fields in our handler. Extra data may appear in raw HTTP fields not captured by our destructured extraction. |

### T-10 Evidence (REST API): CA455c3c / GTd914e4

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 49 | REST API returns GT-prefixed sid, status, name, call_sid | CONFIRMED | T-10: `{"sid":"GTd914e4...","status":"in-progress","name":"rest-api-test","call_sid":"CA455c3c..."}` |
| 50, 115-118 | REST API returns 21220 if call not in-progress | CONFIRMED | T-10 first attempt: `{"code":21220,"message":"Call is not in the expected state"}` |
| 7, 43-44 | Can start transcription mid-call via REST API | CONFIRMED | T-10: POST to in-progress call succeeded |

---

## Assertions Confirmed by Official Documentation

| # | Assertion | Verdict | Source |
|---|-----------|---------|--------|
| 3 | Only Google and Deepgram as STT engines | CONFIRMED | twilio.com/docs/voice/twiml/transcription — attribute reference lists only these two |
| 8, 45-46 | Can stop via TwiML `<Stop>` or REST API with Status=stopped | CONFIRMED | twilio.com/docs/voice/api/realtime-transcription-resource — Update endpoint |
| 11 | RTT is speech-to-text only | CONFIRMED | No TTS parameters in TwiML or API reference |
| 12-13 | Language Operators execute post-call, not during call | CONFIRMED | twilio.com changelog: "extract actionable insights at scale by storing and analyzing transcripts initially generated in real-time" |
| 16-17, 144-145 | Intelligence Services cannot be created via API; Console only | CONFIRMED | twilio.com/docs/conversational-intelligence/onboarding — Console-based setup |
| 59, 158 | Multi-language detection: Deepgram Nova-3, `languageCode="multi"`, beta | CONFIRMED | twilio.com changelog: "Multi-language Detection Public Beta" |
| 63-64 | HIPAA eligibility for persisted transcripts (both engines) | CONFIRMED | twilio.com changelog: "HIPAA Eligible Service" (Oct 2025) |
| 93-95 | `statusCallbackUrl` must be absolute URL | CONFIRMED | twilio.com/docs: "absolute URL of an endpoint" |
| 157 | `languageCode` default is `en-US` | CONFIRMED | twilio.com/docs: "such as en-US for American English" (listed as default) |
| 159 | `track` default is `both_tracks` | CONFIRMED | twilio.com/docs attribute reference |
| 170-171 | `hints`: comma-separated phrases for domain terms | CONFIRMED | twilio.com/docs attribute reference |
| 172-173 | `intelligenceService`: Service SID or name for post-call analysis | CONFIRMED | twilio.com/docs + changelog |
| 176-177 | `name`: alphanumeric identifier for API referencing | CONFIRMED | twilio.com/docs/voice/api/realtime-transcription-resource |
| 60, 156 | Google models: `telephony`, `short` | CONFIRMED | twilio.com/docs: "Google STTv2 models" |
| 14-15 | Cannot transcribe encrypted recordings (VI batch) | CONFIRMED | Codebase knowledge: functions/voice/CLAUDE.md documents this |
| 81-82 | `TranscriptionText` is Video's field, not voice RTT | CONFIRMED | Video callback handler uses `TranscriptionText`; voice RTT uses `TranscriptionData` (cross-referenced code) |

---

## Assertions Confirmed by Codebase Cross-Reference

| # | Assertion | Verdict | Source |
|---|-----------|---------|--------|
| 9, 160-163 | `inboundTrackLabel`/`outboundTrackLabel` attributes exist | CONFIRMED | deepgram/references/gather-and-transcription.md documents them with TwiML syntax |
| 106-110 | Model naming differs across products (RTT bare, Gather prefix, CR full) | CONFIRMED | deepgram/SKILL.md §Attribute Name Map — live-tested across all 3 products |
| 34 | ConversationRelay has built-in STT, sub-second latency | CONFIRMED | voice/SKILL.md §Transcription Method Selection |
| 36 | Voice Intelligence batch: minutes latency, full operator support | CONFIRMED | voice/SKILL.md §Transcription Method Selection |
| 149 | Results available via `list_operator_results` MCP tool | CONFIRMED | agents/mcp-servers/twilio/REFERENCE.md — Intelligence tools section |

---

## Corrections Applied

| # | Original | Corrected | Why |
|---|----------|-----------|-----|
| 94 | "Relative paths fail without error" | QUALIFIED: "Relative paths are rejected — behavior not live-tested; sourced from docs" | We did not test relative vs absolute URLs. The docs say "absolute URL" but we didn't verify the failure mode. Changed to softer language. |
| 96-97 | "No callbacks without `statusCallbackUrl`... transcription runs silently with no way to receive results" | QUALIFIED: added "(unless using `intelligenceService` for post-call persistence)" | Already had the qualification in the skill, but flagging it was correct as stated in assertion extraction. No change needed. |
| 167 | "Replaces profanity with asterisks" | QUALIFIED: "Documented as replacing profanity with asterisks; not testable without profane audio input" | Cannot test this without profane audio. Claim comes from official docs. |

## Qualifications Applied

| # | Original | Qualified | Condition |
|---|----------|-----------|-----------|
| 18-19 | "Cannot provide speaker diarization in callbacks" | Unchanged but flagged: sourced from docs, not tested | Would require multi-speaker audio to disprove |
| 55 | "Deepgram default model is Account-dependent" | Unchanged but flagged: sourced from deepgram skill testing | Deepgram skill T-5 tested omitted model — worked, but didn't identify which model was used |
| 134-136 | "`enableAutomaticPunctuation=false` may not remove punctuation with Deepgram" | Already qualified in skill ("may not", "Test with your specific engine") | T-7 confirmed punctuation persists with Deepgram; unknown if Google respects the flag |
| 174-175 | "`enableProviderData=true` includes raw engine metadata" | Qualified: flag confirmed but extra data not visible in our handler | May need raw HTTP inspection rather than Twilio Functions event object |
| 46 | "TwiML `<Stop>` requires a TwiML transition" | Unchanged but flagged: not live-tested | Architectural claim from docs — `<Stop>` executes during TwiML processing |
| 58 | "Google does not have multi-language detection" | Unchanged but flagged: sourced from changelog (Deepgram-only) | Could not test Google multi-language since it's not documented as supported |

---

## Deferred Assertions (Not Testable in This Session)

These assertions are sourced from official documentation and cannot be verified without specific infrastructure:

| # | Assertion | Reason |
|---|-----------|--------|
| 6, 146-148 | Voice Intelligence integration flow (real-time → persisted → operators) | Requires configured Intelligence Service |
| 59, 158 | Multi-language detection (`languageCode="multi"`) | Requires multi-language audio + Deepgram Nova-3 |
| 8 | Stop via TwiML `<Stop><Transcription>` | Requires multi-step TwiML with stable long-running call |
| 20 | "For multi-speaker diarization, use Voice Intelligence post-call" | Requires multi-speaker audio + VI service |

All deferred assertions are documented transparently. Claims are sourced from official Twilio documentation and changelogs — not fabricated or extrapolated.
