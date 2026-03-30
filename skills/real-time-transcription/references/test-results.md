---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Live test evidence matrix for Real-Time Transcription skill assertions. -->
<!-- ABOUTME: All tests executed 2026-03-24 against account ACb4de2... with call SIDs and callback payloads. -->

# RTT Test Results

All tests executed 2026-03-24 against account ACb4de2....
Callback handler: `functions/callbacks/transcription-status.protected.js` → Sync logging.

---

## Test Matrix

| Test | Engine | Config | Call SID | Transcription SID | Callbacks | Result |
|------|--------|--------|----------|-------------------|-----------|--------|
| T-1 | Google | defaults | `CAfc052e3cb39d958cf6c1cc9f08391296` | `GT63c89e12a03eb72bd125b17ff849f5ac` | 5 | **PASS** |
| T-2 | Deepgram | nova-3, partialResults=true, both_tracks | `CAa1771c2fe04980ec339e788f55e5e2da` | `GTef58e1bc4c60acd1c5260adee1b96889` | 22 | **PASS** |
| T-4 | Deepgram | nova-3 + Recording | `CAae1c753c44cf181acbdbf24548715256` | `GT15227476b00f7bb3e89c3fc8f2e72cb7` | 7+ | **PASS** |
| T-5 | Invalid | `invalid_engine` | `CAb1b113399bc5eaa6713db1a43f3cbf75` | N/A | 0 | **ERROR 32650** |
| T-6 | Deepgram | nova-3, RTT + Gather | `CAb05c8bade3abd74092d8329d55b51509` | `GT086065f5c6ecaa10d05572f13128a7cb` | 8 | **PASS** |
| T-7 | Deepgram | nova-3, profanityFilter=false, punctuation=false | `CA1caaf8bb2b74aa5aef6d3b0fb7b1eba8` | `GTf43b5bda0f4caea58e343c77c064a52c` | 10 | **PASS** |
| T-8 | Deepgram | nova-3, enableProviderData=true, name set | `CA8be04d271f0063d0c14e09889ee430e4` | `GT2d0b72740814d7ab73825df27ca5fea9` | 9 | **PASS** |
| T-10 | Deepgram | REST API start, name="rest-api-test" | `CA455c3c65745cef2195ebeb0236ff31db` | `GTd914e4d9582d9c1ae89d87f91668f9c4` | 5 | **PASS** |

---

## T-1: Google Engine, Default Settings (Baseline)

**TwiML**: `<Start><Transcription statusCallbackUrl="..." />` — no engine or model specified.

**Callback sequence** (5 events):

| Seq | Event | Track | Data |
|-----|-------|-------|------|
| 1 | transcription-started | both_tracks | engine=google, config=`{"profanityFilter":"true","speechModel":"telephony","enableAutomaticPunctuation":"true"}` |
| 2 | transcription-content (final) | inbound_track | "Incoming call from direct call connecting now." conf=0.968 |
| 3 | transcription-content (final) | outbound_track | "This is test 1 revised, Google Engine with default settings. The quick brown fox jumps over the lazy dog, testing real-time transcription call back format and payload fields." conf=0.955 |
| 4 | transcription-content (final) | inbound_track | " We are sorry, an application error has occurred goodbye. Thank you, goodbye." conf=0.999 |
| 5 | transcription-stopped | — | — |

**Key findings**:
- Default engine confirmed: `google`
- Default model confirmed: `telephony`
- Default profanityFilter: `true`
- Default enableAutomaticPunctuation: `true`
- `both_tracks` produces separate callbacks per track (inbound vs outbound)
- SequenceId is global across tracks and event types
- `.protected.js` callback endpoint works — Twilio request signature is valid for transcription callbacks
- `transcription-stopped` fires automatically on call end

---

## T-2: Deepgram Nova-3 with Partial Results

**TwiML**: `<Transcription transcriptionEngine="deepgram" speechModel="nova-3" track="both_tracks" partialResults="true" />`

**Callback sequence** (22 events, abbreviated):

| Seq | Event | Track | Final | Data (excerpt) |
|-----|-------|-------|-------|----------------|
| 1 | started | both_tracks | — | engine=deepgram, config=`{"profanityFilter":"true","speechModel":"nova-3","enableAutomaticPunctuation":"true"}` |
| 2 | content | outbound | false | "This is test two." |
| 3 | content | inbound | false | "In" |
| 5 | content | inbound | false | "Incoming call from" |
| 6 | content | outbound | false | "This is test two. Deepgram engine no" |
| 8 | content | outbound | false | "This is test two. Deepgram engine Nova three with partial" |
| 9 | content | outbound | false | "...with partial results enabled." |
| 10 | content | inbound | false | "Incoming call from direct call. Connecting now." |
| 11 | content | outbound | **true** | "This is test two. Deepgram engine Nova three with partial results enabled." conf=0.996 |
| 12 | content | inbound | **true** | "Incoming call from direct call. Connecting now." conf=0.999 |
| 13-22 | content/stopped | mixed | mixed | Second utterances, inbound error messages, stopped |

**Key findings**:
- 22 callbacks (vs 5 for Google without partials) — 4.4x more webhook volume
- Partials show growing transcript text ("In" → "Incoming call from" → "Incoming call from direct call. Connecting now.")
- `confidence` only present on `Final=true` results
- `Stability` field present in raw logs for Deepgram partials (not present for Google)
- Partials and finals from different tracks are interleaved by SequenceId (not grouped by track)
- Same `ProviderConfiguration` format as Google (with different values)

---

