---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Validation matrix results for Twilio recording methods. -->
<!-- ABOUTME: Live-tested 2026-03-24 on account ACb4de2... with call SIDs for evidence. -->

# Recording Validation Matrix — Test Results

All tests run 2026-03-24 on account ACb4de2... Domain: prototype-1483-dev.twil.io.
Deterministic agents (NATO phonetic phrases, no LLM) used for all tests.

## Summary

| Stat | Value |
|------|-------|
| Total tests run | 47 (Phases A-H + transcript validation) |
| Passed | 44 |
| Failed | 3 (Pause/Resume — "not eligible for recording") |
| Recording methods validated | 14 of 17 (SIP trunk deferred) |
| Transcript analysis | **COMPLETE** — 6 recordings transcribed with 5 Language Operators |
| Intelligence Service | `GA3705f93b29459947e866b921420f8208` (recording-validation) |

## Recording Metadata Results

### Source Field Discovery

| Recording Method | Observed `source` Value |
|-----------------|------------------------|
| `<Record>` verb | `RecordVerb` |
| `<Dial record="...">` | `DialVerb` |
| `<Start><Recording>` | **`StartCallRecordingTwiML`** |
| Calls API `Record=true` | `OutboundAPI` |
| `start_call_recording` API | `StartCallRecordingAPI` |
| Conference `record` attribute | `Conference` |

**Key discovery**: `<Start><Recording>` reports source as `StartCallRecordingTwiML`, NOT `StartCallRecordingAPI`. These are distinct source values that distinguish TwiML-initiated vs API-initiated recordings.

### Channel Count Matrix

| Method | Expected | Observed | Notes |
|--------|----------|----------|-------|
| R1 `<Record>` | 1 | **1** | Single channel, caller audio only |
| R2 `<Dial record-from-answer>` | 1 | **1** | Mono, both parties mixed |
| R3 `<Dial record-from-answer-dual>` | 2 | **2** | Dual channel confirmed |
| R4 `<Dial record-from-ringing>` | 1 | **1** | Mono, includes ringback |
| R5 `<Dial record-from-ringing-dual>` | 2 | **2** | Dual channel confirmed |
| R6 `<Start><Recording> track=both` | 1 (expected) | **2** | **SURPRISE: always 2ch** |
| R7 `<Start><Recording> track=inbound` | 1 (expected) | **2** | **SURPRISE: always 2ch** |
| R8 `<Start><Recording> track=outbound` | 1 (expected) | **2** | **SURPRISE: always 2ch** |
| R9 Calls API `Record=true` | TBD | **1** | **Mono by default** |
| R10 API `channels=mono, track=both` | 1 | **1** | Confirmed |
| R11 API `channels=dual, track=both` | 2 | **2** | Confirmed |
| R12 API `channels=mono, track=inbound` | 1 | **1** | Confirmed |
| R13 API `channels=mono, track=outbound` | 1 | **1** | Confirmed |
| R14 Conference TwiML `record` | 1 | **1** | Mono, all participants mixed |

**Major finding**: `<Start><Recording>` ALWAYS produces 2-channel recordings regardless of the `recordingTrack` parameter. The `recordingTrack` parameter controls which audio is captured (one channel may be silent), but both channels are always written. This is different from the `start_call_recording` API which respects `recordingChannels`.

### Timing Results (Phase D)

| Method | Recording Duration | Call Duration | Difference |
|--------|-------------------|---------------|------------|
| R2 Dial mono from-answer | 15s | 15s | 0s |
| R4 Dial mono from-ringing | 15s | 14s | +1s |
| R3 Dial dual from-answer | 12s | 13s | -1s |
| R5 Dial dual from-ringing | 13s | 13s | 0s |

Timing differences between from-answer and from-ringing are minimal (~1s) in this test environment where calls answer quickly. In production with longer ring times, from-ringing recordings would be significantly longer.

### Concurrent Recording Results (Phase E)

