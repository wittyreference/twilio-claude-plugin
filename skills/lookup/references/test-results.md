---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Live test evidence for Lookup v2 skill claims. -->
<!-- ABOUTME: All tests run 2026-03-29 against account ACb4de2... using Node.js SDK. -->

# Lookup v2 Test Results

All tests run 2026-03-29 against account ACb4de2... using Twilio Node.js SDK (`client.lookups.v2.phoneNumbers`).

---

## Test Matrix

| # | Test | Input | Result | Key finding |
|---|------|-------|--------|-------------|
| 1 | Basic lookup (no fields) | +12069666002 | `valid: true`, `validationErrors: []`, `countryCode: "US"` | `validationErrors` is empty array, not null |
| 2 | Invalid number | +141599299600 | `valid: false`, `validationErrors: ["TOO_LONG"]`, `countryCode: null` | HTTP 200 (not 404), `nationalFormat` still populated |
| 3 | Line Type Intelligence | +12069666002 | `type: "nonFixedVoip"`, `carrierName: "Twilio - SMS/MMS-SVR"` | MCC/MNC populated for VoIP |
| 4 | Caller Name (CNAM) | +12069666002 | `callerName: null`, `callerType: "UNDETERMINED"` | "UNDETERMINED" is undocumented value |
| 5 | Multiple fields | +12069666002 | All three packages populated | Confirms multi-field in single request |
| 6 | SMS Pumping Risk | +12069666002 | `smsPumpingRiskScore: 34`, `carrierRiskCategory: "high"` | Score and carrier category are independent |
| 7 | SIM Swap | +12069666002 | `errorCode: 60606` (not enabled) | HTTP 200 with error in body |
| 8 | Line Status | +12069666002 | `errorCode: 60606` (not enabled) | Same pattern — error in body |
| 9 | Reassigned Number | +12069666002 | `errorCode: "60606"` (not enabled) | errorCode is STRING, not number |
| 10 | Call Forwarding | +12069666002 | `errorCode: 60607` | Different error code than 60606 |
| 11 | Quality Score | +12069666002 | `error_code: 60606`, snake_case keys | SDK uses snake_case (not camelCase) |
| 12 | Identity Match | +12069666002 | `errorCode: 60003` | VoIP number not eligible |
| 13 | Invalid field name | +12069666002 | HTTP 400 | Error message lists all valid field names |
| 14 | Non-E.164 with CountryCode | 2069666002, US | `phoneNumber: "+12069666002"`, `valid: true` | Correctly resolves national format |
| 15 | Validation field | +12069666002 | Same as no-fields | `validation` adds nothing extra |
| 16 | UK number line type | +442071234567 | `type: "nonFixedVoip"`, `carrierName: "Gamma Telecom..."` | International line type works |
| 17 | All available fields | +12069666002 | Full response with 4 packages, 7 null | Unrequested fields present as null; score changed to 41 |
| 18 | Garbage input | "notanumber" | `phoneNumber: "+1notanumber"`, `valid: false`, `["NOT_A_NUMBER"]` | +1 prepended silently |
| 19 | Empty string | "" | HTTP 404, error 20404 | Only way to get 404 |
| 20 | Reassigned without date | +12069666002 | `errorCode: "60617"` (string) | Missing LastVerifiedDate |
| 21 | SMS pumping UK | +442071234567 | `errorCode: 60006` | UK number returned error (not null) |
| 22 | TEST_PHONE_NUMBER | +12062021014 | Same as #3/#4 | Both Twilio numbers show nonFixedVoip |
| 23 | CNAM on UK number | +442071234567 | `callerType: null`, `errorCode: 60600` | Non-US: error 60600; callerType is null (not UNDETERMINED) |

---

## Key Discoveries

### 1. `callerType: "UNDETERMINED"` (Test 4)

Twilio docs list `BUSINESS`, `CONSUMER`, and `null` as valid `callerType` values. Live testing on Twilio VoIP numbers returns `"UNDETERMINED"`. This is distinct from `null` — non-US numbers return `callerType: null` (Test 23), while US VoIP numbers return `"UNDETERMINED"`.

### 2. Dynamic SMS Pumping Scores (Tests 6 vs 17)

Same number (+12069666002) returned `smsPumpingRiskScore: 34` in Test 6 and `smsPumpingRiskScore: 41` in Test 17, seconds apart. Scores are not deterministic — they reflect real-time model output.

### 3. `errorCode` Type Inconsistency (Tests 7, 9, 10, 20)

| Package | errorCode value | Type |
|---------|----------------|------|
| sim_swap | 60606 | number |
| reassigned_number | "60606" | string |
| call_forwarding | 60607 | number |
| reassigned_number (60617) | "60617" | string |

`reassigned_number` consistently returns errorCode as a string. All other packages return it as a number.

### 4. Phone Number Quality Score Snake Case (Test 11)

SDK response uses `carrier_risk_category`, `quality_score`, etc. (snake_case) instead of `carrierRiskCategory`, `qualityScore` (camelCase) used by every other package.

### 5. Error 60006 for SMS Pumping on UK Number (Test 21)

UK number +442071234567 returned `errorCode: 60006` for `sms_pumping_risk`. This error code is not documented in the Lookup error code list. It may indicate the number's carrier doesn't participate in the SMS pumping data network, distinct from 60600 (out of coverage) and 60606 (not enabled).

### 6. Error 60607 for Call Forwarding (Test 10)

US number returned 60607 instead of the standard 60606 (not enabled). This error code is not in the published Lookup error code documentation. May indicate "feature geographically restricted" (UK only) as opposed to "account not provisioned."
