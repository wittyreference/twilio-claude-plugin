---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Live test evidence for ConversationRelay skill assertions. -->
<!-- ABOUTME: 12 test calls with SID evidence, organized by test category. -->

# ConversationRelay Test Results

All tests run 2026-03-28 on account ACxx...xx using a diagnostic WebSocket server at `wss://example.ngrok-free.app` with calls to a voicemail endpoint (+15550100004).

## Test Infrastructure

- **Diagnostic WS server**: Node.js WebSocket server logging all messages to JSON
- **ngrok tunnel**: `wss://example.ngrok-free.app` → localhost:8080
- **Call method**: MCP `make_call` with inline TwiML
- **Target**: Business voicemail (+15550100004) — provides consistent spoken audio for STT testing

## Test Results

### Test 1: Baseline — Setup Message Fields

| Field | Value |
|-------|-------|
| **Call SID** | `CAb74ac38038b5378b26090bf02066450e` |
| **Config** | Deepgram nova-3-general, Google Neural2-F, dtmf+interruptible, `<Parameter>` elements |
| **Result** | PASS |

**Setup message fields confirmed** (12 fields):
`type`, `sessionId` (VX...), `callSid`, `parentCallSid`, `from`, `to`, `forwardedFrom`, `callerName`, `direction`, `callType`, `callStatus`, `accountSid`, `customParameters`

**Prompt message fields confirmed** (4 fields only):
`type`, `voicePrompt`, `lang`, `last`

**Key finding**: `confidence` field is ABSENT. Domain CLAUDE.md listed it but live testing shows it is not present in current protocol.

**Custom Parameters**: `<Parameter name="testId" value="test-1-baseline" />` arrived as `customParameters.testId`.

**X-Twilio-Signature**: Present on WebSocket upgrade request. Also present: `x-amzn-bedrock-agentcore-runtime-custom-twilio-signature`.

**Action callback** (POST to `/action-callback`): Standard call params plus `SessionId`, `SessionStatus=completed`, `SessionDuration=50`.

---

### Test 2: Debug Attribute

| Field | Value |
|-------|-------|
| **Call SID** | `CA235cd451086ac730a9f3d851c2f7b560` |
| **Config** | `debug="debugging speaker-events tokens-played"` |
| **Result** | PASS — 46 events (vs 14 for baseline) |

**Debug produces `type: "info"` messages:**

| Debug Channel | `name` | `value` examples |
|--------------|--------|-----------------|
| `debugging` | `roundTripDelayMs` | `"148"`, `"129"`, `"109"`, `"110"`, `"121"` |
| `speaker-events` | `agentSpeaking` | `"on"` / `"off"` |
| `speaker-events` | `clientSpeaking` | `"on"` / `"off"` |
| `tokens-played` | `tokensPlayed` | `"Diagnostic"`, `"You said:"` (actual text played) |

Round-trip delay values ranged 109-148ms across the call.

---

### Test 3: Welcome Greeting + Interruptibility

| Field | Value |
|-------|-------|
| **Call SID** | `CA8afda66f4d1506b3f10fcef5deb28646` |
| **Config** | `welcomeGreeting="..."` + `welcomeGreetingInterruptible="none"` |
| **Result** | PASS — 5 events (greeting played, no interrupts during greeting) |

With `welcomeGreetingInterruptible="none"`, the greeting played uninterrupted. First prompt arrived only after greeting completed.

---

### Test 4: ElevenLabs TTS Provider

| Field | Value |
|-------|-------|
| **Call SID** | `CA05cc0daba17ef8dbeb558fd39cf4dab8` |
| **Config** | `ttsProvider="ElevenLabs"` + `voice="Google.en-US-Neural2-F"` |
| **Result** | FAIL — Error 64101 |

**Error**: `Invalid values (block_elevenlabs/en-US/Google.en-US-Neural2-F) for tts settings`

**Two issues discovered**:
1. `block_elevenlabs` — ElevenLabs is not enabled on this account. Requires account-level enablement.
2. Voice/provider mismatch — Google voice name used with ElevenLabs provider. ElevenLabs uses opaque voice IDs (e.g., `UgBBYS2sOqTuMpoF3BR0`).

---

### Test 5: partialPrompts Attribute

| Field | Value |
|-------|-------|
| **Call SID** | `CA9819c407c094327647b63349a4a59994` |
| **Config** | `partialPrompts="true"` |
| **Result** | PASS — 49 events (progressive partials confirmed) |

**Partial transcript pattern** (first utterance):
```
voicePrompt: "Thank you for"                              last: false
voicePrompt: "Thank you for calling"                      last: false
voicePrompt: "Thank you for calling Acme"                 last: false
voicePrompt: "Thank you for calling Acme Corporation."    last: false
voicePrompt: "Thank you for calling Acme Corporation."    last: true
```

Each partial contains the full utterance so far (cumulative, not deltas). Final `last: true` confirms the transcript.

---

### Test 6: Chirp3-HD Voice Naming

| Field | Value |
|-------|-------|
| **Call SID** | `CA11513868d479847233c32500a6166771` |
| **Config** | `voice="en-US-Chirp3-HD-Aoede"` + `ttsProvider="Google"` |
| **Result** | PASS — 14 events, no errors |