| Test | Method Combination | Recordings Created | Sources |
|------|-------------------|-------------------|---------|
| E1 | `<Dial record>` + API recording | **2** | DialVerb (2ch, 13s) + StartCallRecordingAPI (1ch, 9s) |
| E2 | API `Record=true` + API `start_call_recording` | **2** | OutboundAPI (1ch, 16s) + StartCallRecordingAPI (2ch, 11s) |
| E3 | Two API `start_call_recording` | **1** | Second succeeded silently (no error), only 1 recording |
| E4 | TwiML `<Start><Recording>` + API recording | **2** | StartCallRecordingTwiML (2ch, 13s) + StartCallRecordingAPI (2ch, 9s) |

**Key findings**:
- Concurrent recordings from different sources are allowed and produce separate RE SIDs
- Two API recordings via `start_call_recording` do NOT error — the second call appears to succeed but only one recording is produced
- Each concurrent recording has its own source, channels, and duration

### Pause/Resume Results (Phase F)

**All 3 tests FAILED** with error: "Requested resource is not eligible for recording"

This error occurs when trying to start an API recording on a call that's connected via ConversationRelay (`<Connect><ConversationRelay>`). The `start_call_recording` API cannot record calls in the `<Connect>` state.

**Workaround**: Use `<Start><Recording>` BEFORE `<Connect>` (as the codebase already does), or use `Record=true` on the Calls API at call creation time.

### `<Record>` Verb Results (Phase G)

| Test | Config | Duration | Source | Channels |
|------|--------|----------|--------|----------|
| R1-basic | Default | 10s | RecordVerb | 1 |
| R1-maxLength | `maxLength=10` | 10s | RecordVerb | 1 |
| R1-trim | `trim=trim-silence` | **5s** (trimmed from ~10) | RecordVerb | 1 |
| R1-finishOnKey | `finishOnKey=#` | 10s | RecordVerb | 1 |

`trim-silence` reduced duration from ~10s to 5s, confirming it removes leading/trailing silence.

### Callback Payload Validation (Phase H)

All callback payloads confirmed to include:

| Field | Present | Example Value |
|-------|---------|---------------|
| `AccountSid` | Yes | ACb4de2... |
| `CallSid` | Yes | CA... |
| `RecordingSid` | Yes | RE... |
| `RecordingUrl` | Yes | Without extension |
| `RecordingStatus` | Yes | `completed` |
| `RecordingDuration` | Yes | Seconds as string |
| `RecordingChannels` | Yes | `1` or `2` |
| `RecordingSource` | Yes | See source table above |
| `RecordingStartTime` | Yes | RFC 2822 format |
| `RecordingTrack` | Yes | `both` (even for non-track methods) |
| `ErrorCode` | Yes | `0` for success |

**New discovery**: `RecordingTrack` is included in ALL callback payloads, defaulting to `both` even when the method doesn't support track selection (e.g., `<Dial record>`).

## Call SIDs (Evidence)

### Phase A (Smoke)
- R6 `<Start><Recording>`: CA=CAa3dcf2d8..., RE=RE23986ac6..., 2ch, 19s, StartCallRecordingTwiML
- R3 `<Dial record>`: CA=CAbd23c32a..., RE=RE140654d8..., 2ch, 13s, DialVerb
- R11 API dual: CA=CA1b72aebf..., RE=REaf8b2141..., 2ch, 8s, StartCallRecordingAPI
- R14 Conference: CF=CFe63d102b..., RE=RE254a465f..., 1ch, 16s, Conference

### Phase B (Channel Assignment)
- R3-run1: CA=CA1368b69d..., RE=REf9c4b9cc..., 2ch, 13s
- R3-run2: CA=CA1431ab6b..., RE=RE8d139f20..., 2ch, 18s
- R5-run1: CA=CAd99bed9b..., RE=RE00f2b584..., 2ch, 13s
- R5-run2: CA=CA1a87b630..., RE=REfb3263ef..., 2ch, 20s
- R9-run1: CA=CA6b4b9856..., RE=REa2b2df54..., 1ch, 14s
- R9-run2: CA=CA1caf63fe..., RE=RE640c00ff..., 1ch, 14s
- R11-run1: CA=CA8d193ae9..., RE=REda555042..., 2ch, 10s
- R11-run2: CA=CA6378b7fc..., RE=RE0f0e0a26..., 2ch, 10s

