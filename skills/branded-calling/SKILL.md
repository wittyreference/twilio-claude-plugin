---
name: "branded-calling"
description: "Twilio development skill: branded-calling"
---

---
name: branded-calling
description: Twilio Branded Calling development guide. Use when improving outbound call answer rates, displaying business name/logo on caller ID, setting up SHAKEN/STIR attestation, remediating spam labels, or configuring CNAM.
allowed-tools: mcp__twilio__*, Read, Grep, Glob
---

# Branded Calling Skill

Decision-making guide for the Twilio call trust stack: Branded Calling (Basic and Enhanced), SHAKEN/STIR attestation, Voice Integrity spam remediation, and CNAM caller ID. Load this skill when a developer wants to improve outbound call answer rates, display a business name or logo on the recipient's phone, remediate spam/scam labels, or configure caller identity.

**Evidence date**: 2026-03-28 | **Account**: ACb4de2... | **Trust Hub policies verified via live API**

---

## Scope

### What the Call Trust Stack CAN Do

- Display a **business name** on the recipient's phone (Basic Branded Calling — T-Mobile, some carriers)
- Display a **business name + logo + call reason** on the recipient's phone (Enhanced Branded Calling — T-Mobile, limited Apple/iOS)
- Achieve **SHAKEN/STIR A-level attestation** on outbound calls (proves your business owns the calling number)
- **Remediate spam/scam labels** on your numbers across T-Mobile, AT&T, Verizon via Voice Integrity
- Register **CNAM** (Caller Name) for display on landlines and some carriers
- Track branded call delivery via **Voice Insights** (branded call status, SHAKEN/STIR verification)
- Manage the full setup programmatically via **Trust Hub API** (TrustProducts, CustomerProfiles, EndUsers, Documents)

### What the Call Trust Stack CANNOT Do

- **Cannot guarantee display on every device** — Branded Calling display depends on the recipient's carrier, device, and OS. Not all combinations show the brand. There is no way to force display.
- **Cannot brand inbound calls** — Branded Calling applies to outbound calls only. Inbound caller ID is controlled by the originating carrier.
- **Cannot use Branded Calling without Voice Integrity (Enhanced)** — Enhanced Branded Calling requires an approved Voice Integrity trust product as a prerequisite.
- **Cannot skip the LOA (Letter of Authorization)** — Both Basic and Enhanced require a signed LOA proving your business is authorized to use the phone numbers.
- **Cannot change the display name per call** — The display name is registered at the Trust Product level. All calls from assigned numbers show the same name.
- **Cannot use toll-free numbers** — Branded Calling is for local and mobile numbers only. Toll-free has its own trust framework.
- **Cannot self-approve** — All Branded Calling trust products require Twilio review and carrier-side registration. Approval timelines are measured in business days to weeks.
- **Cannot use Branded Calling outside the US** — Currently US-only for both Basic and Enhanced tiers.
- **Cannot add a logo without Enhanced tier** — Basic shows business name only. Logo requires Enhanced Branded Calling.
- **Cannot brand calls made via SIP Trunking** — Branded Calling requires calls to originate from the Twilio Programmable Voice platform (API or TwiML). SIP trunk calls bypass the branding layer.

---

## Quick Decision Reference

| Need | Use | Why |
|------|-----|-----|
| Business name on caller ID (text only) | Basic Branded Calling | Broadest carrier support for name display |
| Business name + logo + call reason | Enhanced Branded Calling | Rich display on supported devices |
| Prove number ownership to carriers | SHAKEN/STIR | A-level attestation reduces spam flags |
| Remove spam/scam labels | Voice Integrity | Carrier-side remediation (T-Mobile, AT&T, Verizon) |
| Caller name on landlines | CNAM | Traditional caller ID database registration |
| Maximize answer rates (comprehensive) | All of the above | Each layer addresses a different trust signal |

---

## Decision Frameworks

### Which Product(s) Do You Need?

The call trust stack is layered — each product builds on the one below it. You can stop at any layer.

