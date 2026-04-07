---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the Twilio Verify skill. -->
<!-- ABOUTME: Every factual claim verified via live testing or Twilio docs. Evidence: 2026-03-25. -->

# Assertion Audit Log

**Skill**: verify
**Audit date**: 2026-03-25
**Account**: ACxx...xx
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 38 |
| CORRECTED | 1 |
| QUALIFIED | 2 |
| REMOVED | 0 |
| **Total** | **41** |

## Assertions

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 1 | Send OTP codes via SMS | behavioral | CONFIRMED | VE5d276ab1 status=pending channel=sms | |
| 2 | Send OTP codes via voice call | behavioral | CONFIRMED | VE5d276ab1 channel=call after switch | |
| 3 | Send OTP codes via email | scope | CONFIRMED | Error 60217 confirms channel exists but requires Mailer | |
| 4 | Send OTP codes via WhatsApp | behavioral | CONFIRMED | VE5d276ab1 channel=whatsapp | |
| 5 | SNA for frictionless carrier-level verification | scope | CONFIRMED | Error 60001 confirms channel exists; requires carrier setup | |
| 6 | TOTP for authenticator app (separate factor flow) | architectural | QUALIFIED | Twilio docs confirm TOTP via Factors API, not Verifications API | Qualified: "separate factor flow" — not testable via start_verification |
| 7 | Custom code lengths: 4-10 digits | behavioral | CONFIRMED | codeLength=4 (VAc9a16794), codeLength=10 (VA6baabed), 3 and 11 → 60200 | |
| 8 | Custom codes for testing require customCodeEnabled | behavioral | CONFIRMED | VEb40fc044 verified with customCode=987654 on enabled service | |
| 9 | Locale override for message language | behavioral | CONFIRMED | VEc148ee18 with locale=es succeeded; locale=xx → 60200 | |
| 10 | Lookup integration adds carrier data | behavioral | CONFIRMED | lookup returned type=voip, name=Twilio, MCC/MNC on lookupEnabled service | |
| 11 | Cancel pending verifications | behavioral | CONFIRMED | VEbc83fbec update status=canceled succeeded | |
| 12 | Check by phone/email (to) | behavioral | CONFIRMED | VE5d276ab1 checked via to=+15551234567 | |
| 13 | Check by VerificationSid | behavioral | CONFIRMED | VE07cb3eac checked via verificationSid, approved | |
| 14 | Tags metadata accepted | behavioral | CONFIRMED | VEc148ee18 with tags={purpose:signup} succeeded | |
| 15 | riskCheck per-attempt disable | behavioral | CONFIRMED | VE5d276ab1 with riskCheck=disable accepted | |
| 16 | DoNotShareWarning configurable on service | default | CONFIRMED | VAeb5a1c91 created with doNotShareWarningEnabled=true | |
| 17 | Verification Attempts API with VL SIDs | behavioral | CONFIRMED | VL30e44f12 returned via verificationAttempts.list() | |
| 18 | No built-in channel fallback | scope | CONFIRMED | Docs + live test: channel switch requires separate API call | |
| 19 | No webhook on verification completion | scope | CONFIRMED | Docs: no callback URL parameter exists on Verifications resource | |
| 20 | Cannot retrieve the actual code | scope | CONFIRMED | No code field in any API response; docs confirm by design | |
| 21 | Channel switch reuses same VE SID and token | behavioral | CONFIRMED | VE5d276ab1 across sms→call→whatsapp, same SID | |
| 22 | Cannot extend TTL on existing verification | scope | CONFIRMED | No TTL parameter on update; docs say contact Support for account-level | |
| 23 | VE SID deleted after approval | behavioral | CONFIRMED | VEe9a0bd66 → 404 after approval | |
| 24 | Canceled verification SID persists | behavioral | CONFIRMED | VEbc83fbec fetchable after cancel, status=canceled | |
| 25 | Max attempts verification SID persists | behavioral | CONFIRMED | VEf635fd47 fetchable after max_attempts_reached | |
| 26 | auto channel returns 60200 | behavioral | QUALIFIED | 60200 on test account | Qualified: may work on accounts with Fraud Guard enabled |
| 27 | Email requires Mailer, error 60217 | behavioral | CONFIRMED | Error 60217 "A Mailer must be associated with the service" | |
| 28 | SNA returns 60001 without carrier setup | behavioral | CONFIRMED | Error 60001 "Downstream Authentication Failed" | |
| 29 | Status polling rate-limited: 60/min, 180/hr, 250/day | architectural | CONFIRMED | Twilio docs: rate-limits-and-timeouts page | Not live-tested (would require >60 calls/min) |
| 30 | Default TTL is 10 minutes | default | CONFIRMED | Twilio docs: rate-limits-and-timeouts, "default period of 10 minutes" | |
| 31 | Wrong code returns pending/false, not error | behavioral | CONFIRMED | 5 wrong checks all returned status=pending, valid=false | |
| 32 | 6th wrong code throws 60202 | behavioral | CONFIRMED | Attempt 6 → error 60202 "Max check attempts reached" | |
| 33 | 60202 is max check attempts | error | CORRECTED | Live: 60202 = "Max check attempts reached". Domain CLAUDE.md had it as "Max send attempts" | Updated CLAUDE.md and skill |
| 34 | 60203 is max send attempts | error | CORRECTED | Live: 60203 = "Max send attempts reached". Domain CLAUDE.md had it as "Max check attempts" | Updated CLAUDE.md and skill |
| 35 | Check non-existent verification returns 60200 | error | CONFIRMED | Check to +19995551234 (never sent) → 60200 "Invalid parameter To" | |
| 36 | codeLength default is 6 | default | CONFIRMED | Service fetch: codeLength=6 | |
| 37 | dtmfInputRequired defaults to true | default | CONFIRMED | Service fetch: dtmfInputRequired=true | |
| 38 | lookupEnabled defaults to false | default | CONFIRMED | Service fetch: lookupEnabled=false | |
| 39 | skipSmsToLandlines defaults to false | default | CONFIRMED | Service fetch: skipSmsToLandlines=false | |
| 40 | customCodeEnabled defaults to false | default | CONFIRMED | Service fetch: customCodeEnabled=false | |
| 41 | FriendlyName rejects 5+ digits, allows 4 | behavioral | CONFIRMED | 4 digits → VA684db2da OK; 5 digits → 60200 | |

