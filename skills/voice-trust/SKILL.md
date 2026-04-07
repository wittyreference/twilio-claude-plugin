---
name: "voice-trust"
description: "Twilio development skill: voice-trust"
---

---
name: voice-trust
description: Twilio voice trust and caller identity guide. Use when calls are blocked, getting "Spam Likely" or "Scam Likely" labels, seeing SIP 603/608 rejections, low answer rates, improving outbound call delivery, verifying inbound callers via StirVerstat, preserving SHAKEN/STIR across transfers with CallToken, or choosing trust products (SHAKEN/STIR, Branded Calling, Voice Integrity, CNAM).
allowed-tools: mcp__twilio__*, Read, Grep, Glob
---

# Voice Trust & Caller Identity Skill

Decision framework for the Twilio call trust stack and inbound caller verification. Load this skill when a developer needs to choose trust products for answer rate improvement, verify inbound caller identity via SHAKEN/STIR, preserve attestation across call transfers, or route calls based on trust level. This is a medium-freedom skill — there are preferred product combinations, but the right stack depends on the use case.

**Evidence date**: 2026-03-28 | **Account**: ACxx...xx | **Branded Calling assertions**: 65 live-tested (see `/branded-calling` skill)

---

## Scope

### What the Voice Trust Stack CAN Do

- Achieve **SHAKEN/STIR A-level attestation** on outbound calls (proves number ownership to recipient carriers)
- **Verify inbound caller identity** via `StirVerstat` webhook parameter (attestation level of the incoming call)
- **Preserve caller verification across transfers** via `CallToken` (forward SHAKEN/STIR PASSporT to new call legs)
- Display **business name** on recipient's mobile (Basic Branded Calling)
- Display **business name + logo + call reason** on recipient's mobile (Enhanced Branded Calling)
- **Remediate spam/scam labels** on your numbers (Voice Integrity — carrier database registration)
- Register **CNAM** (Caller Name) for landline display
- **Route inbound calls by trust level** — skip IVR for Level A, screen Level B, send Level C to voicemail
- Track trust metrics via **Voice Insights** — `stir_verstat` in call summaries, Reports API for fleet-level analysis

### What the Voice Trust Stack CANNOT Do

- **Cannot guarantee call delivery** — Carrier spam filters operate independently. Even Level A + Branded Calling + Voice Integrity can still be filtered by carrier heuristics.
- **Cannot verify callers without carrier cooperation** — `StirVerstat` is only present when the originating carrier provides SHAKEN/STIR information. International calls, legacy carriers, and VoIP providers may not sign calls.
- **Cannot force display on every device** — Branded Calling display depends on recipient carrier, device OS, and phone app. No mechanism to force display.
- **Cannot brand inbound calls** — Branded Calling is outbound-only. Inbound caller ID is controlled by the originating carrier.
- **Cannot use trust products outside the US** — SHAKEN/STIR and Branded Calling are currently US-only.
- **Cannot bypass manual approval** — Trust Hub vetting involves human review at Twilio (1-3 business days for profiles, 2-6 weeks for branded calling). No API shortcut.
- **Cannot preserve attestation through `<Dial>`** — CallToken forwarding requires the Calls API or Conference Participants API. `<Dial>` uses original caller ID by default but does not pass the cryptographic PASSporT.
- **Cannot use Branded Calling with SIP Trunking** — Calls must originate via Programmable Voice (API or TwiML). SIP trunk calls bypass the branding layer.

---

## Symptom Diagnostic

When a developer reports a trust problem, they describe symptoms, not products. Map symptoms to actions:

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "Spam Likely" / "Scam Likely" on recipient phone | Number flagged in carrier analytics | Voice Integrity registration |
| SIP 603 (Decline) on outbound calls | Carrier or recipient rejecting call | Check attestation level → SHAKEN/STIR + Voice Integrity |
| SIP 608 (Rejected) on outbound calls | Carrier or callee explicitly rejecting call | Voice Integrity remediation + check calling patterns |
| Answer rates dropping over time | Numbers accumulating negative reputation | Voice Integrity + review call volume/frequency patterns |
| Answer rates <30% on new numbers | No trust signals on fresh numbers | SHAKEN/STIR (automatic with Business Profile) + Voice Integrity |
| Calls going straight to voicemail | Carrier silently filtering | Voice Integrity + Branded Calling (visual trust signal) |
| Recipients don't know who's calling | No caller identity beyond phone number | Branded Calling (mobile) + CNAM (landline) |
| Forwarded calls getting flagged | SHAKEN/STIR attestation lost on transfer | Pass CallToken via Calls API |