## T-4: RTT + Recording Simultaneously

**TwiML**: Both `<Transcription>` and `<Recording>` inside same `<Start>` block.

**Result**: Both transcription AND recording callbacks arrived. Transcription callbacks went to transcription-status handler, recording callbacks went to call-status handler. No interference between the two.

**Evidence**: Transcription SID `GT15227476b00f7bb3e89c3fc8f2e72cb7` produced content callbacks. Recording SID `RE010aa5eeca63c147ca76aff7ffdf9c45` produced recording-complete callback.

---

## T-5: Invalid Engine Name

**TwiML**: `<Transcription transcriptionEngine="invalid_engine" />`

**Result**: Call completed normally (9s duration). Error 32650 in debugger and call notifications. No transcription callbacks delivered. The call was not terminated by the invalid transcription — TwiML execution continued past the `<Start>` block.

**Evidence**: `validate_call` shows `debuggerAlerts: ["32650"]`, `callNotifications: ["32650"]`. No Sync doc created (no callbacks received).

---

## T-10: REST API Start

**Sequence**:
1. Made call with plain TwiML (no `<Start><Transcription>`)
2. Polled call status until `in-progress`
3. `POST /Calls/{sid}/Transcriptions.json` with `TranscriptionEngine=deepgram`, `SpeechModel=nova-3`, `Name=rest-api-test`

**API Response**:
```json
{
  "account_sid": "ACb4de2...",
  "call_sid": "CA455c3c65745cef2195ebeb0236ff31db",
  "sid": "GTd914e4d9582d9c1ae89d87f91668f9c4",
  "status": "in-progress",
  "name": "rest-api-test",
  "date_updated": "Tue, 24 Mar 2026 18:29:34 +0000",
  "uri": "/2010-04-01/Accounts/.../Calls/.../Transcriptions/GTd914e4d9582d9c1ae89d87f91668f9c4.json"
}
```

**Callback sequence** (5 events): started → 3 content events (all inbound_track, final) → stopped.

**Key findings**:
- REST API returns GT-prefixed SID, status, name, and URI
- Callbacks arrive at the specified statusCallbackUrl just like TwiML approach
- Error 21220 if call is not `in-progress` when API is called
- `transcription-stopped` fires automatically when call ends (even for API-started transcriptions)
- Stopping via API (`POST .../Transcriptions/{sid}` with `Status=stopped`) returns 21220 if call already completed
- Out-of-order delivery observed: seq 5 (stopped) arrived before seq 4 (content)

---

## T-6: RTT + Gather Coexistence

**TwiML**: `<Start><Transcription>` followed by `<Gather input="speech">` with Deepgram on both.

**Call SID**: `CAb05c8bade3abd74092d8329d55b51509`
**Transcription SID**: `GT086065f5c6ecaa10d05572f13128a7cb`
**Callbacks**: 8 (started + 6 content + stopped)

**Result**: **PASS** — RTT and Gather coexist. RTT captured outbound audio ("Test six, transcription and") and inbound audio. Gather timed out (no speech input from called party), but RTT continued transcribing through and after the Gather timeout. No errors, no alerts.

**Key finding**: RTT runs as a background operation independent of Gather. Gather's STT session is separate from RTT's — they don't interfere with each other.

---

## T-7: profanityFilter=false, enableAutomaticPunctuation=false

**TwiML**: `<Transcription transcriptionEngine="deepgram" speechModel="nova-3" profanityFilter="false" enableAutomaticPunctuation="false" />`

**Call SID**: `CA1caaf8bb2b74aa5aef6d3b0fb7b1eba8`
**Transcription SID**: `GTf43b5bda0f4caea58e343c77c064a52c`
**Callbacks**: 10

**ProviderConfiguration confirms**: `{"profanityFilter":"false","speechModel":"nova-3","enableAutomaticPunctuation":"false"}`

**Transcript output** (outbound track):
- seq 2: "Test seven." (conf=0.998)
- seq 3: "Profanity filter off and punctuation disabled." (conf=0.992)
- seq 6: "Numbers one two three four five. This is a test of formatting differences." (conf=1.0)

**Key finding**: `enableAutomaticPunctuation=false` does NOT remove punctuation with Deepgram Nova-3. Periods and commas still appear in the transcript. This may be a Deepgram-specific behavior where punctuation is inherent to the model output and the flag has no effect, or it may only affect Google's engine. Numbers rendered as words ("one two three four five"), not digits.

---

## T-8: enableProviderData=true + name Attribute

**TwiML**: `<Transcription name="provider-data-test" enableProviderData="true" />`

**Call SID**: `CA8be04d271f0063d0c14e09889ee430e4`
**Transcription SID**: `GT2d0b72740814d7ab73825df27ca5fea9`
**Callbacks**: 9

**Result**: **PASS** — Transcription worked. The `ProviderConfiguration` in the started callback shows standard fields. No visibly different fields in the Sync-captured callback data compared to tests without `enableProviderData`. The extra provider data may appear in raw HTTP fields not captured by our handler's destructured extraction, or may only manifest with specific engine configurations.

---

## Tests Not Executed (Deferred)

| Test | Reason |
|------|--------|
| `<Stop><Transcription>` via TwiML | Need multi-step TwiML flow with stable long-running call |
| Multiple concurrent transcriptions | Need stable long-running call |
| `intelligenceService` integration | Requires Voice Intelligence Service configured |
| Multi-language detection (`languageCode="multi"`) | Requires multi-language audio source |
| `name` attribute for API-based stop | REST API stop returned 21220 (call completed first) |
