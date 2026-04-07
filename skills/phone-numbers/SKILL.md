---
name: "phone-numbers"
description: "Twilio development skill: phone-numbers"
---

---
name: phone-numbers
description: Twilio phone number management guide. Use when searching, purchasing, configuring webhooks, releasing numbers, or debugging number-related issues.
---

<!-- verified: twilio.com/docs/phone-numbers/api/incomingphonenumber-resource, twilio.com/docs/phone-numbers/api/availablephonenumber-resource, twilio.com/docs/phone-numbers/api/availablephonenumberlocal-resource + live testing 2026-03-25 -->

# Twilio Phone Numbers

Search, purchase, configure, and release phone numbers. Covers number types, search filters, webhook configuration, capabilities, address requirements, and the purchase/release lifecycle.

Evidence date: 2026-03-25. Account prefix: AC...

## Scope

### CAN

- Search available numbers by country, area code, pattern, and capabilities
- Purchase local and toll-free numbers via API
- Configure voice/SMS webhook URLs, fallback URLs, and status callbacks
- Set voiceApplicationSid or smsApplicationSid to route to TwiML Apps
- Filter owned numbers by phone number or friendlyName
- Geographic proximity search (nearNumber, nearLatLong, distance) — US/Canada only
- Filter by address requirements (exclude numbers needing address verification)
- Search with vanity letter patterns (e.g., "TEST" maps to digits)
- Release (delete) numbers, returning them to the pool
- Update friendlyName on owned numbers (max 64 chars)
- Lookup carrier/line-type via `mcp__twilio__lookup_phone_number`
- Clear webhook URLs by setting to empty string

### CANNOT

<!-- verified: all CANNOT items live-tested 2026-03-25 unless noted -->

- **No mobile number type in the US** — `availablePhoneNumbers('US').mobile.list()` returns 404. US numbers are classified as local or toll-free only. Mobile is available in other countries (e.g., GB). <!-- verified: 20404 on US/Mobile.json -->
- **Cannot use both voiceApplicationSid and voiceUrl** — Setting voiceApplicationSid causes voiceUrl to be ignored. Setting one auto-clears the other. Same applies to smsApplicationSid vs smsUrl. <!-- verified: twilio.com/docs/phone-numbers/api/incomingphonenumber-resource -->
- **Cannot use voiceApplicationSid and trunkSid simultaneously** — Setting one auto-deletes the other. <!-- verified: twilio.com/docs/phone-numbers/api/incomingphonenumber-resource -->
- **`contains` pattern requires minimum 2 characters** — Single-character patterns (e.g., "5") return 400 "Invalid Pattern Provided". Wildcards `*` mid-pattern also fail — the pattern is matched as a substring, not a glob. <!-- verified: "5" → 400; "206*55*" → 400; "55" → OK -->
- **Geographic search is US/Canada only** — `nearNumber`, `nearLatLong`, `inPostalCode`, `inRegion`, `inRateCenter`, `inLata` parameters are ignored or error for non-US/CA countries. <!-- verified: twilio.com/docs/phone-numbers/api/availablephonenumberlocal-resource -->
- **`areaCode` filter is US/Canada only** — Does not apply to international numbers. <!-- verified: twilio.com/docs docs -->
- **No undo for release** — Once released, the number goes back to the pool. Another customer may purchase it immediately. There is no grace period or reclaim mechanism.
- **Address required for many international numbers** — `addressRequirements` can be `none`, `any`, `local`, or `foreign`. UK local numbers require a local address (`addressRequirements: "local"`). Purchase will fail without the required address/bundle. <!-- verified: GB search returned addressRequirements="local" -->
- **Purchasing not exposed as a serverless function** — Intentionally excluded from `` due to cost implications. Use MCP tools, CLI, or Console instead. <!-- verified: CLAUDE.md -->

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Find available numbers | `mcp__twilio__search_available_numbers` | Filters by country, area code, capabilities |
| List owned numbers | `mcp__twilio__list_phone_numbers` | Shows SIDs, capabilities, webhook URLs |
| Set webhook URLs | `mcp__twilio__configure_webhook` | Updates voice/SMS URLs by PN SID |
| Buy a number | `mcp__twilio__purchase_phone_number` | Requires E.164 number from search |
| Release a number | `mcp__twilio__release_phone_number` | Irreversible — number returns to pool |
| Check carrier/type | `mcp__twilio__lookup_phone_number` | Carrier name, line type (mobile/landline/voip) |
| Buy via CLI | `twilio api:core:incoming-phone-numbers:create --phone-number "+1..."` | Alternative to MCP for purchase |

