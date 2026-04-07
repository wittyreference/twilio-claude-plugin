---
name: "deepgram"
description: "Twilio development skill: deepgram"
---

---
name: deepgram
description: Deepgram STT integration with Twilio Voice. Use when configuring speech recognition with Deepgram for ConversationRelay, Gather, or real-time Transcription.
allowed-tools: Read, Grep, Glob
---

# Deepgram Integration Skill

Decision-making guide for using Deepgram speech-to-text within Twilio Voice products. Load this skill when choosing or configuring Deepgram as the STT provider for ConversationRelay, `<Gather>`, or `<Start><Transcription>`.

All claims in this skill are backed by live testing (2026-03-24, account ACxx...xx). See [references/test-results.md](references/test-results.md) for the full evidence matrix with call SIDs.

---

## Scope: What Deepgram Does (and Doesn't Do) in Twilio

Deepgram is a **speech-to-text (STT) provider only** in Twilio's voice platform. It is not available for:

- **TTS** — Use Google, Amazon Polly, or ElevenLabs for text-to-speech
- **Batch/post-call transcription** — Voice Intelligence uses its own engines
- **Media Streams** — `<Connect><Stream>` delivers raw audio; no native Deepgram routing

No Deepgram API key is required. Twilio manages the Deepgram integration — you configure it through TwiML attributes only.

---

## Attribute Name Map

Each product uses a **different mechanism** to select Deepgram and a **different model name format**. This is the single most important table in the skill.

| What you want | ConversationRelay | `<Gather>` | `<Start><Transcription>` |
|---|---|---|---|
| **Select Deepgram** | `transcriptionProvider="Deepgram"` | Implied by `deepgram_` prefix on `speechModel` | `transcriptionEngine="deepgram"` |
| **Choose model** | `speechModel="nova-3-general"` | `speechModel="deepgram_nova-3-general"` | `speechModel="nova-3"` |
| **Smart formatting** | `deepgramSmartFormat="true"` | N/A | N/A |
| **Language** | `transcriptionLanguage="en-US"` | `language="en-US"` | `languageCode="en-US"` |
| **Hints** | `hints="pizza, pepperoni"` | `hints="pizza, pepperoni"` | `hints="pizza, pepperoni"` |

**Critical**: The model name format is different for every product:
- **ConversationRelay**: `nova-3-general` (bare model name)
- **`<Gather>`**: `deepgram_nova-3-general` (requires `deepgram_` prefix)
- **`<Start><Transcription>`**: `nova-3` or `nova-3-general` (bare, short or full)

Using the wrong format silently fails: ConversationRelay/RTT model names in `<Gather>` produce error 13334 and fall back to Google. No crash — just the wrong engine.

---

## Model Compatibility Matrix (Live-Tested)

All tested 2026-03-24 with live Twilio calls. Every cell backed by a call SID.

| Model | ConversationRelay | `<Gather>` | `<Start><Transcription>` |
|-------|-------------------|------------|--------------------------|
| `nova-3-general` / `deepgram_nova-3-general` | **PASS** | **PASS** | **PASS** |
| `nova-3` / `deepgram_nova-3` | **PASS** | **PASS** | **PASS** |
| `nova-2-general` / `deepgram_nova-2-general` | **PASS** | **PASS** | **PASS** |
| `nova-2` / `deepgram_nova-2` | **PASS** | **PASS** | **PASS** |
| (omitted/default) | **PASS** | N/A | **PASS** |
| `nova-2-phonecall` / `deepgram_nova-2-phonecall` | not tested | **PASS** | not tested |

**Deepgram works in ALL THREE products.** The key is using the correct model name format per product.

---

## Quick Decision: Deepgram vs Google

| Factor | Choose Deepgram | Choose Google |
|--------|----------------|---------------|
| Call environment | Noisy, mobile, speakerphone | Clean audio, quiet environment |
| Accents | Heavy or diverse accents | Standard accents |
| Latency | Typically lower | Slightly higher |
| Language coverage | 50+ languages (Nova-3) | Broadest overall |
| CR default | Yes (new accounts post-Sept 2025) | Pre-Sept 2025 accounts |
| RTT default | Must opt in | Default |
| `<Gather>` default | Must opt in (prefix required) | Default |
| Domain models | Medical, phonecall variants | telephony, telephony_short |