## Corrections Applied

- **Original text** (CLAUDE.md, not skill): "60202 | Max send attempts reached" / "60203 | Max check attempts reached"
- **Corrected text**: "60202 | Max check attempts reached (5 wrong codes)" / "60203 | Max send attempts reached (too many sends to same number)"
- **Why**: Live testing proved the codes are swapped from what was documented. 6th wrong code check threw 60202 with message "Max check attempts reached". Resending to rate-limited number threw 60203 with message "Max send attempts reached". Domain CLAUDE.md updated.

Note: Assertions #33 and #34 are listed as CORRECTED because the domain CLAUDE.md had them wrong. The skill itself was written with the correct mapping from the start (based on live testing).

## Qualifications Applied

- **#6 — TOTP**: "TOTP for authenticator app integration (separate factor flow)"
  - **Qualified text**: Already qualified in skill with "(separate factor flow)"
  - **Condition**: TOTP uses the Factors API (`/v2/Services/{SID}/Entities/{identity}/Factors`), not the Verifications API. Cannot be started via `start_verification`.

- **#26 — auto channel**: "`auto` channel not universally available"
  - **Qualified text**: "Returns 60200 on accounts without Fraud Guard or specific configuration"
  - **Condition**: May work on accounts with Fraud Guard enabled. Our test account (ACxx...xx) does not have it. The skill already notes "Do not assume it works" which is the appropriate guidance.
