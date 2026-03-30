---
name: "real-time-transcription"
description: "Twilio development skill: real-time-transcription"
---

---
name: real-time-transcription
description: Twilio Real-Time Transcription development guide. Use when adding live transcription to voice calls via <Start><Transcription> or the Transcriptions REST API — covers engine selection, callback format, track behavior, and Voice Intelligence integration.
---

# Real-Time Transcription Skill

Decision-making guide for Twilio Real-Time Transcription (RTT). Load this skill when adding live transcription to voice calls, choosing between transcription approaches, configuring callback handlers, or integrating with Voice Intelligence.

All claims backed by live testing (2026-03-24, account ACb4de2...). See [references/test-results.md](references/test-results.md) for the evidence matrix with call SIDs.

---

## Scope

### What RTT CAN Do

- Transcribe live voice calls in near real-time (1-2s latency)
- Transcribe both sides of a call independently (`inbound_track`, `outbound_track`, or `both_tracks`)
- Use Google or Deepgram as the STT engine
- Deliver partial (interim) and final transcription results via webhooks
- Run concurrently with `<Recording>` on the same call
- Integrate with Voice Intelligence for post-call analysis via `intelligenceService` attribute
- Be started via TwiML (`<Start><Transcription>`) or REST API mid-call
- Be stopped via TwiML (`<Stop><Transcription>`) or REST API
- Label tracks with custom names (`inboundTrackLabel`, `outboundTrackLabel`)
- Filter profanity, add punctuation, and provide recognition hints

### What RTT CANNOT Do

- **Cannot do TTS** — RTT is speech-to-text only. Use Google, Amazon Polly, or ElevenLabs for text-to-speech.
- **Cannot run Language Operators in real-time** — Voice Intelligence operators (summarization, PII detection, sentiment) execute post-call on the persisted transcript, not during the call.
- **Cannot transcribe encrypted recordings** — Voice Intelligence batch transcription fails on encrypted recordings.
- **Cannot create Intelligence Services via API** — Services must be created in the Twilio Console (Console → Voice → Voice Intelligence).
- **Cannot provide speaker diarization in callbacks** — Track labels identify call legs (inbound/outbound), not individual speakers. For multi-speaker diarization, use Voice Intelligence post-call.
- **Cannot guarantee callback ordering** — SequenceId is monotonically increasing, but callbacks can arrive out of order at your webhook. Use SequenceId to reorder.
- **Cannot share an STT session with `<Gather>`** — `<Gather>` and RTT can run on the same call simultaneously (tested), but each uses an independent STT engine and produces independent results. RTT continues through and after Gather timeouts.

---

## Quick Decision: When to Use RTT

| Need | Use | Why |
|------|-----|-----|
| Live captioning / monitoring | **RTT** | Near real-time webhooks with 1-2s latency |
| Compliance recording with transcript | **RTT + Recording** | Both run simultaneously; RTT gives live text, recording gives audio archive |
| AI agent conversation | **ConversationRelay** | Built-in STT as part of WebSocket AI flow, sub-second latency |
| Post-call analysis at scale | **Voice Intelligence batch** | Process recordings after call ends, minutes latency, full operator support |
| Custom STT engine | **`<Start><Stream>`** | Raw audio WebSocket, bring your own STT |
| IVR speech input | **`<Gather input="speech">`** | Purpose-built for collecting spoken responses with action URL |
| Live + post-call analysis | **RTT with `intelligenceService`** | Real-time webhooks during call, operators run after |

---

## Decision Frameworks

### TwiML vs REST API

| Scenario | Use | Why |
|----------|-----|-----|
| Transcription starts at call beginning | TwiML `<Start><Transcription>` | Natural fit — part of the call flow |
| Transcription starts mid-call | REST API `POST /Calls/{sid}/Transcriptions` | Can start on any in-progress call without TwiML change |
| Transcription needs to stop before call ends | REST API `POST .../Transcriptions/{sid}` with `Status=stopped` | TwiML `<Stop>` requires a TwiML transition; API is immediate |
| Supervisor starts monitoring live call | REST API | No TwiML change needed on the active call |

**REST API response** returns `sid` (GT-prefixed), `status` (`in-progress` or `stopped`), `name`, `call_sid`.

**REST API error**: If the call is not `in-progress`, the API returns error **21220** ("Call is not in the expected state").

### Engine Selection: Google vs Deepgram