```
Layer 4: Enhanced Branded Calling  (name + logo + call reason)
         ↑ requires
Layer 3: Basic Branded Calling     (business name display)
         ↑ requires
Layer 2: Voice Integrity           (spam label remediation)
         ↑ requires
Layer 1: SHAKEN/STIR               (attestation + Business Profile)
         ↑ requires
Layer 0: Primary Customer Profile  (Trust Hub business identity)
```

| Starting point | What you already have | What to set up |
|---------------|----------------------|----------------|
| New Twilio account | Nothing | Start at Layer 0, work up |
| Existing account with Business Profile | Layer 0 | Add SHAKEN/STIR (Layer 1), then higher |
| Getting spam-flagged | Layers 0-1 maybe | Add Voice Integrity (Layer 2) |
| Want name display | Layers 0-2 | Add Basic Branded Calling (Layer 3) |
| Want rich display with logo | Layers 0-3 | Add Enhanced Branded Calling (Layer 4) |

### Basic vs Enhanced Branded Calling

| Factor | Basic | Enhanced |
|--------|-------|----------|
| **Display** | Business name (text) | Business name + logo + call reason |
| **Carrier support** | T-Mobile (native), growing | T-Mobile (native), Apple/iOS (limited) |
| **Prerequisites** | Business Profile, SHAKEN/STIR, LOA | Everything in Basic + Voice Integrity |
| **Logo requirements** | N/A | Square, min 300x300px, max 1MB, PNG/JPG |
| **Call reason** | N/A | Free-text field (~40 char carrier display limit), reviewed during approval |
| **Setup complexity** | Moderate | High (more prerequisites, longer review) |
| **Approval timeline** | Typically 2-4 weeks | Typically 3-6 weeks |
| **Console setup** | Yes (guided wizard) | Yes (guided wizard) |
| **API setup** | Trust Hub API | Trust Hub API |

### When to Use Console vs API

| Scenario | Use | Why |
|----------|-----|-----|
| First-time setup, <5 numbers | Console | Guided wizard, visual status tracking |
| Programmatic provisioning, >5 numbers | Trust Hub API | Scriptable, repeatable, auditable |
| Checking approval status | Console or API | Console is visual; API gives exact `status` field |
| Adding numbers to existing trust product | API | Faster than navigating Console for each number |

---

## Prerequisite Chain (Setup Order)

### Step 1: Primary Customer Profile (Layer 0)

Every trust product requires an approved Primary Customer Profile in Trust Hub. This proves your business identity.

**Required information:**
- Business name, type, registration number (EIN for US businesses)
- Business address (documented separately)
- Authorized representative (name, email, phone, title)
- Website URL
- Industry classification

**Key fields** (from policy `RN6433641899984f951173ef1738c3bdd0`):
- `business_type`, `business_registration_number`, `business_name`
- `business_registration_identifier`, `business_identity`, `business_industry`
- `website_url`, `business_regions_of_operation`
- `social_media_profile_urls`
- Authorized representatives (up to 2): `first_name`, `last_name`, `email`, `phone_number`, `business_title`, `job_position`

**Status lifecycle**: `draft` → `pending-review` → `in-review` → `twilio-approved` (or `twilio-rejected`)

**Timeline**: Typically 1-3 business days for review.

### Step 2: SHAKEN/STIR (Layer 1)

SHAKEN/STIR is **automatically applied** to all approved Primary Customer Profiles. There is no separate Trust Product to create.

Once your Primary Customer Profile is approved:
- Outbound calls from your Twilio numbers receive **A-level attestation** (highest)
- The recipient's carrier sees a cryptographic signature proving number ownership
- This reduces spam/scam flag probability

**Attestation levels** (received on inbound webhook as `StirVerstat`; standard values — exact format may vary by carrier):
- `TN-Validation-Passed-A` — Full attestation: caller has right to use the number
- `TN-Validation-Passed-B` — Partial: caller is authenticated but number isn't verified
- `TN-Validation-Passed-C` — Gateway: call entered network but caller isn't verified
- `TN-Validation-Failed` — Signature verification failed
- `No-TN-Validation` — No SHAKEN/STIR information present

