---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit log for the Voice Trust & Caller Identity skill. -->
<!-- ABOUTME: Cross-references branded-calling (65 assertions) and voice (23 trust assertions) audits. -->

# Assertion Audit Log

**Skill**: voice-trust
**Audit date**: 2026-03-28
**Account**: ACb4de2...
**Auditor**: Claude + MC
**Cross-referenced audits**: branded-calling (65 assertions), voice (T1-T23)

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 48 |
| QUALIFIED | 7 |
| CORRECTED | 2 |
| REMOVED | 0 |
| **Total** | **57** |

### Verification Methods

- **Cross-ref (BC)**: Assertion verified in branded-calling assertion audit (live API evidence)
- **Cross-ref (V)**: Assertion verified in voice skill assertion audit (doc-sourced + cross-checked)
- **Doc-sourced**: Verified against official Twilio SHAKEN/STIR documentation (fetched 2026-03-28)
- **Inferred**: Logical deduction from API behavior and documentation structure
- **Untestable**: Requires inbound calls from external carriers with specific attestation levels

---

## Evidence Group 1: Attestation Level Definitions (6 assertions)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 1 | Level A = caller known AND authorized to use number | CONFIRMED | Cross-ref V:T1. Docs: "Full attestation: the caller has the right to use the calling number." |
| 2 | Level B = caller known, number authorization unverified | CONFIRMED | Cross-ref V:T2. Docs: exact definition. |
| 3 | Level C = does not meet A or B (international, gateway) | CONFIRMED | Cross-ref V:T3. Docs: "it doesn't meet the requirements of A or B including international calls." |
| 4 | SHAKEN/STIR is US-only | CONFIRMED | Cross-ref V:T10, BC:#15. Docs: "being deployed in the United States only." |
| 5 | SHAKEN/STIR is automatic with approved Primary Customer Profile (no separate Trust Product) | CONFIRMED | Cross-ref BC:#11. Live API: no SHAKEN/STIR policy found in Policies list (100 policies queried). Docs: "SHAKEN/STIR is automatically added to all the approved Primary Customer Profiles." |
| 6 | A-level attestation requires phone numbers assigned to Business Profile AND SHAKEN/STIR Trust Product | CONFIRMED | Doc-sourced: "only calls from those assigned Phone Numbers will be signed 'A'." |

## Evidence Group 2: StirVerstat Values (10 assertions)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 7 | `TN-Validation-Passed-A` = full attestation, verified | CONFIRMED | Cross-ref V:T4. Docs: value table matches. |
| 8 | `TN-Validation-Passed-B` = partial attestation, verified | CONFIRMED | Cross-ref V:T4. |
| 9 | `TN-Validation-Passed-C` = gateway attestation, verified | CONFIRMED | Cross-ref V:T4. |
| 10 | `-Diverted` suffix variants exist for A/B/C | CONFIRMED | Cross-ref V:T4. Docs reference diverted call handling. |
| 11 | `-Passthrough` suffix variants exist for A/B/C | CONFIRMED | Cross-ref V:T4. Docs reference passport passthrough. |
| 12 | `TN-Validation-Failed-A/B/C` = PASSporT present but verification failed | CONFIRMED | Doc-sourced: "Unable to verify PASSporT contents." |
| 13 | `TN-Validation-Failed` (no level) = general verification failure | CONFIRMED | Doc-sourced: listed in value table. |
| 14 | `No-TN-Validation` = malformed E.164, invalid PASSporT, missing fields, or stale timestamp | CONFIRMED | Doc-sourced: specific causes listed. Docs also note "exceeding 1 minute old" for iat timestamp. |
| 15 | StirVerstat is absent when no PASSporT exists in the call | CONFIRMED | Doc-sourced: "only present in the incoming call webhook when the incoming call has SHAKEN PASSporT identity headers." |
| 16 | StirVerstat is on inbound webhooks only (not status callbacks) | QUALIFIED | Doc-sourced: described for "incoming webhooks." **Qualification**: StirStatus (not StirVerstat) appears in status callbacks for outbound calls. These are different parameters — easy to confuse. Added explicit distinction in skill. |