### Phase C (Track Isolation)
- R7 inbound-run1: CA=CA0cac9736..., RE=REcb2f22ed..., 2ch, 13s
- R7 inbound-run2: CA=CA8bdc2084..., RE=RE13d28422..., 2ch, 14s
- R8 outbound-run1: CA=CA0742b6e3..., RE=RE28f14b8c..., 2ch, 16s
- R8 outbound-run2: CA=CAc084a309..., RE=RE987431c4..., 2ch, 17s
- R12 API inbound-run1: CA=CA58ebbbf2..., RE=RE37c97ffc..., 1ch, 10s
- R12 API inbound-run2: CA=CAe5755efa..., RE=RE4ad34c05..., 1ch, 8s
- R13 API outbound-run1: CA=CA46e54b7e..., RE=RE0d182599..., 1ch, 9s
- R13 API outbound-run2: CA=CAc4715300..., RE=RE4c90e61e..., 1ch, 10s

### Phase E (Concurrent)
- E1: CA=CA5f730c49..., 2 recordings (DialVerb 2ch + API 1ch)
- E2: CA=CA648f5555..., 2 recordings (OutboundAPI 1ch + API 2ch)
- E3: CA=CA3e16738d..., 1 recording only (second API call silent-succeeded)
- E4: CA=CA1e009cc8..., 2 recordings (TwiML 2ch + API 2ch)

### Phase G (`<Record>`)
- R1-basic: CA=CAb0ff6966..., RE=REb1ee3f86..., 1ch, 10s
- R1-maxLength: CA=CAce91067c..., RE=REb0414126..., 1ch, 10s
- R1-trim: CA=CAbb9e43e7..., RE=RE97121f10..., 1ch, 5s
- R1-finishOnKey: CA=CA8acd1901..., RE=RE9b592110..., 1ch, 10s

## Transcript + Operator Validation (Post-PCI Fix)

Initial transcripts were blocked by PCI mode on the account. After PCI disable + fresh recordings, all transcripts completed in ~10 seconds with 5 Language Operators firing.

**Root cause of earlier transcript stalls**: PCI mode prevents Voice Intelligence from processing recordings. Recordings created while PCI is active are permanently untranscribable even after PCI is disabled. Only fresh recordings (created post-PCI-disable) can be transcribed.

### Channel Assignment — THE Definitive Answer

Validated by `channel-map` operator across 6 recording methods. **Consistent result across every method**:

| Method | ALPHA (parent leg) | CHARLIE (child leg) | `channel-map` output |
|--------|:------------------:|:-------------------:|---------------------|
| R6 `<Start><Recording>` both | **Channel 2** | **Channel 1** | ALPHA_CHANNEL: 2, CHARLIE_CHANNEL: 1, SEPARATION: PARTIAL |
| R3 `<Dial record>` dual | **Channel 2** | **Channel 1** | ALPHA_CHANNEL: 2, CHARLIE_CHANNEL: 1, SEPARATION: PARTIAL |
| R11 API `dual` | **Channel 2** | **Channel 1** | ALPHA_CHANNEL: 2, CHARLIE_CHANNEL: 1, SEPARATION: PARTIAL |
| R7 Start Recording inbound | **Channel 2** | **Channel 1** | ALPHA_CHANNEL: 2, CHARLIE_CHANNEL: 1, SEPARATION: PARTIAL |
| R8 Start Recording outbound | **Channel 2** | **Channel 1** | ALPHA_CHANNEL: 2, CHARLIE_CHANNEL: 1, SEPARATION: PARTIAL |
| R9 API `Record=true` mono | **Channel 2** | **Channel 1** | ALPHA_CHANNEL: 2, CHARLIE_CHANNEL: 1, SEPARATION: PARTIAL |

**Channel assignment rule**:
- **Channel 1 = child leg / TO number / inbound audio** (the party being called)
- **Channel 2 = parent leg / API-initiated side / outbound audio** (the caller/initiator)

