---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Deep-dive reference for inbound caller verification via SHAKEN/STIR. -->
<!-- ABOUTME: StirVerstat value reference, SIP header mapping, advanced routing patterns, Conference trust. -->

# Inbound Caller Verification Reference

## Complete StirVerstat Value Reference

The `StirVerstat` parameter appears in the inbound call webhook body. It is only present when the originating carrier provides SHAKEN/STIR information.

### Standard Values

| Value | Attestation | Status | Meaning |
|-------|-------------|--------|---------|
| `TN-Validation-Passed-A` | Full (A) | Verified | Caller is known AND authorized to use this number |
| `TN-Validation-Passed-B` | Partial (B) | Verified | Caller is known, number authorization unverified |
| `TN-Validation-Passed-C` | Gateway (C) | Verified | Call entered the network, caller not verified (international, gateway) |

### Diverted Call Values

When a call has been forwarded/diverted before reaching you. The attestation reflects the original caller's verification, with the diversion noted.

| Value | Attestation | Status | Meaning |
|-------|-------------|--------|---------|
| `TN-Validation-Passed-A-Diverted` | Full (A) | Verified + Diverted | Original caller verified at A, call was forwarded |
| `TN-Validation-Passed-B-Diverted` | Partial (B) | Verified + Diverted | Original caller at B, call was forwarded |
| `TN-Validation-Passed-C-Diverted` | Gateway (C) | Verified + Diverted | Original caller at C, call was forwarded |

### Passthrough Values

When the PASSporT was passed through without re-signing at an intermediate carrier.

| Value | Attestation | Status | Meaning |
|-------|-------------|--------|---------|
| `TN-Validation-Passed-A-Passthrough` | Full (A) | Passthrough | PASSporT passed through from originating carrier |
| `TN-Validation-Passed-B-Passthrough` | Partial (B) | Passthrough | PASSporT passed through |
| `TN-Validation-Passed-C-Passthrough` | Gateway (C) | Passthrough | PASSporT passed through |

### Failure Values

| Value | Meaning | Risk Level |
|-------|---------|------------|
| `TN-Validation-Failed-A` | PASSporT claimed A but verification failed | **High** — possible spoofing |
| `TN-Validation-Failed-B` | PASSporT claimed B but verification failed | **High** — possible spoofing |
| `TN-Validation-Failed-C` | PASSporT claimed C but verification failed | **Medium** — certificate or format issue |
| `TN-Validation-Failed` | General verification failure (no level) | **Medium** — could be technical issue |
| `No-TN-Validation` | No valid PASSporT present | **Low** — normal for international, legacy carriers |
| *(absent)* | Parameter not in webhook body | **Low** — SHAKEN/STIR not available on this call |

### Parsing Strategy

Use prefix matching, not exact string matching:

```javascript
// ABOUTME: Parse StirVerstat into a normalized trust tier.
// ABOUTME: Handles all variants including -Diverted and -Passthrough suffixes.

function parseTrustTier(stirVerstat) {
  if (!stirVerstat) return { tier: 'unknown', verified: false, diverted: false };

  const diverted = stirVerstat.includes('-Diverted');
  const passthrough = stirVerstat.includes('-Passthrough');

  if (stirVerstat.includes('Failed')) {
    return { tier: 'failed', verified: false, diverted };
  }
  if (stirVerstat.includes('Passed-A')) {
    return { tier: 'full', verified: true, diverted, passthrough };
  }
  if (stirVerstat.includes('Passed-B')) {
    return { tier: 'partial', verified: true, diverted, passthrough };
  }
  if (stirVerstat.includes('Passed-C')) {
    return { tier: 'gateway', verified: true, diverted, passthrough };
  }
  if (stirVerstat === 'No-TN-Validation') {
    return { tier: 'none', verified: false, diverted: false };
  }

  return { tier: 'unknown', verified: false, diverted: false };
}
```

---

## Elastic SIP Trunking Header Mapping

SIP Trunking delivers SHAKEN/STIR data through SIP headers instead of webhook parameters.

| Programmable Voice (Webhook) | Elastic SIP Trunking (SIP Header) | Notes |
|------------------------------|-----------------------------------|-------|
| `StirVerstat` | `X-Twilio-VerStat` | Same values (e.g., `TN-Validation-Passed-A`) |
| `StirPassportToken` | `Identity` header | Raw SHAKEN PASSporT JWT |
| `CallToken` | *(not available)* | No CallToken forwarding mechanism for SIP |

### SIP Header Extraction

If you're receiving calls via Elastic SIP Trunking into a PBX/SBC, extract verification from SIP headers:

```
X-Twilio-VerStat: TN-Validation-Passed-A
Identity: eyJhbGciOiJFUzI1NiIsInR5cCI6InBhc3Nwb3J0IiwieDV1Ijoi...
```

The `Identity` header contains the actual SHAKEN PASSporT JWT. You can decode it at jwt.io to inspect the attestation claims (`attest`, `orig`, `dest`).

---

## Advanced Routing Patterns

### Conference with Trust-Based Coaching

Route verified callers into a conference with agents, but enable coaching/barge for unverified callers:

```javascript
// ABOUTME: Conference routing that enables supervisor coaching for unverified callers.
// ABOUTME: Level A callers get standard conference; others get a coached conference.

exports.handler = function(context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  const trust = parseTrustTier(event.StirVerstat);
  const confName = `call-${event.CallSid}`;

  if (trust.tier === 'full') {
    // Verified caller — standard two-party conference
    const dial = twiml.dial();
    dial.conference({
      startConferenceOnEnter: true,
      endConferenceOnExit: true
    }, confName);
  } else {
    // Unverified — conference with coaching enabled
    const dial = twiml.dial();
    dial.conference({
      startConferenceOnEnter: true,
      endConferenceOnExit: true,
      record: 'record-from-start',
      coaching: true,              // allow supervisor to listen
      statusCallback: `${context.BASE_URL}/callbacks/conference-status`,
      statusCallbackEvent: 'start end join leave'
    }, `coached-${confName}`);
  }

  return callback(null, twiml);
};
```

### IVR Shortcut for Verified Callers

Skip the full IVR menu tree for Level A callers — jump straight to the relevant department:

```javascript
// ABOUTME: IVR that skips the menu for verified callers with known history.
// ABOUTME: Uses caller identity + trust level to route directly.

exports.handler = async function(context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  const trust = parseTrustTier(event.StirVerstat);

  if (trust.tier === 'full' && !trust.diverted) {
    // Verified, non-diverted — check if we know this caller
    const client = context.getTwilioClient();
    // Look up caller in your CRM or Sync map
    // If found: route directly to their assigned agent/department
    twiml.say('Welcome back. Connecting you now.');
    twiml.dial(context.AGENT_NUMBER);
  } else {
    // Standard IVR flow
    twiml.gather({
      action: `${context.BASE_URL}/voice/ivr/menu-handler`,
      numDigits: 1
    }).say('Press 1 for sales, 2 for support, 3 for billing.');
    twiml.redirect(`${context.BASE_URL}/voice/ivr/welcome`);
  }

  return callback(null, twiml);
};
```

### Trust-Aware Voicemail Transcription Priority

Use attestation level to prioritize voicemail processing:

```javascript
// ABOUTME: Voicemail handler that prioritizes transcription for verified callers.
// ABOUTME: Unverified voicemails get queued; verified ones get immediate SMS notification.

exports.handler = function(context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  const trust = parseTrustTier(event.StirVerstat);

  twiml.say('Please leave a message after the tone.');
  twiml.record({
    maxLength: 120,
    transcribe: true,
    transcribeCallback: `${context.BASE_URL}/callbacks/voicemail-transcription`,
    action: `${context.BASE_URL}/callbacks/voicemail-complete`,
    // Pass trust tier to the callback for prioritization
    recordingStatusCallback: `${context.BASE_URL}/callbacks/recording-status?trust=${trust.tier}`,
    recordingStatusCallbackEvent: 'completed'
  });

  return callback(null, twiml);
};
```

---

## StirPassportToken (JWT)

The `StirPassportToken` parameter contains the raw SHAKEN PASSporT JWT. You can decode it to inspect:

| JWT Claim | Description |
|-----------|-------------|
| `attest` | Attestation level: `A`, `B`, or `C` |
| `orig` | Originating telephone number (JSON: `{"tn": "+1XXXXXXXXXX"}`) |
| `dest` | Destination telephone number(s) (JSON: `{"tn": ["+1XXXXXXXXXX"]}`) |
| `iat` | Issued-at timestamp (UNIX epoch) — must be within 60 seconds |
| `origid` | Unique origination identifier (UUID) |

The PASSporT uses ES256 (ECDSA with P-256) signing. The `x5u` header points to the originating carrier's public certificate for verification.

**When to inspect the JWT directly**: Almost never in application code. `StirVerstat` gives you the verification result. The JWT is useful for:
- Forensic debugging of failed verifications
- Building compliance audit trails
- Carrier-level integration where you need the raw cryptographic proof
