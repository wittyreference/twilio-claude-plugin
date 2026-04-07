---
name: "recordings"
description: "Twilio development skill: recordings"
---

---
name: recordings
description: Twilio call recording guide. Use when recording calls, choosing recording methods, managing recording lifecycle, transcribing recordings, or debugging missing/broken recordings.
allowed-tools: mcp__twilio__*, Read, Grep, Glob
---

# Recordings Skill

Decision-making guide for Twilio voice call recording across all products. Load this skill when choosing a recording method, implementing recording callbacks, setting up Voice Intelligence transcription, or debugging recording issues.

All behavioral claims validated by live testing (2026-03-24, account ACxx...xx) with 47 tests across 14 recording methods. See [references/test-results.md](references/test-results.md) for the full evidence matrix with call SIDs.

---

## Scope

**This skill covers:**
- Recording calls via TwiML verbs, REST APIs, conference attributes, and SIP trunk config
- Recording lifecycle (creation, pause/resume, completion, retrieval, deletion)
- Post-call transcription via Voice Intelligence
- Channel assignment (mono vs dual, who is on which channel)
- Recording callbacks and webhook payloads

**What recordings CANNOT do** (things a developer might reasonably assume):
- Cannot record only one party's audio via TwiML `recordingTrack` — the parameter has no observable effect on `<Start><Recording>`. Use the `start_call_recording` API with `recordingTrack` for actual isolation. [Evidence: R7/R8 vs D4/D5]
- Cannot start API recordings on ConversationRelay-connected calls — "not eligible for recording." Must use `<Start><Recording>` before `<Connect>`. [Evidence: F1-F3]
- Cannot pause/resume recordings via TwiML — only via the REST API (`update_call_recording`)
- Cannot get dual-channel conference recordings — conference recording is always mono (all participants mixed)
- Cannot get dual-channel from `Record=true` on Calls API without specifying `recordingChannels: 'dual'` — defaults to mono [Evidence: R9]
- Cannot transcribe recordings created while PCI mode was enabled, even after PCI is disabled [Evidence: session debugging]

**Out of scope** (covered by other skills):
- Video recording → [video skill](/skills/video/SKILL.md)
- Real-time transcription during calls → [real-time-transcription skill](/skills/real-time-transcription/SKILL.md)
- Media Streams raw audio → [media-streams skill](/skills/media-streams/SKILL.md)
- Deepgram STT engine selection → [deepgram skill](/skills/deepgram/SKILL.md)

---

## Legal & Consent Requirements

Recording laws vary by jurisdiction. Key requirements:

- **US Federal**: One-party consent (18 U.S.C. § 2511) — at least one party must consent
- **US State (two-party)**: California, Florida, Illinois, Pennsylvania, and 8 other states require ALL parties to consent. When calls cross state lines, the stricter standard applies.
- **GDPR (EU)**: Requires explicit consent (Art. 6) and clear notice of recording purpose and retention
- **Best practice**: Always announce recording at call start (e.g., "This call may be recorded for quality assurance")

For payment capture during recording, use `<Pay>` with `<Record>` pause/resume or `<Pause>` the recording during sensitive input to avoid PCI DSS scope issues.

---

## The Critical Distinction

Two fundamentally different recording categories exist. Confusing them is the #1 source of recording bugs.

| Category | What It Does | Verb/API | Output |
|----------|-------------|----------|--------|
| **Voicemail-style** (`<Record>`) | Records the caller's speech after a prompt, stops on silence/key/timeout | `<Record>` TwiML verb | 1-channel, caller audio only |
| **Call recording** (everything else) | Records an ongoing conversation between two or more parties | 7 methods below | 1 or 2 channels |

If you want voicemail → use `<Record>`. For anything else → read the Method Selection table.

---

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Voicemail / caller message | `<Record>` verb | Only method that records caller speech then stops on silence |
| Record a two-party call | `<Dial record="record-from-answer-dual">` | Simplest for Dial-based calls, dual-channel for transcription |
| Record a Voice AI (CR) call | `<Start><Recording>` before `<Connect>` | Only method that works with ConversationRelay |
| Pause/resume mid-call | `start_call_recording` API + `Twilio.CURRENT` | Only method with programmatic pause/resume |
| Record only one party | `start_call_recording` API with `recordingTrack` | Only method where track isolation actually works |
| Record all trunk calls | Elastic SIP Trunk recording config | Automatic, no per-call TwiML needed |
| Record a conference | `record="record-from-start"` on `<Conference>` | Only option for conference-level recording (always mono) |