---

## Quick Decision

| Problem | Product | Why |
|---------|---------|-----|
| Getting "Spam Likely" / "Scam Likely" labels | Voice Integrity | Registers numbers with carrier analytics databases |
| Calls blocked (SIP 603/608) | Voice Integrity + SHAKEN/STIR | Remediate flags + prove number ownership |
| Low answer rates on outbound | SHAKEN/STIR + Voice Integrity | Attestation + spam remediation — foundational pair |
| Want business name on caller ID | Basic Branded Calling | Text name on supported mobile carriers |
| Want name + logo + call reason | Enhanced Branded Calling | Rich display (requires Voice Integrity + LOA) |
| Need caller name on landlines | CNAM | Traditional caller ID database (15 char limit) |
| Need to verify who's calling me | StirVerstat webhook parameter | Check attestation level on inbound calls |
| Forwarding calls, keep verification | CallToken | Pass SHAKEN/STIR PASSporT to new call leg |
| Maximum answer rate improvement | All products combined | Each addresses a different trust signal |

---

## Trust Product Stack

Products layer on each other. Implement bottom-up.

```
Layer 4: Enhanced Branded Calling  (name + logo + call reason)
         ↑ requires Voice Integrity
Layer 3: Basic Branded Calling     (business name display)
         ↑ requires Business Profile + LOA
Layer 2: Voice Integrity           (spam label remediation)
         ↑ requires Business Profile
Layer 1: SHAKEN/STIR               (A-level attestation — automatic)
         ↑ requires approved Primary Customer Profile
Layer 0: Primary Customer Profile  (Trust Hub business identity)
```

| Starting point | What you already have | Add next |
|---------------|----------------------|----------|
| New account | Nothing | Layer 0 → gets Layer 1 free |
| Approved Business Profile | Layers 0-1 | Voice Integrity (Layer 2) |
| Getting spam-flagged | Layers 0-1 maybe | Voice Integrity (Layer 2) |
| Want name display | Layers 0-2 | Basic Branded Calling (Layer 3) |
| Want rich display | Layers 0-3 | Enhanced Branded Calling (Layer 4) |

For detailed setup steps, Trust Hub API patterns, and carrier support: load [Branded Calling Skill](/skills/branded-calling/SKILL.md).

---

## Inbound Caller Verification

The unique value of SHAKEN/STIR for inbound calls: verify who is calling you before answering.

### StirVerstat Webhook Parameter

Present on inbound call webhooks when the originating carrier provides SHAKEN/STIR information.

| StirVerstat Value | Meaning | Recommended Action |
|-------------------|---------|-------------------|
| `TN-Validation-Passed-A` | Caller known, authorized to use this number | Trust — direct connect, skip IVR |
| `TN-Validation-Passed-B` | Caller known, number authorization unverified | Screen — name recording, light verification |
| `TN-Validation-Passed-C` | Gateway call, caller not verified | Challenge — CAPTCHA, voicemail, or queue |
| `TN-Validation-Passed-A-Diverted` | Level A but call was diverted (forwarded) | Trust with awareness — original caller verified |
| `TN-Validation-Passed-B-Diverted` | Level B, diverted | Screen |
| `TN-Validation-Passed-C-Diverted` | Level C, diverted | Challenge |
| `TN-Validation-Passed-A-Passthrough` | Level A, passport passthrough | Trust |
| `TN-Validation-Passed-B-Passthrough` | Level B, passthrough | Screen |
| `TN-Validation-Passed-C-Passthrough` | Level C, passthrough | Challenge |
| `TN-Validation-Failed-A` | PASSporT present but verification failed | Reject or challenge — possible spoofing |
| `TN-Validation-Failed-B` | Failed verification, partial attestation | Reject or challenge |
| `TN-Validation-Failed-C` | Failed verification, gateway | Reject or voicemail |
| `TN-Validation-Failed` | General verification failure | Challenge |
| `No-TN-Validation` | No valid PASSporT (malformed E.164, stale timestamp, missing fields) | Default handling — treat as unverified |
| *(absent/undefined)* | No SHAKEN/STIR information available | Default handling — parameter not in webhook body |

