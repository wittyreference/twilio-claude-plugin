---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Complete WebSocket protocol reference for ConversationRelay. -->
<!-- ABOUTME: All message types, fields, examples for both directions (Twilio→app and app→Twilio). -->

# ConversationRelay WebSocket Protocol Reference

All message formats verified by live testing (2026-03-28, account ACxx...xx). See [test-results.md](test-results.md) for SID evidence.

## Connection

Twilio initiates a WebSocket connection to the `url` specified in TwiML. The upgrade request includes:

- `x-twilio-signature` — Standard Twilio request signature for validation
- `x-amzn-bedrock-agentcore-runtime-custom-twilio-signature` — Additional signature header
- Standard WebSocket upgrade headers

Validate the `x-twilio-signature` using the same method as standard Twilio webhooks (HMAC-SHA1 with your auth token).

---

## Messages from Twilio → Your Application

### `setup`

Sent once immediately after WebSocket connection. Contains call metadata and custom parameters.

```json
{
  "type": "setup",
  "sessionId": "VXe3ca98b72ebb218e4cad48fcf12826e0",
  "callSid": "CAb74ac38038b5378b26090bf02066450e",
  "parentCallSid": "",
  "accountSid": "ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "from": "+15551234567",
  "to": "+15550100004",
  "forwardedFrom": "",
  "callerName": "",
  "direction": "outbound-api",
  "callType": "PSTN",
  "callStatus": "IN_PROGRESS",
  "customParameters": {
    "customerId": "cust_12345"
  }
}
```

| Field | Type | Always Present | Description |
|-------|------|:--------------:|-------------|
| `type` | string | Yes | Always `"setup"` |
| `sessionId` | string | Yes | ConversationRelay session SID (`VX...`) |
| `callSid` | string | Yes | Twilio Call SID (`CA...`) |
| `parentCallSid` | string | Yes | Parent call SID (empty string if none) |
| `accountSid` | string | Yes | Twilio Account SID (`AC...`) |
| `from` | string | Yes | Caller phone number |
| `to` | string | Yes | Called phone number |
| `forwardedFrom` | string | Yes | Forwarding number (empty string if none) |
| `callerName` | string | Yes | Caller name from CNAM (empty string if unavailable) |
| `direction` | string | Yes | Call direction: `"outbound-api"`, `"inbound"` |
| `callType` | string | Yes | `"PSTN"`, `"SIP"`, `"CLIENT"` |
| `callStatus` | string | Yes | `"IN_PROGRESS"` |
| `customParameters` | object | Yes | Key-value pairs from `<Parameter>` elements (empty object if none) |

### `prompt`

Sent when caller speech is transcribed. With `partialPrompts="false"` (default), only the final transcript is sent. With `partialPrompts="true"`, progressive partial transcripts arrive before the final.

```json
{
  "type": "prompt",
  "voicePrompt": "I need help with my account",
  "lang": "en-US",
  "last": true
}
```

| Field | Type | Always Present | Description |
|-------|------|:--------------:|-------------|
| `type` | string | Yes | Always `"prompt"` |
| `voicePrompt` | string | Yes | Transcribed caller speech |
| `lang` | string | Yes | Detected language code |
| `last` | boolean | Yes | `true` = final transcript for this utterance. `false` = partial (more coming) |

**Important**: The `confidence` field documented in some references is NOT present in live prompt messages. Do not depend on it.

**Partial prompts pattern** (`partialPrompts="true"`):
```
{"voicePrompt": "I need",        "last": false}
{"voicePrompt": "I need help",   "last": false}
{"voicePrompt": "I need help with my account", "last": false}
{"voicePrompt": "I need help with my account", "last": true}
```
Each partial contains the full utterance so far (not deltas). Only process `last: true` for LLM input.

### `dtmf`

Sent when caller presses a key. Requires `dtmfDetection="true"` in TwiML.

```json
{
  "type": "dtmf",
  "digit": "1"
}
```

| Field | Type | Always Present | Description |
|-------|------|:--------------:|-------------|
| `type` | string | Yes | Always `"dtmf"` |
| `digit` | string | Yes | Single character: `0`-`9`, `*`, `#` |

### `interrupt`

Sent when caller speech interrupts TTS playback (requires `interruptible` to include `"speech"` or `"any"`).

```json
{
  "type": "interrupt",
  "utteranceUntilInterrupt": "You said:",
  "durationUntilInterruptMs": 513
}
```

| Field | Type | Always Present | Description |
|-------|------|:--------------:|-------------|
| `type` | string | Yes | Always `"interrupt"` |
| `utteranceUntilInterrupt` | string | Yes | Text that was played before interruption (may be empty) |
| `durationUntilInterruptMs` | number | Yes | Milliseconds of TTS played before interruption |

### `error`

Sent when a session error occurs.

```json
{
  "type": "error",
  "description": "Invalid message format"
}
```

