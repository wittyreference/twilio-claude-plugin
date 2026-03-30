---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Deepgram configuration details specific to ConversationRelay. -->
<!-- ABOUTME: Covers attributes, TwiML syntax, codebase examples, and TTS pairing guidance. -->

# Deepgram in ConversationRelay

ConversationRelay is the richest Deepgram integration point in Twilio Voice. Deepgram handles real-time speech-to-text while Twilio manages the WebSocket protocol, TTS, and call orchestration.

## Deepgram-Relevant Attributes

| Attribute | Values | Default | Notes |
|-----------|--------|---------|-------|
| `transcriptionProvider` | `Google`, `Deepgram` | `Deepgram` (new accounts post-Sept 2025) | Selects the STT engine |
| `speechModel` | `nova-3-general`, `nova-2-general` | Provider default | Model names are engine-specific — Google values don't work here |
| `deepgramSmartFormat` | `true`, `false` | `true` | Deepgram-exclusive. Auto-formats numbers, dates, currencies in transcript output |
| `transcriptionLanguage` | Language code (e.g., `en-US`) | Inherits from `language` | Override STT language independently from TTS |
| `hints` | Comma-separated phrases | — | Recognition hints for domain terms, proper nouns |
| `profanityFilter` | `true`, `false` | — | Filter profanity from transcription results |

## TwiML Configuration

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
const connect = twiml.connect();
connect.conversationRelay({
  url: 'wss://your-server.com/relay',
  // STT: Deepgram
  transcriptionProvider: 'deepgram',
  speechModel: 'nova-3-general',
  // TTS: separate provider (Deepgram is NOT a TTS option)
  ttsProvider: 'Google',               // Google, Amazon, or ElevenLabs
  voice: 'Google.en-US-Neural2-F',
  language: 'en-US',
  dtmfDetection: 'true',
  interruptible: 'true',
});
```

## TTS Pairing

Deepgram provides STT only. You must pair it with a separate TTS provider:

| TTS Provider | Voice Format | Example |
|-------------|-------------|---------|
| Google | `Google.{locale}-{type}-{variant}` | `Google.en-US-Neural2-F` |
| Amazon | `Polly.{name}` | `Polly.Amy` |
| ElevenLabs | ElevenLabs voice ID | (see ElevenLabs docs) |

The established codebase pattern is **Deepgram STT + Google Neural TTS**.

## Codebase Examples

All three handlers use `transcriptionProvider: 'deepgram'` with `speechModel: 'nova-3-general'`:

| Handler | TTS Voice | Notable Features |
|---------|-----------|-----------------|
| `ai-assistant-inbound.js` | `Google.en-US-Neural2-F` | Background recording, env var validation |
| `relay-handler.js` | `Polly.Amy` | Minimal configuration example |
| `pizza-agent-connect.js` | `Google.en-US-Neural2-F` | `welcomeGreeting`, background recording |

## Gotchas

- **Voice/provider mismatch → error 64101**: Certain voice + ttsProvider combinations cause connection failures. Google Neural voices are the safest choice.
- **`deepgramSmartFormat` is CR-only**: This attribute doesn't exist on `<Gather>` or `<Start><Transcription>`. It controls whether Deepgram auto-formats numbers ("one hundred twenty three" → "123"), dates, and currencies in the transcript.
- **Default provider changed Sept 2025**: Accounts created after this date default to Deepgram. Older accounts default to Google. Code without an explicit `transcriptionProvider` may behave differently across accounts.
- **Chirp3-HD voice naming**: For Google Chirp3-HD voices in ConversationRelay, omit the `Google.` prefix: use `en-US-Chirp3-HD-Aoede`, not `Google.en-US-Chirp3-HD-Aoede`. Neural2 voices keep the prefix.