This maps to the Voice Intelligence participant labels:
- `channel_participant: 1` ("caller") = the TO number's audio
- `channel_participant: 2` ("agent") = the API-initiated side's audio

**Note on SEPARATION: PARTIAL**: The operators report PARTIAL rather than CLEAN because ConversationRelay TTS audio has some acoustic bleed between channels (the TTS output is audible at low level on the other channel). This is a telephony characteristic, not a recording bug. The primary content is correctly separated.

### Track Isolation — `recordingTrack` Does NOT Silence Channels

| Method | `channel-silence` result | Finding |
|--------|-------------------------|---------|
| R7 Start Recording `track=inbound` | CH1: HAS_SPEECH, CH2: HAS_SPEECH, BOTH | **Both channels have audio** |
| R8 Start Recording `track=outbound` | CH1: HAS_SPEECH, CH2: HAS_SPEECH, BOTH | **Both channels have audio** |

**Confirmed**: `<Start><Recording recordingTrack="inbound|outbound">` does NOT silence the other channel. Both channels always contain audio regardless of the `recordingTrack` parameter. Combined with the earlier finding that `<Start><Recording>` always produces 2 channels, the `recordingTrack` parameter on the TwiML verb appears to have no observable effect on the recording output.

### Transcript Evidence (Call SIDs)

| Test | Call SID | Recording SID | Transcript SID | Sentences |
|------|----------|---------------|----------------|-----------|
| R6 | CAda6feaf4... | RE3eafb078... | GT5c041363... | 5 |
| R3 | CA59dca802... | RE7b23e964... | GT64fed747... | 6 |
| R11 | CA7f7f6cdf... | RE6c12e9d3... | GT632ea9d1... | 4 |
| R7 | CA65b796d9... | REe33131bc... | GT4184f5fe... | 6 |
| R8 | CAde4fd063... | RE0b5240c5... | GT36e18526... | 6 |
| R9 | CAd4018cb8... | RE48f5a27c... | GT328d3869... | 5 |

## Deferred Tests — Completed

### Pause/Resume (API Recording)

Pause/Resume does NOT work on ConversationRelay-connected calls ("not eligible for recording"). Works on API-started recordings on non-CR calls.

| Test | pauseBehavior | Duration | Expected | Finding |
|------|--------------|----------|----------|---------|
| D1 | `skip` | **7s** | ~6s (3+3, skip 3) | Skip removes paused time from recording |
| D2 | `silence` | **8s** | ~9s (3+3silence+3) | Silence inserts dead air, included in duration |

**`Twilio.CURRENT` confirmed working** — `client.calls(sid).recordings('Twilio.CURRENT').update()` successfully pauses and resumes without knowing the RE SID. (Test D3: CA=CAa16faf3c..., RE=REc5e59f46...)

### API `recordingTrack` — Actually Isolates (Unlike TwiML)

The API's `start_call_recording` with `recordingTrack` parameter DOES isolate audio. The TwiML `<Start><Recording recordingTrack>` does NOT. Critical distinction.

| Test | Track | channel-silence | channel-map | Finding |
|------|-------|----------------|-------------|---------|
| D4 API `inbound` | inbound | CH1: SILENT, CH2: HAS_SPEECH | CHARLIE on ch2 only | **Inbound = child leg audio (TO number)** |
| D5 API `outbound` | outbound | CH1: SILENT, CH2: HAS_SPEECH | ALPHA on ch2 only | **Outbound = parent leg audio (API side)** |