### Routing by Trust Level

```javascript
// ABOUTME: Route inbound calls based on SHAKEN/STIR attestation level.
// ABOUTME: Level A gets direct connect, B gets screening, C/missing gets CAPTCHA.

exports.handler = function(context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  const stirVerstat = event.StirVerstat || '';

  if (stirVerstat.includes('Passed-A')) {
    // Fully verified — connect directly
    twiml.dial(context.AGENT_NUMBER);

  } else if (stirVerstat.includes('Passed-B')) {
    // Known caller, unverified number — light screening
    twiml.say('Please state your name after the tone.');
    twiml.record({
      maxLength: 5,
      action: `${context.BASE_URL}/voice/trust-router/announce`,
      recordingStatusCallback: `${context.BASE_URL}/callbacks/recording-status`
    });

  } else if (stirVerstat.includes('Failed')) {
    // Verification failed — possible spoofing
    twiml.say('We are unable to verify your call. Goodbye.');
    twiml.hangup();

  } else {
    // Level C, No-TN-Validation, or absent — CAPTCHA challenge
    twiml.gather({
      action: `${context.BASE_URL}/voice/trust-router/captcha-verify`,
      numDigits: 2
    }).say('To prove you are a person, please enter the number after nine.');
    twiml.say('We did not receive input. Goodbye.');
    twiml.hangup();
  }

  return callback(null, twiml);
};
```

### CAPTCHA Verification Handler

```javascript
// ABOUTME: Verify DTMF CAPTCHA response for unverified inbound callers.
// ABOUTME: Correct answer connects to agent, wrong answer hangs up.

exports.handler = function(context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();

  if (event.Digits === '10') {
    twiml.dial(context.AGENT_NUMBER);
  } else {
    twiml.say('Incorrect. Goodbye.');
    twiml.hangup();
  }

  return callback(null, twiml);
};
```

### TaskRouter Integration

Route verified callers to priority queues:

```javascript
// ABOUTME: Create TaskRouter task with trust-level attribute for priority routing.
// ABOUTME: Level A callers get higher priority in the workflow expression.

const taskAttributes = {
  from: event.From,
  to: event.To,
  trust_level: getTrustLevel(event.StirVerstat),
  call_sid: event.CallSid
};

// In your TaskRouter Workflow:
// Filter: "trust_level == 'verified'" → Priority Queue
// Filter: "trust_level == 'partial'" → Standard Queue
// Default: → Screening Queue

function getTrustLevel(stirVerstat) {
  if (!stirVerstat) return 'unknown';
  if (stirVerstat.includes('Passed-A')) return 'verified';
  if (stirVerstat.includes('Passed-B')) return 'partial';
  if (stirVerstat.includes('Failed')) return 'failed';
  return 'unknown';
}
```

See [references/inbound-verification.md](references/inbound-verification.md) for the complete StirVerstat reference, Elastic SIP Trunking header mapping, and advanced routing patterns.

---

## Call Transfer with Trust Preservation

When forwarding or transferring a call, the original SHAKEN/STIR attestation is lost unless you explicitly pass the `CallToken`.

### How CallToken Works

1. Inbound call arrives → webhook includes `CallToken` parameter (JWT containing the SHAKEN PASSporT)
2. Extract `CallToken` from the webhook body
3. Pass it to the Calls API or Conference Participants API on the new leg
4. Recipient carrier sees the original attestation level

### Calls API Transfer