| Field | Type | Always Present | Description |
|-------|------|:--------------:|-------------|
| `type` | string | Yes | Always `"error"` |
| `description` | string | Yes | Error description |

### `info` (debug only)

Sent when `debug` attribute is set in TwiML. Not sent by default.

```json
{
  "type": "info",
  "name": "roundTripDelayMs",
  "value": "148"
}
```

| `name` value | Debug channel | Description |
|-------------|---------------|-------------|
| `roundTripDelayMs` | `debugging` | Round-trip latency in milliseconds |
| `agentSpeaking` | `speaker-events` | `"on"` or `"off"` — agent TTS state |
| `clientSpeaking` | `speaker-events` | `"on"` or `"off"` — caller speech state |
| `tokensPlayed` | `tokens-played` | Text content that was played as TTS |

---

## Messages from Your Application → Twilio

### `text`

Send text to be converted to speech and played to the caller. Stream tokens as they arrive from your LLM for lowest latency.

```json
{
  "type": "text",
  "token": "I can help you with that.",
  "last": true
}
```

| Field | Type | Required | Default | Description |
|-------|------|:--------:|---------|-------------|
| `type` | string | **Yes** | — | Must be `"text"` |
| `token` | string | **Yes** | — | Text to convert to speech. Cannot be null. Supports SSML `<phoneme>` across all providers. |
| `last` | boolean | No | `false` | `true` = final token in this response. Triggers end of talk cycle. |
| `interruptible` | boolean | No | TwiML value | Override per-message. Whether caller can interrupt this text. |
| `preemptible` | boolean | No | TwiML value | Override per-message. Whether next talk cycle can interrupt this one. |
| `lang` | string | No | session language | Override TTS language for this token. |

**Streaming pattern**: Send tokens as your LLM generates them. Only the final token gets `last: true`:

```javascript
stream.on('text', (text) => {
  ws.send(JSON.stringify({ type: 'text', token: text }));
});
// After stream completes:
ws.send(JSON.stringify({ type: 'text', token: '', last: true }));
```

### `play`

Play an audio file to the caller.

```json
{
  "type": "play",
  "source": "https://example.com/hold-music.mp3",
  "loop": 1,
  "preemptible": true,
  "interruptible": true
}
```

| Field | Type | Required | Default | Description |
|-------|------|:--------:|---------|-------------|
| `type` | string | **Yes** | — | Must be `"play"` |
| `source` | string | **Yes** | — | Public URL of audio file |
| `loop` | number | No | `1` | Number of times to play. `0` = loop up to 1000 times. |
| `preemptible` | boolean | No | `false` | Whether next talk cycle can interrupt playback |
| `interruptible` | boolean | No | TwiML value | Whether caller can interrupt playback |

### `sendDigits`

Send DTMF tones to the caller.

```json
{
  "type": "sendDigits",
  "digits": "12345"
}
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `type` | string | **Yes** | Must be `"sendDigits"` |
| `digits` | string | **Yes** | Non-empty string of `0`-`9`, `w` (500ms pause), `#`, `*` |

### `language`

Switch STT and/or TTS language mid-session. Requires matching `<Language>` elements in TwiML for voice/provider configuration.

```json
{
  "type": "language",
  "ttsLanguage": "es-MX",
  "transcriptionLanguage": "es-MX"
}
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `type` | string | **Yes** | Must be `"language"` |
| `ttsLanguage` | string | No | New TTS language. Must be supported and pre-configured in TwiML. |
| `transcriptionLanguage` | string | No | New STT language. Must be supported. |

At least one of `ttsLanguage` or `transcriptionLanguage` must be provided.

### `end`

End the ConversationRelay session. Returns call control to TwiML via the `<Connect action>` URL.

```json
{
  "type": "end",
  "handoffData": "{\"reason\":\"transfer\",\"department\":\"billing\"}"
}
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `type` | string | **Yes** | Must be `"end"` |
| `handoffData` | string | No | Arbitrary string passed to `<Connect action>` callback as `HandoffData` parameter. If sending JSON, stringify it. |

After `end`, the call continues — the `<Connect action>` URL returns TwiML for the next call phase (transfer, IVR, hangup).

---

## Error Handling

| Scenario | What happens |
|----------|-------------|
| Single malformed message | Error 64107 logged, message ignored, session continues |
| 10 consecutive malformed messages | Session terminated, WebSocket close code 1007, error 64105 |
| WebSocket server crashes | Call disconnects, no auto-reconnect |
| Invalid `type` field | Counted as malformed message |
| Null `token` in text message | Error 64107 |

---

## WebSocket Close Codes

| Code | Reason | Meaning |
|------|--------|---------|
| 1000 | `"Closing websocket session"` | Normal close (call ended or `end` message sent) |
| 1007 | `"Too many consecutive malformed messages"` | 10+ unrecognized messages, error 64105 |