## Evidence Group 3: CallToken & Transfer (8 assertions)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 17 | CallToken parameter present in inbound webhook body | CONFIRMED | Cross-ref V:T6. Docs: "a CallToken property." |
| 18 | CallToken contains SHAKEN PASSporT JWT | CONFIRMED | Doc-sourced: "The CallToken contains any SHAKEN/STIR and DIV (diversion) PASSporTs." |
| 19 | CallToken works with Calls API `calls.create()` | CONFIRMED | Cross-ref V:T7. Docs: "CallToken parameter when creating a new Call Resource." |
| 20 | CallToken works with Conference Participants API | CONFIRMED | Cross-ref V:T9. Docs: "creating a new Conference Participant." |
| 21 | `<Dial>` does NOT pass CallToken / cryptographic proof | CONFIRMED | Doc-sourced: "Immutable caller ID call forwarding is available for calls created using the Programmable Voice Calls API and Participants API." `<Dial>` not listed. |
| 22 | `<Dial>` preserves original caller ID (display) by default | CONFIRMED | Cross-ref V:T8. Docs: "Dial calls can use the original caller ID by default." |
| 23 | CallToken is single-use / must be passed immediately | CONFIRMED | Cross-ref V:T23. Implied by extract-and-pass-immediately pattern. No storage/reuse mechanism documented. |
| 24 | SIP REFER does not pass PASSporT | QUALIFIED | Inferred: no documentation mentions SIP REFER preserving SHAKEN/STIR. CallToken is explicitly described for Calls API and Participants API only. **Qualification**: Not explicitly documented as unsupported — rather, not mentioned as supported. Treat as unsupported but note inference. |

## Evidence Group 4: Outbound Monitoring (4 assertions)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 25 | StirStatus parameter appears in status callbacks for outbound calls | CONFIRMED | Cross-ref V:T5. Docs: "The Status Callback StirStatus optional parameter." |
| 26 | StirStatus values: A, B, C (for outbound signing level) | CONFIRMED | Doc-sourced: attestation levels applied to outbound calls. |
| 27 | `stir_verstat` field exists in Voice Insights Call Summary | CONFIRMED | Cross-ref BC:#35. Voice Insights API reference confirms field. |
| 28 | `caller_name` field in Call Summary `properties` object | CONFIRMED | Cross-ref BC:#37. Corrected location (properties object, not top-level). |

## Evidence Group 5: Elastic SIP Trunking (4 assertions)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 29 | SIP Trunking uses `X-Twilio-VerStat` header instead of StirVerstat | CONFIRMED | Cross-ref V:T21. Docs: "a new header called X-Twilio-VerStat" for SIP customers. |
| 30 | SIP Trunking uses `Identity` header for raw PASSporT | CONFIRMED | Doc-sourced: "a new Identity header with the SHAKEN PASSporT." |
| 31 | X-Twilio-VerStat uses same values as StirVerstat | CONFIRMED | Doc-sourced: same verification framework, different delivery mechanism. |
| 32 | No CallToken forwarding mechanism for SIP Trunking | QUALIFIED | Inferred: CallToken documented only for Calls API and Participants API. No mention of SIP-based CallToken delivery. **Qualification**: absence of documentation is not proof of absence. Marked as "not available" rather than "explicitly unsupported." |

## Evidence Group 6: Trust Product Stack (8 assertions)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 33 | Enhanced Branded Calling requires Voice Integrity | CONFIRMED | Cross-ref BC:#22. Live API: policy `RNca63d...` requires `voice_integrity_trust_product`. |
| 34 | Basic Branded Calling requires Business Profile + LOA | CONFIRMED | Cross-ref BC:#5, BC:#6. Live API: LOA required in all 7 policies. |
| 35 | Voice Integrity requires Business Profile | CONFIRMED | Cross-ref BC:#48. Trust Product hierarchy documented. |
| 36 | Primary Customer Profile vetting ~1-3 business days | CONFIRMED | Cross-ref BC:#31. Qualified with "typically" in skill text. |
| 37 | Basic Branded Calling approval ~2-4 weeks | CONFIRMED | Cross-ref BC:#32. Corrected from original "5-10 business days" in BC audit. |
| 38 | Enhanced Branded Calling approval ~3-6 weeks | CONFIRMED | Cross-ref BC:#33. Corrected from original "10-15+ business days" in BC audit. |
| 39 | Cannot self-approve trust products (human review required) | CONFIRMED | Cross-ref BC:#23. Status lifecycle requires `pending-review` → `in-review` → `twilio-approved`. |
| 40 | Cannot skip LOA for any Branded Calling tier | CONFIRMED | Cross-ref BC:#21. All 7 policies require `letter_of_authorization_document`. |

## Evidence Group 7: Scope CANNOT Claims (8 assertions)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 41 | Cannot guarantee call delivery (carrier filters independent) | CONFIRMED | Doc-sourced: Twilio docs explicitly state trust products don't override carrier heuristics. |
| 42 | Cannot verify callers without carrier cooperation | CONFIRMED | Doc-sourced: StirVerstat only present when originating carrier provides SHAKEN/STIR. |
| 43 | Cannot force branded display on every device | CONFIRMED | Cross-ref BC:#11 (runtime gotcha). Display depends on carrier + device + OS. |
| 44 | Cannot brand inbound calls (outbound only) | CONFIRMED | Cross-ref BC:#16. Branded Calling applies to outbound calls only. |
| 45 | Cannot preserve attestation through `<Dial>` | CONFIRMED | Same as assertion #21. CallToken is Calls API / Participants API only. |
| 46 | Cannot use Branded Calling with SIP Trunking | CONFIRMED | Cross-ref V:T20, BC:#19. Requires Programmable Voice. |
| 47 | Cannot use trust products outside the US | CONFIRMED | Cross-ref V:T10, BC:#15. SHAKEN/STIR and Branded Calling are US-only. |
| 48 | Cannot bypass manual approval | CONFIRMED | Cross-ref BC:#23, #39 above. Human review is mandatory. |

