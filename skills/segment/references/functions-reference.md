---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Segment Functions reference covering Source, Destination, and Insert Functions — runtime, handlers, dependencies, and constraints. -->
<!-- ABOUTME: Read when writing custom Segment Functions for webhook ingestion, custom destinations, or data enrichment/transformation. -->

# Segment Functions Reference

Functions let you create custom sources and destinations with JavaScript. Powered by AWS Lambda. Available on all plans with a free usage allotment.

## Runtime Environment

| Constraint | Value |
|-----------|-------|
| Node.js version | LTS (currently v20); auto-upgrades on next deploy |
| Execution timeout | 5 seconds |
| Max payload size | 512 KiB (Source Functions) |
| Max event size | 32 KB (Tracking API limit) |
| Console log limit | 4 KB (in test UI) |
| Retry attempts | Up to 6 (on RetryError/Timeout) |
| Retry backoff | Exponential; initial 1-3 min, max 20 min |
| Destination retry window | 4 hours with randomized exponential backoff |

## Pre-installed Dependencies

Available in all three Function types without importing:

| Package | Version | Use |
|---------|---------|-----|
| `@google-cloud/*` | Various | Google Cloud services |
| `atob` / `btoa` | — | Base64 encoding |
| `aws-sdk` | 2.488.0 | AWS services |
| `crypto` | Built-in | Cryptographic operations |
| `fetch-retry` | — | HTTP with retry |
| `form-data` | — | Multipart form data |
| `https` | Built-in | HTTPS requests |
| `jsforce` | — | Salesforce integration |
| `jsonwebtoken` | — | JWT creation/verification |
| `lodash` | — | Utility functions |
| `node-fetch` | 2.6.0 | HTTP requests (also available as global `fetch`) |
| `stripe` | — | Stripe API |
| `twilio` | 3.68.0 | Twilio API (pinned, not latest) |
| `xml2js` | — | XML parsing |

Only `crypto` and `https` from Node built-ins. No `fs`, `path`, `child_process`, etc.

## Caching

All Function types support a process-local `cache` object:

```javascript
const value = await cache.load(key, ttlMs, async () => {
  // Fetch value if not cached
  return await fetchAccessToken();
});

await cache.delete(key);
```

- Process-local, not shared between Lambda instances
- May be expunged before TTL (memory pressure, scaling events)
- Low-volume functions may be suspended, emptying cache
- Do not rely on cache for correctness — use as performance optimization only

## Settings / Secrets

All Function types support configurable settings with Label, Name, Type, Description, Required, and Encrypted flags. Encrypted settings are stored securely and not visible after save.

Declare settings inside handler functions, not globally. Global declaration leaks settings across function instances sharing the same codebase.

```javascript
// WRONG — leaks across instances
const apiKey = settings.apiKey;

async function onTrack(event, settings) {
  // CORRECT — scoped to invocation
  const apiKey = settings.apiKey;
  await fetch(url, { headers: { Authorization: `Bearer ${apiKey}` } });
}
```

## Permissions

| Role | Can Do |
|------|--------|
| Functions Admin | Create, edit, delete, deploy functions |
| Functions Read-only | View function code and settings |
| Source Admin | Enable source, connect source, deploy source functions |

---

## Source Functions

Receive external data via webhook and create Segment events.

### Handler

```javascript
async function onRequest(request, settings) {
  const body = request.json();
  const headers = request.headers; // Headers API (get, entries, etc.)
  const url = request.url;        // URL API (searchParams, etc.)

  Segment.track({
    event: "Webhook Received",
    userId: body.userId,
    properties: { source: "custom-webhook", payload: body }
  });
}
```

### Available Segment Methods

| Method | Required Fields |
|--------|----------------|
| `Segment.identify({ userId, anonymousId, traits, context })` | One of userId/anonymousId |
| `Segment.track({ event, userId, anonymousId, properties, context })` | `event` + one of userId/anonymousId |
| `Segment.group({ groupId, traits, context })` | `groupId` |
| `Segment.page({ name, userId, anonymousId, properties, context })` | One of userId/anonymousId |
| `Segment.screen({ name, userId, anonymousId, properties, context })` | One of userId/anonymousId |
| `Segment.alias({ previousId, userId, anonymousId })` | `previousId` |
| `Segment.set({ collection, id, properties })` | All three (Object API — warehouse only, not visible in Debugger) |

### Constraints

- POST requests only (no GET)
- Cannot send custom HTTP responses (success/failure only)
- Cannot send data back to its own webhook endpoint (infinite loop prevention)
- Payload fields are alphabetized in deployed functions (not in tester)
- Webhook URL format: `api.segmentapis.com/functions`

### Testing

POST to the Source Function webhook with:
```
Authorization: Bearer <public_api_token>
Content-Type: application/json
```

### Error Types