```javascript
// ABOUTME: Forward a call while preserving SHAKEN/STIR verification.
// ABOUTME: CallToken must be extracted from inbound webhook and passed immediately.

exports.handler = async function(context, event, callback) {
  const client = context.getTwilioClient();

  try {
    await client.calls.create({
      to: context.FORWARD_NUMBER,
      from: event.From,           // original caller's number
      callToken: event.CallToken, // preserves SHAKEN/STIR attestation
      url: `${context.BASE_URL}/voice/forwarded-handler`
    });

    // Respond with hold music or announcement while transfer connects
    const twiml = new Twilio.twiml.VoiceResponse();
    twiml.say('Transferring your call. Please hold.');
    twiml.play({ loop: 0 }, 'https://api.twilio.com/cowbell.mp3');
    return callback(null, twiml);
  } catch (err) {
    console.error('Transfer failed:', err);
    const twiml = new Twilio.twiml.VoiceResponse();
    twiml.say('We were unable to transfer your call. Goodbye.');
    return callback(null, twiml);
  }
};
```

### Conference Participants API Transfer

```javascript
// ABOUTME: Add a participant to a conference while preserving SHAKEN/STIR.
// ABOUTME: Works with warm transfers where the original caller stays on the line.

await client.conferences(conferenceSid)
  .participants.create({
    to: destinationNumber,
    from: originalFrom,
    callToken: callToken  // preserves attestation on the new leg
  });
```

### What Does NOT Preserve Attestation

| Method | Preserves attestation? | Why |
|--------|----------------------|-----|
| Calls API with `callToken` | Yes | Explicitly passes the PASSporT JWT |
| Conference Participants API with `callToken` | Yes | Same mechanism |
| `<Dial>` TwiML verb | **No** | Uses original caller ID but does not pass cryptographic proof |
| `<Dial>` with `callerId` | **No** | Sets display number but no PASSporT |
| SIP REFER | **No** | Twilio does not pass PASSporT through SIP REFER |

---

## Outbound Trust Monitoring

### StirStatus in Status Callbacks

For outbound calls you make via the Calls API, the `StirStatus` parameter in status callbacks tells you what attestation level Twilio applied:

```javascript
// ABOUTME: Status callback handler that logs outbound SHAKEN/STIR attestation.
// ABOUTME: StirStatus indicates what level Twilio signed the call with.

exports.handler = function(context, event, callback) {
  console.log(`Call ${event.CallSid}: StirStatus=${event.StirStatus}`);

  // StirStatus values for outbound:
  // 'A' — signed with full attestation
  // 'B' — signed with partial attestation
  // 'C' — signed with gateway attestation
  // absent — not signed (account not verified, or non-US call)

  return callback(null, '');
};
```

### Voice Insights Fields

| Field | Location | What it tells you |
|-------|----------|------------------|
| `stir_verstat` | Call Summary | Attestation level (inbound) or signing status (outbound) |
| `caller_name` | Call Summary `properties` object | CNAM name registered for the number |

**MCP tools for trust diagnostics:**
- `mcp__twilio__get_call_summary` — trust fields for a single call
- `mcp__twilio__validate_call` — deep validation including trust indicators
- `mcp__twilio__list_call_summaries` — filter calls by time range, direction

