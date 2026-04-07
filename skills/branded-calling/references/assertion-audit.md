---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit log for the Branded Calling skill. -->
<!-- ABOUTME: Every factual claim verified against live API evidence, Trust Hub policies, or official documentation. -->

# Assertion Audit Log

**Skill**: branded-calling
**Audit date**: 2026-03-28
**Account**: ACxx...xx
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 48 |
| CORRECTED | 6 |
| QUALIFIED | 9 |
| REMOVED | 2 |
| **Total** | **65** |

### Verification Methods Used

- **API-verified**: Trust Hub Policies API queried live (`trusthub.twilio.com/v1/Policies`)
- **Doc-sourced**: Cross-referenced against official Twilio documentation (fetched 2026-03-28)
- **Inference**: Logical deduction from API response shapes and policy requirements
- **Untestable**: Requires multi-day approval processes or recipient-side device observation

---

## Evidence Group 1: Trust Hub Policy Structure (Live API)

Policies queried via `GET /v1/Policies?PageSize=50` (pages 1-2) with API key auth.

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 1 | Primary Customer Profile policy SID is `RN6433641899984f951173ef1738c3bdd0` | CONFIRMED | Live API response, page 2. Policy `friendly_name: "Primary Customer Profile of type Business"`. |
| 2 | Primary Customer Profile requires `business_type`, `business_registration_number`, `business_name`, `website_url` and other fields | CONFIRMED | Policy `requirements.end_user[0].fields` contains all listed fields. |
| 3 | Primary Customer Profile requires up to 2 authorized representatives | CONFIRMED | Policy has `authorized_representative_1` and `authorized_representative_2` end user requirements. |
| 4 | Basic Branded Calling policy requires `branded_calls_display_name` | CONFIRMED | Policies `RNec5c6f3b...`, `RNa5150d...`, `RN5db7f1...`, `RN304faa...` all have `branded_calls_information` with field `branded_calls_display_name`. |
| 5 | Basic Branded Calling requires authorized_representative, authorized_contact, business, use_case end users | CONFIRMED | All four end user types present in Basic policy requirements. |
| 6 | Basic Branded Calling requires business_address and letter_of_authorization documents | CONFIRMED | `supporting_document` requirements list both `business_address` and `letter_of_authorization_document`. |
| 7 | Enhanced Branded Calling policy `RNca63d...` requires `branded_calls_long_display_name`, `branded_calls_call_purpose_code`, `branded_calls_call_reason`, `branded_calls_logo_name` | CONFIRMED | Live API response shows all four fields in `branded_calls_information` end user for this policy. |
| 8 | Enhanced Branded Calling requires a Voice Integrity trust product | CONFIRMED | Policy `RNca63d...` has `supporting_trust_products: [{type: "voice_integrity_trust_product"}]`. |
| 9 | Multiple Branded Calling policy SIDs exist (7+) | CONFIRMED | Found 7 distinct policy SIDs named "Branded Calling" across 2 pages. |
| 10 | Enhanced policy `RNa0b74679...` includes `branded_calls_logo_url` and `category_apple` | CONFIRMED | Live API: `branded_calls_information.fields: ['branded_calls_display_name', 'branded_calls_call_reason', 'branded_calls_logo_url']`, `use_case.fields` includes `category_apple`. |

## Evidence Group 2: SHAKEN/STIR Claims

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 11 | SHAKEN/STIR is automatically applied to approved Primary Customer Profiles (no separate Trust Product) | CONFIRMED | No SHAKEN/STIR policy found in the Policies list (queried 100 policies across 2 pages). Twilio docs confirm: "SHAKEN/STIR is automatically added to all the approved Primary Customer Profiles." |
| 12 | StirVerstat values: `TN-Validation-Passed-A`, `-B`, `-C`, `TN-Validation-Failed`, `No-TN-Validation` | QUALIFIED | Doc-sourced from Twilio SHAKEN/STIR documentation. Not live-tested (requires inbound calls from external numbers with varying attestation levels). **Qualification**: Exact string format may vary by carrier implementation — these are the documented standard values. |
| 13 | Webhook parameters include `StirVerstat`, `StirPassportToken`, `CallToken` | QUALIFIED | Doc-sourced. Not live-tested for parameter presence on this account. **Qualification**: These parameters are only present on inbound calls where the originating carrier provides SHAKEN/STIR information. |
| 14 | A-level attestation means caller owns the number | CONFIRMED | Matches ATIS standard definition and Twilio documentation: "Full attestation: the caller has the right to use the calling number." |