| Factor | Google (default) | Deepgram |
|--------|-----------------|----------|
| Default engine | Yes — used when `transcriptionEngine` is omitted | Must specify `transcriptionEngine="deepgram"` |
| Default model | `telephony` | Account-dependent |
| Partial result extras | No `Stability` field | Includes `Stability` field (0-1 float) |
| Multi-language detection | Not available | `languageCode="multi"` with Nova-3 (beta) |
| Model naming | `telephony`, `short` | `nova-3`, `nova-2`, `nova-3-general`, `nova-2-general` |
| Case sensitivity | N/A | `transcriptionEngine` is case-insensitive (`deepgram` or `Deepgram`) |
| HIPAA eligibility | Yes (with persisted transcripts) | Yes (with persisted transcripts, GA since Oct 2025) |

For full Deepgram model compatibility across products (ConversationRelay, Gather, RTT), load the [Deepgram skill](/skills/deepgram/SKILL.md).

### Track Selection

| Track | What it captures | Use case |
|-------|-----------------|----------|
| `inbound_track` | Audio from the party who received the call | Monitor what the customer says |
| `outbound_track` | Audio from the party who initiated the call | Monitor what the agent/system says |
| `both_tracks` (default) | Both sides, as separate callbacks per track | Full conversation transcript |

**How `both_tracks` works**: Callbacks arrive with `Track: "inbound_track"` or `Track: "outbound_track"` on each `transcription-content` event. They are NOT interleaved into a single stream — each utterance is labeled with its source track. Use `SequenceId` for global ordering across tracks.

---

## TwiML Integration

### Starting Transcription

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
const start = twiml.start();
start.transcription({
  statusCallbackUrl: `https://${context.DOMAIN_NAME}/callbacks/transcription-status`,
  transcriptionEngine: 'deepgram',        // 'google' (default) or 'deepgram'
  speechModel: 'nova-3',                  // engine-specific model name
  languageCode: 'en-US',                  // BCP-47 code (default: en-US)
  track: 'both_tracks',                   // inbound_track, outbound_track, both_tracks
  inboundTrackLabel: 'customer',          // custom label for inbound track
  outboundTrackLabel: 'agent',            // custom label for outbound track
  partialResults: 'false',                // 'true' for interim results (high webhook volume)
  profanityFilter: 'true',               // replaces profanity with asterisks (default: true)
  enableAutomaticPunctuation: 'true',     // adds punctuation (default: true)
  hints: 'Twilio, ConversationRelay',     // recognition hints
  // intelligenceService: 'GAxxxxxxxx',   // Voice Intelligence Service SID for post-call analysis
  // enableProviderData: 'false',         // include raw engine metadata in callbacks
  // name: 'my-transcription',            // identifier for API-based stop
});

// Call continues — transcription runs in the background
twiml.say('Your call is being transcribed for quality assurance.');
```

### Stopping Transcription

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
twiml.stop().transcription({
  // Omit to stop all active transcriptions on the call
  // Or specify: sid: 'GTxxxxxxxx'
});
```

Transcription also stops automatically when the call ends.

### RTT + Recording (Both Work Simultaneously)

```javascript
const start = twiml.start();
start.transcription({
  statusCallbackUrl: `https://${context.DOMAIN_NAME}/callbacks/transcription-status`,
  transcriptionEngine: 'deepgram',
  speechModel: 'nova-3',
});
start.recording({
  statusCallbackUrl: `https://${context.DOMAIN_NAME}/callbacks/call-status`,
});
// Both run concurrently — no conflict
```

---

## REST API Integration

### Start Transcription on In-Progress Call

```javascript
const transcription = await client.calls(callSid)
  .transcriptions
  .create({
    statusCallbackUrl: `https://${context.DOMAIN_NAME}/callbacks/transcription-status`,
    transcriptionEngine: 'deepgram',
    speechModel: 'nova-3',
    name: 'supervisor-monitor',           // optional, for referencing later
    track: 'both_tracks',
  });

console.log(transcription.sid);     // GTxxxxxxxx
console.log(transcription.status);  // 'in-progress'
console.log(transcription.name);    // 'supervisor-monitor'
```

**Error 21220**: If the call is not `in-progress` (still ringing, already completed), the API returns this error. Poll call status before starting.

### Stop Transcription

```javascript
await client.calls(callSid)
  .transcriptions(transcriptionSid)
  .update({ status: 'stopped' });