For fleet-level metrics (answer rates, carrier block rates, branded calling ROI), see [Branded Calling Skill → Observability](/skills/branded-calling/SKILL.md#observability--roi-measurement).

---

## Elastic SIP Trunking

SIP Trunking delivers SHAKEN/STIR information through SIP headers, not webhook parameters.

| Programmable Voice | Elastic SIP Trunking |
|-------------------|---------------------|
| `StirVerstat` webhook parameter | `X-Twilio-VerStat` SIP header |
| `StirPassportToken` webhook parameter | `Identity` SIP header (raw PASSporT JWT) |
| `CallToken` webhook parameter | Not available — no CallToken forwarding for SIP |

For SIP Trunking integration details: load [Elastic SIP Trunking Skill](/skills/elastic-sip-trunking/SKILL.md).

---

## Gotchas

### Inbound Verification

1. **StirVerstat is absent when no PASSporT exists**: Do not assume all inbound calls will have a `StirVerstat` parameter. International calls, calls from carriers without SHAKEN/STIR, and calls with malformed data will have either `No-TN-Validation` or the parameter will be absent entirely. Always handle the undefined case.

2. **StirVerstat values vary more than docs suggest**: Beyond the standard A/B/C levels, there are `-Diverted`, `-Passthrough`, and `-Failed` variants. Use `.includes('Passed-A')` rather than exact string matching to catch all A-level variants.

3. **"No-TN-Validation" is not suspicious**: It means no SHAKEN/STIR information was available — the call may be perfectly legitimate. It's the default for international calls and carriers that haven't adopted SHAKEN/STIR.

4. **Verification-Failed IS suspicious**: `TN-Validation-Failed-*` means a PASSporT was present but could not be verified. This suggests tampering or certificate issues. Treat differently from "no information."

5. **StirVerstat rollout is ongoing**: Not all US carriers sign all calls yet. The percentage of calls with valid attestation is growing but not 100%. Build routing logic that handles the absent case gracefully.

### Call Transfer

6. **CallToken is for Calls API and Conference Participants API only**: `<Dial>` preserves the original caller ID display but does NOT pass the cryptographic SHAKEN/STIR proof. For verified transfers, you must use the REST API.

7. **CallToken must be passed immediately**: Extract it from the inbound webhook and use it in the same request flow. CallTokens are not designed for storage and reuse.

8. **`<Dial>` preserves caller ID, not attestation**: When `<Dial>` forwards a call, the recipient sees the original From number, but their carrier has no cryptographic proof the call is legitimate. The recipient carrier may assign a lower attestation to the forwarded leg.

### Outbound Trust

9. **SHAKEN/STIR is automatic once approved**: There is no per-call opt-in. Once your Primary Customer Profile is approved in Trust Hub, all outbound calls from assigned numbers are signed. There is no separate Trust Product to create for SHAKEN/STIR.

10. **A-level attestation requires number assignment**: Only calls from phone numbers assigned to both the Business Profile and SHAKEN/STIR Trust Product get Level A signing. Unassigned numbers may get Level B or C.

11. **SIP Trunk calls bypass Branded Calling**: Calls originating through Elastic SIP Trunking do not receive Branded Calling treatment. Only Calls API or TwiML-driven flows are branded.

### Trust Products

12. **Trust products layer — skip nothing**: Enhanced Branded Calling requires Voice Integrity, which requires a Business Profile. Basic requires a Business Profile + LOA. There is no shortcut.

13. **Approval timelines are business days**: Primary Customer Profile ~1-3 days. Basic Branded Calling ~2-4 weeks. Enhanced ~3-6 weeks. Plan ahead of production launch.

14. **US only**: Both SHAKEN/STIR signing and Branded Calling are US-only. International calling trust is handled differently (varies by country regulation).

15. **High volume + low answer rate = spam labels**: Even with every trust product enabled, carrier heuristics can still flag your numbers if call patterns look suspicious. Trust products complement good calling practices — they don't replace them.

---

## Related Resources

- [Branded Calling Skill](/skills/branded-calling/SKILL.md) — Deep implementation: Trust Hub API, setup walkthrough, carrier support, Reports API, ROI measurement (65 live-tested assertions)
- [Voice Skill](/skills/voice/SKILL.md) — Core voice development, TwiML, Calls API
- [Voice Insights Skill](/skills/voice-insights/SKILL.md) — Call diagnostics, quality metrics, `stir_verstat` field
- [Voice Use Case Map](/skills/voice-use-case-map/SKILL.md) — Product selection by use case
- [Elastic SIP Trunking Skill](/skills/elastic-sip-trunking/SKILL.md) — SIP header delivery for `X-Twilio-VerStat`
- [Phone Numbers Skill](/skills/phone-numbers/SKILL.md) — Number purchase, webhook config
- [Compliance Skill](/skills/compliance-regulatory.md) — Trust Hub, regulatory bundles, A2P 10DLC
- [IAM Skill](/skills/iam/SKILL.md) — API key auth for Trust Hub API operations
- MCP tools: `mcp__twilio__get_call_summary`, `mcp__twilio__validate_call`, `mcp__twilio__list_call_summaries`, `mcp__twilio__get_insights_settings`, `mcp__twilio__update_insights_settings`

---

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Inbound verification deep-dive | [references/inbound-verification.md](references/inbound-verification.md) | Full StirVerstat reference, SIP header mapping, advanced routing patterns, Conference trust patterns |
| Assertion audit | [references/assertion-audit.md](references/assertion-audit.md) | Provenance chain for all factual claims in this skill |
