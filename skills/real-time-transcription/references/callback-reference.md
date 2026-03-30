---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Complete callback field reference for Twilio Real-Time Transcription events. -->
<!-- ABOUTME: Covers all four event types with per-field documentation, parsing examples, and engine-specific differences. -->

# RTT Callback Reference

Real-Time Transcription delivers events via form-encoded POST to your `statusCallbackUrl`. Four event types, each with specific fields.

---

## Event: `transcription-started`

Fires when the transcription engine initializes. One per transcription session.

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| `TranscriptionSid` | string | `GT63c89e12a03eb7...` | GT-prefixed SID identifying this transcription |
| `CallSid` | string | `CAfc052e3cb39d95...` | Associated call |
| `AccountSid` | string | `ACb4de277f6d5544...` | Account |
| `TranscriptionEvent` | string | `transcription-started` | Event type |
| `TranscriptionEngine` | string | `google` or `deepgram` | Confirms which engine is active |
| `ProviderConfiguration` | JSON string | `{"profanityFilter":"true","speechModel":"telephony","enableAutomaticPunctuation":"true"}` | Engine config confirmation |
| `LanguageCode` | string | `en-US` | Active language code |
| `PartialResults` | string | `false` | Whether partial results are enabled |
| `Track` | string | `both_tracks` | Which tracks are being transcribed |
| `SequenceId` | string | `1` | Always `1` for the started event |
| `Timestamp` | string | `2026-03-24T18:23:44.751Z` | ISO 8601 with nanoseconds |

**Use case**: Verify the correct engine and model were selected. Parse `ProviderConfiguration` to confirm `speechModel`.

---

## Event: `transcription-content`

Fires for each utterance (partial or final). Multiple per transcription session.

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| `TranscriptionSid` | string | `GT63c89e12a03eb7...` | Same SID as started event |
| `CallSid` | string | `CAfc052e3cb39d95...` | Associated call |
| `AccountSid` | string | `ACb4de277f6d5544...` | Account |
| `TranscriptionEvent` | string | `transcription-content` | Event type |
| `TranscriptionData` | JSON string | `{"transcript":"Hello","confidence":0.99}` | **The transcript payload** — see parsing section below |
| `Final` | string | `true` or `false` | `true` = final utterance, `false` = partial/interim |
| `Track` | string | `inbound_track` or `outbound_track` | Which call leg produced this utterance |
| `SequenceId` | string | `2`, `3`, ... | Monotonically increasing across all tracks |
| `LanguageCode` | string | `en-US` | Language code for this utterance |
| `Timestamp` | string | `2026-03-24T18:23:50.181Z` | ISO 8601 with nanoseconds |
| `Stability` | string | `0.99121094` | **Deepgram only** — confidence that partial will not change (0-1). Not present with Google. |

### Parsing `TranscriptionData`

```javascript
const data = JSON.parse(event.TranscriptionData);

// Always present:
data.transcript    // "Hello, how can I help you?"

// Only on final results (Final === 'true'):
data.confidence    // 0.9554443 (0-1 scale)
```

**Partial vs Final:**
- Partials (`Final="false"`): Contain `transcript` only (growing text as speech progresses). No `confidence`.
- Finals (`Final="true"`): Contain `transcript` and `confidence`. Represent a completed utterance.

### Track Identification

With `both_tracks`, each callback carries exactly one track label:
- `Track: "inbound_track"` — audio from the party who received the call
- `Track: "outbound_track"` — audio from the party who initiated the call

Tracks are never mixed in a single callback. Correlate across tracks using `SequenceId` for temporal ordering.

---

## Event: `transcription-stopped`

Fires when transcription ends. One per transcription session.

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| `TranscriptionSid` | string | `GT63c89e12a03eb7...` | Same SID |
| `CallSid` | string | `CAfc052e3cb39d95...` | Associated call |
| `AccountSid` | string | `ACb4de277f6d5544...` | Account |
| `TranscriptionEvent` | string | `transcription-stopped` | Event type |
| `SequenceId` | string | `5` | Final sequence number |
| `Timestamp` | string | `2026-03-24T18:23:57.468Z` | ISO 8601 |

**Triggers**: Fires when:
- Call ends (automatic)
- `<Stop><Transcription>` executes in TwiML
- REST API sets status to `stopped`

No `Track` or `TranscriptionData` on stopped events.

---

## Event: `transcription-error`

Fires when the transcription engine fails.

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| `TranscriptionSid` | string | `GTxxxxxxxx` | May or may not be present |
| `CallSid` | string | `CAxxxxxxxx` | Associated call |
| `AccountSid` | string | `ACxxxxxxxx` | Account |
| `TranscriptionEvent` | string | `transcription-error` | Event type |
| `ErrorCode` | string | `32650` | Twilio error code |
| `ErrorMessage` | string | Description of the error | Human-readable |
| `Timestamp` | string | ISO 8601 | When the error occurred |

**Known error codes:**
- **32650**: Invalid transcription engine or configuration

---

## Engine-Specific Callback Differences

| Field | Google | Deepgram |
|-------|--------|----------|
| `TranscriptionEngine` in started event | `google` | `deepgram` |
| `ProviderConfiguration.speechModel` | `telephony` (default) | `nova-3`, `nova-2`, etc. |
| `Stability` in content events | Not present | Present on partial results (0-1 float) |
| `confidence` range | 0-1 | 0-1 |
| Partial result `TranscriptionData` | `{"transcript":"..."}` | `{"transcript":"..."}` |
| Final result `TranscriptionData` | `{"transcript":"...","confidence":0.95}` | `{"transcript":"...","confidence":0.99}` |

---

## Callback Handler Pattern

```javascript
// functions/callbacks/transcription-status.protected.js
exports.handler = async function (context, event, callback) {
  const { TranscriptionEvent, TranscriptionSid, TranscriptionData, Final, Track, SequenceId } = event;

  switch (TranscriptionEvent) {
    case 'transcription-started':
      console.log(`Transcription ${TranscriptionSid} started: ${event.TranscriptionEngine}`);
      break;

    case 'transcription-content':
      if (TranscriptionData) {
        const data = JSON.parse(TranscriptionData);
        const label = Final === 'true' ? '[FINAL]' : '[partial]';
        console.log(`${label} [${Track}] seq=${SequenceId}: "${data.transcript}"`);
      }
      break;

    case 'transcription-stopped':
      console.log(`Transcription ${TranscriptionSid} stopped`);
      break;

    case 'transcription-error':
      console.log(`Transcription error: ${event.ErrorCode} - ${event.ErrorMessage}`);
      break;
  }

  const response = new Twilio.Response();
  response.setStatusCode(200);
  response.appendHeader('Content-Type', 'application/json');
  response.setBody(JSON.stringify({ success: true }));
  return callback(null, response);
};
```