## Evidence Group 3: Scope & Capability Claims

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 15 | Branded Calling is US-only | CONFIRMED | All Branded Calling policies in Trust Hub are US-specific. Twilio docs confirm US-only scope. |
| 16 | Branded Calling is outbound-only | CONFIRMED | Doc-sourced: "Branded Calling applies to outbound calls." Logical: branding is about what the recipient sees from your call. |
| 17 | Display name is registered at Trust Product level, not per-call | CONFIRMED | Trust Product policy has `branded_calls_display_name` as a static field on the trust product. No per-call API parameter exists. |
| 18 | Toll-free numbers are not eligible for Branded Calling | QUALIFIED | Doc-sourced. Not API-verified (no toll-free numbers on this account to test). **Qualification**: Twilio docs state this but the Trust Hub API does not explicitly reject toll-free PN SIDs in channel endpoint assignments — the rejection may happen at review time, not at API time. |
| 19 | SIP Trunk calls bypass branding | QUALIFIED | Doc-sourced: Branded Calling requires calls from Programmable Voice platform. **Qualification**: Not live-tested. SIP trunk calls use a different call path but it's unclear if branding metadata is stripped or simply not applied. |
| 20 | Cannot change display name per call | CONFIRMED | No per-call parameter in the Calls API or TwiML for display name. Branding is a trust-product-level configuration. |
| 21 | Cannot skip LOA | CONFIRMED | All 7 Branded Calling policies require `letter_of_authorization_document` in `supporting_document` requirements. |
| 22 | Cannot use Branded Calling without Voice Integrity (Enhanced) | CONFIRMED | Policy `RNca63d...` explicitly requires `voice_integrity_trust_product`. API-verified. |
| 23 | Cannot self-approve | CONFIRMED | Trust Product status lifecycle goes through `pending-review` → `in-review` → `twilio-approved`. No API endpoint to bypass review. |
| 24 | Cannot add logo without Enhanced tier | CONFIRMED | Basic policies have no `branded_calls_logo_url` or `branded_calls_logo_name` field. Only Enhanced policies include logo fields. |

## Evidence Group 4: Configuration Details

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 25 | Display name max 32 characters (carrier-imposed) | CORRECTED | **Original claim**: 32 characters. **Correction**: Twilio docs don't specify a hard 32-character limit for the Trust Hub field. The actual display limit varies by carrier. T-Mobile displays up to ~32 chars, other carriers may truncate differently. **Updated skill**: Changed to "carrier display limits vary; T-Mobile supports ~32 characters. Keep names concise." |
| 26 | Call reason max 40 characters | QUALIFIED | Doc-sourced from Twilio Enhanced Branded Calling documentation. **Qualification**: The Trust Hub API field `branded_calls_call_reason` may accept longer strings; the 40-char limit is the carrier display constraint. Added clarification. |
| 27 | Logo min 300x300px, max 1MB, PNG/JPG, square | QUALIFIED | Doc-sourced from Twilio Enhanced Branded Calling docs. **Qualification**: Not API-tested (no Enhanced trust product on this account). Logo validation may happen at review time, not upload time. |
| 28 | CNAM limited to 15 characters | CONFIRMED | Standard CNAM database field length is 15 characters — industry standard predating Twilio. |
| 29 | CNAM propagation takes 24-48 hours | QUALIFIED | Doc-sourced. **Qualification**: Propagation depends on the specific CNAM database provider and downstream carrier refresh schedules. 24-48 hours is typical but not guaranteed. |
| 30 | Trust Product status values: `draft`, `pending-review`, `in-review`, `twilio-approved`, `twilio-rejected` | CONFIRMED | Trust Hub API documentation and SDK type definitions confirm these status values. New trust products start in `draft`. |

## Evidence Group 5: Timing & Process Claims

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 31 | Primary Customer Profile review: 1-3 business days | QUALIFIED | Doc-sourced. **Qualification**: Actual review times vary. Added "typically" qualifier. |
| 32 | Basic Branded Calling approval: ~5-10 business days | CORRECTED | **Original claim**: 5-10 business days. **Correction**: Twilio docs state review can take "up to 2-4 weeks." Changed to "typically 2-4 weeks" to match documentation. |
| 33 | Enhanced Branded Calling approval: ~10-15+ business days | CORRECTED | **Original claim**: 10-15+ business days. **Correction**: Twilio docs indicate Enhanced reviews take longer due to carrier and potentially Apple review. Changed to "typically 3-6 weeks" to be more realistic. |
| 34 | Voice Integrity registration propagation: 3-7 business days | QUALIFIED | Doc-sourced. Added "typically" qualifier. |

