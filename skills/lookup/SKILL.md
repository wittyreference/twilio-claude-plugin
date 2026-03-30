---
name: "lookup"
description: "Twilio development skill: lookup"
---

---
name: lookup
description: Twilio Lookup v2 phone number intelligence guide. Use when validating phone numbers, detecting line type or carrier, checking fraud risk (SIM swap, SMS pumping), verifying caller identity, or choosing between Lookup data packages.
allowed-tools: mcp__twilio__lookup_phone_number, mcp__twilio__check_fraud_risk, Read, Grep, Glob
---

# Lookup v2 Development Skill

Decision-making guide for Twilio Lookup v2 — phone number intelligence, validation, fraud detection, and identity verification. Load this skill when choosing which data packages to use, interpreting Lookup responses, or integrating number intelligence into voice/messaging workflows.

**Evidence date**: 2026-03-29 | **Account**: ACb4de2...

---

## Scope

### What Lookup v2 Can Do

- **Validate phone numbers** (free) — format check, E.164 normalization, country detection
- **Identify line type** — 12-type classification including fixedVoip vs nonFixedVoip distinction
- **Retrieve carrier data** — carrier name, MCC, MNC for mobile/VoIP numbers
- **CNAM lookup** — caller name and type (US numbers only)
- **Detect SIM swap** — carrier-reported SIM change history (Beta, 10 countries)
- **Assess SMS pumping risk** — per-number risk score and carrier risk category
- **Check number reassignment** — whether a US number changed owners since a given date
- **Verify identity** — match name/address/DOB against carrier records (10 countries)
- **Check line status** — HLR-based reachability (active/reachable/unreachable/inactive)
- **Detect call forwarding** — unconditional forwarding status (UK only, Private Beta)
- **Combine multiple packages** in a single API call — comma-separated `fields` parameter
- **Override line type classification** — persist per-account line type override for a number

### What Lookup v2 Cannot Do

1. **Cannot look up information by name/address** — input is always a phone number; you cannot reverse-search "who owns this number" without a number
2. **Cannot get CNAM for non-US numbers** — returns error 60600 (out of coverage); no international CNAM
3. **Cannot detect conditional call forwarding** — only unconditional forwarding is detected, and only for UK carriers
4. **Cannot guarantee SIM swap data without carrier registration** — returns error 60606 until carrier approval is completed
5. **Cannot use Reassigned Number outside the US** — US-only dataset with monthly update cadence
6. **Cannot get real-time SMS pumping scores** — scores are statistical models, not live traffic analysis; they change between calls but reflect aggregate patterns
7. **Cannot write data** — Lookup v2 is read-only (GET only). The one exception is Line Type Override (POST/DELETE)
8. **Cannot batch multiple phone numbers in one request** — one number per API call; use concurrent requests for bulk lookups
9. **Cannot avoid billing on CNAM requests that return no data** — billed per request regardless of whether caller name is found
10. **Cannot use Phone Number Quality Score or Pre-fill without account provisioning** — returns 60606; contact Twilio sales

---

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Validate a number is real | No `fields` (free) | Returns `valid`, `validationErrors`, country, format |
| Check if mobile/landline/VoIP | `line_type_intelligence` ($0.008) | 12-type classification with carrier data |
| Get caller name for US number | `caller_name` ($0.01) | CNAM database; US-only |
| Block SMS pumping before OTP | `sms_pumping_risk` (free NAMER / $0.025 ROW) | Risk score + carrier risk category |
| Detect SIM swap for fraud check | `sim_swap` (contact sales) | Carrier-reported swap history; requires registration |
| KYC identity verification | `identity_match` ($0.10–$1.20) | Name/address/DOB match against carrier; 10 countries |
| Check if number was reassigned | `reassigned_number` ($0.02–$0.0015) | US-only; requires `LastVerifiedDate` |
| Check if number is reachable | `line_status` ($0.007–$0.00385) | HLR query; Private Beta |
| Detect call forwarding | `call_forwarding` (contact sales) | UK major carriers only; Private Beta |

---

## Decision Frameworks

### Choosing Data Packages for Fraud Prevention