---

## Integration Quick Reference

### ConversationRelay (7/7 configs tested, all pass)

```javascript
connect.conversationRelay({
  url: 'wss://your-server.com/relay',
  transcriptionProvider: 'deepgram',     // case-insensitive
  speechModel: 'nova-3-general',         // bare model name, no prefix
  deepgramSmartFormat: 'true',           // CR-exclusive feature
  voice: 'Google.en-US-Neural2-F',       // TTS is a separate provider
  language: 'en-US',
});
```

See [references/conversation-relay.md](references/conversation-relay.md) for full attribute reference and codebase examples.

### `<Gather>` (5/5 prefixed configs pass)

```javascript
twiml.gather({
  input: 'speech',
  speechModel: 'deepgram_nova-3-general',  // MUST have deepgram_ prefix
  speechTimeout: 'auto',
  action: '/voice/handle-result',
});
```

The `deepgram_` prefix is **mandatory**. Without it (`nova-3-general`), Twilio rejects the model (error 13334) and silently falls back to Google. This follows the same convention as Google V2 models (`googlev2_telephony`).

### `<Start><Transcription>` (6/6 configs tested, all pass)

```javascript
start.transcription({
  transcriptionEngine: 'deepgram',       // case-insensitive
  speechModel: 'nova-3',                 // bare model name, no prefix
  track: 'both_tracks',
  statusCallbackUrl: callbackUrl,
});
```

Callback field for transcript text is `TranscriptionData` (JSON string with `transcript` and `confidence` keys), not `TranscriptionText`.

See [references/gather-and-transcription.md](references/gather-and-transcription.md) for full details and callback format.

---

## Gotchas

1. **Model name format differs per product**: This is the #1 pitfall. `<Gather>` requires a `deepgram_` prefix (`deepgram_nova-3-general`). ConversationRelay and RTT use the bare model name (`nova-3-general` or `nova-3`). Using the wrong format causes a silent fallback to Google — no crash, just the wrong engine.

2. **Different attribute names per product**: ConversationRelay uses `transcriptionProvider`, RTT uses `transcriptionEngine`, `<Gather>` has no engine attribute (engine is implied by the model name prefix). Both `transcriptionProvider` and `transcriptionEngine` are case-insensitive.

3. **Default provider changed Sept 2025**: Deepgram became the default `transcriptionProvider` for ConversationRelay on new accounts. Code without explicit `transcriptionProvider` may use different engines across accounts.

4. **`deepgramSmartFormat` is ConversationRelay-only**: Controls number/date/currency formatting in transcripts. Not available on RTT or Gather.

5. **RTT callback field is `TranscriptionData`, not `TranscriptionText`**: The transcript is a JSON string inside `TranscriptionData` with keys `transcript` and `confidence`. Parsing with `event.TranscriptionText` yields nothing.

6. **No Deepgram API key needed**: Twilio manages the integration entirely.

7. **`<Gather>` fails silently with wrong model format**: Error 13334 is a WARNING, not a hard failure. The call continues with Google STT. You will get speech recognition results — just not from Deepgram. Always check call notifications after testing to confirm.

---

## Related Resources

- [ConversationRelay CLAUDE.md](/CLAUDE.md) — Protocol, streaming, WebSocket handler patterns
- [Voice Skill](/skills/voice/SKILL.md) — Transcription Method Selection framework, TTS Voice Tier guidance
- [Voice Use Case Map](/skills/voice-use-case-map/SKILL.md) — Per-use-case product recommendations
- [Media Streams Skill](/skills/media-streams/SKILL.md) — Raw audio alternative (no native Deepgram, bring-your-own STT)

---

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| ConversationRelay config | [references/conversation-relay.md](references/conversation-relay.md) | Configuring Deepgram STT for voice AI agents, TTS pairing, codebase examples |
| Gather & Transcription | [references/gather-and-transcription.md](references/gather-and-transcription.md) | `<Gather>` prefix syntax, RTT callback format |
| Model selection | [references/model-selection.md](references/model-selection.md) | Choosing between Deepgram models, comparing Deepgram vs Google |
| Test evidence | [references/test-results.md](references/test-results.md) | Full test matrix with call SIDs, 25+ tests across 3 products |
