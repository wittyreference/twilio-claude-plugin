---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Live test results from Event Streams skill builder validation. -->
<!-- ABOUTME: Evidence SIDs and behavioral findings from 2026-03-29 testing session. -->

# Event Streams — Live Test Results

**Date**: 2026-03-29  
**Account**: ACb4de2...  
**Webhook**: https://prototype-1483-dev.twil.io/callbacks/event-stream

## Test Infrastructure

- Webhook receiver function: `event-stream.js`
- Events stored in Sync List: `event-stream-events` (24h TTL)
- Summary tracked in Sync Document: `event-stream-summary`
- Sync Service: IS8d793d6cb78bcc3367d66a7eb9ab1f0b

## Test 1: Sink Creation and Test Event

| Step | Result | Evidence |
|------|--------|----------|
| Create webhook sink | `active` status, `DG` SID | DG1e0cf49a159ed0bd80c5845b63ab7cc1 |
| POST to `/Test` | `{ result: "submitted" }` | — |
| Test event received | CloudEvents envelope with `data.test_id` | test_id: ac09e217-c034-4e44-a981-9ee421e3ff6b |
| Test event type | `com.twilio.eventstreams.test-event` | — |
| Test event `id` | Account SID (not EZ format) | ACb4de2... |
| Test event schema | `EventStreams.TestSink/1.json` | — |
| Test event latency | ~1.5s (time: 03:59:04, received: 03:59:05) | — |
| POST to `/Validate` with test_id | `{ result: "valid" }` | — |
| POST to `/Validate` without TestId | 400: "Missing required parameter TestId" | — |

## Test 2: Subscription Creation

| Step | Result | Evidence |
|------|--------|----------|
| Create messaging subscription | Success, `DF` SID | DFaf3e9d66c3210bb2742c5f61126a793d |
| Create 2nd subscription on same sink | **FAILED**: "Sink with SID DGxxx is in use" | DG1e0cf49a159ed0bd80c5845b63ab7cc1 |
| Create separate sink for voice | Success | DG9f6c373cc0a025adc46906e8e034dada |
| Create voice subscription | Success | DF2fb1163bfc3e79909494cee10c0bb7c2 |
| Create separate sink for errors | Success | DG718b1f000979ef7fc570f1e2d1ea53ba |
| Create error subscription | Success | DFa417e8e7cc2eaf14e8bac7b8f74c245f |

## Test 3: Messaging Events (Send SMS)

Sent SMS: SMaf53f755fc01b434d69700511984da79

| Event Type | Received | Latency | Event ID |
|------------|----------|---------|----------|
| `message.queued` | **NO** (subscribed but never fired) | — | — |
| `message.sent` | Yes | ~2s | EZf40f223873cb33b29e536dbcc34fb98b |
| `message.delivered` | Yes | ~2s | EZc834b30d632d38fb956cc8e879e039ef |
| `inbound-message.received` | Yes | ~2s | EZd852c5ecf4b0bc323480c02741fbefb5 |

**Outbound message payload** (`Messaging.MessageStatus/7`):
- `messageStatus`: UPPERCASE (`SENT`, `DELIVERED`)
- `numberOfSegments`: integer
- `rawDlrDoneDate`: compact format `YYMMDDHHMM`
- `tags`: empty object `{}`
- Missing fields when not applicable: `body`, `errorCode`, `messagingServiceSid`, `mnc`, `mcc`

**Inbound message payload** (`Messaging.InboundMessageV1/6`):
- Field naming differs: `numSegments` (not `numberOfSegments`), `numMedia`
- Has geo data: `fromCity`, `fromCountry`, `fromState`, `toCity`, `toCountry`, `toState`, `toZip`
- Has `body` with message content
- Has `recipients: []` (empty for non-group MMS)
- No `accountSid` in some observations (present in outbound)

## Test 4: Error-Log Feedback Loop

| Metric | Value |
|--------|-------|
| Events generated from 1 SMS | 130 error-log events in ~3 minutes |
| Cause | `console.log()` → Functions INFO alert → error-log event → webhook → more logs |
| Error log `level` values observed | `INFO`, `ERROR` |
| Error log `id` SID prefix | `NO` (not `EZ`) |
| Error log `payload` format | JSON string (requires `JSON.parse()`) |

## Test 5: Voice Events (Organic Account Activity)

| Event Type | Count | Evidence |
|------------|-------|----------|
| `voice.api-request.call.created` | 21 | VW094d1e3c775693258767372ce9327122 |
| `voice.twiml.dial.finished` | 4 | — |

**Voice event payload** (`Voice.WebhookEvent/2`):
- `id` uses `VW` SID prefix (not `EZ`)
- `data.response.responseBody` is base64-encoded
- `data.request.parameters` contains full call parameters (From, To, Twiml, etc.)
- `data.response.responseCode`: integer HTTP status
- `data.response.requestDuration`: ms

## Test 6: Deprecated vs Discontinued Event Types

| Event Type | Status | Subscribable | Evidence |
|------------|--------|-------------|----------|
| `com.twilio.voice.webhook.status-callback.call.completed` | deprecated | **YES** (accepted) | — |
| `com.twilio.conversations.delivery.updated` | discontinued | **NO** ("Type is discontinued") | — |
| `com.twilio.voice.twiml.requested` | available (docs) | **NO** ("Type not found in system") | — |

## Test 7: Event Type and Schema APIs

| Operation | Method | Result |
|-----------|--------|--------|
| List event types | REST `GET /v1/Types` | Works, paginated |
| Get specific type | REST `GET /v1/Types/{type}` | Returns `type`, `description`, `status`, `schema_id` |
| List schema versions | REST `GET /v1/Schemas/{id}/Versions` | Works: `Messaging.MessageStatus` has 7 versions (v1 from 2020 to v7 from 2025) |
| Node SDK `types` | `client.events.v1.types` | **undefined** — not implemented in SDK |

## Test 8: Subscription Management

| Operation | Method | Result |
|-----------|--------|--------|
| Add event type to subscription | SDK `subscribedEvents.create()` | Success |
| Remove event type from subscription | SDK `subscribedEvents(type).remove()` | Success |
| List subscribed events | SDK `subscribedEvents.list()` | Returns types with auto-assigned schema versions |
| Schema version when omitted | Auto-assigns latest (v6 for inbound, v7 for outbound) | — |

## Test 9: Cleanup

| Resource | Action | Result |
|----------|--------|--------|
| Orphaned sink (sub deleted) | Sink remains `active` | Must delete explicitly |
| Delete subscription | `subscriptions(sid).remove()` | Success |
| Delete sink | `sinks(sid).remove()` | Success |

## REST API Format Discovery

Creating subscriptions via `curl` with form-encoded data does NOT work for the `Types` parameter. The API expects a format that maps to the SDK's array-of-objects pattern. Use the Node SDK or a JSON-aware HTTP client for subscription creation.

| Attempt | Format | Result |
|---------|--------|--------|
| `-d 'Types=[{"type":"..."}]'` | Raw JSON in form field | "Missing required input parameter event_types[0].type" |
| `--data-urlencode 'Types=[...]'` | URL-encoded JSON | Same error |
| `-H "Content-Type: application/json"` | JSON body | "Missing required parameter Description" (ignores JSON body) |
| Node SDK `types: [{type: '...'}]` | SDK | **Success** |