| Scenario | Recommended packages | Rationale |
|----------|---------------------|-----------|
| OTP/2FA signup | `sms_pumping_risk` + `line_type_intelligence` | Block pumping bots and filter non-SMS-capable types |
| High-value transaction auth | `sim_swap` + `line_type_intelligence` | SIM swap detects account takeover; line type filters VoIP |
| Re-engagement campaign | `reassigned_number` + `line_type_intelligence` | Avoid contacting wrong person after number recycling |
| KYC onboarding | `identity_match` + `line_type_intelligence` | Verify identity against carrier records |
| Inbound caller screening | `caller_name` + `line_type_intelligence` | CNAM + carrier data for US callers |

### SMS Pumping Risk Interpretation

The `smsPumpingRiskScore` and `carrierRiskCategory` are **independent signals**:

| Score range | Risk level | Action |
|-------------|-----------|--------|
| 0–60 | Low | Send normally |
| 60–75 | Mild | Add CAPTCHA or rate limiting |
| 75–90 | Moderate | Require additional verification |
| 90–100 | High | Block the request |

`carrierRiskCategory` reflects the carrier's overall fraud profile, not this specific number. A number can have a low `smsPumpingRiskScore` but a `high` carrier risk category (e.g., VoIP carriers). Use both signals together.

### Line Type for SMS Routing

| Line type | Can receive SMS? | Action |
|-----------|-----------------|--------|
| `mobile` | Yes | Send directly |
| `nonFixedVoip` | Usually | Send, but higher fraud risk |
| `fixedVoip` | Sometimes | Test before relying on it |
| `landline` | No | Use voice call or skip |
| `tollFree` | No | Do not message |
| `personal`, `premium`, `sharedCost`, `uan`, `voicemail`, `pager` | No | Do not message |
| `unknown` | Unknown | Test or skip |

---

## Integration Patterns

### Basic Validation (Free)

```javascript
const client = require('twilio')(accountSid, authToken);

const result = await client.lookups.v2
  .phoneNumbers('+14159929960')
  .fetch();

console.log(result.valid);            // true
console.log(result.validationErrors); // []
console.log(result.countryCode);      // "US"
console.log(result.nationalFormat);   // "(415) 992-9960"
```

### Line Type Intelligence

```javascript
const result = await client.lookups.v2
  .phoneNumbers('+14159929960')
  .fetch({ fields: 'line_type_intelligence' });

console.log(result.lineTypeIntelligence.type);        // "nonFixedVoip"
console.log(result.lineTypeIntelligence.carrierName);  // "Twilio - SMS/MMS-SVR"
```

### Multiple Packages in One Request

```javascript
const result = await client.lookups.v2
  .phoneNumbers('+14159929960')
  .fetch({ fields: 'line_type_intelligence,caller_name,sms_pumping_risk' });

// All three populated in a single response
console.log(result.lineTypeIntelligence.type);
console.log(result.callerName.callerType);
console.log(result.smsPumpingRisk.smsPumpingRiskScore);
```

### SMS Pumping Guard Before OTP

```javascript
const result = await client.lookups.v2
  .phoneNumbers(userPhone)
  .fetch({ fields: 'sms_pumping_risk,line_type_intelligence' });

const score = result.smsPumpingRisk.smsPumpingRiskScore;
const lineType = result.lineTypeIntelligence.type;

if (score >= 75 || lineType === 'landline') {
  // Block or require additional verification
  throw new Error('Phone number failed fraud check');
}

// Safe to send OTP
await client.verify.v2.services(verifySid)
  .verifications.create({ to: userPhone, channel: 'sms' });
```

### Identity Match (KYC)

```javascript
const result = await client.lookups.v2
  .phoneNumbers('+14159929960')
  .fetch({
    fields: 'identity_match',
    firstName: 'Jane',
    lastName: 'Smith',
    addressLine1: '123 Main St',
    city: 'San Francisco',
    state: 'CA',
    postalCode: '94105',
    addressCountryCode: 'US',
  });

const match = result.identityMatch;
console.log(match.summaryScore);     // 0-100
console.log(match.firstNameMatch);   // "exact_match", "partial_match", etc.
console.log(match.lastNameMatch);
```

