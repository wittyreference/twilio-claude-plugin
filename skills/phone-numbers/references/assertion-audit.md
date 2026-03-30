---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the Twilio Phone Numbers skill. -->
<!-- ABOUTME: Every factual claim verified via live testing or Twilio docs. Evidence: 2026-03-25. -->

# Assertion Audit Log

**Skill**: phone-numbers
**Audit date**: 2026-03-25
**Account**: ACb4de2...
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 28 |
| CORRECTED | 0 |
| QUALIFIED | 1 |
| REMOVED | 0 |
| **Total** | **29** |

## Assertions

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 1 | Search available numbers by country, area code, capabilities | behavioral | CONFIRMED | Search areaCode=206 returned 3 Seattle numbers | |
| 2 | Purchase local and toll-free via API | behavioral | CONFIRMED | PNa869b36b purchased toll-free +18889156018 | |
| 3 | Configure voice/SMS webhook URLs | behavioral | CONFIRMED | PN32313fb8 updated voiceUrl and smsUrl | |
| 4 | Filter owned numbers by phoneNumber | behavioral | CONFIRMED | Filter +12069666002 returned 1 result, SID PNfd5828a6 | |
| 5 | Filter owned numbers by friendlyName | behavioral | CONFIRMED | Filter "Payment Agent" returned 1 result | |
| 6 | Geographic proximity search US/Canada | behavioral | CONFIRMED | nearNumber +12069666002, distance 10mi returned Kent WA numbers | |
| 7 | Vanity letter patterns work in contains | behavioral | CONFIRMED | "TEST" returned 2 results | |
| 8 | Release returns number to pool | behavioral | CONFIRMED | PNa869b36b remove() returned true, fetch → 404 | |
| 9 | Clear webhooks with empty string | behavioral | CONFIRMED | voiceUrl="" and smsUrl="" accepted | |
| 10 | No mobile type in US | scope | CONFIRMED | US/Mobile.json → 20404 | |
| 11 | voiceApplicationSid and voiceUrl mutually exclusive | architectural | CONFIRMED | Twilio docs + non-existent AP SID → 400 | |
| 12 | trunkSid and voiceApplicationSid mutually exclusive | architectural | CONFIRMED | Twilio docs: "Setting voiceApplicationSid auto-deletes trunkSid" | |
| 13 | contains requires min 2 characters | behavioral | CONFIRMED | "5" → 400 "Invalid Pattern"; "55" → OK | |
| 14 | contains wildcards mid-pattern fail | behavioral | CONFIRMED | "206*55*" → 400 "Invalid Pattern" | |
| 15 | Geographic search US/Canada only | scope | CONFIRMED | Twilio docs: "Available for only phone numbers from the US and Canada" | |
| 16 | areaCode filter US/Canada only | scope | CONFIRMED | Twilio docs: "Applies to only phone numbers in the US and Canada" | |
| 17 | No undo for release | scope | CONFIRMED | PNa869b36b → 404 after release, no reclaim API exists | |
| 18 | UK requires local address | behavioral | CONFIRMED | GB search: addressRequirements="local" | |
| 19 | Capabilities keys inconsistent casing | behavioral | CONFIRMED | Available: MMS/SMS uppercase; Owned: mms/sms lowercase | |
| 20 | Invalid webhook URL returns 21402 | error | CONFIRMED | "not-a-url" → 21402 "VoiceUrl is not valid" | |
| 21 | Purchase sets status in-use immediately | behavioral | CONFIRMED | PNa869b36b status="in-use" on create response | |
| 22 | SID format is PN-prefixed | behavioral | CONFIRMED | All SIDs confirmed PN + 32 hex chars | |
| 23 | Toll-free search works | behavioral | CONFIRMED | US toll-free returned 3 numbers, capabilities voice+sms+mms+fax | |
| 24 | Toll-free addressRequirements is none | behavioral | CONFIRMED | Toll-free search: addressRequirements="none" | |
| 25 | +1 prefix works in contains | behavioral | CONFIRMED | "+1206" returned matching numbers | |
| 26 | Non-existent PN SID returns 20404 | error | CONFIRMED | PNfff... → 20404 | |
| 27 | friendlyName max 64 chars | default | QUALIFIED | Twilio docs state 64 chars; not boundary-tested | Qualified: doc-sourced, not live-tested at boundary |
| 28 | contains pattern supports letters for vanity | behavioral | CONFIRMED | "TEST" returned results (maps to DTMF 8378) | |
| 29 | Purchase not in serverless functions (by design) | architectural | CONFIRMED | functions/phone-numbers/CLAUDE.md: "intentionally not included" | |

## Qualifications Applied

- **#27 — friendlyName max 64 chars**: Twilio docs state 64-character limit. Not live-tested at the 64/65 boundary because exceeding it would require creating and then cleaning up a number. Trusting docs on this one.
