---
name: "event-streams"
description: "Twilio development skill: event-streams"
---

---
name: event-streams
description: Twilio Event Streams development guide. Use when building event-driven integrations, streaming Twilio events to webhooks/Kinesis/Segment, setting up sinks and subscriptions, or debugging event delivery.
---

# Event Streams Development Skill

Guide for building event-driven integrations with Twilio Event Streams. Load this skill when streaming platform events (calls, messages, recordings, TaskRouter, etc.) to external systems via webhooks, AWS Kinesis, or Segment.

**Evidence date**: 2026-03-29 | **Account**: ACxx...xx

## What Event Streams Cannot Do

Explicit list of things developers commonly assume work but don't:

- **Cannot guarantee ordering** — Events may arrive out of order. A `delivered` event can arrive before `sent`. Design consumers to be order-independent.
- **Cannot guarantee exactly-once delivery** — At-least-once semantics. You WILL receive duplicates. Deduplicate using the `id` field (SID format varies by product: `EZ` for messaging, `VW` for voice, `NO` for error logs).
- **Cannot provide latency SLAs** — Typical webhook delivery is 1-5 seconds, but no contractual guarantee. Voice Insights call summaries take 10-30 minutes.
- **Cannot attach multiple subscriptions to one sink** — Each sink supports exactly ONE subscription. Error: "Sink with SID DGxxx is in use". Create separate sinks for each subscription. [Evidence: DG1e0cf4..., 2026-03-29]
- **Cannot subscribe to discontinued event types** — API rejects with "Type is discontinued". Deprecated types ARE subscribable (they just won't fire for new activity). [Evidence: 2026-03-29]
- **Cannot subscribe to `com.twilio.voice.twiml.requested`** — Listed in docs but API rejects: "Type not found in the system". [Evidence: 2026-03-29]
- **Cannot use the Node SDK `types` property** — `client.events.v1.types` is `undefined` in the Twilio Node SDK. Use REST API directly for event type listing/fetching. [Evidence: 2026-03-29]
- **Cannot rely on `queued` events for API-originated messages** — `com.twilio.messaging.message.queued` is subscribable but never fires for messages sent via the API. Only `sent` and `delivered` arrive. [Evidence: SMaf53f7..., 2026-03-29]
- **Cannot use EventBridge as a native sink type** — AWS EventBridge requires routing through a Segment sink as intermediary.
- **Cannot receive transcript content via Event Streams** — Use the Transcript API or status callbacks for actual transcript text.

## Architecture

Event Streams is a **publish-subscribe system** built on CloudEvents v1.0. It decouples event producers (Twilio platform) from consumers (your systems).

```
Twilio Platform Events
         │
    ┌────┴────┐
    │  Event  │  CloudEvents v1.0 envelope
    │ Streams │  At-least-once delivery
    │  (free) │  4-hour retry window
    └────┬────┘
         │
    ┌────┴────────────────┐
    │                     │
    ▼                     ▼
┌────────┐          ┌──────────┐
│  Sink  │          │   Sink   │   1 sink = 1 subscription
│(webhook)│         │(kinesis) │   100 sinks per account
└────┬───┘          └────┬─────┘   100 subscriptions per account
     │                   │
     ▼                   ▼
┌──────────┐       ┌──────────┐
│Subscript.│       │Subscript.│   Subscribe to specific event types
│(msg evts)│       │(voice)   │   Schema versioning per type
└──────────┘       └──────────┘
```

### Key Resources

| Resource | SID Prefix | Purpose |
|----------|-----------|---------|
| Sink | `DG` | Destination endpoint (webhook URL, Kinesis stream, Segment write key) |
| Subscription | `DF` | Links event types to a sink |
| Event Type | — | Catalog entry (e.g., `com.twilio.messaging.message.delivered`) |
| Schema | — | JSON Schema definition (e.g., `Messaging.MessageStatus`) |
| Event | varies | Individual delivered event (dedup key; prefix varies: `EZ` messaging, `VW` voice, `NO` errors) |

### Base URL

All REST API calls: `https://events.twilio.com/v1/`

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| React to individual call/message events in real-time | **Status callbacks** (webhooks on each resource) | Lower latency, per-resource granularity, no setup overhead |
| Stream ALL events of a type to an analytics pipeline | **Event Streams** → Kinesis/Segment | Centralized, no per-resource webhook config, schema-versioned |
| Feed events to a webhook for processing | **Event Streams** → Webhook sink | Single endpoint receives all subscribed events across the account |
| Audit trail / compliance logging | **Event Streams** → Kinesis → S3 | Durable, ordered (within partition), full account coverage |
| Monitor for errors across all products | **Event Streams** → `com.twilio.error-logs.error.logged` | Real-time error alerts without polling the Debugger API |
| Voice call quality monitoring | **Event Streams** → Voice Insights events | Faster than REST polling (15-30+ min), push-based |

### Event Streams vs Status Callbacks

| Dimension | Event Streams | Status Callbacks |
|-----------|--------------|-----------------|
| Scope | Account-wide, all resources | Per-resource (set on each call/message) |
| Setup | One-time: sink + subscription | Per-resource: StatusCallback URL parameter |
| Format | CloudEvents JSON with schema versioning | Form-encoded (`application/x-www-form-urlencoded`) |
| Delivery | At-least-once, 4-hour retry window | At-least-once, shorter retry |
| Latency | 1-5s typical (30+ min for Insights) | Sub-second for most events |
| Ordering | No guarantee | No guarantee |
| Coverage | 120+ event types across 17 products | Product-specific callbacks only |
| Cost | Free (no Event Streams charges) | Free |

## Decision Frameworks

### Choosing a Sink Type

| Scenario | Sink Type | Why |
|----------|-----------|-----|
| Prototype / simple webhook consumer | `webhook` | Fastest setup, inspect events immediately |
| Production analytics pipeline | `kinesis` | Durable, scalable, partition by key |
| Customer data platform integration | `segment` | Direct CDP ingestion, no middleware |
| Need EventBridge | `segment` → EventBridge | No native EventBridge sink; route via Segment |
| Email notifications (testing only) | `email` | Sink test events sent to email; not for production |

### Webhook Sink Configuration

| Parameter | Required | Default | Notes |
|-----------|----------|---------|-------|
| `destination` | Yes | — | HTTPS URL. Must respond within 5 seconds. |
| `method` | No | `POST` | HTTP method |
| `batch_events` | No | `false` | `false` = individual delivery (1 event per request). `true` = batched (JSON array). |

### Webhook Response Handling

| Response Code | Event Streams Behavior |
|---------------|----------------------|
| `200`, `204` | Success — event acknowledged |
| `400` | **Discard** — event is NOT retried |
| `429` | **Retry** — rate limiting, event re-queued |
| `500` | **Retry** — transient error, exponential backoff |

### Kinesis Sink Configuration

| Parameter | Required | Notes |
|-----------|----------|-------|
| `arn` | Yes | Kinesis stream ARN |
| `role_arn` | Yes | IAM role ARN for cross-account access |
| `external_id` | Yes | External ID for STS AssumeRole |

### Segment Sink Configuration

| Parameter | Required | Notes |
|-----------|----------|-------|
| `write_key` | Yes | Segment source write key |

### CloudEvents to Segment Spec Field Mapping

When routing Twilio Event Streams to a Segment sink, the CloudEvents envelope maps to Segment track calls:

| CloudEvents Field | Segment Field | Notes |
|---|---|---|
| `type` (e.g., `com.twilio.messaging.message.sent`) | `event` | Use the full CloudEvents type as the Segment event name |
| `data.*` | `properties` | The entire `data` object becomes Segment event properties |
| `time` (ISO 8601) | `timestamp` | Direct mapping — both use ISO 8601 |
| `id` | `messageId` | Use as deduplication key — CloudEvents IDs are unique per event |
| `source` | `context.source_id` | Identifies the Twilio account/resource that emitted the event |
| `dataschema` | `properties._schema` | Optional — preserves schema version for downstream consumers |
| `specversion` | (omit) | CloudEvents metadata — not meaningful in Segment context |

**Deduplication**: Use `id` as `messageId` to prevent duplicate processing. Event Streams guarantees at-least-once delivery, so duplicates are expected.

**Identity resolution**: CloudEvents do not include a Segment `userId` or `anonymousId`. Set `anonymousId` to the resource SID (e.g., `CallSid`, `MessageSid`) from `data.*`, or use a Segment Function to resolve identity from your user database.

## CloudEvents Envelope

Every event is wrapped in a CloudEvents v1.0 envelope:

```json
{
  "id": "EZf40f223873cb33b29e536dbcc34fb98b",
  "type": "com.twilio.messaging.message.sent",
  "specversion": "1.0",
  "source": "/2010-04-01/Accounts/ACxxx/Messages/SMxxx.json",
  "time": "2026-03-29T04:00:56.753Z",
  "datacontenttype": "application/json",
  "dataschema": "https://events-schemas.twilio.com/Messaging.MessageStatus/7",
  "data": {
    "messageSid": "SMaf53f755fc01b434d69700511984da79",
    "messageStatus": "SENT",
    "from": "+15551234567",
    "to": "+15559876543"
  }
}
```

Key fields:
- **`id`**: Deduplication key. SID prefix varies by product: `EZ` (messaging), `VW` (voice), `NO` (error logs). Test events use Account SID.
- **`source`**: REST API resource path (not a full URL).
- **`dataschema`**: Schema URL with version number. Use to handle schema evolution.
- **`data`**: The actual event payload. Structure varies by event type.

## Usage Patterns

### Create a Webhook Sink + Subscription (Node.js)

```javascript
const client = require('twilio')(accountSid, authToken);

// Step 1: Create a sink
const sink = await client.events.v1.sinks.create({
  description: 'my-webhook-sink',
  sinkConfiguration: {
    destination: 'https://example.com/events',
    method: 'POST',
    batch_events: false
  },
  sinkType: 'webhook'
});
// sink.sid = "DGxxx"

// Step 2: Test the sink (sends a test event)
await client.events.v1.sinks(sink.sid).sinkTest().create();
// Returns { result: "submitted" }

// Step 3: Validate (requires test_id from received test event)
await client.events.v1.sinks(sink.sid).sinkValidate().create({
  testId: 'received-test-id-uuid'
});
// Returns { result: "valid" }

// Step 4: Create subscription (ONE subscription per sink)
const subscription = await client.events.v1.subscriptions.create({
  description: 'messaging-events',
  sinkSid: sink.sid,
  types: [
    { type: 'com.twilio.messaging.message.sent' },
    { type: 'com.twilio.messaging.message.delivered' },
    { type: 'com.twilio.messaging.message.failed' },
    { type: 'com.twilio.messaging.inbound-message.received' }
  ]
});
```

### Add/Remove Event Types from Existing Subscription

```javascript
// Add a new event type
await client.events.v1.subscriptions(subscriptionSid)
  .subscribedEvents.create({ type: 'com.twilio.messaging.message.undelivered' });

// Remove an event type
await client.events.v1.subscriptions(subscriptionSid)
  .subscribedEvents('com.twilio.messaging.message.undelivered').remove();
```

### Webhook Receiver (Twilio Functions)

```javascript
// Event Streams sends JSON, not form-encoded data.
// Use a public (.js) endpoint — see Gotcha #8 for .protected.js considerations.
exports.handler = async function(context, event, callback) {
  // event contains the CloudEvents object (or array if batch_events=true)
  const cloudEvent = event;

  console.log('Event type:', cloudEvent.type);
  console.log('Event ID:', cloudEvent.id);
  console.log('Data:', JSON.stringify(cloudEvent.data));

  // Deduplicate using cloudEvent.id (EZ SID)
  // Store/process cloudEvent.data

  const response = new Twilio.Response();
  response.setStatusCode(200);
  response.appendHeader('Content-Type', 'application/json');
  response.setBody(JSON.stringify({ received: 1 }));
  callback(null, response);
};
```

### Deduplication Pattern

```javascript
const processedIds = new Set(); // Use Redis/DB in production

function handleEvent(cloudEvent) {
  if (processedIds.has(cloudEvent.id)) {
    return; // Already processed
  }
  processedIds.add(cloudEvent.id);
  // Process the event
}
```

### Query Event Types and Schemas (REST API)

```bash
# List available event types
curl "https://events.twilio.com/v1/Types?PageSize=20" \
  -u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN"

# Get specific event type details
curl "https://events.twilio.com/v1/Types/com.twilio.messaging.message.delivered" \
  -u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN"

# List schema versions
curl "https://events.twilio.com/v1/Schemas/Messaging.MessageStatus/Versions" \
  -u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN"
```

**Note**: The Node SDK does not expose `client.events.v1.types` — use REST API for type listing. Sinks, subscriptions, and subscribed events work via SDK.

## Gotchas

### Setup

1. **One sink per subscription**: A sink can only be attached to ONE subscription. Creating a second subscription on the same sink returns "Sink with SID DGxxx is in use". Create separate sinks even if they point to the same URL. [Evidence: DG1e0cf4..., 2026-03-29]

2. **Orphaned sinks on subscription delete**: Deleting a subscription does NOT delete its sink. Sinks remain `active` and count toward the 100-sink limit. Clean up sinks explicitly after removing subscriptions. [Evidence: DG718b1f..., 2026-03-29]

3. **Validate requires receiving the test event first**: The sink validate endpoint requires a `TestId` parameter. This ID comes from the `data.test_id` field in the test event delivered to your sink. You must POST to `/Test` first, receive the test event, extract the UUID, then POST to `/Validate`. [Evidence: DG1e0cf4..., test_id: ac09e217..., 2026-03-29]

4. **100 sinks + 100 subscriptions per account**: Hard limit. Since each subscription needs its own sink, you can have at most 100 active event subscriptions per account.

### Configuration

5. **`batch_events` defaults to `false`**: Despite documentation suggesting batching is the default, creating a sink without specifying `batch_events` returns `batch_events: false`. If you DO set it to `true`, events arrive as JSON arrays, and Twilio Functions spread arrays into numeric keys on the `event` parameter (`event['0']`, `event['1']`, etc.). [Evidence: 2026-03-29]

6. **Schema versions auto-assigned to latest**: When creating a subscription, omitting `schema_version` subscribes to the latest version. This means your payload format can change when Twilio releases a new schema version. Pin versions in production: `{ type: 'com.twilio.messaging.message.sent', schema_version: 7 }`.

7. **Deprecated vs discontinued event types**: Deprecated types can be subscribed to (they accept but may not fire). Discontinued types are rejected with an error. Check the `/Types` endpoint for current status before subscribing. [Evidence: 2026-03-29]

### Runtime

8. **Webhook signature validation with Functions**: Event Streams signs webhooks using standard Twilio request validation (HMAC-SHA1 via `X-Twilio-Signature` + `bodySHA256` query parameter). Protected Twilio Functions (`.protected.js`) should validate this, but since the body is JSON (not form-encoded), test thoroughly before relying on `.protected.js` for Event Streams webhooks.

9. **Error-log feedback loop with Functions webhooks**: Subscribing to `com.twilio.error-logs.error.logged` while using a Twilio Functions webhook creates an infinite feedback loop. Your function's `console.log()` generates INFO-level alerts → those become error-log events → delivered to your function → more logs → more events. Use a non-Functions endpoint for error-log subscriptions, or filter by `data.level` early and suppress logging for loop events. [Evidence: DG718b1f..., 2026-03-29]

10. **Error logs include INFO level**: The event type `com.twilio.error-logs.error.logged` fires for ALL debugger alert levels, including `INFO`. The name is misleading — it's not limited to errors. Check the `data.level` field (`ERROR`, `WARNING`, `INFO`). [Evidence: 2026-03-29]

11. **Error log `payload` is a JSON string**: The `data.payload` field in error-log events contains a JSON string, not a parsed object. You must `JSON.parse(data.payload)` to access the structured content. [Evidence: NO8b9489..., 2026-03-29]

12. **`messageStatus` is UPPERCASE in Event Streams**: Event Streams returns `"SENT"`, `"DELIVERED"`, `"FAILED"`. Status callbacks return lowercase `"sent"`, `"delivered"`, `"failed"`. If you're migrating from status callbacks, update your comparisons. [Evidence: EZf40f22..., 2026-03-29]

13. **Field naming inconsistency between inbound and outbound messaging**: Outbound messages use `numberOfSegments`; inbound messages use `numSegments`. Different schema names too: `Messaging.MessageStatus/7` vs `Messaging.InboundMessageV1/6`. [Evidence: 2026-03-29]

### Observability

14. **Voice event `responseBody` is base64-encoded**: The `data.response.responseBody` field in voice API-request and TwiML events contains the full response body base64-encoded. Decode with `Buffer.from(responseBody, 'base64').toString()`. [Evidence: VW094d1e..., 2026-03-29]

15. **CloudEvents `id` prefix varies by product**: Messaging events use `EZ`, voice webhook events use `VW`, error log events use `NO`, and test events use the Account SID. Do not assume `EZ` prefix for dedup logic — key on the full `id` string. [Evidence: 2026-03-29]

16. **`rawDlrDoneDate` format is `YYMMDDHHMM`**: The delivery receipt timestamp in messaging events uses compact format (`2603290400`), not ISO 8601. Parse accordingly. [Evidence: EZc834b3..., 2026-03-29]

17. **Webhook retry window is 4 hours**: Failed deliveries (5xx responses) retry with exponential backoff + jitter for up to 4 hours. After 4 hours, the event is dropped. Return 400 to explicitly discard without retry; return 429 to signal rate limiting.

18. **Webhook timeout is 5 seconds**: Your endpoint must respond within 5 seconds or the delivery is treated as failed and retried. For heavy processing, acknowledge immediately (200) and process asynchronously.

19. **Webhook source CIDR: `35.90.102.128/25`**: Whitelist this CIDR range for firewall rules. Events originate from this IP range.

## Error Codes

| Code | Context | Description |
|------|---------|-------------|
| 93101 | Kinesis | Error writing to stream |
| 93101 | Webhook | Rate limited (429), bad request (400), or server error (500) |
| 93102 | Kinesis | IAM AssumeRole error |
| 93103 | Kinesis | Error getting shard count |
| 93104 | Kinesis | Error getting stream name/region — event discarded |

## Related Resources

- **Voice Insights events**: `/skills/voice-insights/SKILL.md` — Conference/call summary events via Event Streams
- **Conference Insights**: `/skills/conference/references/insights-and-validation.md` — Real-time conference events
- **Segment integration**: `/skills/segment/SKILL.md` — Segment sink destination setup
- **Deep crawl reference**: `/references/event-streams-deep-crawl.md` — Full 1692-line API reference with all payload schemas
- **Webhook receiver function**: `event-stream.js` — Live webhook that stores events in Sync

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Live test results | `references/test-results.md` | When verifying specific behaviors or checking evidence SIDs |
| Event types catalog | `references/event-types-catalog.md` | When choosing which event types to subscribe to |
| Deep crawl (full API) | `/references/event-streams-deep-crawl.md` | When needing full payload schemas or REST API parameter details |
