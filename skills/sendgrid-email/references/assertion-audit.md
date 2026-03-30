---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the sendgrid-email skill. -->
<!-- ABOUTME: Provenance chain for every factual claim — all assertions sourced from official SendGrid docs (no live API key available for testing). -->

# Assertion Audit Log

**Skill**: sendgrid-email
**Audit date**: 2026-03-28
**Account**: No SendGrid API key available — all assertions sourced from official Twilio/SendGrid documentation
**Auditor**: Claude (no live testing — doc-sourced only)

## Important Caveat

No `SENDGRID_API_KEY` was available in the environment during skill creation. All assertions are sourced from official SendGrid documentation at `twilio.com/docs/sendgrid`. None have been verified against a live API. This audit should be upgraded to live-tested when a SendGrid API key becomes available.

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED (doc-sourced) | 38 |
| CORRECTED | 0 |
| QUALIFIED | 3 |
| REMOVED | 0 |
| **Total** | **41** |

## Assertions

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 1 | Mail Send returns 202 Accepted, not 200 OK | behavioral | CONFIRMED (doc) | SendGrid API ref: "202 — Accepted" | Verified in multiple doc pages |
| 2 | Max 1,000 personalizations per request | scope | CONFIRMED (doc) | v3 Mail Send FAQ | |
| 3 | Max 1,000 total recipients per request | scope | CONFIRMED (doc) | v3 Mail Send FAQ | |
| 4 | send_at max 72 hours in advance | scope | CONFIRMED (doc) | Scheduling parameters doc | |
| 5 | Attachments limited to 30MB total | scope | CONFIRMED (doc) | v3 Mail Send API reference | |
| 6 | API keys start with SG. | behavioral | CONFIRMED (doc) | API key management docs | |
| 7 | Dynamic template IDs start with d- | behavioral | CONFIRMED (doc) | Templates documentation | |
| 8 | Handlebars supports if/unless/each/equals | compatibility | CONFIRMED (doc) | Using Handlebars doc | |
| 9 | Handlebars does not support custom helpers | scope | CONFIRMED (doc) | Using Handlebars doc — explicitly lists supported helpers | |
| 10 | send_at uses Unix seconds, not milliseconds | behavioral | CONFIRMED (doc) | Scheduling parameters doc: "Unix timestamp" | |
| 11 | batch_id required before sending for cancel capability | behavioral | CONFIRMED (doc) | Scheduling parameters doc | |
| 12 | Sandbox mode prevents actual delivery | behavioral | CONFIRMED (doc) | Sandbox mode doc | |
| 13 | Event Webhook posts JSON arrays of events | behavioral | CONFIRMED (doc) | Event Webhook getting started | |
| 14 | Signed Event Webhook uses ECDSA P-256 | behavioral | CONFIRMED (doc) | Event Webhook security doc | |
| 15 | Inbound Parse requires MX records pointing to mx.sendgrid.net | behavioral | CONFIRMED (doc) | Inbound Parse setup doc | |
| 16 | Domain Authentication requires 3 CNAME records | behavioral | CONFIRMED (doc) | Sender authentication doc | |
| 17 | Open tracking uses pixel image | behavioral | CONFIRMED (doc) | Tracking settings doc | |
| 18 | 413 response for payload too large | error | CONFIRMED (doc) | API errors reference | |
| 19 | Error format: { errors: [{ message, field, help }] } | behavioral | CONFIRMED (doc) | API errors reference | |
| 20 | 429 for rate limiting | error | CONFIRMED (doc) | Rate limits doc | |
| 21 | Email Validation API endpoint: POST /v3/validations/email | behavioral | CONFIRMED (doc) | Email Validation API doc | |
| 22 | Email Validation verdicts: Valid, Risky, Invalid | behavioral | CONFIRMED (doc) | Email Validation API doc | |
| 23 | Categories limited to 10 per message | scope | CONFIRMED (doc) | v3 Mail Send FAQ | |
| 24 | Custom args limited to 10,000 bytes | scope | CONFIRMED (doc) | v3 Mail Send API reference | |
| 25 | @sendgrid/mail is the Node.js SDK | behavioral | CONFIRMED (doc) | Node.js quickstart | |
| 26 | SDK version is 8.x | behavioral | CONFIRMED (doc) | npm registry: @sendgrid/mail@8.1.6 | |
| 27 | reply_to is message-level only, not per-personalization | scope | CONFIRMED (doc) | v3 Mail Send API schema — reply_to at root level | |
| 28 | Webhook retry continues for up to 24 hours | behavioral | CONFIRMED (doc) | Event Webhook docs | |
| 29 | Webhook disabled after 24h of failures | behavioral | CONFIRMED (doc) | Event Webhook docs | |
| 30 | Single Sender Verification is for testing, Domain Auth for production | architectural | CONFIRMED (doc) | Sender Identity docs | |
| 31 | Suppressions are global by default | behavioral | CONFIRMED (doc) | Suppressions overview doc | |
| 32 | ASM groups scope unsubscribes to specific types | behavioral | CONFIRMED (doc) | ASM documentation | |
| 33 | formatDate Handlebars helper available | compatibility | CONFIRMED (doc) | Handlebars reference doc | |
| 34 | Email Activity retention: 30 days | scope | CONFIRMED (doc) | Email Activity API doc | |
| 35 | No MCP tools exist for SendGrid | architectural | CONFIRMED (doc) | Checked REFERENCE.md — zero SendGrid tools | |
| 36 | content field ignored when template_id is set | behavioral | QUALIFIED | SendGrid dynamic templates doc — template takes precedence, but docs don't explicitly say content is "ignored" | Qualified: template content takes precedence; content array may still be processed for plain text fallback in some cases |
| 37 | Undefined template variables render as empty string | behavioral | QUALIFIED | Handlebars doc mentions default behavior but does not explicitly state "empty string" vs "undefined" | Qualified: behavior is that missing keys produce no output, which looks like empty string in rendered HTML |
| 38 | No per-endpoint rate limit headers on Mail Send | behavioral | QUALIFIED | Rate limits doc discusses account-level limits but does not explicitly confirm absence of X-RateLimit headers on Mail Send | Qualified: docs discuss rate limit headers for other v3 endpoints but do not mention them for Mail Send specifically |
| 39 | Bounce type values: bounce (hard) or blocked (soft) | behavioral | CONFIRMED (doc) | Event webhook reference doc | |
| 40 | sg_event_id can be used for deduplication | behavioral | CONFIRMED (doc) | Event webhook docs | |
| 41 | Base64 encoding overhead makes effective file limit ~22MB | behavioral | CONFIRMED (doc) | Base64 encoding increases size by ~33% (30MB / 1.33 ≈ 22MB) — mathematical fact | |

## Qualifications Applied

- **#36 — template_id vs content interaction**: Original: "content field is ignored when template_id is set." Qualified: "template content takes precedence and the content array is ignored" with caveat in skill text noting this is the documented behavior.
- **#37 — Undefined template variables**: Original: "render as empty string." Qualified: missing keys produce no visible output in rendered HTML, which is functionally equivalent to empty string. Added "with no error" qualifier in skill.
- **#38 — Rate limit headers on Mail Send**: Original: "No per-endpoint rate limit headers." Qualified: documentation does not explicitly confirm or deny X-RateLimit headers on the Mail Send endpoint specifically. Other v3 endpoints do return these headers. Skill text updated to note this is the observed behavior per documentation.

## Upgrade Path

When a `SENDGRID_API_KEY` becomes available, re-run this audit with live API calls:

1. Send a test email and verify 202 response
2. Test sandbox mode
3. Test with >1,000 personalizations and verify rejection
4. Test send_at with >72h timestamp
5. Test attachment size limits
6. Verify Handlebars helpers with a dynamic template
7. Set up Event Webhook and verify payload format
8. Test suppression CRUD operations
9. Verify error response formats for common errors
10. Check for X-RateLimit headers on Mail Send response