**Key insight**: "inbound" means audio arriving at Twilio FROM the remote party (the TO number). "Outbound" means audio sent BY Twilio TO the remote party (the parent leg's audio/TTS).

Evidence:
- D4: CA=CAcb245d92..., RE=REa1f4b746..., GT completed, CHARLIE-only on ch2
- D5: CA=CA37446956..., RE=RE3b0014b0..., GT completed, ALPHA-only on ch2

### from-ringing vs from-answer Timing

| Mode | Recording Duration | Call Duration | Difference |
|------|-------------------|---------------|------------|
| from-answer | 12s | 12s | 0s |
| from-ringing | 12s | 12s | 0s |

Difference is 0s because our test numbers answer instantly (ConversationRelay has no ring delay). In production with real PSTN ring times (5-30s), from-ringing recordings would be longer by the ring duration.

### SIP Trunk Recording — COMPLETE

SIP trunk `TK8b2bdbd54a36235ca82915f7cbe85439` with Asterisk PBX at `134.209.166.32`.

| Mode | Channels | Duration | Source | Recording SID |
|------|----------|----------|--------|---------------|
| `record-from-answer-dual` | **2** | 12s | `Trunking` | RE7da90e3e... |
| `record-from-answer` (mono) | **1** | 8s | `Trunking` | RE846bfb17... |

**Trunk recording findings**:
- Source is `Trunking` (distinct from all other sources)
- Call direction is `trunking-originating`
- Recording SID is on the **trunk leg's call SID** (`CAa3cbcf63...`), not the parent API call (`CAf52bcd02...`). You must find the trunk call to list its recordings.
- Dual-channel trunk recording: ch1 = Twilio/originating side (TTS/TwiML audio), ch2 = SIP/terminating side (PBX audio)
- Transcript: ALPHA phrases on ch1, Asterisk playback (`[music]`) on ch2. Channel assignment for trunk recordings is **opposite** from ConversationRelay recordings — ch1 = the originator's audio, ch2 = the remote party.

Evidence:
- Dual: CA=CAf52bcd02... (parent) → trunk leg CA=CAa3cbcf63..., RE=RE7da90e3e..., GT=GTc9c30766...
- Mono: CA=CA2dea4252..., RE=RE846bfb17...

## Questions Answered

1. **`<Start><Recording>` source**: `StartCallRecordingTwiML` (distinct from API's `StartCallRecordingAPI`)
2. **`<Start><Recording>` channels**: Always 2, regardless of `recordingTrack` parameter
3. **Calls API `Record=true` channels**: 1 (mono) by default
4. **Concurrent recordings**: Allowed from different sources, produce separate RE SIDs
5. **Two API recordings on same call**: Second silently succeeds but only one recording produced
6. **Callback fields**: All methods include RecordingTrack, RecordingSource, RecordingChannels
7. **Pause/Resume on ConversationRelay**: NOT supported — "not eligible for recording" error
8. **`trim-silence`**: Confirmed working — reduced 10s recording to 5s
9. **Channel assignment**: Channel 1 = child leg (TO number), Channel 2 = parent leg (API side). Consistent across ALL methods.
10. **`recordingTrack` on `<Start><Recording>`**: Has no observable effect — both channels always have audio, recording is always 2 channels.
11. **PCI mode blocks Voice Intelligence**: Recordings created under PCI mode are permanently untranscribable.
12. **`Twilio.CURRENT`**: Works for pause/resume without knowing RE SID.
13. **API `recordingTrack` isolates audio**: `inbound` = child leg only, `outbound` = parent leg only. Unlike TwiML which does NOT isolate.
14. **Pause `skip` vs `silence`**: Skip removes paused time (shorter duration). Silence inserts dead air (same duration as elapsed time).
15. **Pause/Resume requires non-CR call**: ConversationRelay-connected calls reject `start_call_recording` and pause/resume.
16. **SIP trunk recording**: Source is `Trunking`, records on trunk leg call SID (not parent). Dual-channel: ch1=originator, ch2=remote (opposite from CR recordings).
17. **Channel assignment differs by recording source**: ConversationRelay: ch1=child, ch2=parent. Trunk: ch1=originator(Twilio), ch2=terminator(PBX). Not universal — depends on how the call was established.

## Questions Still Open

1. **from-ringing with real ring delay**: API `start_call_recording` during ringing phase captured 15s for a ~12s call, but `Record=true` (OutboundAPI) showed same duration. Inconclusive — need calls with longer ring times to see clear delta.
2. **Trunk `record-from-ringing-dual`**: Not tested separately from `record-from-answer-dual`. Expect same behavior with ring time added to duration.
