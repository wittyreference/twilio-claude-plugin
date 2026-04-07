---
name: "verify"
description: "Twilio development skill: verify"
---

---
name: verify
description: Twilio Verify OTP verification guide. Use when building phone/email verification, 2FA login, signup confirmation, or debugging failed verifications.
allowed-tools: mcp__twilio__*, Read, Grep, Glob
---

<!-- verified: twilio.com/docs/verify/api, twilio.com/docs/verify/api/verification, twilio.com/docs/verify/api/verification-check, twilio.com/docs/verify/api/service, twilio.com/docs/verify/api/rate-limits-and-timeouts + live testing 2026-03-25 -->

# Twilio Verify

OTP verification across SMS, voice, email, and WhatsApp channels. Covers channel selection, service configuration, verification lifecycle, error handling, and fraud prevention.

Evidence date: 2026-03-25. Account prefix: AC... Service: VA9e7e80.

## Scope

### CAN

- Send OTP codes via SMS, voice call, email, and WhatsApp
- Silent Network Auth (SNA) for frictionless carrier-level verification
- TOTP for authenticator app integration (separate factor flow)
- Custom code lengths: 4-10 digits <!-- verified: live-tested codeLength=4 and 10 OK, 3 and 11 rejected -->
- Custom codes for testing (`customCodeEnabled` on service)
- Rate limiting via programmable rate limit keys (IP, session ID, etc.)
- Locale override for message language
- Lookup integration for carrier/line-type detection during verification
- PSD2 compliance (amount + payee in verification message)
- Cancel pending verifications
- Check by phone/email (`to`) or by VerificationSid
- Tags metadata for analytics (max 10 tags, 128 chars each)
- Risk check per-attempt (enable/disable Fraud Guard)
- DoNotShareWarning appended to SMS body
- Verification Attempts API for analytics (VL-prefixed SIDs)

### CANNOT

<!-- verified: all CANNOT items live-tested 2026-03-25 unless noted -->

- **No built-in channel fallback** — Must implement retry logic manually (e.g., SMS fails → voice). The API does not auto-escalate between channels.
- **No webhook on verification completion** — There is no callback URL. You must poll `get_verification_status` or check status in the VerificationCheck response. Status check polling is rate-limited: 60/min, 180/hr, 250/day. <!-- verified: twilio.com/docs/verify/api/rate-limits-and-timeouts -->
- **Cannot retrieve the actual code sent** — By design. The code is never returned in API responses.
- **Cannot change channel mid-verification** — Starting on a new channel reuses the same VE SID and token, but the code itself does not change. You get a new sendCodeAttempt entry. <!-- verified: live-tested channel switch sms→call→whatsapp, same VE SID -->
- **Cannot extend TTL on an existing verification** — Default 10 minutes. Customizable only at the account level (2min-24hr) via Twilio Support, not per-verification. <!-- verified: twilio.com/docs/verify/api/rate-limits-and-timeouts -->
- **VE SID deleted after approval** — Fetching an approved verification returns 404. Canceled and max_attempts_reached verifications remain fetchable. <!-- verified: live-tested, VE SID 404 after approval, persists after cancel -->
- **`auto` channel not universally available** — Returns 60200 on accounts without Fraud Guard or specific configuration. Do not assume it works. <!-- verified: live-tested, 60200 "Invalid parameter: Channel" -->
- **Email requires Mailer configuration** — Passing `channel: 'email'` without a configured Mailer (SendGrid integration) on the service returns error 60217. This is a service-level setup, not a per-request option. <!-- verified: live-tested, error 60217 -->
- **SNA requires carrier integration** — Returns 60001 "Downstream Authentication Failed" without carrier-level setup. Region-dependent availability. <!-- verified: live-tested, error 60001 -->
- **No SMS delivery confirmation** — Verify API does not report whether the SMS was actually delivered. Use Messaging Insights separately if delivery tracking is needed.

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Signup phone confirmation | `start_verification` + `check_verification` via SMS | Simplest flow, highest reach |
| Login 2FA | Same flow, store verified flag in your DB | Verify does not track "verified users" |
| Voice fallback after SMS | Start with `channel: 'sms'`, retry with `channel: 'call'` | Manual fallback; same VE SID reused |
| Email verification | Configure Mailer on service first, then `channel: 'email'` | Will not work without Mailer (error 60217) |
| Frictionless verification | SNA (`channel: 'sna'`) | No code, carrier-level — but limited availability |
| Authenticator app | TOTP factor creation (separate API flow) | Not via `start_verification` |
| Testing without real SMS | `customCodeEnabled: true` on service + `customCode` param | Avoids rate limits and costs |
| Fraud prevention | `lookupEnabled: true` on service + `riskCheck: 'enable'` | Carrier type detection + Fraud Guard |

## Decision Frameworks

### Channel Selection

