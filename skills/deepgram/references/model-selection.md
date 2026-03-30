---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Deepgram model comparison and selection guide for Twilio Voice. -->
<!-- ABOUTME: Covers Nova-3 vs Nova-2, Deepgram vs Google, and Twilio-supported model subset. -->

# Deepgram Model Selection

## Twilio-Supported Models

Twilio documents support for a subset of Deepgram's full model catalog. Stick to these unless you have confirmed broader support with Twilio:

| Model | ConversationRelay | `<Start><Transcription>` | `<Gather>` (with `deepgram_` prefix) |
|-------|-------------------|--------------------------|--------------------------------------|
| `nova-3-general` | **PASS** | **PASS** | **PASS** (`deepgram_nova-3-general`) |
| `nova-3` | **PASS** | **PASS** | **PASS** (`deepgram_nova-3`) |
| `nova-2-general` | **PASS** | **PASS** | **PASS** (`deepgram_nova-2-general`) |
| `nova-2` | **PASS** | **PASS** | **PASS** (`deepgram_nova-2`) |
| `nova-2-phonecall` | not tested | not tested | **PASS** (`deepgram_nova-2-phonecall`) |

All results from live testing (2026-03-24). All three products support all Deepgram models. The critical difference: `<Gather>` requires a `deepgram_` prefix on the model name; CR and RTT use bare names. See [test-results.md](test-results.md) for call SIDs.

**Recommendation**: Start with `nova-3-general`. Fall back to `nova-2-general` if you encounter issues or need a language only supported by Nova-2.

## Nova-3 vs Nova-2

| Factor | Nova-3 | Nova-2 |
|--------|--------|--------|
| Accuracy | Higher (latest generation) | Good (proven, stable) |
| Language coverage | 50+ languages | 40+ languages |
| Specialized variants | `nova-3-medical` (English) | `nova-2-phonecall`, `nova-2-meeting`, `nova-2-finance`, etc. |
| Twilio default (CR) | Yes (new accounts) | No |
| Maturity | Newer | Battle-tested |

Nova-2's specialized variants (`nova-2-phonecall`, `nova-2-meeting`, etc.) are documented by Deepgram but not explicitly listed in Twilio's docs. They may work — test before relying on them.

## Deepgram vs Google

| Factor | Deepgram | Google |
|--------|----------|--------|
| Noisy environments | Better noise handling | Good in clean audio |
| Heavy accents | May perform better | Broad coverage |
| Latency | Typically lower | Slightly higher |
| Language breadth | 50+ (Nova-3) | Broadest overall |
| Domain models | Medical, phonecall, meeting variants | telephony, telephony_short |
| Smart formatting | Yes (`deepgramSmartFormat` in CR) | Standard punctuation |
| Default (CR) | New accounts (post-Sept 2025) | Pre-Sept 2025 accounts |
| Default (Transcription) | Must opt in | Default |
| Default (Gather) | Must specify model | Default |

## When to Choose Deepgram

- **Voice AI agents (ConversationRelay)**: Deepgram is the default for new accounts and offers lower latency, which matters for conversational flow.
- **Noisy call environments**: Contact centers, mobile callers, speakerphone usage.
- **Domain-specific vocabulary**: Medical, financial, or other specialized terminology where Deepgram's models may have better coverage.
- **Latency-sensitive flows**: When STT speed directly affects user experience (e.g., real-time transcription displays).

## When to Choose Google

- **Maximum language coverage**: Google supports the broadest set of languages.
- **Existing Google STT V2 configuration**: If you're already tuned for Google models like `googlev2_telephony`.
- **Consistency with pre-Sept 2025 setup**: Avoid changing behavior on existing accounts.

## Model Naming Across Products

The model name format varies by Twilio product:

| Product | Attribute | Deepgram Values |
|---------|-----------|----------------|
| ConversationRelay | `speechModel` | `nova-3-general`, `nova-2-general` |
| `<Gather>` | `speechModel` | Deepgram model names (see [gather-and-transcription.md](gather-and-transcription.md)) |
| `<Start><Transcription>` | `speechModel` | `nova-3`, `nova-2` (short form) or `nova-3-general`, `nova-2-general` |

## Full Deepgram Catalog (Not All Twilio-Supported)

For reference, Deepgram's complete model lineup includes models not documented by Twilio:

- **Flux** (`flux-general-en`): English-only, optimized for voice agent turn-taking
- **Nova-2 variants**: `nova-2-phonecall`, `nova-2-meeting`, `nova-2-finance`, `nova-2-voicemail`, `nova-2-drivethru`, `nova-2-automotive`, `nova-2-atc`
- **Nova-3 medical**: `nova-3-medical` (English variants)
- **Legacy**: Enhanced, Base models

These may or may not work through Twilio's integration. Test before documenting as supported.
