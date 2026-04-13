---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Complete TwiML attribute reference for ConversationRelay. -->
<!-- ABOUTME: Covers all 21 attributes, child elements, defaults, and provider-specific naming. -->

# ConversationRelay TwiML Attribute Reference

All attributes go on the `<ConversationRelay>` noun inside `<Connect>`. Tested 2026-03-28 on account ACxx...xx.

## Core Attributes

| Attribute | Type | Default | Required | Description |
|-----------|------|---------|:--------:|-------------|
| `url` | string | — | **Yes** | WebSocket URL. Must begin with `wss://`. |
| `welcomeGreeting` | string | none | No | Text spoken to caller immediately on connection. Played via TTS before WebSocket receives any prompts. |
| `welcomeGreetingInterruptible` | enum | `any` | No | Whether caller can interrupt the welcome greeting. Values: `none`, `dtmf`, `speech`, `any`. |
| `language` | string | `en-US` | No | Sets both STT and TTS language. Override individually with `ttsLanguage` or `transcriptionLanguage`. |

## TTS (Text-to-Speech) Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `ttsProvider` | enum | `ElevenLabs` (per docs; see caveat) | Provider for TTS. Values: `Google`, `Amazon`, `ElevenLabs`. ElevenLabs requires account enablement — accounts without access get `block_elevenlabs` (64101), so effective default is account-dependent. Use explicit `ttsProvider` always. |
| `voice` | string | provider default | Voice identifier. Format depends on provider (see Voice Naming below). |
| `ttsLanguage` | string | inherits from `language` | Override TTS language independently from STT. |
| `elevenlabsTextNormalization` | enum | `off` | ElevenLabs-only. Values: `on` (auto-normalize), `auto`, `off` (manual control, lower latency). |

### Voice Naming by Provider

| Provider | Format | Examples |
|----------|--------|----------|
| Google Neural2 | `Google.{locale}-Neural2-{letter}` | `Google.en-US-Neural2-F`, `Google.en-GB-Neural2-B` |
| Google Chirp3-HD | `{locale}-Chirp3-HD-{name}` (NO `Google.` prefix) | `en-US-Chirp3-HD-Aoede`, `en-US-Chirp3-HD-Puck` |
| Amazon Polly | `Polly.{name}` | `Polly.Amy`, `Polly.Matthew` |
| ElevenLabs | Voice ID string | `UgBBYS2sOqTuMpoF3BR0` |

**Gotcha**: Chirp3-HD voices omit the `Google.` prefix. Bare name `en-US-Chirp3-HD-Aoede` confirmed working. [Evidence: CA11513868] The Deepgram skill and codebase patterns also document this convention.

## STT (Speech-to-Text) Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `transcriptionProvider` | enum | `Deepgram` (post-Sept 2025) | STT provider. Values: `Google`, `Deepgram`. Default depends on account creation date. |
| `speechModel` | string | provider default | STT model. Deepgram: `nova-3-general`, `nova-3`, `nova-2-general`. Google: `telephony`, `default`. |
| `deepgramSmartFormat` | boolean | `true` | Deepgram-only. Auto-formats numbers, dates, currencies in transcript ("one hundred" → "100"). |
| `transcriptionLanguage` | string | inherits from `language` | Override STT language independently from TTS. |
| `hints` | string | none | Comma-separated phrases to improve recognition. Brand names, domain terms, proper nouns. |
| `profanityFilter` | boolean | — | Filter profanity from transcription results. |
| `partialPrompts` | boolean | `false` | Enable partial transcript delivery. Sends progressive `last: false` prompts as speech is recognized. |

**Deepgram model names differ by product** — ConversationRelay uses bare names (`nova-3-general`), `<Gather>` requires `deepgram_` prefix, `<Start><Transcription>` uses short names (`nova-3`). See the [Deepgram skill](/.claude/skills/deepgram/SKILL.md) for the full attribute name map.

## Behavior Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `interruptible` | enum/bool | `any` | Whether caller speech/DTMF can interrupt TTS. Values: `none`, `dtmf`, `speech`, `any`. Boolean `true`=`any`, `false`=`none`. |
| `interruptSensitivity` | enum | `high` | Sensitivity for speech interruption detection. Values: `low`, `medium`, `high`. |
| `dtmfDetection` | boolean | `false` | Enable DTMF keypress detection. Sends `dtmf` messages to WebSocket. |
| `reportInputDuringAgentSpeech` | enum | `none` | Deliver speech/DTMF events while agent TTS is playing, even when `interruptible` is off. Values: `none`, `dtmf`, `speech`, `any`. |
| `preemptible` | boolean | `false` | Whether subsequent talk-cycle text tokens can interrupt current TTS output. Also settable per-message in WebSocket `text` messages. |

## Observability Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `intelligenceService` | string | none | Voice Intelligence v2 Service SID (`GA...`) or unique name. Creates post-call transcript with Language Operators. Do NOT pass Intelligence v3 IDs (`intelligence_configuration_*`) — use Sierra pipeline for v3. |
| `debug` | string | none | Space-separated debug channels. Values: `debugging` (roundTripDelayMs), `speaker-events` (agentSpeaking/clientSpeaking), `tokens-played` (tokensPlayed). Produces `type: "info"` WebSocket messages. |

## Child Elements

### `<Language>` Element

Configure per-language STT/TTS overrides for multi-language sessions:

```xml
<ConversationRelay url="wss://..." language="en-US">
  <Language code="en-US" ttsProvider="Google" voice="Google.en-US-Neural2-F"
            transcriptionProvider="Deepgram" speechModel="nova-3-general" />
  <Language code="es-MX" ttsProvider="Google" voice="Google.es-US-Neural2-A"
            transcriptionProvider="Deepgram" speechModel="nova-3-general" />
  <Language code="multi" ttsProvider="Google" voice="Google.en-US-Neural2-F" />
</ConversationRelay>
```

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `code` | string | **Yes** | Language code (e.g., `en-US`, `es-MX`) or `multi` for automatic detection |
| `ttsProvider` | enum | No | Override TTS provider for this language |
| `voice` | string | No | Override voice for this language |
| `transcriptionProvider` | enum | No | Override STT provider for this language |
| `speechModel` | string | No | Override speech model for this language |

Switch languages mid-session by sending a `language` WebSocket message. The `<Language>` elements pre-configure the voice/provider for each language so the switch is instant.

### `<Parameter>` Element

Pass custom key-value pairs to the WebSocket server:

```xml
<ConversationRelay url="wss://...">
  <Parameter name="customerId" value="cust_12345" />
  <Parameter name="intent" value="billing" />
</ConversationRelay>
```

Parameters arrive in the `setup` message's `customParameters` object:

```json
{
  "type": "setup",
  "customParameters": {
    "customerId": "cust_12345",
    "intent": "billing"
  }
}
```
