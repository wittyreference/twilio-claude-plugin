---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Complete Deepgram ASR test results across all Twilio voice products. -->
<!-- ABOUTME: 19 live tests with call SIDs as evidence. Tested 2026-03-23 on account ACb4de2... -->

# Deepgram ASR Test Results

Comprehensive live testing of every Deepgram STT permutation across ConversationRelay, `<Gather>`, and `<Start><Transcription>`. All tests executed 2026-03-23 on account ACb4de2....

## Test Methodology

- **Speech source**: ConversationRelay-powered AI agent (WebSocket server + ngrok) provides automated speech input — no human needed
- **ConversationRelay tests**: Parent leg inline TwiML with CR config, child leg speaks via incoming-call handler
- **Gather tests**: Parent leg inline `<Gather>` with Deepgram speechModel, CR agent on child leg speaks
- **RTT tests**: Inline `<Start><Transcription>` + `<Connect><ConversationRelay>`, HTTP callback server captures events
- **Validation**: Call notifications API checked for each call SID. Error 13334 = "speechModel must be in the list of supported models"

## ConversationRelay Results (7/7 PASS)

| Test | transcriptionProvider | speechModel | Extra | Call SID | Result |
|------|----------------------|-------------|-------|----------|--------|
| CR-1 | `Deepgram` | `nova-3-general` | — | CA0d1c85a9... | **PASS** |
| CR-2 | `Deepgram` | `nova-3` | — | CA54b78c8f... | **PASS** |
| CR-3 | `Deepgram` | `nova-2-general` | — | CAa78c2ff3... | **PASS** |
| CR-4 | `Deepgram` | `nova-2` | — | CA9b8e6d7c... | **PASS** |
| CR-5 | `Deepgram` | (omitted) | default model | CAb2f550e4... | **PASS** |
| CR-6 | `deepgram` | `nova-3-general` | lowercase | CA4afc2dfd... | **PASS** |
| CR-7 | `Deepgram` | `nova-3-general` | `deepgramSmartFormat=false` | CA22f137df... | **PASS** |

**Key findings:**
- All 4 model name forms work: `nova-3-general`, `nova-3`, `nova-2-general`, `nova-2`
- Case-insensitive: `"deepgram"` and `"Deepgram"` both accepted
- Omitting `speechModel` uses account default (works)
- `deepgramSmartFormat=false` accepted without error

## `<Start><Transcription>` Results (6/6 PASS)

| Test | transcriptionEngine | speechModel | Call SID | Result |
|------|-------------------|-------------|----------|--------|
| T-1 | `deepgram` | `nova-3` | CAc6294b92... | **PASS** |
| T-2 | `deepgram` | `nova-3-general` | CA772357dd... | **PASS** |
| T-3 | `deepgram` | `nova-2` | CA40643732... | **PASS** |
| T-4 | `deepgram` | `nova-2-general` | CA6e1f2ac4... | **PASS** |
| T-5 | `deepgram` | (omitted) | CA27ba566f... | **PASS** |
| T-6 | `Deepgram` | `nova-3` | CAc9d74ca4... | **PASS** |

**Key findings:**
- All 4 model name forms work (same as CR)
- Case-insensitive: both cases accepted for `transcriptionEngine`
- Omitting `speechModel` uses account default (works)
- Callback confirms Deepgram via `TranscriptionEngine: "deepgram"` field
- Callback `ProviderConfiguration` shows `{"speechModel":"nova-3"}` confirming model selection
- Transcript text in `TranscriptionData` field (JSON string), NOT `TranscriptionText`

### RTT Callback Sample (T-1, with partialResults=true)

```
transcription-started: TranscriptionEngine=deepgram, ProviderConfiguration={"speechModel":"nova-3"}
transcription-content: TranscriptionData={"transcript":"Welcome"}, Final=false
transcription-content: TranscriptionData={"transcript":"Welcome to the Twilio Pro"}, Final=false
transcription-content: TranscriptionData={"transcript":"Welcome to the Twilio prototype.","confidence":1.0}, Final=true
transcription-content: TranscriptionData={"transcript":"Please press a number or speak your request.","confidence":0.999}, Final=true
transcription-stopped
```

## `<Gather>` Results — Prefix Discovery

### Phase 1: Bare model names (all fail)

| Test | speechModel | Call SID | Result |
|------|-------------|----------|--------|
| G-1 | `nova-3-general` | CA79df7406... | **FAIL** (13334) |
| G-2 | `nova-3` | CA5853e021... | **FAIL** (13334) |
| G-3 | `nova-2-general` | CA2c83c18c... | **FAIL** (13334) |
| G-4 | `nova-2` | CA8ffb3a1e... | **FAIL** (13334) |
| G-5 | `nova-2-phonecall` | CA3edfda05... | **FAIL** (13334) |
| G-6 | `deepgram:nova-3` | CAbe042791... | **FAIL** (13334) |
| G-ctrl | `googlev2_telephony` | CAef63e4f3... | **PASS** (clean) |

The Google control passing while all Deepgram models failed was the clue: Google V2 uses a `googlev2_` prefix. Maybe Deepgram needs `deepgram_`.

### Phase 2: Hypothesis testing (prefix discovery)

| Test | speechModel | Call SID | Result | Hypothesis |
|------|-------------|----------|--------|-----------|
| H1 | `deepgram_nova-3-general` | CA9598e17a... | **PASS** | `deepgram_` prefix works! |
| H2 | `deepgram_nova_3_general` | CA54f2566d... | **FAIL** (13343) | Underscores in model name wrong |
| H3 | `deepgram` | CA3f8b5a0a... | **FAIL** (13334) | Prefix alone not enough |
| H4 | `deepgram_nova-3` | CA049422bf... | **PASS** | Short name with prefix works! |
| H5 | `nova-3-general` + `language` | CA77603817... | **FAIL** (13334) | Language attr doesn't help |
| H6 | `nova-3-general` + `enhanced` | CA02350915... | **FAIL** (13334) | Enhanced attr doesn't help |

### Phase 3: Full prefix validation

| Test | speechModel | Call SID | Result |
|------|-------------|----------|--------|
| G-7 | `deepgram_nova-2-general` | CA5ad23d24... | **PASS** |
| G-8 | `deepgram_nova-2` | CAd7437c63... | **PASS** |
| G-9 | `deepgram_nova-2-phonecall` | CA946b8d4a... | **PASS** |

**Root cause**: `<Gather>` has no separate engine attribute. Unlike CR (`transcriptionProvider`) and RTT (`transcriptionEngine`), Gather encodes the engine in the model name prefix: `deepgram_` for Deepgram, `googlev2_` for Google V2. Using bare Deepgram model names (`nova-3-general`) fails because Gather doesn't recognize them without the prefix.

## Summary

| Product | Deepgram Status | Models Tested | Pass Rate |
|---------|----------------|---------------|-----------|
| **ConversationRelay** | **Fully working** | 4 models + default + case + smartFormat | 7/7 |
| **`<Start><Transcription>`** | **Fully working** | 4 models + default + case | 6/6 |
| **`<Gather>`** | **Fully working** (with `deepgram_` prefix) | 5 prefixed models + 6 bare (fail) + 1 Google ctrl | 5/5 (prefixed), 0/6 (bare) |