| Error | Behavior |
|-------|----------|
| Bad Request | Discarded |
| Invalid Settings | Discarded |
| Message Rejected | Discarded |
| Unsupported Event Type | Discarded |
| 429 TooManyRequests | Retried |
| RetryError | Retried (up to 6 times) |
| Timeout (>5s) | Retried |
| Oversized (>32KB per event) | Rejected by Tracking API |

---

## Destination Functions

Transform and deliver Segment events to external APIs. Replaces a destination entirely.

### Handlers

```javascript
async function onTrack(event, settings) {
  const response = await fetch("https://api.example.com/events", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${settings.apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      event: event.event,
      userId: event.userId,
      properties: event.properties,
      timestamp: event.timestamp
    })
  });

  if (!response.ok) {
    throw new RetryError(`API returned ${response.status}`);
  }
}
```

Available handlers: `onIdentify`, `onTrack`, `onPage`, `onScreen`, `onGroup`, `onAlias`, `onDelete`, `onBatch`

Unimplemented handlers throw `EventNotSupported` by default (event is discarded).

### Error Types

| Error | Behavior |
|-------|----------|
| `EventNotSupported` | Discarded |
| `InvalidEventPayload` | Discarded |
| `ValidationError` | Discarded |
| `RetryError` | Retried for 4 hours |
| Timeout | Retried for 4 hours |

### Batching

```javascript
async function onBatch(events, settings) {
  const response = await fetch("https://api.example.com/batch", {
    method: "POST",
    headers: { "Authorization": `Bearer ${settings.apiKey}` },
    body: JSON.stringify({ events })
  });

  // Partial failure support
  return events.map((event, i) => ({
    status: response.ok ? 200 : 500,
    errormessage: response.ok ? undefined : "Batch item failed"
  }));
}
```

- Default: 10-second window, 20 events per batch (up to 400 via support request)
- Under 1 event/sec may not trigger batch handler
- Single-event handlers required as fallback
- Partial failure: return array of `{ status, errormessage }`. Only 500/retry statuses are retried.

### Key Behaviors

- Cloud-mode only (no device-mode)
- No guaranteed event ordering
- `console.log` only visible for errored payloads in Event Delivery (not successes)
- Global variables persist between invocations (use for token caching with expiry checks)
- Reference in `integrations` object: `"My Destination Function (My Workspace)": true` (include workspace name, case-sensitive)
- Do not accept data from Object Cloud Sources

### IP Allowlisting Regions

| Workspace Region | AWS Region |
|-----------------|-----------|
| US | `us-west-2` |
| EU | `eu-west-1` |

---

## Insert Functions

Enrich, transform, or filter events in-flight between source and an existing destination. Middleware pattern — does not replace the destination.

### Critical: Must Return the Event

```javascript
async function onTrack(event, settings) {
  // Enrich with external data
  const profile = await fetchProfile(event.userId, settings);
  event.properties.tier = profile.tier;
  event.properties.lifetime_value = profile.ltv;

  return event;  // MUST return — omitting silently drops the event
}
```

### Pipeline Position

```
Source → Schema Filters → Transformations → Destination Filters → INSERT FUNCTION → Mapping Triggers → Destination
```

Insert Functions sit AFTER Destination Filters but BEFORE mapping triggers. An Insert Function cannot change an event to match a trigger it didn't previously match — the trigger check uses the original event.

### Key Differences from Destination Functions

| Aspect | Insert Function | Destination Function |
|--------|----------------|---------------------|
| Returns | Must return one event | No return (sends externally) |
| Pipeline position | Before existing destination | Replaces destination |
| Multi-destination | One function → many destinations | One function = one destination |
| Stacking | Cannot stack multiple on one destination | N/A |
| Coexistence | Can coexist with Destination Filters | N/A |

### Batching in Insert Functions

Same as Destination Functions with one critical addition: **preserve original event order**. Segment uses positional consistency (array index) between input and output.

```javascript
async function onBatch(events, settings) {
  // Enrich each event while preserving order
  return Promise.all(events.map(async (event) => {
    event.properties.enriched = true;
    return event;
  }));
}
```

Filtered events surfaced as "Filtered at insert function" in Event Delivery.

### Constraints

- Cloud-mode destinations only (no device-mode, no storage destinations)
- Event destinations only (not list destinations)
- Display name max 120 characters
- Must handle all event types expected by the downstream destination
- Removing a handler blocks that event type entirely
- Use `throw new DropEvent()` to explicitly drop events

### Use Cases

| Pattern | Implementation |
|---------|---------------|
| Profile enrichment | Call Profile API or external API, merge into `event.properties` |
| PII tokenization | Hash/encrypt sensitive fields before destination receives them |
| Advanced filtering | Regex patterns, nested business rules, external lookup |
| Compliance gating | Check consent status, drop non-consented events |
| Data normalization | Standardize field names, formats, units across sources |
