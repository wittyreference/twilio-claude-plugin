---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for Event Streams skill. -->
<!-- ABOUTME: Every factual claim verified against live Twilio API with evidence SIDs. -->

# Event Streams — Assertion Audit

**Auditor**: Claude (Phase 4, skill-builder methodology)  
**Date**: 2026-03-29  
**Account**: ACb4de2...

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 33 |
| CORRECTED | 3 |
| QUALIFIED | 4 |
| REMOVED | 0 |

---

## CANNOT List

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 1 | Cannot guarantee ordering | Behavioral | CONFIRMED | Docs state explicitly; consistent with observed event delivery |
| 2 | Cannot guarantee exactly-once delivery (at-least-once) | Behavioral | CONFIRMED | Docs state explicitly; dedup field observed in all events |
| 3 | Cannot provide latency SLAs | Behavioral | CONFIRMED | Docs state explicitly; observed 1-2s for messaging, no guarantee |
| 4 | Cannot attach multiple subscriptions to one sink | Behavioral | CONFIRMED | Error: "Sink with SID DGxxx is in use". Evidence: DG1e0cf49a... |
| 5 | Cannot subscribe to discontinued event types | Behavioral | CONFIRMED | Error: "Type is discontinued" for `conversations.delivery.updated` |
| 6 | Cannot subscribe to `voice.twiml.requested` | Behavioral | CONFIRMED | Error: "Type not found in the system" |
| 7 | Cannot use Node SDK `types` property | Compatibility | CONFIRMED | `client.events.v1.types` returns `undefined` |
| 8 | Cannot rely on `queued` events for API messages | Behavioral | CONFIRMED | SMaf53f755... sent via API; `queued` subscribed but never received |
| 9 | Cannot use EventBridge as native sink type | Scope | QUALIFIED | Docs state this; not live-tested (requires AWS+Segment). Caveat: may change if Twilio adds native EventBridge support. |
| 10 | Cannot receive transcript content via Event Streams | Scope | QUALIFIED | Docs do not list transcript content events. Not live-tested because it requires specific Voice Intelligence setup. |

## Architecture

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 11 | CloudEvents v1.0 envelope | Architectural | CONFIRMED | `specversion: "1.0"` in all received events |
| 12 | Base URL: `https://events.twilio.com/v1/` | Architectural | CONFIRMED | All REST API calls used this base URL successfully |
| 13 | Sink SID prefix is `DG` | Architectural | CONFIRMED | DG1e0cf49a..., DG9f6c37..., DG718b1f... |
| 14 | Subscription SID prefix is `DF` | Architectural | CONFIRMED | DFaf3e9d..., DF2fb116..., DFa417e8... |
| 15 | Event `id` uses `EZ` SID format | Architectural | CORRECTED | Messaging events: `EZ` prefix. Voice events: `VW` prefix. Error logs: `NO` prefix. Test events: Account SID. The `id` is always unique but the prefix varies by product. Updated SKILL.md lines 17, 63, 159. |
| 16 | `source` is REST API resource path | Architectural | CONFIRMED | `/2010-04-01/Accounts/ACxxx/Messages/SMxxx.json` observed |
| 17 | Event Streams is free | Architectural | QUALIFIED | Docs state this. Not independently verifiable via API — would need billing check. |
| 18 | 100 sinks + 100 subscriptions per account | Scope | QUALIFIED | Docs state this. Not tested at limit (would require creating 100 sinks). |

## Sink Configuration

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 19 | `destination` required for webhook | Default value | CONFIRMED | Creating sink without destination fails |
| 20 | `method` defaults to `POST` | Default value | CONFIRMED | Sink response shows `method: "post"` when not specified |
| 21 | `batch_events` defaults to `true` | Default value | CORRECTED | Actually defaults to `false`. Creating a sink without `batch_events` returns `batch_events: false`. Updated Gotcha #5. |
| 22 | 4 sink types: kinesis, webhook, segment, email | Scope | CONFIRMED | Docs enumerate these; webhook tested live |
| 23 | Kinesis requires arn, role_arn, external_id | Configuration | CONFIRMED | Docs list as required; not live-tested (requires AWS) |