### National Format Input

```javascript
// Non-E.164 input requires countryCode parameter
const result = await client.lookups.v2
  .phoneNumbers('2069666002')
  .fetch({ countryCode: 'US' });

console.log(result.phoneNumber); // "+12069666002" (normalized to E.164)
```

### Using MCP Tools

```
# Basic lookup with line type
ToolSearch("select:mcp__twilio__lookup_phone_number")
mcp__twilio__lookup_phone_number({ phoneNumber: "+14159929960", fields: ["line_type_intelligence"] })

# Fraud risk check
ToolSearch("select:mcp__twilio__check_fraud_risk")
mcp__twilio__check_fraud_risk({ phoneNumber: "+14159929960", checks: ["sim_swap", "sms_pumping_risk"] })
```

**MCP tool limitations**: The `lookup_phone_number` tool exposes `validation`, `caller_name`, `line_type_intelligence`, and `line_status` fields. The `check_fraud_risk` tool exposes `sim_swap` and `sms_pumping_risk`. For `identity_match`, `reassigned_number`, `call_forwarding`, or `phone_number_quality_score`, use the Node.js SDK directly.

---

## Gotchas

### Request & Response

1. **Invalid numbers return HTTP 200, not 404**: Unlike Lookup v1 which returned 404, v2 returns HTTP 200 with `valid: false` and a `validationErrors` array. Check the `valid` field, not the HTTP status code.

2. **Garbage input gets country code prepended**: Passing `"notanumber"` returns `phoneNumber: "+1notanumber"` with `valid: false`, `validationErrors: ["NOT_A_NUMBER"]`. The API silently prepends `+1` (US default) to non-E.164 input. [Evidence: live test 2026-03-29]

3. **Empty phone number input causes HTTP 404**: The only way to get a 404 from Lookup v2 is passing an empty string, which resolves to `/v2/PhoneNumbers` (no number segment). All other invalid inputs return 200. [Evidence: error 20404, live test 2026-03-29]

4. **`callerType` has undocumented value "UNDETERMINED"**: Docs list only `BUSINESS`, `CONSUMER`, and `null`. In practice, Twilio VoIP numbers return `callerType: "UNDETERMINED"`. Handle this value in your code. [Evidence: live test on +12069666002, 2026-03-29]

5. **`validationErrors` is an empty array for valid numbers, not null**: Despite docs showing `null`, live testing returns `[]`. Check `result.valid` rather than testing `validationErrors` for truthiness. [Evidence: live test 2026-03-29]

### Billing & Coverage

6. **CNAM billed even when no data returned**: Every `caller_name` request costs $0.01 regardless of whether a name is found. Non-US numbers return error 60600 without charge, but US numbers with no CNAM data are still billed.

7. **SMS pumping scores are dynamic**: Consecutive lookups on the same number return different `smsPumpingRiskScore` values (observed: 34, then 41 on the same number seconds apart). Do not cache or compare scores across calls. [Evidence: live tests 6 and 17, 2026-03-29]

8. **Carrier risk and pumping score are independent**: A number can have `smsPumpingRiskScore: 34` (low) but `carrierRiskCategory: "high"`. The carrier category reflects the carrier's overall profile (VoIP carriers are flagged high), while the score is number-specific. [Evidence: live test on +12069666002, 2026-03-29]

### Data Package Availability

9. **Unprovisioned packages return 200 with error_code in the response body**: Requesting `sim_swap`, `line_status`, `reassigned_number`, or `phone_number_quality_score` without account provisioning returns HTTP 200 with `errorCode: 60606` inside the package object. No HTTP error is thrown — you must check `errorCode` in the response. [Evidence: live tests 7–11, 2026-03-29]

10. **`errorCode` type is inconsistent across packages**: `reassigned_number` returns `errorCode` as a string (`"60606"`), while `sim_swap` and others return it as a number (`60606`). Always coerce to string or number before comparison. [Evidence: live tests 9 vs 7, 2026-03-29]

