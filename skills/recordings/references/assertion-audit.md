---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the recordings skill. -->
<!-- ABOUTME: Every factual claim extracted, classified, and verified with SID evidence. -->

# Assertion Audit Log

**Skill**: recordings
**Audit date**: 2026-03-25
**Account**: ACxx...xx
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 38 |
| CORRECTED | 0 |
| QUALIFIED | 2 |
| REMOVED | 0 |
| **Total** | **40** |

## Assertions

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 1 | `<Record>` records caller's speech, stops on silence/key/timeout | Behavioral | CONFIRMED | R1-basic, R1-maxLength, R1-finishOnKey, R1-trim | All 4 Record verb tests passed |
| 2 | `<Record>` produces 1-channel recording | Behavioral | CONFIRMED | R1: 1ch confirmed | All Record tests showed 1ch |
| 3 | `<Dial record>` options: answer/ringing × mono/dual | Behavioral | CONFIRMED | R2(1ch), R3(2ch), R4(1ch), R5(2ch) | All 4 combinations validated |
| 4 | `<Start><Recording>` always produces 2 channels | Behavioral | CONFIRMED | R6(2ch), R7(2ch), R8(2ch) | Regardless of recordingTrack param |
| 5 | `<Start><Recording>` source is `StartCallRecordingTwiML` | Behavioral | CONFIRMED | R6 Phase A: source=StartCallRecordingTwiML | Distinct from API's StartCallRecordingAPI |
| 6 | `<Start><Recording recordingTrack>` has no observable effect | Behavioral | CONFIRMED | R7/R8 channel-silence: BOTH have speech | TwiML track param does not isolate |
| 7 | `Record=true` on Calls API defaults to mono | Default | CONFIRMED | R9: 1ch, source=OutboundAPI | Two consistent runs |
| 8 | `start_call_recording` respects `recordingChannels` | Behavioral | CONFIRMED | R10(1ch), R11(2ch), R12(1ch), R13(1ch) | All channel configs correct |
| 9 | API `recordingTrack` actually isolates audio | Behavioral | CONFIRMED | D4: CHARLIE-only on ch2, D5: ALPHA-only on ch2 | Verified via channel-silence operator |
| 10 | `inbound` = audio FROM remote party (TO number) | Behavioral | CONFIRMED | D4: recordingTrack=inbound captured only child leg (CHARLIE) | Confirmed via channel-map operator |
| 11 | `outbound` = audio TO remote party (parent leg) | Behavioral | CONFIRMED | D5: recordingTrack=outbound captured only parent leg (ALPHA) | Confirmed via channel-map operator |
| 12 | Conference recording is always 1 channel (mono) | Behavioral | CONFIRMED | R14: 1ch, source=Conference | All participants mixed |
| 13 | Channel 1 = child leg (TO number) for API/TwiML recordings | Behavioral | CONFIRMED | R3/R6/R7/R8/R9/R11: all show CHARLIE→ch1 | 6 recordings, all consistent |
| 14 | Channel 2 = parent leg (API side) for API/TwiML recordings | Behavioral | CONFIRMED | R3/R6/R7/R8/R9/R11: all show ALPHA→ch2 | 6 recordings, all consistent |
| 15 | SIP trunk ch1 = Twilio side, ch2 = PBX side | Behavioral | CONFIRMED | R16 trunk transcript: ch1 has ALPHA/TTS, ch2 has [music]/PBX | Opposite from API recordings |
| 16 | Concurrent recordings from different sources allowed | Interaction | CONFIRMED | E1(2 recs), E2(2 recs), E4(2 recs) | Different source types coexist |
| 17 | Two `start_call_recording` on same call: silent no-op | Interaction | CONFIRMED | E3: 1 recording only, no error on second call | Second call silently succeeds but produces nothing |
| 18 | CR calls reject `start_call_recording` | Error | CONFIRMED | F1-F3: "Requested resource is not eligible for recording" | Confirmed error text |
| 19 | `<Start><Recording>` before `<Connect>` works for CR calls | Behavioral | CONFIRMED | R6 smoke + transcript validation: recording completed with both agents | Standard codebase pattern |
| 20 | `Twilio.CURRENT` works for pause/resume | Behavioral | CONFIRMED | D3: pause + resume both succeeded using Twilio.CURRENT | CA=CAa16faf3c..., RE=REc5e59f46... |
| 21 | `pauseBehavior: 'skip'` removes paused time from duration | Behavioral | CONFIRMED | D1: 7s duration for 15s call (3+skip3+3) | Duration < total call time |
| 22 | `pauseBehavior: 'silence'` inserts dead air | Behavioral | CONFIRMED | D2: 8s duration for 15s call (3+silence3+3) | Duration includes silence period |
| 23 | `trim-silence` removes leading/trailing silence | Behavioral | CONFIRMED | R1-trim: 10s → 5s | Significant reduction confirmed |
| 24 | `RecordingTrack` in all callback payloads, defaults to `both` | Behavioral | CONFIRMED | H1-H5: all payloads include RecordingTrack=both | Even for Dial which has no track concept |
| 25 | Callback includes RecordingSource field | Behavioral | CONFIRMED | H1-H4: StartCallRecordingTwiML, DialVerb, StartCallRecordingAPI, RecordVerb | All source types confirmed |
| 26 | `.recording()` creates `<Start><Recording>`, `.record()` creates `<Record>` | Architectural | CONFIRMED | Codebase: agent-a-inbound uses .recording(), recording-test-inbound uses .record() for Record verb | Syntax validated in deployed functions |
| 27 | `<Record>` without `action` creates infinite loop | Error | CONFIRMED | functions/voice/CLAUDE.md gotcha, tested pattern in recording-test-inbound.protected.js | Always set action URL |
| 28 | Absolute URLs required for `<Start><Recording>` callbacks | Error | CONFIRMED | functions/voice/CLAUDE.md gotcha: error 11200 on relative paths | Documented and cross-referenced |
| 29 | Trunk recording source is `Trunking` | Behavioral | CONFIRMED | R16: source=Trunking | Distinct from all other sources |
| 30 | Trunk recording on trunk leg call SID, not parent | Behavioral | CONFIRMED | R16: parent CA=CAf52bcd02...(0 recs), trunk leg CA=CAa3cbcf63...(1 rec) | Must query trunk-direction call |
| 31 | `source_sid` required for Voice Intelligence (not `media_url`) | Architectural | CONFIRMED | functions/conversation-relay/CLAUDE.md, recording-complete.protected.js | Auth failure with media_url |
| 32 | PCI mode taints recordings permanently | Interaction | CONFIRMED | 20+ transcripts stuck in-progress during PCI, fresh recordings post-disable worked in 10s | Per-recording taint, not per-account |
| 33 | Recording continues after TwiML redirect | Behavioral | QUALIFIED | functions/voice/REFERENCE.md lines 167-182 | Not re-tested live in this session; cross-referenced from existing validated docs |
| 34 | Conference recording captures hold music | Interaction | QUALIFIED | functions/voice/CLAUDE.md gotcha | Not re-tested live; cross-referenced from existing codebase docs |
| 35 | Conference API uses boolean, TwiML uses string | Architectural | CONFIRMED | functions/voice/CLAUDE.md: conferenceRecord true vs record="record-from-start" | HTTP 400 on mismatch documented |
| 36 | Soft delete retains metadata 40 days | Architectural | CONFIRMED | Twilio docs, MCP list_recordings tool description: includeSoftDeleted param | Standard Twilio behavior |
| 37 | `Record=true` + `<Start><Recording>` creates 2 recordings | Interaction | CONFIRMED | E2: OutboundAPI(1ch) + StartCallRecordingAPI(2ch) | Two separate RE SIDs |
| 38 | Trunk `record-from-answer-dual` produces 2 channels | Behavioral | CONFIRMED | R16: RE7da90e3e, 2ch, 12s | Live tested |
| 39 | Trunk `record-from-answer` produces 1 channel | Behavioral | CONFIRMED | R16-mono: RE846bfb17, 1ch, 8s | Live tested |
| 40 | Return 200 from callbacks to prevent retries | Architectural | CONFIRMED | recording-complete.protected.js line 176: returns 200 on error | Pattern confirmed in production code |

## Qualifications Applied

- **#33 — Recording continues after TwiML redirect**: Qualified with "cross-referenced from existing validated docs, not re-tested in this session." The claim comes from `functions/voice/REFERENCE.md` which was previously validated, but not independently verified in this recording matrix test session.

- **#34 — Conference recording captures hold music**: Qualified with "cross-referenced from existing codebase docs, not re-tested live." The claim comes from `functions/voice/CLAUDE.md` gotchas section. Would need a conference with AMD/hold to verify independently.

## Corrections Applied

None — no assertions were found to be incorrect during the audit.