**Webhook parameters for inbound calls** (present when originating carrier provides SHAKEN/STIR information):
- `StirVerstat` — Attestation result (values above)
- `StirPassportToken` — The raw SHAKEN passport (JWT)
- `CallToken` — Twilio's authentication token for the call

### Step 3: Voice Integrity (Layer 2)

Voice Integrity registers your numbers with carrier spam databases to **remediate existing spam labels** and **prevent future mislabeling**.

**Setup**: Done through Twilio Console (Trust Hub → Voice Integrity). Requires an approved Primary Customer Profile.

**Carrier coverage:**
- T-Mobile — Direct registration
- AT&T — Direct registration
- Verizon — Direct registration

**Timeline**: Registration propagation typically takes 3-7 business days per carrier after Trust Product approval.

**API access**: Voice Integrity trust products are visible in the Trust Products API (`GET /v1/TrustProducts/{sid}`) for approval status. However, carrier-side registration propagation status is not available via API — monitor via Console.

### Step 4: Basic Branded Calling (Layer 3)

**Required Trust Hub policy fields** (from live API, policy `RNec5c6f3b750ed0d117c1951b5d5ce8c1`):

| Category | Fields |
|----------|--------|
| Brand info | `branded_calls_display_name` |
| Auth representative | `first_name`, `last_name`, `email`, `phone_number`, `job_position` |
| Authorized contact | `first_name`, `last_name`, `verification_email`, `mobile_phone_number` |
| Business | `business_name`, `trade_name`, `business_type`, `business_identity`, `business_registration_number`, `business_registration_identifier`, `business_industry`, `business_website`, `is_subassigned`, `privacy_notice_url`, `business_employee_count` |
| Use case | `category`, `use_case_description`, `consent_description`, `call_volume_daily` |
| Documents | Business address, Letter of Authorization (LOA) |

**Display name rules:**
- Must match or be a recognizable trade name of the registered business
- Carrier display limits vary; T-Mobile supports ~32 characters. Keep names concise.
- No phone numbers, URLs, or special characters in the display name
- Reviewed during approval — misleading names are rejected

### Step 5: Enhanced Branded Calling (Layer 4)

**Additional fields beyond Basic** (from live API, policy `RNca63d1066fbd5e44eac02d0b3cf6d019`):

| Field | Description |
|-------|-------------|
| `branded_calls_long_display_name` | Extended business name |
| `branded_calls_call_purpose_code` | Category code for the call purpose |
| `branded_calls_call_reason` | Free-text call reason displayed on screen (carrier display limit ~40 chars) |
| `branded_calls_logo_name` | Logo identifier (uploaded separately) |

**Prerequisite Trust Product**: Requires an approved **Voice Integrity** trust product (`voice_integrity_trust_product` type).

**Logo requirements:**
- Square aspect ratio
- Minimum 300x300 pixels
- Maximum file size: 1MB
- Formats: PNG, JPG
- No text overlays — logo only
- Reviewed for brand consistency during approval

---

## CNAM (Caller Name)

CNAM is the traditional caller ID system — a 15-character name stored in a national database and displayed on the recipient's phone (primarily landlines and some mobile carriers).

**Key differences from Branded Calling:**
- **15-character limit** (vs 32 for Branded Calling display name)
- **No logo or call reason** — text name only
- **Works on landlines** — Branded Calling is mobile-focused
- **Update propagation**: Typically 24-48 hours after registration (carrier database sync)
- **No approval process** — set via Console or API, propagates automatically

**Setup**: Configure via Twilio Console on individual phone numbers (Phone Numbers → Manage → select number → CNAM).

---

## Observability & ROI Measurement

### Prerequisites: Voice Insights Advanced Features

Advanced Features must be enabled to access phone number reports and branded calling metrics. This incurs **per-minute billing** (rounds up to the next minute) on all voice calls.

