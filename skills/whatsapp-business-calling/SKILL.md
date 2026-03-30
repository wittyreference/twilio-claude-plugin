---
name: "whatsapp-business-calling"
description: "Twilio development skill: whatsapp-business-calling"
---

---
name: whatsapp-business-calling
description: Twilio WhatsApp Business Calling guide. Use when building voice calls over WhatsApp, configuring WhatsApp voice endpoints, or routing WhatsApp calls via TwiML.
---

# WhatsApp Business Calling Skill

Voice calling over WhatsApp endpoints using Twilio Programmable Voice. Load this skill when building WhatsApp-to-WhatsApp or WhatsApp-to-VoIP voice applications.

**Status:** Public Beta (no SLA). Features may change before GA.

---

## Scope

### CAN

- Receive inbound calls from WhatsApp users (user-initiated)
- Place outbound calls to WhatsApp users (business-initiated, geo-restricted)
- Use standard TwiML verbs: `<Say>`, `<Play>`, `<Gather>`, `<Record>`, `<Dial>`, `<Hangup>`
- Route WhatsApp calls to Twilio Flex
- Route WhatsApp calls to VoIP/WebRTC endpoints
- Route WhatsApp calls to SIP interfaces
- Embed voice call buttons in WhatsApp message templates
- Configure via TwiML App (Voice URL + Status Callback)

### CANNOT

- **Bridge to PSTN** — Calls from WhatsApp endpoints cannot connect to PSTN numbers. Such calls are rejected.
- **Business-initiated calls in US, Canada, Egypt, Nigeria, Turkiye, Vietnam** — Outbound calling blocked in these countries
- **Calls to/from sanctioned countries** — Cuba, Iran, North Korea, Syria, Crimea, Donetsk, Luhansk
- **Work without Meta prerequisites** — Requires Meta Business Verification + 2,000 business-initiated messaging capacity in rolling 24h

---

## Quick Decision

| Need | Use WhatsApp Calling? | Why |
|------|----------------------|-----|
| Voice calls between WhatsApp users via Twilio | Yes | Native WhatsApp audio with TwiML control |
| Voice calls to PSTN phones | No — use regular Programmable Voice | WhatsApp cannot bridge to PSTN |
| Outbound calls in the US | No — use regular Programmable Voice | US is blocked for business-initiated WhatsApp calls |
| Voice AI agent over WhatsApp | Possible — ConversationRelay or `<Connect><Stream>` | Same TwiML verbs apply, but test WebSocket compatibility |
| WhatsApp messaging (not voice) | No — use Messaging API | This skill is voice-only |

---

## Prerequisites

1. **Meta Business Verification** — Complete Meta's business verification process
2. **WhatsApp Messaging Capacity** — Must have 2,000+ business-initiated conversations in a rolling 24h period
3. **WhatsApp Sender** — A WhatsApp-enabled Twilio number or sender
4. **TwiML App** — Configure `voice_application_sid` on the WhatsApp sender

### Setup

```
POST /v2/Channels/Senders/{SenderSID}
voice_application_sid=APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

To deactivate: set `voice_application_sid` to `null`.

---

## Call Flow

### Inbound (User-Initiated)

1. WhatsApp user taps calling icon or voice button in message template
2. Twilio sends webhook to your TwiML App's Voice URL
3. Your app returns TwiML — handled identically to standard inbound calls
4. Webhook includes standard voice parameters (CallSid, From, To, etc.)

### Outbound (Business-Initiated)

1. Create call via Calls API with WhatsApp endpoint
2. Consumer receives call on WhatsApp
3. Requires business-initiated conversation consent
4. **Not available in US, CA, EG, NG, TR, VN**

---

## TwiML

### `<Dial><WhatsApp>`

Route calls to WhatsApp endpoints:

```xml
<Response>
  <Dial>
    <WhatsApp>whatsapp:+15551234567</WhatsApp>
  </Dial>
</Response>
```

All standard `<Dial>` attributes apply (timeout, callerId, record, etc.).

### Supported Verbs

Standard Programmable Voice TwiML verbs work with WhatsApp calls:
- `<Say>`, `<Play>`, `<Gather>`, `<Record>`, `<Hangup>`, `<Redirect>`, `<Pause>`
- `<Dial>` (to WhatsApp, VoIP, SIP — NOT PSTN)
- `<Connect>` (Stream, ConversationRelay — verify compatibility in beta)

---

## Gotchas

1. **No PSTN bridging**: Calls from WhatsApp endpoints to PSTN numbers are rejected outright. No fallback, no error recovery — the call simply fails. Design call flows with WhatsApp-only routing.

2. **US outbound blocked**: Business-initiated calls are unavailable in the US, Canada, and 4 other countries. This is a Meta platform restriction, not a Twilio limitation. Inbound (user-initiated) calls work in all Meta Cloud API supported countries.

3. **Messaging capacity gate**: You need 2,000+ business-initiated conversations in a rolling 24h period before WhatsApp voice is available. New accounts with low messaging volume cannot enable voice.

4. **Template voice buttons require approval**: Voice call buttons embedded in WhatsApp message templates need Meta template approval before they work.

5. **Beta status means no SLA**: Feature behavior may change. Do not build mission-critical production flows on WhatsApp Business Calling without a GA commitment from your account team.

6. **TwiML App config is voice-only**: When configuring the TwiML App on a WhatsApp sender, only set the Voice Configuration section. Ignore the Messaging Configuration — that's handled separately by the Messaging API.

---

## Related Resources

- [Voice Skill](/.claude/skills/voice/SKILL.md) — Core voice decision frameworks
- [Conference Skill](/.claude/skills/conference/SKILL.md) — If routing WhatsApp calls into conferences
- [Media Streams Skill](/.claude/skills/media-streams.md) — If streaming WhatsApp call audio to WebSocket
- [Twilio WhatsApp Business Calling Docs](https://www.twilio.com/docs/voice/whatsapp-business-calling)