## Method Selection (Detail)

| Method | When to Use | Channels | Control After Start | Source Value |
|--------|-------------|----------|---------------------|-------------|
| `<Record>` verb | Voicemail, spoken input capture | 1 (mono) | None (verb blocks TwiML) | `RecordVerb` |
| `<Dial record="...">` | Two-party calls via Dial | 1 or 2 | None | `DialVerb` |
| `<Start><Recording>` | Background recording, persists across TwiML | **Always 2** | Pause/resume/stop via API | `StartCallRecordingTwiML` |
| Calls API `Record=true` | Record at outbound call creation | 1 (mono default) | Pause/resume/stop via API | `OutboundAPI` |
| `start_call_recording` API | Mid-call programmatic control | 1 or 2 | Full (pause/resume/stop) | `StartCallRecordingAPI` |
| Conference `record` attr | Conference-level recording | 1 (mono, all mixed) | None via attribute | `Conference` |
| Elastic SIP Trunk config | Record all trunk traffic | 1 or 2 | None (trunk-level setting) | `Trunking` |

---

## Decision Framework

```
Need to record?
├── Voicemail / caller leaves a message?
│   └── <Record> verb (always set action URL to avoid infinite loop)
│
├── Two-party call via <Dial>?
│   ├── Need dual-channel for transcription? → record="record-from-answer-dual"
│   └── Simple compliance recording? → record="record-from-answer"
│
├── Voice AI (ConversationRelay)?
│   └── <Start><Recording> BEFORE <Connect> (CR rejects API recordings)
│
├── Outbound API call?
│   ├── Know at creation time? → Record=true on Calls API
│   └── Decide mid-call? → start_call_recording API
│
├── Need pause/resume?
│   └── start_call_recording API (NOT on ConversationRelay calls)
│       Use Twilio.CURRENT as recordingSid if you don't know the RE SID
│
├── Conference?
│   └── record="record-from-start" on <Conference>
│
├── All trunk calls automatically?
│   └── Elastic SIP Trunk recording setting
│
└── Need to isolate one party's audio?
    └── start_call_recording API with recordingTrack=inbound|outbound
        (TwiML recordingTrack does NOT isolate — only the API version works)
```

---

## Mono vs Dual Channel

| Config | What You Get | When to Use |
|--------|-------------|-------------|
| Mono (1 channel) | All parties mixed | Simple playback, compliance archival, conference recording |
| Dual (2 channels) | Separate channel per party | Voice Intelligence transcription, speaker attribution, quality analysis |

### Channel Assignment Rules (Live-Validated)

Channel assignment depends on the recording source:

**API/TwiML recordings** (`DialVerb`, `StartCallRecordingTwiML`, `StartCallRecordingAPI`, `OutboundAPI`):
- **Channel 1** = child leg / TO number / inbound audio (the party being called)
- **Channel 2** = parent leg / API-initiated side / outbound audio (the caller/initiator)

**SIP trunk recordings** (`Trunking`):
- **Channel 1** = Twilio/originating side
- **Channel 2** = SIP/terminating side (PBX)

For Voice Intelligence, set `channel_participant: 1` = the TO number and `channel_participant: 2` = the API-initiated side. Reversing this swaps speaker labels.

### Track Isolation (API Only)

The `recordingTrack` parameter on `start_call_recording` API isolates audio to one party:
- `inbound` = audio arriving at Twilio FROM the remote party (the TO number's voice)
- `outbound` = audio sent BY Twilio TO the remote party (the parent leg's TTS/audio)
- `both` = both parties (default)

**The TwiML `<Start><Recording recordingTrack>` parameter has no observable effect** — both channels always contain audio regardless of the track setting. Only the API version isolates.

---

## Recording → Transcription Pipeline

Three-step flow for post-call analysis. Detail in [references/transcription-pipeline.md](references/transcription-pipeline.md).

1. **Recording completes** → `recordingStatusCallback` fires with `RecordingStatus=completed`
2. **Create transcript** → `client.intelligence.v2.transcripts.create()` with `source_sid` (NOT `media_url`)
3. **Transcript completes** → `voice_intelligence_transcript_available` webhook fires with operator results

Use a dedicated Intelligence Service per validation domain. Configure Language Operators on the service to auto-run analysis (summarization, sentiment, custom validators).

---

## Common Patterns

### Background Recording + ConversationRelay (Tested)

```javascript
// Pattern from agent-a-inbound.protected.js
const twiml = new Twilio.twiml.VoiceResponse();

// Start recording BEFORE ConversationRelay (CR rejects API recordings)
const start = twiml.start();
start.recording({
  recordingStatusCallback: `https://${context.DOMAIN_NAME}/conversation-relay/recording-complete`,
  recordingStatusCallbackEvent: 'completed',
});

