---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Voice SDK to SIP bridging patterns, decision matrix, codec negotiation. -->
<!-- ABOUTME: Covers SDK↔SIP integration via TwiML, custom headers, and product boundaries. -->

# Voice SDK ↔ SIP Bridge

This reference documents how Voice SDK (WebRTC) clients interact with SIP endpoints through Twilio's Programmable Voice platform, and when to choose each voice product.

## Architecture

```
SDK Client (WebRTC)                    SIP Endpoint (PBX/SBC)
 ┌──────────────┐                       ┌──────────────┐
 │ JS/iOS/Android│                       │   Asterisk   │
 │ Voice SDK     │                       │   FreeSWITCH │
 │ (Opus/SRTP)   │                       │   etc.       │
 └──────┬───────┘                       └──────┬───────┘
        │ WebRTC                               │ SIP/RTP
        ▼                                      ▼
 ┌──────────────────────────────────────────────┐
 │              Twilio PV Platform              │
 │                                              │
 │  TwiML App Voice URL → <Dial><Sip>          │
 │  Codec transcoding: Opus ↔ G.711            │
 │  Media relay: SRTP ↔ RTP                    │
 └──────────────────────────────────────────────┘
```

Twilio acts as the transcoding middlebox. The developer does not manage codec negotiation — Twilio handles the WebRTC-to-SIP media bridge automatically.

## SDK → SIP (Outbound)

1. SDK client calls `device.connect()` (JS) or `Voice.connect()` (iOS/Android)
2. TwiML App's Voice URL receives the webhook with standard params + custom params from `ConnectOptions`
3. TwiML returns `<Dial><Sip>sip:extension@pbx.example.com</Sip></Dial>`
4. Twilio bridges WebRTC media to SIP media

```javascript
// TwiML handler for SDK→SIP bridge
exports.handler = function(context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  const sipUri = event.sipTarget || 'sip:default@pbx.example.com';
  const dial = twiml.dial({ callerId: context.TWILIO_PHONE_NUMBER });
  dial.sip(sipUri);
  callback(null, twiml);
};
```

## SIP → SDK (Inbound)

1. Inbound SIP INVITE arrives at a SIP Domain, triggers the Voice URL
2. TwiML returns `<Dial><Client identity="agent-name">`
3. SDK client receives incoming call via push notification / event handler

```javascript
// TwiML handler for SIP→SDK bridge
exports.handler = function(context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  const agentId = event.SipHeader_X_Agent || 'default-agent';
  const dial = twiml.dial();
  dial.client(agentId);
  callback(null, twiml);
};
```

## Custom Header / Parameter Passing

| Direction | Mechanism | Details |
|-----------|-----------|---------|
| SDK → TwiML | `ConnectOptions.params` | Available in webhook as `event.param_name` |
| TwiML → SIP | URI parameters | `sip:dest@host?x-custom-param=value` |
| SIP → TwiML | SIP headers | Available as `event.SipHeader_X_Name` (dashes become underscores) |
| SIP → SDK | Not direct | SIP headers arrive at the `<Dial action>` callback, not the SDK client |

## Codec Negotiation

SDK clients use Opus (WebRTC standard). SIP endpoints typically use G.711 μ-law/A-law (PCMU/PCMA). Twilio transcodes automatically.

**Implications:**
- Small quality loss from transcoding (Opus is higher quality than G.711)
- Small latency addition (~5ms for transcoding)
- No developer action needed — codec selection is automatic
- Voice Insights shows codec mismatch between legs when transcoding occurs

## Decision Matrix

| Scenario | Product | Why |
|----------|---------|-----|
| Browser agent calling PBX extensions | SDK (JS) + `<Dial><Sip>` | WebRTC in browser, TwiML bridges to PBX |
| Mobile app calling PBX extensions | SDK (iOS/Android) + `<Dial><Sip>` | Native app, TwiML bridges to PBX |
| PBX calling PSTN, no TwiML logic | Elastic SIP Trunking | No SDK, no PV, just a PSTN pipe |
| PBX with IVR/routing logic | SIP Interface alone | SIP INVITE triggers TwiML |
| Softphone registration on Twilio | SIP Interface with REGISTER | Endpoints register and receive calls |
| Carrier interconnect, keep numbers | BYOC | Carrier's SIP, Twilio's PV |
| Browser + SIP phone on same call | SDK + Conference + SIP Interface | Both join a conference room |
| Pure PSTN, no SIP, no SDK | Calls API or TwiML | Server-originated calls |

## What Is NOT Possible

- **SDK clients cannot REGISTER on SIP Domains** — SDKs use Twilio's proprietary signaling (not SIP REGISTER)
- **SDK clients cannot send raw SIP** — the SDK abstracts SIP entirely
- **Elastic SIP Trunking cannot be used with SDK clients** — no Programmable Voice surface
- **Inbound SIP headers are not forwarded to SDK clients during the call** — they arrive at the webhook only
- **SDK cannot negotiate specific codecs** — Twilio chooses the codec at each leg independently

## Related Resources

- [SIP Interface SKILL.md](/.claude/skills/sip/SKILL.md) — Full SIP Interface guide
- [iOS SDK SKILL.md](/.claude/skills/ios-sdk/SKILL.md) — iOS Voice SDK
- [Android SDK SKILL.md](/.claude/skills/android-sdk/SKILL.md) — Android Voice SDK
- [Elastic SIP Trunking SKILL.md](/.claude/skills/elastic-sip-trunking/SKILL.md) — Trunking guide