## Decision Frameworks

### Number Type Selection

| Type | Available In | Use Case | Cost Tier |
|------|-------------|----------|-----------|
| Local | Most countries | Geographic presence, local caller ID | Standard |
| Toll-Free | US, CA, GB, AU + others | Customer support, inbound-heavy | Higher monthly |
| Mobile | Non-US countries (GB, DE, etc.) | SMS-heavy, international | Varies by country |

### Search Strategy

| Goal | Approach | Parameters |
|------|----------|-----------|
| Specific area code | Search local with areaCode | `areaCode: 206` (US/CA only) |
| Vanity number | Search with letter pattern | `contains: 'TEST'` (maps to 8378) |
| Near existing number | Geographic proximity | `nearNumber: '+15551234567', distance: 10` |
| SMS-capable only | Capability filter | `smsEnabled: true` |
| No address hassle | Exclude address-required | `excludeAllAddressRequired: true` |
| International | Specify country code | `countryCode: 'GB'`, check addressRequirements |

### Webhook Configuration

| Setting | When to Use |
|---------|-------------|
| `voiceUrl` | Direct TwiML webhook for incoming calls |
| `voiceApplicationSid` | Route to a TwiML App (overrides voiceUrl) |
| `smsUrl` | Direct webhook for incoming SMS |
| `smsApplicationSid` | Route SMS to a TwiML App (overrides smsUrl) |
| `statusCallback` | Receive call status events (initiated, ringing, answered, completed) |
| `voiceFallbackUrl` | Backup URL if voiceUrl fails |
| `trunkSid` | Route to SIP trunk (mutually exclusive with voiceApplicationSid) |

## Integration Patterns

### Search and Purchase Flow

```javascript
// Step 1: Search for available numbers
const available = await client.availablePhoneNumbers('US')
  .local.list({ areaCode: 206, smsEnabled: true, voiceEnabled: true, limit: 5 });

// Step 2: Purchase the first match
const purchased = await client.incomingPhoneNumbers.create({
  phoneNumber: available[0].phoneNumber,
  friendlyName: 'My App Line',
  voiceUrl: 'https://myapp.com/voice',
  smsUrl: 'https://myapp.com/sms'
});
// purchased.sid = 'PN...'
// purchased.status = 'in-use'
```

### Configure Webhooks on Existing Number

```javascript
const updated = await client.incomingPhoneNumbers(phoneNumberSid).update({
  voiceUrl: 'https://myapp.com/voice',
  smsUrl: 'https://myapp.com/sms',
  statusCallback: 'https://myapp.com/status'
});
```

### Clear Webhook URLs

```javascript
// Set to empty string to clear
await client.incomingPhoneNumbers(phoneNumberSid).update({
  voiceUrl: '',
  smsUrl: ''
});
```

### Filter Owned Numbers

```javascript
// By phone number (exact match, E.164)
const byNumber = await client.incomingPhoneNumbers.list({
  phoneNumber: '+15551234567'
});

// By friendly name
const byName = await client.incomingPhoneNumbers.list({
  friendlyName: 'My App Line'
});
```

## Gotchas

### Search

1. **Capabilities keys have inconsistent casing**: Available numbers return `MMS` and `SMS` (uppercase) while owned numbers return `mms` and `sms` (lowercase). `voice` and `fax` are lowercase in both. Normalize case before comparing. [Evidence: available caps keys MMS/SMS/fax/voice vs owned fax/mms/sms/voice]

2. **`contains` pattern does not support wildcards**: Despite docs mentioning `*` metacharacter, mid-pattern wildcards like `206*55*` return 400 "Invalid Pattern Provided". Only simple substrings work (e.g., `"55"`, `"TEST"`). Minimum 2 characters. [Evidence: "206*55*" → 400; "55" → OK; "5" → 400]