```
mcp__twilio__get_insights_settings()       → check current state
mcp__twilio__update_insights_settings({ advancedFeatures: true })  → enable (billing starts)
```

Each subaccount has independent settings — enabling on the parent does NOT cascade.

### Per-Call Diagnostics (Call Summary API)

For investigating individual calls:

| Field | Location | Description |
|-------|----------|-------------|
| `stir_verstat` | Call Summary | SHAKEN/STIR attestation level |
| `caller_name` | `properties` object | CNAM name registered for the number |

**MCP tools:**
- `mcp__twilio__get_call_summary` — SHAKEN/STIR and trust fields for one call
- `mcp__twilio__validate_call` — Deep validation including trust indicators
- `mcp__twilio__list_call_summaries` — Filter calls by direction, state, time range

### Fleet-Level Metrics (Phone Number Reports API)

For measuring branded calling ROI at scale, use the Reports API. This is **async**: POST to create a report, GET to retrieve results.

**Outbound report fields** (live-verified, 2026-03-28):
- `call_answer_score` — % of calls answered. **Primary ROI metric.**
- `blocked_calls_by_carrier` — Per-carrier (att, tmobile, verizon) block rates
- `potential_robocalls_percentage` — % flagged as potential robocalls
- `answering_machine_detection` — Human vs machine answer rates
- `call_state_percentage` — Breakdown: completed, busy, canceled, fail, noanswer

**Branded calling specific fields** (doc-sourced, visible when branded calling is active):
- `branded_calling.total_branded_calls`, `branded_calling.answer_rate`
- `voice_integrity.enabled_calls`, `voice_integrity.answer_rate`
- `stir_shaken` — Attestation metrics with answer rates

**ROI measurement approach:**
1. Pull outbound reports for 30 days before and after branded calling activation
2. Compare `call_answer_score` and `blocked_calls_percentage` per number
3. Identify outlier numbers: answer rate <40% with >100 calls = likely spam-flagged

See [references/reports-api-guide.md](references/reports-api-guide.md) for complete API patterns, curl examples, and a monthly health check script.

**MCP tool gap**: The `get_outbound_number_report` and `get_inbound_number_report` MCP tools use GET (incorrect). The API requires POST to create + GET by report_id (async). Use direct curl until the tools are updated.

---

## Trust Hub API Reference

All Branded Calling setup is managed through the Trust Hub API (`trusthub.twilio.com/v1/`).

### Key Endpoints

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Create Trust Product | POST | `/v1/TrustProducts` |
| List Trust Products | GET | `/v1/TrustProducts` |
| Get Trust Product | GET | `/v1/TrustProducts/{sid}` |
| Update Trust Product | POST | `/v1/TrustProducts/{sid}` |
| Submit for review | POST | `/v1/TrustProducts/{sid}/Evaluations` |
| Create Customer Profile | POST | `/v1/CustomerProfiles` |
| Create End User | POST | `/v1/EndUsers` |
| Create Supporting Document | POST | `/v1/SupportingDocuments` |
| Assign entity to Trust Product | POST | `/v1/TrustProducts/{sid}/EntityAssignments` |
| Assign phone number | POST | `/v1/TrustProducts/{sid}/ChannelEndpointAssignments` |

### Status Values (Trust Products and Customer Profiles)

| Status | Meaning |
|--------|---------|
| `draft` | Created but not submitted |
| `pending-review` | Submitted, awaiting Twilio review |
| `in-review` | Actively being reviewed |
| `twilio-approved` | Approved by Twilio |
| `twilio-rejected` | Rejected (check `failure_reason`) |

### Branded Calling Policy SIDs (from live API)

Multiple policy SIDs exist for Branded Calling. The policy determines which fields are required:

| Policy SID | Type | Key differentiator |
|------------|------|-------------------|
| `RNec5c6f3b750ed0d117c1951b5d5ce8c1` | Basic | `branded_calls_display_name` only |
| `RNa5150dedb5f110adba478ce9dde61d56` | Basic | Same fields, different policy version |
| `RN5db7f1c57f6157280b28428ede4db708` | Basic | Same fields, different policy version |
| `RN304faa2408f673b68867fe5cb65b7f50` | Basic | Same fields, different policy version |
| `RNa0b74679be7511921f4d2e3094fa6d23` | Enhanced (v1) | Adds `branded_calls_call_reason`, `branded_calls_logo_url`, `category_apple` |
| `RNca63d1066fbd5e44eac02d0b3cf6d019` | Enhanced (v2) | Adds `branded_calls_long_display_name`, `branded_calls_call_purpose_code`, `branded_calls_logo_name`; requires Voice Integrity |
| `RN5e3462f05c241bc1d0f3aca861c5c628` | Basic (page 1) | Earliest policy version |

Use the Console wizard to auto-select the correct policy, or reference the policy SID directly when using the API.

---

## Gotchas

### Setup

1. **Primary Customer Profile is the foundation for everything**: You cannot create any Branded Calling trust product without an approved Primary Customer Profile. This takes 1-3 business days to review. Start here before anything else.

2. **SHAKEN/STIR is automatic, not a separate product**: Once your Primary Customer Profile is approved, SHAKEN/STIR A-level attestation is automatically applied to outbound calls. There is no separate trust product to create or manage.

3. **Voice Integrity is required for Enhanced but not Basic**: Enhanced Branded Calling policy `RNca63d...` explicitly requires a `voice_integrity_trust_product`. Basic has no such prerequisite. If you skip Voice Integrity and try to set up Enhanced, the trust product evaluation will fail.

4. **LOA is required for all Branded Calling tiers**: Both Basic and Enhanced require a Letter of Authorization document. This is a signed document proving your business is authorized to use the phone numbers. Without it, the trust product submission will be rejected.

5. **Multiple policy SIDs exist for the same tier**: The Trust Hub API returns 7+ policy SIDs all named "Branded Calling." They have different field requirements. Use the Console wizard or check the policy's `requirements` field to find the correct one.

### Configuration

6. **Display name length varies by carrier**: The Trust Hub API may accept longer names, but carriers truncate differently. T-Mobile supports ~32 characters. Keep display names concise to ensure consistent display.

7. **Display name must match registered business**: Twilio reviews the display name against the business name in your Customer Profile. Trade names and DBAs are acceptable if documented.

8. **Logo must be square with no text**: Enhanced Branded Calling logos are rejected if they have text overlays, non-square aspect ratios, or are below 300x300px. The logo should be a clean icon or brand mark.

9. **Call reason display limited to ~40 characters**: The `branded_calls_call_reason` field (Enhanced) is displayed to the recipient. The API field may accept longer strings, but carrier displays truncate around 40 characters. Keep it concise and accurate — misleading reasons are rejected during review.

10. **CNAM is limited to 15 characters**: The CNAM database predates modern caller ID. Names are truncated at 15 characters. Use abbreviations strategically.

### Runtime

11. **Branded display is not guaranteed**: Even with an approved trust product, the recipient's phone may not show the branded information. Display depends on: carrier support, device OS, phone app, and whether the recipient has opted into branded caller ID services.

12. **No per-call branding control**: Once a number is assigned to a Branded Calling trust product, all outbound calls from that number display the brand. You cannot selectively brand some calls and not others from the same number.

13. **Toll-free numbers are not eligible**: Branded Calling works with local and mobile numbers only. Toll-free numbers have their own trust framework (toll-free verification).

14. **SIP Trunk calls bypass branding**: Calls originating through SIP Trunking do not receive Branded Calling treatment. Only calls made via the Calls API or TwiML-driven flows are branded.

### Observability

15. **Voice Insights is the primary diagnostic tool**: Use `mcp__twilio__get_call_summary` or `mcp__twilio__validate_call` to check `stir_verstat` and branded status for a specific call.

