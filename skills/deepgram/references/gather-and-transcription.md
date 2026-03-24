<!-- ABOUTME: Deepgram configuration for Gather and Start-Transcription TwiML verbs. -->
<!-- ABOUTME: Covers attribute syntax, TwiML examples, and cross-product naming inconsistencies. -->

# Deepgram in Gather and Real-Time Transcription

Two additional Twilio voice products support Deepgram beyond ConversationRelay. Each uses different attribute names to select Deepgram as the STT engine.

## Cross-Product Attribute Reference

The same concept — "use Deepgram" — requires different attributes across products:

| Action | ConversationRelay | `<Gather>` | `<Start><Transcription>` |
|--------|-------------------|-----------|--------------------------|
| Select engine | `transcriptionProvider="Deepgram"` | Implied by `speechModel` value | `transcriptionEngine="deepgram"` |
| Choose model | `speechModel="nova-3-general"` | `speechModel="nova-3-general"` | `speechModel="nova-3"` |
| Smart format | `deepgramSmartFormat="true"` | N/A | N/A |
| Language | `transcriptionLanguage` | `language` | `languageCode` |

This naming inconsistency is the single most common source of confusion. The attribute names are not interchangeable across products.

---

## `<Gather>` with Deepgram — WORKS (prefix required)

Deepgram works with `<Gather>`, but the model name requires a `deepgram_` prefix. This follows the same convention as Google V2 models (`googlev2_telephony`). Without the prefix, Twilio rejects the model with error 13334 and silently falls back to Google.

### The Prefix Rule

| speechModel value | Result | Why |
|---|---|---|
| `deepgram_nova-3-general` | **PASS** | Correct prefix |
| `deepgram_nova-3` | **PASS** | Short name with prefix |
| `deepgram_nova-2-general` | **PASS** | Nova-2 with prefix |
| `deepgram_nova-2` | **PASS** | Short name with prefix |
| `deepgram_nova-2-phonecall` | **PASS** | Domain variant with prefix |
| `nova-3-general` | FAIL (13334) | Missing `deepgram_` prefix |
| `nova-3` | FAIL (13334) | Missing prefix |
| `deepgram` | FAIL (13334) | Prefix only, no model name |
| `deepgram_nova_3_general` | FAIL (13343) | Wrong separator (underscores not hyphens in model name) |

### TwiML Syntax

```javascript
const twiml = new Twilio.twiml.VoiceResponse();

twiml.gather({
  input: 'speech',
  speechModel: 'deepgram_nova-3-general',  // deepgram_ prefix is MANDATORY
  timeout: 5,
  speechTimeout: 'auto',
  action: '/voice/handle-result',
  method: 'POST',
});
```

### speechModel Categories (Gather)

| Category | Format | Examples |
|----------|--------|---------|
| Generic | bare name | `default`, `phone_call`, `numbers_and_commands` |
| Google STT V2 | `googlev2_` prefix | `googlev2_telephony`, `googlev2_short` |
| Deepgram | `deepgram_` prefix | `deepgram_nova-3-general`, `deepgram_nova-2` |

### Why Bare Model Names Fail

Unlike ConversationRelay (which has a separate `transcriptionProvider` attribute) and RTT (which has `transcriptionEngine`), `<Gather>` has **no engine selector attribute**. The engine is encoded in the model name itself via the prefix. This is why `nova-3-general` works in CR/RTT but fails in Gather — Gather doesn't know it's a Deepgram model without the prefix.

---

## `<Start><Transcription>` with Deepgram

Real-time transcription uses an explicit `transcriptionEngine` attribute to select Deepgram. This is the clearest integration point — separate attributes for engine and model.

### TwiML Syntax

```javascript
const twiml = new Twilio.twiml.VoiceResponse();

const start = twiml.start();
start.transcription({
  transcriptionEngine: 'deepgram',
  speechModel: 'nova-3',
  languageCode: 'en-US',
  track: 'both_tracks',
  inboundTrackLabel: 'customer',
  outboundTrackLabel: 'agent',
  statusCallbackUrl: `https://${context.DOMAIN_NAME}/callbacks/transcription-status`,
  partialResults: 'false',
});

// Continue with call flow — transcription runs in background
twiml.dial('+15551234567');
```

### Transcription Attributes (Deepgram-Relevant)

| Attribute | Values | Default | Notes |
|-----------|--------|---------|-------|
| `transcriptionEngine` | `google`, `deepgram` | `google` | Selects the STT engine |
| `speechModel` | `nova-3`, `nova-2` (Deepgram); `telephony` etc. (Google) | `telephony` | Engine-specific — not interchangeable |
| `languageCode` | e.g., `en-US` | `en-US` | Standard language code |
| `track` | `inbound_track`, `outbound_track`, `both_tracks` | `both_tracks` | Which call legs to transcribe |
| `partialResults` | `true`, `false` | `false` | Interim results (high webhook volume) |
| `hints` | Comma-separated phrases | — | Recognition hints |
| `intelligenceService` | Service SID or name | — | Voice Intelligence integration |
| `enableProviderData` | `true`, `false` | `false` | Include engine-specific metadata |

### Transcription Callbacks

Callbacks arrive as **form-encoded** (not JSON). The transcript text is in `TranscriptionData` (a JSON string), NOT `TranscriptionText`.

| Event | Key Fields |
|-------|-----------|
| `transcription-started` | `TranscriptionSid`, `CallSid`, `TranscriptionEngine`, `ProviderConfiguration` |
| `transcription-content` | `TranscriptionData` (JSON: `{"transcript":"...","confidence":0.99}`), `Final`, `Track`, `SequenceId` |
| `transcription-stopped` | `TranscriptionSid` |
| `transcription-error` | `ErrorCode`, `ErrorMessage` |

**Parsing `TranscriptionData`:**
```javascript
// TranscriptionData is a JSON string inside a form-encoded POST
const data = JSON.parse(event.TranscriptionData);
const text = data.transcript;       // "Welcome to the Twilio prototype."
const confidence = data.confidence;  // 1.0
const isFinal = event.Final === 'true';
```

**Confirming Deepgram is active:** The `transcription-started` callback includes `TranscriptionEngine: "deepgram"` and `ProviderConfiguration: {"speechModel":"nova-3"}` — use these to verify the engine and model.

### Voice Intelligence Integration

When `intelligenceService` is specified, the transcript is automatically persisted and Language Operators run post-call — bridging real-time transcription with post-call analytics without additional API calls.

```javascript
start.transcription({
  transcriptionEngine: 'deepgram',
  speechModel: 'nova-3',
  intelligenceService: context.TWILIO_INTELLIGENCE_SERVICE_SID,
  statusCallbackUrl: callbackUrl,
});
```

## Gotchas

- **speechModel values not interchangeable**: Using `telephony` (a Google value) with `transcriptionEngine="deepgram"` will fail or produce degraded results. Always match model names to the selected engine.
- **Short utterances**: Utterances under ~200ms may not produce transcription output regardless of engine.
- **partialResults webhook volume**: Enabling partial results generates high webhook traffic. Budget for sustained volume in your callback handler.
- **Encrypted recordings**: Cannot be transcribed. Ensure recordings are unencrypted if they feed into a transcription pipeline.
- **Transcription model name format**: `<Start><Transcription>` accepts short forms (`nova-3`, `nova-2`) while ConversationRelay uses full forms (`nova-3-general`, `nova-2-general`). Both may work in both contexts, but follow the documented convention for each product.