11. **Phone Number Quality Score uses snake_case in SDK response**: Every other package returns camelCase properties (`carrierName`, `callerType`). Quality Score returns snake_case (`carrier_risk_category`, `quality_score`). This is an SDK inconsistency. [Evidence: live test 11, 2026-03-29]

12. **Unrequested packages return `null`, not absent**: When you request specific fields, all other data package fields are still present in the response as `null`. Don't check for key existence — check for non-null values. [Evidence: live test 17, 2026-03-29]

### Package-Specific

13. **`reassigned_number` requires `LastVerifiedDate`**: Omitting this parameter returns error 60617 in the response body (not an HTTP error). Format is `YYYYMMDD`. [Evidence: live test 20, 2026-03-29]

14. **`identity_match` on VoIP numbers returns error 60003**: VoIP/non-mobile numbers may not have carrier identity records. The error appears in the response body, not as an HTTP error. [Evidence: live test 12, 2026-03-29]

15. **`call_forwarding` returns error 60607 (not 60606) when unavailable**: This is a different error code than the standard "not enabled" 60606. Likely indicates the feature's Private Beta status or UK-only restriction. [Evidence: live test 10, 2026-03-29]

16. **Line type carrier data is null for non-carrier types**: `carrierName`, `mobileCountryCode`, and `mobileNetworkCode` return `null` for types: `personal`, `tollFree`, `premium`, `sharedCost`, `uan`, `voicemail`, `pager`, `unknown`. Only `mobile`, `fixedVoip`, `nonFixedVoip`, and `landline` have carrier data.

17. **`validation` as a field name is accepted but adds nothing**: Passing `fields: "validation"` returns the same response as no fields. The validation data (`valid`, `validationErrors`, `countryCode`, `nationalFormat`) is always included for free.

---

## Error Codes

| Code | Meaning | Common cause |
|------|---------|-------------|
| 60600 | Unprovisioned or out of coverage | CNAM on non-US number; number not assigned to carrier |
| 60601 | Canada authorization required | CLNPC/NPAC approval needed for Canadian line type |
| 60003 | Authentication/eligibility error | Identity match on VoIP number |
| 60606 | Package not enabled | Account not provisioned for the requested package |
| 60607 | Feature unavailable | Call forwarding outside UK |
| 60608 | Downstream provider error | Carrier/data provider timeout; retry |
| 60610 | Outside coverage area | Number in unsupported region for the package |
| 60611 | Quota reached | Package request quota exceeded |
| 60616 | Rate limit exceeded | Reassigned number: 50 RPS limit |
| 60617 | Missing required parameters | Reassigned number without `LastVerifiedDate`; Identity match without names |
| 60618 | Malformed parameter | `PartnerSubId` exceeds 64 chars |

---

## Related Resources

### Skills
- [`/verify`](/skills/verify/SKILL.md) — Verify integration with `lookupEnabled` flag for carrier detection during OTP
- [`/phone-numbers`](/skills/phone-numbers/SKILL.md) — Phone number management, uses `mcp__twilio__lookup_phone_number` for carrier checks
- [`/branded-calling`](/skills/branded-calling/SKILL.md) — CNAM registration and caller identity (complementary to Lookup CNAM)
- [`/voice-trust`](/skills/voice-trust/SKILL.md) — Caller identity verification, SHAKEN/STIR attestation

### MCP Tools
- `mcp__twilio__lookup_phone_number` — Line type, caller name, validation, line status
- `mcp__twilio__check_fraud_risk` — SIM swap, SMS pumping risk

### API Reference
- Endpoint: `GET https://lookups.twilio.com/v2/PhoneNumbers/{PhoneNumber}`
- Auth: HTTP Basic (Account SID + Auth Token, or API Key + Secret)
- Regions: US1 (default), IE1 (Ireland)

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Data package response shapes | [references/data-packages.md](references/data-packages.md) | When interpreting response fields, checking enums, or reviewing pricing |
| Live test evidence | [references/test-results.md](references/test-results.md) | When verifying a specific behavioral claim |
| Assertion audit | [references/assertion-audit.md](references/assertion-audit.md) | When reviewing the provenance chain for skill claims |