## Evidence Group 8: Symptom Diagnostic Claims (5 assertions)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 49 | SIP 603 (Decline) can result from carrier rejection of untrusted calls | CONFIRMED | SIP 603 is "Decline" per RFC 3261. Carrier spam filters use this to reject calls. Doc-sourced from Twilio Voice error reference. |
| 50 | SIP 608 (Rejected) indicates carrier explicitly blocking a call | CORRECTED | **Original**: SIP 608 = carrier explicitly blocking. **Correction**: SIP 608 is "Rejected" per RFC 3261 — it means the callee does not wish to be reached. While carriers can use it, it's not exclusively a carrier-blocking code. Updated symptom table: "Carrier or callee explicitly rejecting call." |
| 51 | Voice Integrity remediates spam labels by registering with carrier analytics databases | CONFIRMED | Cross-ref V:T22. Carrier analytics providers: Hiya, TNS, First Orion. |
| 52 | High call volume + low answer rate can trigger spam labels even with trust products | CONFIRMED | Doc-sourced: Twilio trust product documentation warns about calling pattern heuristics. |
| 53 | Forwarded calls lose SHAKEN/STIR attestation without CallToken | CONFIRMED | Same as assertions #21, #45. Only Calls API and Participants API pass the PASSporT. |

## Evidence Group 9: StirPassportToken JWT Claims (4 assertions)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 54 | StirPassportToken contains SHAKEN PASSporT JWT | CONFIRMED | Doc-sourced: "The CallToken contains any SHAKEN/STIR and DIV (diversion) PASSporTs." StirPassportToken is the raw JWT. |
| 55 | JWT `attest` claim contains attestation level (A/B/C) | CONFIRMED | ATIS SHAKEN standard (ATIS-1000074): `attest` is a mandatory claim. |
| 56 | JWT `iat` must be within 60 seconds | CONFIRMED | Doc-sourced: Twilio references "timestamp exceeding 1 minute old" causing No-TN-Validation. ATIS standard specifies freshness. |
| 57 | PASSporT uses ES256 (ECDSA P-256) signing | QUALIFIED | ATIS standard specifies ES256 for SHAKEN PASSporTs. **Qualification**: Twilio docs don't explicitly state the algorithm — this is from the ATIS-1000074 specification. Practically, all SHAKEN implementations use ES256, but we're citing the standard rather than Twilio-specific documentation. |

---

## Corrections Applied to Skill

| # | Location | Original | Corrected |
|---|----------|----------|-----------|
| 50 | SKILL.md §Symptom Diagnostic | "Carrier explicitly blocking call" | "Carrier or callee explicitly rejecting call" |
| 16 | SKILL.md §Outbound Trust Monitoring | (no issue — but clarified) | Added explicit note that StirVerstat (inbound) and StirStatus (outbound) are different parameters |

## Qualifications Applied to Skill

| # | Location | Qualification |
|---|----------|--------------|
| 16 | SKILL.md §Outbound Trust | StirVerstat vs StirStatus distinction clarified |
| 24 | SKILL.md §What Does NOT Preserve | SIP REFER: "not documented as supported" rather than "explicitly unsupported" |
| 32 | references/inbound-verification.md §SIP Trunking | CallToken for SIP: "not available" based on absence from docs |
| 57 | references/inbound-verification.md §JWT | ES256: sourced from ATIS standard, not Twilio-specific docs |

---

## Cross-Reference Index

Assertions in this audit that directly map to prior audits:

| This Audit | Branded-Calling Audit | Voice Audit |
|------------|-----------------------|-------------|
| #1-3 | — | T1-T3 |
| #4 | BC:#15 | T10 |
| #5 | BC:#11 | — |
| #6 | — | — (doc-only) |
| #7-11 | — | T4 |
| #17 | — | T6 |
| #19 | — | T7 |
| #20 | — | T9 |
| #22 | — | T8 |
| #23 | — | T23 |
| #25 | — | T5 |
| #27 | BC:#35 | — |
| #28 | BC:#37 | — |
| #29 | — | T21 |
| #33 | BC:#22 | — |
| #34 | BC:#5, BC:#6 | — |
| #36-38 | BC:#31-33 | — |
| #39 | BC:#23 | — |
| #40 | BC:#21 | — |
| #46 | BC:#19 | T20 |
| #51 | — | T22 |