16. **Voice Integrity carrier propagation is not API-visible**: The Trust Product approval status is available via `GET /v1/TrustProducts/{sid}`, but carrier-side registration propagation status is not. Monitor carrier propagation via the Twilio Console.

17. **CNAM propagation takes 24-48 hours**: After setting CNAM on a number, changes take 24-48 hours to propagate through the national caller ID database. Testing immediately after setting will show stale data.

### Approval & Timing

18. **Approval timelines are business days, not calendar days**: Basic Branded Calling typically takes 2-4 weeks. Enhanced typically takes 3-6 weeks. Plan accordingly for launch dates.

19. **Rejection reasons are in the Trust Product status**: If a trust product is rejected, the `failure_reason` field on the Trust Product resource explains why. Common reasons: mismatched business name, missing LOA, invalid logo format.

20. **Phone numbers can only be in one Branded Calling trust product at a time**: You must remove a number from one trust product before assigning it to another. The removal may take time to propagate.

21. **Carrier registration is separate from Twilio approval**: Twilio approving your trust product is step 1. Carrier-side registration (T-Mobile, AT&T, Verizon) is step 2 and happens automatically but adds additional days.

### Observability

22. **Advanced Features must be enabled for Reports API**: The Phone Number Reports API requires Voice Insights Advanced Features (`mcp__twilio__update_insights_settings`). This incurs per-minute billing that rounds up. Enable it for analysis windows, disable when done if cost-sensitive.

23. **Reports API is async (POST then GET)**: The Phone Number Reports API does not return data synchronously. POST creates a report job (returns `report_id` immediately), then GET the report by ID after a few seconds. The MCP tools `get_outbound_number_report` and `get_inbound_number_report` incorrectly use GET — use direct curl until fixed.

24. **Account Report endpoint is not accessible via API**: The `/v2/Voice/Reports/Account` endpoint returned 404 (GET) and 405 (POST) with both API key and auth token auth during testing (2026-03-28). Aggregate account metrics by combining phone number reports instead.

25. **Branded calling report fields only appear when branded calling is active**: The `branded_calling.*`, `voice_integrity.*`, and `stir_shaken` report fields are doc-sourced but not visible on accounts without active branded calling. They should appear once a Trust Product is approved and calls are flowing.

26. **30-day windows for meaningful ROI comparison**: Branded calling ROI requires sufficient call volume per number. Compare 30-day windows before/after activation with at least ~1000 calls per cohort for statistical significance.

---

## Related Resources

- [Voice Skill](/skills/voice/SKILL.md) — Core voice development, TwiML, Calls API
- [Phone Numbers Skill](/skills/phone-numbers/SKILL.md) — Number purchase, webhook config, capabilities
- [Voice Insights Skill](/skills/voice-insights/SKILL.md) — Call diagnostics, quality metrics, SHAKEN/STIR fields
- [Voice Use Case Map](/skills/voice-use-case-map/SKILL.md) — Product selection by use case
- [Compliance Skill](/skills/compliance-regulatory.md) — Regulatory framework, A2P 10DLC, toll-free verification
- MCP tools: `mcp__twilio__get_call_summary`, `mcp__twilio__validate_call`, `mcp__twilio__list_call_summaries`, `mcp__twilio__get_insights_settings`, `mcp__twilio__update_insights_settings`, `mcp__twilio__list_phone_numbers`

---

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Setup walkthrough | [references/setup-guide.md](references/setup-guide.md) | Step-by-step API setup for Basic and Enhanced Branded Calling |
| Trust Hub API patterns | [references/trusthub-api-patterns.md](references/trusthub-api-patterns.md) | API code examples for Trust Products, Customer Profiles, End Users |
| Carrier support matrix | [references/carrier-support.md](references/carrier-support.md) | Which carriers display what, device/OS compatibility |
| Reports API & ROI | [references/reports-api-guide.md](references/reports-api-guide.md) | Voice Insights Settings, Phone Number Reports, ROI measurement, outlier detection |