3. **US has no mobile number type**: `availablePhoneNumbers('US').mobile.list()` returns 404. US numbers are local or toll-free only. Use `smsEnabled: true` to find SMS-capable local numbers instead. [Evidence: 20404 on US/Mobile.json]

4. **International numbers may require address verification**: UK local numbers require `addressRequirements: "local"`. Purchase fails without the required regulatory bundle and address. Check `addressRequirements` in search results before attempting purchase. [Evidence: GB search returned addressRequirements="local"]

### Configuration

5. **Invalid webhook URL returns specific error 21402**: Not a generic 400 — the error code 21402 specifically identifies "VoiceUrl is not valid". Useful for distinguishing URL validation errors from other configuration issues. [Evidence: "not-a-url" → error 21402]

6. **voiceApplicationSid and voiceUrl are mutually exclusive**: Setting voiceApplicationSid causes Twilio to ignore voiceUrl. Setting voiceUrl after voiceApplicationSid clears the application. Same for SMS counterparts. [Evidence: Twilio docs confirm; voiceApplicationSid validation tested — non-existent AP SID returns 400]

7. **voiceApplicationSid and trunkSid are mutually exclusive**: Setting one auto-deletes the other. A number can route to a TwiML App OR a SIP trunk, not both. [Evidence: Twilio docs]

### Lifecycle

8. **Release is irreversible and immediate**: `remove()` returns `true` and the number is gone. Fetch after release returns 404. No grace period, no undo. Another customer can purchase it within seconds. [Evidence: PNa869b36b released, immediate 404 on fetch]

9. **Purchased numbers start as `in-use` immediately**: No provisioning delay — `status: "in-use"` on the create response. Webhooks are active from the moment of purchase if configured. [Evidence: PNa869b36b status=in-use on create]

10. **SID format is PN-prefixed**: Phone number SIDs start with `PN` followed by 32 hex characters. Do not confuse with phone numbers in E.164 format. List and filter endpoints accept both SIDs and phone numbers as identifiers. [Evidence: PNfd5828a6... format confirmed]

### Pricing

11. **Toll-free numbers have higher monthly fees than local**: Toll-free numbers typically cost more per month. Search results do not include pricing — check Console or Pricing API for current rates before purchasing. [Evidence: Twilio pricing docs]

## Error Code Reference

| Code | Meaning | Trigger |
|------|---------|---------|
| 400 | Invalid Pattern Provided | `contains` pattern too short or uses unsupported wildcards |
| 20404 | Resource not found | Non-existent PN SID, or US/Mobile search |
| 21402 | VoiceUrl is not valid | Invalid URL format in webhook configuration |
| 21452 | Phone number not available | Number already purchased or no longer in pool |

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Assertion audit | `references/assertion-audit.md` | Verifying claim provenance, reviewing evidence chain |

## Related Resources

- **Domain docs**: `CLAUDE.md` (function inventory, search params, manage actions)
- **Codebase functions**: `search-numbers.protected.js`, `manage-number.protected.js`
- **MCP tools**: `mcp__twilio__search_available_numbers`, `mcp__twilio__list_phone_numbers`, `mcp__twilio__configure_webhook`, `mcp__twilio__purchase_phone_number`, `mcp__twilio__release_phone_number`, `mcp__twilio__lookup_phone_number`
- **Related skills**: `/skills/lookup/SKILL.md` (phone number intelligence — line type, carrier, fraud detection, identity match), `/skills/proxy/SKILL.md` (number pools for masking), `/skills/verify/SKILL.md` (phone verification), `/skills/compliance-regulatory.md` (regulatory bundles, address requirements), `/skills/branded-calling/SKILL.md` (branded caller ID, SHAKEN/STIR, Voice Integrity, CNAM)
- **Twilio docs**: [IncomingPhoneNumber API](https://www.twilio.com/docs/phone-numbers/api/incomingphonenumber-resource), [AvailablePhoneNumber API](https://www.twilio.com/docs/phone-numbers/api/availablephonenumber-resource), [Pricing](https://www.twilio.com/docs/phone-numbers/pricing)