| Channel | Setup Required | Code Delivery | User Experience | Best For |
|---------|---------------|---------------|-----------------|----------|
| `sms` | None | 4-10 digit code | Universal, familiar | Default for most apps |
| `call` | None | Spoken code (DTMF prompt by default) | Accessible, works on landlines | Fallback for SMS, accessibility |
| `email` | Mailer integration on service | Code in email body | Slower, may land in spam | Email-only verification |
| `whatsapp` | WhatsApp sender on service | Code in WhatsApp message | Rich, high open rate | Markets with high WhatsApp usage |
| `sna` | Carrier integration | No code (silent) | Frictionless, invisible | Mobile apps with carrier support |
| `auto` | Fraud Guard (account-level) | Varies | Twilio chooses best channel | Not reliably available |

### Service Configuration Strategy

| Setting | Default | When to Change |
|---------|---------|---------------|
| `codeLength` | 6 | Shorter (4) for better UX; longer (8-10) for higher security |
| `lookupEnabled` | false | Enable for fraud detection (adds carrier type to response) |
| `skipSmsToLandlines` | false | Enable to auto-route landlines to voice (requires lookupEnabled) |
| `dtmfInputRequired` | true | Disable for simpler voice UX (code plays immediately) |
| `customCodeEnabled` | false | Enable for testing environments only |
| `doNotShareWarningEnabled` | false | Enable for consumer-facing apps (adds security text to SMS) |

<!-- verified: all defaults confirmed via live service fetch 2026-03-25 -->

## Integration Patterns

### Basic SMS Verification

```javascript
// Start verification
const verification = await client.verify.v2
  .services(context.TWILIO_VERIFY_SERVICE_SID)
  .verifications.create({ to: phoneNumber, channel: 'sms' });
// verification.status === 'pending'
// verification.sid === 'VE...' (reused if resending within TTL)

// Check code
const check = await client.verify.v2
  .services(context.TWILIO_VERIFY_SERVICE_SID)
  .verificationChecks.create({ to: phoneNumber, code: userCode });
// check.status === 'approved' means success
// check.status === 'pending' means wrong code (no error thrown!)
```

### Fallback: SMS to Voice

```javascript
const channel = attemptCount >= 2 ? 'call' : 'sms';
const verification = await client.verify.v2
  .services(context.TWILIO_VERIFY_SERVICE_SID)
  .verifications.create({ to: phoneNumber, channel });
// Same VE SID and token reused — sendCodeAttempts array grows
```

### Check by VerificationSid (Alternative)

```javascript
// When you stored the VE SID instead of the phone number
const check = await client.verify.v2
  .services(serviceSid)
  .verificationChecks.create({ verificationSid: veSid, code: userCode });
```

### Cancel a Pending Verification

```javascript
await client.verify.v2
  .services(serviceSid)
  .verifications(veSid)
  .update({ status: 'canceled' });
// SID remains fetchable with status 'canceled'
```

### Error Handling — Start Verification

```javascript
try {
  const verification = await client.verify.v2
    .services(serviceSid)
    .verifications.create({ to: phoneNumber, channel: 'sms' });
  return { success: true, status: verification.status };
} catch (error) {
  switch (error.code) {
    case 60200: // Invalid parameter (To, Channel, Locale, etc.)
      return { success: false, error: 'Invalid input: ' + error.message };
    case 60203: // Max SEND attempts reached
      return { success: false, error: 'Too many attempts. Wait before retrying.' };
    case 60217: // Email channel not configured
      return { success: false, error: 'Email verification not available.' };
    default:
      throw error;
  }
}
```

### Error Handling — Check Verification

```javascript
try {
  const check = await client.verify.v2
    .services(serviceSid)
    .verificationChecks.create({ to: phoneNumber, code: userCode });

  if (check.status === 'approved') {
    return { success: true, verified: true };
  }
  // Wrong code: status remains 'pending', valid=false — NOT an error
  return { success: false, verified: false, attemptsRemaining: true };
} catch (error) {
  if (error.code === 60202) {
    // Max CHECK attempts (5 wrong codes)
    return { success: false, verified: false, attemptsRemaining: false };
  }
  if (error.code === 20404) {
    // VE SID deleted (expired or already approved)
    return { success: false, error: 'Verification expired. Request a new code.' };
  }
  throw error;
}
```

## Gotchas

### Service Setup

1. **FriendlyName rejects 5+ total digits**: Error 60200 if the name contains 5 or more digit characters, even non-consecutive. `my-svc-1a2b3c4d5` fails. Use alpha-only suffixes: `echo "$TS" | md5 | tr '0-9' 'g-p' | head -c 8`. [Evidence: 4-digit name VA684db2da created OK, 5-digit name returned 60200]

2. **Email channel requires Mailer integration**: Passing `channel: 'email'` without first configuring a Mailer (SendGrid or custom SMTP) on the Verify Service returns error 60217 with no hint about what to configure. [Evidence: error 60217 "A Mailer must be associated with the service"]

3. **`auto` channel is not universally available**: Returns 60200 "Invalid parameter: Channel" on accounts without Fraud Guard. Do not use in production without confirming account eligibility. [Evidence: 60200 on test account]

### Verification Lifecycle