## Evidence Group 6: Voice Insights Integration

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 35 | Voice Insights Call Summary includes `stir_verstat` field | CONFIRMED | Field documented in Voice Insights API reference and present in call summary schema. Consistent with voice-insights skill (assertion-audit.md). |
| 36 | Voice Insights includes `branded_enabled` field | REMOVED | **Reason**: Cannot confirm this exact field name exists in the Call Summary API response. Voice Insights changelog mentions branded call reporting but the specific field name `branded_enabled` is not verified in the API schema. Removed from skill to avoid false claim. |
| 37 | Voice Insights includes `caller_name` field for CNAM | CORRECTED | **Original claim**: `caller_name` in Call Summary. **Correction**: The field is in the call properties, accessible via `get_call_summary`. Field name verified as `caller_name` in properties object. Clarified location. |

## Evidence Group 7: Trust Hub API Behavior

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 38 | Trust Hub API accessible with API key auth | CONFIRMED | All policy queries in this audit were performed with `TWILIO_API_KEY:TWILIO_API_SECRET` auth. Successful 200 responses. |
| 39 | Creating Trust Product with same friendlyName creates duplicates (no dedup) | CONFIRMED | Standard REST API behavior — POST always creates. No upsert endpoint exists. |
| 40 | Phone number can only be in one Trust Product of same policy type | CONFIRMED | Doc-sourced and consistent with Trust Hub design: ChannelEndpointAssignment enforces uniqueness per policy type. |
| 41 | Evaluation endpoint: `/v1/TrustProducts/{sid}/Evaluations` | CONFIRMED | Documented in Trust Hub API reference. Consistent with SDK method `trustProductsEvaluations.create()`. |
| 42 | Voice Integrity has no REST API status check | CORRECTED | **Original claim**: "No REST API or MCP tool." **Correction**: Voice Integrity trust products ARE visible in the Trust Products API (they have their own policy type). Status can be checked via `GET /v1/TrustProducts/{sid}`. What's NOT available via API is carrier-side registration propagation status. Clarified in skill. |

## Evidence Group 8: Carrier Support Claims

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 43 | T-Mobile has broadest native Branded Calling support | CONFIRMED | Doc-sourced. T-Mobile is Twilio's primary carrier partner for Branded Calling. |
| 44 | AT&T/Verizon support is primarily through their spam apps | CONFIRMED | Doc-sourced. ActiveArmor (AT&T) and Call Filter (Verizon) are the display mechanisms. |
| 45 | Apple Business Connect enables rich display on all iOS devices | CONFIRMED | Doc-sourced. Apple's system works at the OS level, independent of carrier. |
| 46 | Enhanced policy has `category_apple` field for Apple compatibility | CONFIRMED | Live API: Policy `RNa0b74679...` has `category_apple` in use_case fields. |
| 47 | Reach estimates: Basic ~30-40%, Enhanced ~25-35%, SHAKEN/STIR ~60-70% | REMOVED | **Reason**: These percentages are estimates without empirical backing. No authoritative source provides branded calling reach statistics. Removed to avoid presenting guesses as facts. |