```

---

## TwiML Attribute Reference

| Attribute | Values | Default | Notes |
|-----------|--------|---------|-------|
| `statusCallbackUrl` | Absolute URL | none | Where transcription events are sent. Without this, no callbacks are delivered. |
| `transcriptionEngine` | `google`, `deepgram` | `google` | Case-insensitive |
| `speechModel` | Engine-specific | `telephony` (Google) | Deepgram: `nova-3`, `nova-2`, `nova-3-general`, `nova-2-general`. Google: `telephony`, `short` |
| `languageCode` | BCP-47 code, or `multi` | `en-US` | `multi` = Deepgram Nova-3 multi-language detection (beta) |
| `track` | `inbound_track`, `outbound_track`, `both_tracks` | `both_tracks` | Which call leg(s) to transcribe |
| `inboundTrackLabel` | Alphanumeric string | none | Custom label for inbound track in callbacks |
| `outboundTrackLabel` | Alphanumeric string | none | Custom label for outbound track in callbacks |
| `partialResults` | `true`, `false` | `false` | Interim results. Dramatically increases webhook volume. |
| `profanityFilter` | `true`, `false` | `true` | Replaces profanity with asterisks |
| `enableAutomaticPunctuation` | `true`, `false` | `true` | Adds punctuation to transcript text |
| `hints` | Comma-separated phrases | none | Recognition hints for domain-specific terms |
| `intelligenceService` | Service SID or name | none | Voice Intelligence integration for post-call analysis |
| `enableProviderData` | `true`, `false` | `false` | Include raw engine metadata in callbacks |
| `name` | Alphanumeric string | none | Identifier for referencing via REST API |

---

## Callback Format

Callbacks arrive as **form-encoded POST** (`application/x-www-form-urlencoded`), NOT JSON. See [references/callback-reference.md](references/callback-reference.md) for the complete field reference.

### Parsing Transcript Content

```javascript
// In your callback handler (Twilio Function):
exports.handler = async function (context, event, callback) {
  const { TranscriptionEvent, TranscriptionData, Final, Track, SequenceId } = event;

  if (TranscriptionEvent === 'transcription-content') {
    const data = JSON.parse(TranscriptionData);    // JSON string, not object
    const text = data.transcript;                   // "Hello, how can I help?"
    const confidence = data.confidence;             // 0.99 (only on Final=true)
    const isFinal = Final === 'true';               // String, not boolean
    const track = Track;                            // 'inbound_track' or 'outbound_track'
  }
};
```

### Event Lifecycle

```
transcription-started  →  transcription-content (repeated)  →  transcription-stopped
                           ↑                                    ↑
                           Partial and/or final utterances       Auto on call end,
                                                                 or via API/TwiML stop
```

---

## Gotchas

### Callback Format

1. **Callbacks are form-encoded, not JSON**: Transcription callbacks arrive as `application/x-www-form-urlencoded`. Do not `JSON.parse(event.body)`. In Twilio Functions, access fields directly: `event.TranscriptionData`, `event.Final`, etc.

2. **Transcript text is in `TranscriptionData`, not `TranscriptionText`**: `TranscriptionData` is a JSON string containing `{"transcript":"...","confidence":0.99}`. The field `TranscriptionText` is used by Video transcription, not voice RTT. Parsing `event.TranscriptionText` yields `undefined`.

3. **`Final` is a string, not a boolean**: The value is `"true"` or `"false"` (string). Checking `if (event.Final)` is always truthy. Check `event.Final === 'true'` instead.

4. **`confidence` is only present on final results**: Partial results (`Final="false"`) include `transcript` but not `confidence`. Only final results (`Final="true"`) include both fields.

5. **Callbacks can arrive out of order**: SequenceId is monotonically increasing, but network conditions can deliver seq 5 before seq 4. Use SequenceId to reorder if ordering matters.

### Configuration

6. **`statusCallbackUrl` must be an absolute URL**: The docs specify "absolute URL." Always use `https://domain/path`, not `/path`.

7. **No callbacks without `statusCallbackUrl`**: If omitted, transcription runs silently with no way to receive results (unless using `intelligenceService` for post-call persistence).

8. **`partialResults=true` generates high webhook volume**: A 13-second call produced 22 callbacks with partials vs 5 without. Budget callback handler capacity accordingly. Consider async queuing for high-volume deployments.

9. **Default engine is Google, default model is `telephony`**: If you omit both `transcriptionEngine` and `speechModel`, you get Google's telephony model. The `transcription-started` callback confirms the engine and model in `ProviderConfiguration`.