// Connect to voice AI agent
const connect = twiml.connect();
connect.conversationRelay({
  url: relayUrl,
  voice: 'Google.en-US-Neural2-F',
});
```

### API Recording with Pause/Resume (Tested)

```javascript
// Start recording mid-call
const rec = await client.calls(callSid).recordings.create({
  recordingChannels: 'dual',
  recordingTrack: 'both',
});

// Pause (skip removes paused time from recording)
await client.calls(callSid).recordings('Twilio.CURRENT').update({
  status: 'paused',
  pauseBehavior: 'skip',
});

// Resume
await client.calls(callSid).recordings('Twilio.CURRENT').update({
  status: 'in-progress',
});
```

---

## Gotchas

### Syntax & Setup

1. **`.recording()` not `.record()`**: `twiml.start().recording({...})` creates `<Start><Recording>`. `twiml.record({...})` creates `<Record>` verb. Different behavior entirely. [Evidence: codebase pattern, `CLAUDE.md`]

2. **`<Record>` without `action` creates infinite loop**: POSTs back to self, re-executing and creating multiple recordings. Always set `action` to a different handler. [Evidence: `CLAUDE.md` gotchas]

3. **`<Start><Recording>` requires absolute callback URLs**: Relative paths trigger error 11200. Recording completes but callback never fires. `<Gather action>` and `<Dial action>` resolve relative URLs fine. [Evidence: `CLAUDE.md` gotchas]

### Channel & Track Behavior

4. **`<Start><Recording>` always produces 2 channels**: Regardless of `recordingTrack` parameter. The TwiML verb ignores `recordingTrack` for channel isolation. Use `start_call_recording` API for actual control. [Evidence: R6/R7/R8 all 2ch]

5. **Channel assignment differs between API and trunk recordings**: API/TwiML: ch1=child(TO), ch2=parent(FROM). Trunk: ch1=Twilio, ch2=PBX. Get this wrong and Voice Intelligence speaker labels are swapped. [Evidence: R3/R6/R11 transcripts vs R16 trunk transcript]

6. **`Record=true` on Calls API defaults to mono**: If you need dual-channel, use `start_call_recording` API with `recordingChannels: 'dual'` after the call connects. [Evidence: R9 — 1ch confirmed]

### Concurrent & Conflicting

7. **Don't combine `Record=true` API with `<Start><Recording>` TwiML**: Creates two separate recordings with different channel counts and sources. Pick one method. [Evidence: E2 — 2 recordings, OutboundAPI 1ch + StartCallRecordingAPI 2ch]

8. **Two `start_call_recording` on same call: silent no-op**: The second call returns success but only one recording is produced. No error, no warning. [Evidence: E3]

9. **ConversationRelay calls reject `start_call_recording` and pause/resume**: "Requested resource is not eligible for recording." Must use `<Start><Recording>` BEFORE `<Connect><ConversationRelay>`. [Evidence: F1-F3, error text confirmed]

### Callbacks & Retrieval

10. **Append `.mp3` or `.wav` to `RecordingUrl`**: The raw callback URL returns JSON metadata, not audio. Add extension for playable file. [Evidence: H1-H4 callback payloads]

11. **Return 200 from recording callbacks even on error**: Non-200 causes Twilio to retry, potentially triggering duplicate processing. Return 200 and log the error. [Evidence: `recording-complete.protected.js` pattern, 54301 duplicate handling]

12. **`RecordingTrack` appears in ALL callback payloads**: Defaults to `both` even for methods that don't support track selection (e.g., `<Dial record>`). [Evidence: H1-H5 raw payloads in Sync]

### Lifecycle

13. **`<Start><Recording>` continues after TwiML redirect**: Background recording persists through `<Redirect>`, conference join/leave, and subsequent webhook responses. Only stops on call end or explicit API stop. [Evidence: `REFERENCE.md` lines 167-182]

14. **Conference recording captures hold music**: When `Record=true` on Participants API, recording starts from conference creation. AMD classification time means minutes of hold music in recordings. [Evidence: `CLAUDE.md` gotchas]

15. **Conference API uses boolean, TwiML uses string**: Participants API: `conferenceRecord: true`. TwiML: `record="record-from-start"`. Passing TwiML values to API returns HTTP 400. [Evidence: `CLAUDE.md` gotchas]

16. **Soft delete retains metadata 40 days**: `DELETE /Recordings/{sid}` is soft delete. Use `includeSoftDeleted: true` to see deleted recordings in list queries. [Evidence: Twilio docs, MCP `list_recordings` tool description]

### Voice Intelligence

17. **Use `source_sid` not `media_url` for Voice Intelligence**: Intelligence API cannot authenticate to `api.twilio.com`. Always use the Recording SID as `source_sid`. [Evidence: `CLAUDE.md` troubleshooting, `recording-complete.protected.js`]

18. **PCI mode blocks Voice Intelligence permanently**: Recordings created while PCI mode is enabled cannot be transcribed even after PCI is disabled. The taint is permanent per-recording. [Evidence: session debugging — 20+ transcripts stuck, resolved only with fresh recordings post-PCI-disable]

### Trunk-Specific

19. **Trunk recording SID is on the trunk leg's call SID**: Not the parent API call. You must find the trunk-direction call to list its recordings. The parent call shows 0 recordings. [Evidence: R16 — parent CA=CAf52bcd02..., trunk leg CA=CAa3cbcf63..., recording only on trunk leg]

---

## MCP Tools Quick Reference

| Operation | Tool | When |
|-----------|------|------|
| Start recording mid-call | `start_call_recording` | Programmatic control, track isolation |
| Pause/resume/stop | `update_call_recording` | Mid-call control (use `Twilio.CURRENT` as SID) |
| Get recording details | `get_recording` | Check status, get media URL |
| List call recordings | `list_call_recordings` | Find recordings for a specific call |
| List all recordings | `list_recordings` | Account-wide search with filters |
| List conference recordings | `list_conference_recordings` | Conference-specific search |
| Delete recording | `delete_recording` | Cleanup, compliance deletion |
| Validate recording | `validate_recording` | Deep validation (polls for completion) |
| Validate full flow | `validate_voice_ai_flow` | End-to-end: call + recording + transcript |
| SIP trunk recording | `get_trunk_recording` / `update_trunk_recording` | Trunk-level config |

---

## Related Resources

- [Voice skill](/skills/voice/SKILL.md) — Recording Method Selection summary, TwiML verb reference
- [Deepgram skill](/skills/deepgram/SKILL.md) — STT engine selection for real-time transcription
- [Voice Insights skill](/skills/voice-insights/SKILL.md) — Call quality diagnostics on recorded calls
- [Video skill](/skills/video/SKILL.md) — Video room recordings and compositions
- [CLAUDE.md](/CLAUDE.md) — TwiML patterns, `<Start><Recording>` syntax
- [CLAUDE.md](/CLAUDE.md) — Voice AI recording + transcription patterns
- [recording-complete.protected.js](/recording-complete.protected.js) — Production recording callback → Voice Intelligence

---

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| All recording methods with parameters | [recording-methods.md](references/recording-methods.md) | Implementing any recording method |
| Callbacks, lifecycle, retrieval | [callbacks-and-lifecycle.md](references/callbacks-and-lifecycle.md) | Setting up callbacks, downloading recordings |
| Recording → transcription pipeline | [transcription-pipeline.md](references/transcription-pipeline.md) | Post-call transcription with Voice Intelligence |
| Debugging missing/empty recordings | [debugging-recordings.md](references/debugging-recordings.md) | Recording not appearing, shorter than expected |
| Channel mapping and audio formats | [channel-mapping-and-formats.md](references/channel-mapping-and-formats.md) | Dual-channel setup, speaker identification |
| Validation matrix results | [test-results.md](references/test-results.md) | Full evidence with call SIDs |
| Assertion audit | [assertion-audit.md](references/assertion-audit.md) | Provenance chain for every claim (40 assertions) |