4. **Wrong code does NOT throw an error**: A wrong code returns `status: 'pending'`, `valid: false` with no exception. Client code must check the `status` field, not rely on try/catch. Only the 6th wrong attempt throws error 60202. [Evidence: 5 wrong checks returned pending, 6th threw 60202]

5. **VE SID deleted after approval but not after cancel**: Approved verifications return 404 on fetch. Canceled verifications remain fetchable. Max-attempts verifications remain fetchable. This asymmetry means you cannot reliably fetch final status after a successful verification. [Evidence: VEe9a0bd66 returned 404 after approval; VEbc83fbec fetchable after cancel]

6. **Same token reused within validity window**: Resending to the same number returns the same VE SID and code. The sendCodeAttempts array grows but the code does not change. This is by design — prevents code-rotation attacks. [Evidence: VE5d276ab1 returned on both initial send and resend]

7. **Channel switch reuses VE SID**: Switching from SMS to voice to WhatsApp all use the same VE SID and token. Each channel gets a new VL-prefixed sendCodeAttempt entry. [Evidence: VE5d276ab1 across sms→call→whatsapp with 4 VL entries]

### Error Codes

8. **Error 60202 is max CHECK attempts, not max SEND**: 60202 = too many wrong codes (5 attempts). 60203 = too many sends to same number. [Evidence: 6th wrong code → 60202 "Max check attempts reached"; resend after rate limit → 60203 "Max send attempts reached"]

9. **Checking a non-existent verification returns 60200, not 404**: If you check a phone number that has no pending verification, you get 60200 "Invalid parameter `To`" rather than a 404. The error message is misleading. [Evidence: check to unused number returned 60200]

10. **60200 is the catch-all error code**: Used for invalid FriendlyName, invalid To, invalid Channel, invalid Locale, invalid CodeLength, and non-existent verifications. Read the error message, not the code alone. [Evidence: same 60200 for 6 different parameter failures]

### Configuration

11. **`dtmfInputRequired` defaults to true**: Voice verifications prompt the user to press a key before reading the code. If you want the code read immediately, set this to false on the service. [Evidence: service fetch showed dtmfInputRequired=true]

12. **`lookupEnabled` adds carrier data to verification response**: When enabled, the `lookup` field contains carrier type (mobile/landline/voip), name, and MCC/MNC. Useful for fraud detection but adds latency and cost per verification. [Evidence: lookup returned type=voip, name=Twilio for test number]

13. **Code length 4-10 enforced at service creation**: Values below 4 or above 10 return 60200. The default is 6. This is set on the Service, not per-verification. [Evidence: codeLength=4 and 10 created OK; 3 and 11 returned 60200]

14. **Custom codes require service-level opt-in**: The `customCode` parameter is silently ignored unless `customCodeEnabled: true` is set on the Verify Service. Use this for testing environments only. [Evidence: VEb40fc044 verified with customCode=987654 on enabled service]

### Rate Limits

15. **5 check attempts per verification**: After 5 wrong codes, status becomes `max_attempts_reached` and subsequent checks throw 60202. The user must request a new verification. [Evidence: 5 pending responses, 6th threw 60202]

16. **Send rate limit is per-number, per-time-window**: Sending too many verifications to the same number within 10 minutes triggers 60203. The exact threshold depends on account configuration (documented as 5 per 10 minutes). [Evidence: 60203 after repeated sends to same number]

## Error Code Reference

| Code | Meaning | Trigger |
|------|---------|---------|
| 60200 | Invalid parameter | FriendlyName, To, Channel, Locale, CodeLength, or non-existent verification |
| 60202 | Max check attempts reached | 5 wrong codes submitted for one verification |
| 60203 | Max send attempts reached | Too many sends to same number in time window |
| 60212 | Verification expired | Code TTL elapsed (default 10 minutes) |
| 60217 | Mailer not configured | `channel: 'email'` without Mailer on service |
| 60223 | Invalid phone number | Non-E.164 format or unroutable number |
| 60001 | Downstream auth failed | SNA without carrier integration |
| 20404 | Resource not found | Fetching deleted VE SID (approved/expired) |

<!-- verified: all error codes live-tested 2026-03-25 except 60212 (would require 10-min wait) -->

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Assertion audit | `references/assertion-audit.md` | Verifying claim provenance, reviewing evidence chain |

## Related Resources

- **Domain docs**: `CLAUDE.md` (function inventory, env vars), `REFERENCE.md` (code samples, test patterns)
- **Codebase functions**: `start-verification.protected.js`, `check-verification.protected.js`
- **MCP tools**: `mcp__twilio__start_verification`, `mcp__twilio__check_verification`, `mcp__twilio__get_verification_status`
- **Related skills**: `/skills/lookup/SKILL.md` (phone number intelligence — line type, carrier, fraud detection, identity match), `/skills/compliance-regulatory.md` (data retention, regulatory requirements), `/skills/voice/SKILL.md` (voice verification use case)
- **Twilio docs**: [Verify API](https://www.twilio.com/docs/verify/api), [Rate Limits](https://www.twilio.com/docs/verify/api/rate-limits-and-timeouts), [Best Practices](https://www.twilio.com/docs/verify/developer-best-practices)
