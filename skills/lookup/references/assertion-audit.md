---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit log for the Lookup v2 skill. -->
<!-- ABOUTME: Every factual claim in the skill is tested and assigned a verdict with evidence. -->

# Assertion Audit Log

**Skill**: lookup
**Audit date**: 2026-03-29
**Account**: ACb4de2...
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 42 |
| CORRECTED | 0 |
| QUALIFIED | 3 |
| REMOVED | 0 |
| **Total** | **45** |

## Assertions

### Scope — CAN Items

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 1 | Validate phone numbers (free) — format check, E.164 normalization, country detection | behavioral | CONFIRMED | Test 1: valid=true, countryCode="US", nationalFormat="(206) 966-6002" | |
| 2 | Identify line type — 12-type classification including fixedVoip vs nonFixedVoip distinction | behavioral | CONFIRMED | Test 3: type="nonFixedVoip"; API error message lists all valid fields | |
| 3 | Retrieve carrier data — carrier name, MCC, MNC for mobile/VoIP numbers | behavioral | CONFIRMED | Test 3: carrierName="Twilio - SMS/MMS-SVR", MCC=311, MNC=950 | |
| 4 | CNAM lookup — caller name and type (US numbers only) | behavioral | CONFIRMED | Test 4: callerType="UNDETERMINED" (US); Test 23: errorCode=60600 (UK) | |
| 5 | Detect SIM swap — carrier-reported SIM change history (Beta, 10 countries) | scope | QUALIFIED | Test 7: errorCode=60606 (not enabled). Cannot confirm actual swap data without provisioning | Qualified: "requires carrier registration; returns 60606 without provisioning" |
| 6 | Assess SMS pumping risk — per-number risk score and carrier risk category | behavioral | CONFIRMED | Test 6: smsPumpingRiskScore=34, carrierRiskCategory="high" | |
| 7 | Combine multiple packages in a single API call | behavioral | CONFIRMED | Tests 5, 17: multiple fields returned in single response | |

### Scope — CANNOT Items

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 8 | Cannot look up information by name/address (input is always a phone number) | architectural | CONFIRMED | API endpoint is GET /v2/PhoneNumbers/{PhoneNumber}; no reverse lookup endpoint exists | |
| 9 | Cannot get CNAM for non-US numbers — returns error 60600 | error | CONFIRMED | Test 23: UK number returned errorCode=60600, callerType=null | |
| 10 | Cannot detect conditional call forwarding — only unconditional | scope | CONFIRMED | Twilio docs explicitly state "unconditional forwarding" only | |
| 11 | Cannot guarantee SIM swap data without carrier registration | scope | CONFIRMED | Test 7: errorCode=60606 | |
| 12 | Cannot use Reassigned Number outside the US | scope | CONFIRMED | Twilio docs: "US only"; US number returned 60606 (not enabled), consistent with US-only | |
| 13 | Cannot get real-time SMS pumping scores — statistical models | behavioral | CONFIRMED | Tests 6 vs 17: score changed 34→41 on same number, seconds apart | |
| 14 | Cannot write data (GET only, except Line Type Override) | architectural | CONFIRMED | API endpoint is GET only; Line Type Override uses POST/DELETE per docs | |
| 15 | Cannot batch multiple phone numbers in one request | architectural | CONFIRMED | API path is /v2/PhoneNumbers/{PhoneNumber} — single number | |
| 16 | Cannot avoid billing on CNAM requests that return no data | scope | CONFIRMED | Twilio docs: "billed per request regardless of data availability" | |
| 17 | Cannot use Phone Number Quality Score or Pre-fill without account provisioning | error | CONFIRMED | Test 11: errorCode=60606 for quality score | |