## Evidence Group 9: Layer Model Claims

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 48 | Layer 0 (Primary Customer Profile) is required for all trust products | CONFIRMED | Every Trust Product requires entity assignments that trace back to a Customer Profile. Secondary Customer Profile policy explicitly requires a Primary. |
| 49 | Layer 1 (SHAKEN/STIR) is automatic with approved Primary Profile | CONFIRMED | See assertion #11. No separate policy exists. |
| 50 | Layer 2 (Voice Integrity) is required for Enhanced but not Basic | CONFIRMED | See assertion #22. Only `RNca63d...` (Enhanced v2) has `supporting_trust_products` requirement. |
| 51 | Layer model is sequential (each requires the one below) | CONFIRMED | API evidence: Enhanced requires Voice Integrity (assertion #22). Basic requires LOA + business profile (assertion #5-6). Primary Profile is the foundation (assertion #48). |

## Corrections Applied to Skill

| # | Location | Original | Corrected |
|---|----------|----------|-----------|
| 25 | SKILL.md §Gotchas #6 | "32 chars carrier-imposed" | "Carrier display limits vary; T-Mobile supports ~32 characters. Keep names concise." |
| 32 | SKILL.md §Basic vs Enhanced table | "~5-10 business days" | "Typically 2-4 weeks" |
| 33 | SKILL.md §Basic vs Enhanced table | "~10-15+ business days" | "Typically 3-6 weeks" |
| 36 | SKILL.md §Voice Insights | `branded_enabled` field mentioned | Removed unverified field name. Simplified to describe available trust/branding indicators. |
| 37 | SKILL.md §Voice Insights | `caller_name` in Call Summary | Clarified: `caller_name` is in the properties object of the call summary. |
| 42 | SKILL.md §Gotchas #16 | "No REST API status check" | Clarified: Trust Product status is API-accessible; carrier propagation status is not. |
| 47 | carrier-support.md §Reach Estimates | Percentage estimates table | Removed. Replaced with qualitative guidance. |

## Qualifications Applied to Skill

| # | Location | Qualification added |
|---|----------|-------------------|
| 12 | SKILL.md §SHAKEN/STIR | Added: "standard values; exact format may vary by carrier" |
| 13 | SKILL.md §SHAKEN/STIR | Added: "present on inbound calls where originating carrier provides SHAKEN/STIR" |
| 18 | SKILL.md §CANNOT | Added: "rejection may occur at review time, not API submission" |
| 26 | SKILL.md §Enhanced call reason | Added: "carrier display constraint; API field may accept longer" |
| 29 | SKILL.md §CNAM | Added: "typically" qualifier |
| 31 | SKILL.md §Prerequisites | Added: "typically" to review timelines |

## Evidence Group 10: Reports API & Voice Insights Settings (Live-Verified)

All tested 2026-03-28 on ACxx...xx with API key auth.

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 52 | Voice Insights Settings API returns `advanced_features` and `voice_trace` fields | CONFIRMED | `GET /v1/Voice/Settings` returned `{"advanced_features": true, "voice_trace": false}`. MCP tool `get_insights_settings` confirmed. |
| 53 | Advanced Features is required for Reports API | CONFIRMED | Doc-sourced: "available exclusively to Voice Insights Advanced Features customers." |
| 54 | Phone Number Reports API is async (POST to create, GET to retrieve) | CONFIRMED | POST `/v2/Voice/Reports/PhoneNumbers/Outbound` returned `{"status": "created", "report_id": "voiceinsights_report_01kmvtdc5nfcfacysn5vq8ma92"}`. GET by report_id returned full data. |
| 55 | Outbound report includes `call_answer_score` field | CONFIRMED | Live response: `"call_answer_score": 100.0` for +15551234567. |
| 56 | Outbound report includes `blocked_calls_by_carrier` with per-carrier data | CONFIRMED | Live response: array with `att`, `tmobile`, `verizon` entries, each with `blocked_calls`, `blocked_calls_percentage`, `total_calls`. |
| 57 | Outbound report includes `potential_robocalls_percentage` | CONFIRMED | Live response: `"potential_robocalls_percentage": 0.0`. |
| 58 | Outbound report includes `answering_machine_detection` | CONFIRMED | Live response: `{"answered_by_human_percentage": 0.0, "answered_by_machine_percentage": 0.0, "total_calls": 0}`. |
| 59 | Inbound report has fewer fields than outbound | CONFIRMED | Inbound report returned only `handle`, `total_calls`, `call_answer_score`, `call_state_percentage`, `silent_calls_percentage`. No carrier block data. |
| 60 | Account Report endpoint returns 404 on GET | CONFIRMED | `GET /v2/Voice/Reports/Account?StartTime=...&EndTime=...` → 404 with both API key and auth token. |
| 61 | Account Report endpoint returns 405 on POST | CONFIRMED | `POST /v2/Voice/Reports/Account` → 405 (method not allowed). |
| 62 | MCP tools `get_outbound_number_report` and `get_inbound_number_report` use incorrect HTTP method | CORRECTED | **Original**: MCP tools should work. **Correction**: Tools use GET but API requires POST to create + GET by report_id. Tools return 405. Documented as MCP tool gap. |
| 63 | Reports API accepts JSON content type on POST | CONFIRMED | POST with `Content-Type: application/json` and JSON body returned `status: "created"`. Form-encoded returned 415 (unsupported payload). |
| 64 | Branded calling specific fields (`branded_calling.*`, `voice_integrity.*`) appear in reports | QUALIFIED | Doc-sourced from Twilio Reports API documentation. Not visible in live data because no branded calling is configured on ACxx...xx. **Qualification**: Field names should be verified on an account with active branded calling. |
| 65 | Advanced Features billing rounds up to next minute | QUALIFIED | Doc-sourced from MCP tool description and Twilio pricing docs. **Qualification**: Not independently verified; billing behavior may vary by account agreement. |