Confirms: Chirp3-HD voices use bare names without `Google.` prefix. The voice worked correctly with TTS playback.

---

### Test 7: reportInputDuringAgentSpeech + interruptible="none"

| Field | Value |
|-------|-------|
| **Call SID** | `CAeebc1434e5cbd607b2958d6758ab3f8a` |
| **Config** | `interruptible="none"` + `reportInputDuringAgentSpeech="speech"` + `interruptSensitivity="low"` |
| **Result** | PASS — 8 events |

**Behavior**: Zero `interrupt` messages (interruptible=none suppressed them). But `prompt` messages still arrived — `reportInputDuringAgentSpeech="speech"` caused speech events to be delivered during agent TTS playback. This enables capturing what callers say while the agent speaks, without interrupting the agent.

---

### Test 8: preemptible Attribute

| Field | Value |
|-------|-------|
| **Call SID** | `CA890fc3d2bd0d4d52f55b0a6c074e8107` |
| **Config** | `preemptible="true"` |
| **Result** | PASS — 13 events, no errors |

Attribute accepted. Preemptible allows subsequent talk cycle text tokens to interrupt current TTS output.

---

### Test 9: intelligenceService Attribute

| Field | Value |
|-------|-------|
| **Call SID** | `CAb46f3db663a4ae5b1acb27f79d5692d7` |
| **Config** | `intelligenceService="GA7e424e86a596eabb2e8b2e785a39f93f"` |
| **Result** | PASS — Transcript GTa86955e6 created |

**Transcript details**:
- SID: `GTa86955e6f3ee4459adac76b9afe8bfa5`
- Status: `completed`
- Sentences: 12
- Source: `"ConversationRelay"` (not "Recording")
- Source SID: `VXd54574ad255303f0b57d7fcb1b1e16ff` (session SID)
- Participants: "Virtual Agent" (ch 1) + "+15551234567" as "Customer" (ch 2)

No recording was needed — transcript created directly from the CR session.

---

### Test 10: handoffData + Action Callback

| Field | Value |
|-------|-------|
| **Call SID** | `CA92eb48b15298d2d6db5e69bcab526b24` |
| **Config** | `action="https://example.ngrok-free.app/action-callback"` + server sends `end` with `handoffData` |
| **Result** | PASS |

**Server sent**:
```json
{ "type": "end", "handoffData": "{\"reason\":\"test-handoff\",\"score\":42,\"context\":{\"key\":\"value\"}}" }
```

**Action callback received** (form-encoded POST):
| Parameter | Value |
|-----------|-------|
| `HandoffData` | `{"reason":"test-handoff","score":42,"context":{"key":"value"}}` |
| `SessionId` | `VX9daecf7f693f8fe3306e5daebaddecaf` |
| `SessionStatus` | `ended` (not "completed" — because WS sent `end`) |
| `SessionDuration` | `3` |
| `CallStatus` | `in-progress` (call still alive after CR session) |

Key: When `SessionStatus=ended`, the call is still alive. The action URL's TwiML takes control.

---

### Test 11: play Message

| Field | Value |
|-------|-------|
| **Call SID** | `CAf68b4236dc261414b46d61b3f5d3d9b3` |
| **Config** | Server sends `{ type: "play", source: "https://api.twilio.com/cowbell.mp3", loop: 1 }` |
| **Result** | PASS — 0 errors, 0 debugger alerts |

The `play` message was accepted and audio played. No special WebSocket events returned for play completion.

---

### Test 12: sendDigits Message

| Field | Value |
|-------|-------|
| **Call SID** | `CAec5f70f5dcb596dbf70fe2bfb9863cbe` |
| **Config** | Server sends `{ type: "sendDigits", digits: "12345" }` |
| **Result** | PASS — 0 errors, 0 debugger alerts |

The `sendDigits` message was accepted and digits were sent. No errors in debugger.

---

## Summary

| Test | Call SID | Status | Key Finding |
|------|----------|--------|-------------|
| 1 | CAb74ac380... | PASS | 12 setup fields; `confidence` absent from prompts; `lang` present |
| 2 | CA235cd451... | PASS | `debug` produces `type: "info"` with 4 name/value types |
| 3 | CA8afda66f... | PASS | welcomeGreetingInterruptible works |
| 4 | CA05cc0dab... | FAIL | ElevenLabs blocked on account; requires enablement |
| 5 | CA9819c407... | PASS | `partialPrompts` delivers progressive `last: false` transcripts |
| 6 | CA11513868... | PASS | Chirp3-HD bare name (no `Google.` prefix) works |
| 7 | CAeebc1434... | PASS | `reportInputDuringAgentSpeech` delivers prompts without interrupting |
| 8 | CA890fc3d2... | PASS | `preemptible` accepted |
| 9 | CAb46f3db6... | PASS | `intelligenceService` creates transcript from CR session directly |
| 10 | CA92eb48b1... | PASS | `handoffData` passed to action callback; `SessionStatus=ended` |
| 11 | CAf68b4236... | PASS | `play` message works, no errors |
| 12 | CAec5f70f5... | PASS | `sendDigits` message works, no errors |