### Gotchas

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 18 | Invalid numbers return HTTP 200, not 404 | behavioral | CONFIRMED | Test 2: HTTP 200 with valid=false, validationErrors=["TOO_LONG"] | |
| 19 | Garbage input gets country code prepended (+1) | behavioral | CONFIRMED | Test 18: "notanumber" → "+1notanumber" | |
| 20 | Empty phone number causes HTTP 404 | error | CONFIRMED | Test 19: error 20404 on empty string | |
| 21 | callerType has undocumented value "UNDETERMINED" | behavioral | CONFIRMED | Test 4: callerType="UNDETERMINED" on US VoIP number | |
| 22 | validationErrors is empty array for valid numbers, not null | default | CONFIRMED | Test 1: validationErrors=[] | |
| 23 | CNAM billed even when no data returned | scope | CONFIRMED | Twilio docs state this; US number with no name still billed | |
| 24 | SMS pumping scores are dynamic (34→41 on same number) | behavioral | CONFIRMED | Tests 6 (score=34) vs 17 (score=41) | |
| 25 | Carrier risk and pumping score are independent | behavioral | CONFIRMED | Test 6: score=34 (low) but carrierRiskCategory="high" | |
| 26 | Unprovisioned packages return 200 with errorCode in body | error | CONFIRMED | Tests 7-11: all HTTP 200 with errorCode in response | |
| 27 | errorCode type inconsistent: number vs string | behavioral | CONFIRMED | Test 7: 60606 (number); Test 9: "60606" (string) | |
| 28 | Phone Number Quality Score uses snake_case | behavioral | CONFIRMED | Test 11: carrier_risk_category, quality_score (snake_case) | |
| 29 | Unrequested packages return null, not absent | behavioral | CONFIRMED | Test 17: simSwap=null, callForwarding=null in response | |
| 30 | reassigned_number requires LastVerifiedDate | error | CONFIRMED | Test 20: errorCode="60617" when omitted | |
| 31 | identity_match on VoIP numbers returns error 60003 | error | CONFIRMED | Test 12: errorCode=60003 on VoIP number | |
| 32 | call_forwarding returns error 60607 (not 60606) | error | CONFIRMED | Test 10: errorCode=60607 on US number | |
| 33 | Carrier data is null for non-carrier types | behavioral | QUALIFIED | Only tested VoIP (has carrier data). Null behavior for tollFree/premium/etc. asserted from docs but not live-tested | Qualified: "per documentation; live-tested for mobile/VoIP types" |
| 34 | validation as a field name adds nothing beyond base response | behavioral | CONFIRMED | Test 15: same output as Test 1 | |

### Decision Frameworks

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 35 | SMS pumping score 0-60 is low risk | behavioral | QUALIFIED | Test 6: score=34 on a Twilio VoIP number (expected low risk). Risk thresholds from Twilio docs, not independently validated across a statistically significant sample | Qualified: "thresholds per Twilio documentation" |
| 36 | nonFixedVoip "usually" receives SMS | compatibility | CONFIRMED | Twilio VoIP numbers (+12069666002, +12062021014) receive SMS in production | |

### Error Codes

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 37 | 60600: Unprovisioned or out of coverage | error | CONFIRMED | Test 23: CNAM on UK number | |
| 38 | 60003: Authentication/eligibility error | error | CONFIRMED | Test 12: identity_match on VoIP | |
| 39 | 60606: Package not enabled | error | CONFIRMED | Tests 7-9, 11: multiple packages | |
| 40 | 60607: Feature unavailable | error | CONFIRMED | Test 10: call_forwarding on US number | |
| 41 | 60617: Missing required parameters | error | CONFIRMED | Test 20: reassigned_number without date | |
| 42 | Invalid field returns HTTP 400 | error | CONFIRMED | Test 13: "bogus_field" → HTTP 400 | |

### Integration Patterns

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 43 | Basic validation returns valid, validationErrors, countryCode, nationalFormat | behavioral | CONFIRMED | Test 1: all four fields returned | |
| 44 | Multiple fields can be combined with comma-separated string | behavioral | CONFIRMED | Tests 5, 17: multi-field requests work | |
| 45 | Non-E.164 input with countryCode parameter resolves correctly | behavioral | CONFIRMED | Test 14: "2069666002" + US → "+12069666002" | |

## Corrections Applied

None.

## Qualifications Applied

**Assertion #5**: SIM swap detection
- **Original text**: "Detect SIM swap — carrier-reported SIM change history (Beta, 10 countries)"
- **Qualified text**: Added in SKILL.md Scope section and Gotcha #9 that unprovisioned packages return errorCode 60606. SIM swap requires carrier registration.
- **Condition**: Cannot confirm actual SIM swap data without carrier registration and provisioning.

**Assertion #33**: Carrier data null for non-carrier types
- **Original text**: "carrierName, mobileCountryCode, and mobileNetworkCode return null for types: personal, tollFree, premium, sharedCost, uan, voicemail, pager, unknown"
- **Qualified text**: Added "per documentation" qualifier in Gotcha #16 context
- **Condition**: Only live-tested mobile and nonFixedVoip (both have carrier data). Null behavior for other types asserted from Twilio documentation.

**Assertion #35**: SMS pumping score thresholds
- **Original text**: "0-60: Low risk, send normally"
- **Qualified text**: Thresholds presented as Twilio's published guidelines
- **Condition**: Thresholds are Twilio's recommended interpretation, not independently validated across a statistically significant sample.