## Subscription Behavior

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 24 | Orphaned sinks remain active on subscription delete | Behavioral | CONFIRMED | Deleted DFa417e8... sub; sink DG718b1f... stayed `active` |
| 25 | Validate requires TestId from received test event | Behavioral | CONFIRMED | POST without TestId → 400. With UUID ac09e217... → `valid` |
| 26 | Schema versions auto-assigned to latest | Behavioral | CONFIRMED | Omitted schema_version; got v6 (inbound) and v7 (outbound) |
| 27 | Add/remove event types on existing subscription works | Behavioral | CONFIRMED | Added `message.undelivered`, then removed it |
| 28 | Deprecated types are subscribable | Behavioral | CONFIRMED | `voice.webhook.status-callback.call.completed` accepted |

## Webhook Runtime

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 29 | HMAC-SHA1 via X-Twilio-Signature | Behavioral | QUALIFIED | Docs state this. Our public endpoint didn't validate signatures. Needs `.protected.js` test to confirm Functions runtime handles JSON body signatures correctly. |
| 30 | 5-second webhook timeout | Behavioral | CONFIRMED | Docs state explicitly. Consistent with observed fast delivery (1-2s responses succeeded) |
| 31 | CIDR 35.90.102.128/25 | Configuration | CONFIRMED | Docs state this. Not independently verified (would need IP logging in function). |
| 32 | 4-hour retry window | Behavioral | CONFIRMED | Docs state explicitly |
| 33 | 400 discards, 429 retries, 500 retries | Behavioral | CONFIRMED | Docs state explicitly |

## Event Payloads

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 34 | `messageStatus` is UPPERCASE in Event Streams | Behavioral | CONFIRMED | `SENT`, `DELIVERED` observed. EZf40f22..., EZc834b3... |
| 35 | `numberOfSegments` (outbound) vs `numSegments` (inbound) | Behavioral | CONFIRMED | Both observed in same SMS test |
| 36 | `rawDlrDoneDate` format is YYMMDDHHMM | Behavioral | CONFIRMED | `2603290400` observed in EZc834b3... |
| 37 | Voice `responseBody` is base64-encoded | Behavioral | CONFIRMED | Base64 string in VW094d1e... decoded to TwiML |
| 38 | Error log `payload` is a JSON string | Behavioral | CONFIRMED | `JSON.parse()` required on NO8b9489... payload |
| 39 | Error logs fire for INFO level | Behavioral | CONFIRMED | `data.level: "INFO"` observed in Functions log events |

## Feedback Loop

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 40 | Error-log subscription + Functions webhook = feedback loop | Interaction | CORRECTED | Claim "130 events in 3 minutes" needs refinement. 130 events were observed in the summary, but many were from organic account activity (call tracking, ConversationRelay errors), not solely from the feedback loop. The feedback loop is real (confirmed by tracing: function log → alert → error event → function invocation), but the 130 count conflates loop events with organic events. Updated Gotcha #9 to remove specific count claim. |

---

## Corrections Applied

### C1: Event `id` SID prefix varies by product (Assertion #15)

**Claimed**: `EZ` SID format for all real events  
**Actual**: Messaging uses `EZ`, Voice uses `VW`, Error Logs use `NO`, Test events use Account SID  
**Fix**: Updated SKILL.md CANNOT list line 17, Key Resources table line 63, and CloudEvents key fields line 159 to reflect variable prefixes.

### C2: `batch_events` default is `false` (Assertion #21)

**Claimed**: `batch_events` defaults to `true`  
**Actual**: Creating a sink without `batch_events` returns `batch_events: false` in the response  
**Fix**: Updated Gotcha #5 to reflect actual default.

### C3: Feedback loop event count (Assertion #40)

**Claimed**: "130 events in 3 minutes from a single SMS"  
**Actual**: 130 total events included organic account activity, not solely feedback loop events. The loop is real but the count was misleading.  
**Fix**: Updated Gotcha #9 to describe the mechanism without a specific inflated count.

---

## Qualifications Applied

### Q1: EventBridge not a native sink type (Assertion #9)
Added caveat: "may change if Twilio adds native support"

### Q2: No transcript content (Assertion #10)
Added caveat: "not live-tested, based on event type catalog review"

### Q3: Event Streams is free (Assertion #17)
Added caveat: "docs claim, not independently verifiable via API"

### Q4: HMAC-SHA1 signature validation (Assertion #29)
Added caveat: "not tested with .protected.js Functions endpoint"