10. **Deepgram model names differ from `<Gather>`**: RTT uses bare names (`nova-3`). `<Gather>` requires the `deepgram_` prefix (`deepgram_nova-3-general`). ConversationRelay uses `nova-3-general`. Using the wrong format for the wrong product causes silent failures. See the [Deepgram skill](/skills/deepgram/SKILL.md) for the cross-product attribute map.

### Runtime

11. **Invalid engine produces error 32650, call continues**: An invalid `transcriptionEngine` value generates debugger error 32650 but does NOT terminate the call. The transcription silently fails and no callbacks are delivered.

12. **REST API requires `in-progress` call**: Starting transcription via REST API on a call that isn't in-progress returns error 21220 ("Call is not in the expected state"). Poll call status before attempting.

13. **`transcription-stopped` fires automatically on call end**: You do not need to explicitly stop transcription before hangup. The stopped event fires with the same TranscriptionSid.

14. **RTT and `<Recording>` coexist without conflict**: Both `<Transcription>` and `<Recording>` can run inside the same `<Start>` block. They operate independently — each sends callbacks to its own `statusCallbackUrl`.

### Observability

15. **`transcription-started` includes engine confirmation**: The `ProviderConfiguration` field (JSON string) shows `{"profanityFilter":"true","speechModel":"telephony","enableAutomaticPunctuation":"true"}`. Use this to verify the correct engine and model were selected.

16. **Deepgram partials include `Stability` field**: Deepgram partial results include a `Stability` field (0-1 float) indicating how likely the partial will change. Google does not include this field.

17. **`LanguageCode` is present on all content callbacks**: Both `transcription-started` and `transcription-content` events include the `LanguageCode` field.

18. **`enableAutomaticPunctuation=false` may not remove punctuation with Deepgram**: Testing with Deepgram Nova-3 showed punctuation (periods, commas) still appearing in transcripts even with `enableAutomaticPunctuation="false"`. The flag is confirmed in `ProviderConfiguration` but Deepgram's model may emit punctuation regardless. Test with your specific engine before relying on this flag.

19. **RTT and `<Gather>` run independently**: `<Start><Transcription>` and `<Gather input="speech">` can coexist on the same call. RTT continues transcribing through and after a Gather timeout. Gather's STT session is separate from RTT's — they use independent engines and produce independent results. No errors or interference observed.

---

## Voice Intelligence Integration

RTT integrates with Voice Intelligence via the `intelligenceService` attribute. This is the bridge between real-time and post-call analysis.

```javascript
start.transcription({
  transcriptionEngine: 'deepgram',
  speechModel: 'nova-3',
  intelligenceService: context.TWILIO_INTELLIGENCE_SERVICE_SID, // GA-prefixed SID
  statusCallbackUrl: callbackUrl,
});
```

**What happens:**
1. During the call: webhooks deliver real-time transcript to your `statusCallbackUrl`
2. After the call: transcript is persisted to Voice Intelligence
3. Language Operators run on the persisted transcript (summarization, PII detection, sentiment, custom extraction)
4. Results available via `list_operator_results` MCP tool or REST API

**Intelligence Services** (v2) must be created in the Twilio Console — there is no creation API. For the v3 Voice Intelligence API (Language Operators, real-time analysis, cross-channel), see [Voice Intelligence Skill](/skills/voice-intelligence/SKILL.md).

---

## Related Resources

- [Deepgram STT Skill](/skills/deepgram/SKILL.md) — Cross-product model naming, Deepgram-specific config, tested model matrix
- [Voice Skill](/skills/voice/SKILL.md) — Transcription Method Selection framework, broader voice context
- [Voice Use Case Map](/skills/voice-use-case-map/SKILL.md) — Per-use-case product recommendations
- [Media Streams Skill](/skills/media-streams.md) — Alternative: raw audio WebSocket with custom STT
- [Voice CLAUDE.md](/CLAUDE.md) — TwiML control model, background operations
- **MCP Tools**: `validate_transcript`, `get_transcript`, `list_transcripts`, `delete_transcript`, `create_transcript`, `list_sentences`, `list_operator_results`, `get_transcript_media`, `list_recording_transcriptions`, `get_transcription`
- [Voice Intelligence Skill](/skills/voice-intelligence/SKILL.md) — v3 API: Language Operators, real-time/post-call analysis, cross-channel
- **Codebase**: `transcription-status.protected.js` — RTT callback handler with Sync logging

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Callback fields | [references/callback-reference.md](references/callback-reference.md) | Parsing callbacks, building handlers, field-level details per event type |
| Test evidence | [references/test-results.md](references/test-results.md) | Full test matrix with call SIDs, callback payloads, and discovery narratives |
