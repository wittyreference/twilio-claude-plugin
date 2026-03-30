---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Segment API reference covering HTTP Tracking API, Public API, and deprecated Config API. -->
<!-- ABOUTME: Read when integrating with Segment APIs directly for event ingestion, workspace management, or automation. -->

# Segment API Reference

Three APIs serve different purposes: HTTP Tracking API for event ingestion, Public API for workspace management, and Config API (deprecated) for legacy integrations.

## HTTP Tracking API

Direct event ingestion without an SDK. Use when no Segment library is available for your environment.

### Endpoints

| Region | Base URL |
|--------|----------|
| Default (Oregon) | `https://api.segment.io/v1/` |
| EU (Dublin) | `https://events.eu1.segmentapis.com/` |

EU workspaces MUST use the EU endpoint. Using the standard endpoint silently fails.

### Authentication

Three methods (pick one):

**1. Write Key in Body**
```json
POST /v1/track
Content-Type: application/json

{
  "writeKey": "YOUR_WRITE_KEY",
  "event": "Item Purchased",
  "userId": "user_123",
  "properties": { "item": "widget", "price": 9.99 }
}
```

**2. Basic Auth**
```bash
curl -X POST https://api.segment.io/v1/track \
  -u YOUR_WRITE_KEY: \
  -H "Content-Type: application/json" \
  -d '{"event": "Item Purchased", "userId": "user_123"}'
```

The colon after the write key is required (empty password in Basic Auth).

**3. OAuth Bearer Token**
```
Authorization: Bearer <access_token>
```
Write key still required in the payload body when using OAuth.

### Endpoints

| Method | Path | Required Fields |
|--------|------|----------------|
| POST | `/v1/identify` | `userId` or `anonymousId` |
| POST | `/v1/track` | `event` + (`userId` or `anonymousId`) |
| POST | `/v1/page` | `userId` or `anonymousId` |
| POST | `/v1/screen` | `userId` or `anonymousId` |
| POST | `/v1/group` | `groupId` + (`userId` or `anonymousId`) |
| POST | `/v1/alias` | `userId` + `previousId` |
| POST | `/v1/batch` | Array of events |

### Rate Limits & Constraints

| Limit | Value |
|-------|-------|
| Requests per second | 1,000 per workspace |
| Single event max size | 32 KB |
| Batch request max size | 500 KB |
| Engage inbound | 1,000 events/sec |
| Rate limit response | HTTP 429 with `Retry-After` and `X-RateLimit-Reset` headers |

### Error Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 400 | Bad request or oversized payload |
| 401 | Invalid or missing write key |
| 429 | Rate limited |
| 5xx | Server error (retry with backoff) |

### Batch Endpoint

Send multiple events in one request. Reduces HTTP overhead for high-volume ingestion.

```json
POST /v1/batch
Content-Type: application/json

{
  "writeKey": "YOUR_WRITE_KEY",
  "batch": [
    {
      "type": "identify",
      "userId": "user_123",
      "traits": { "name": "Jane", "email": "jane@example.com" }
    },
    {
      "type": "track",
      "userId": "user_123",
      "event": "Item Purchased",
      "properties": { "item": "widget", "price": 9.99 }
    }
  ]
}
```

Each event in the batch must be ≤32 KB. The entire batch must be ≤500 KB.

### IP Address Behavior

IP is auto-captured from the request source if not provided in `context.ip`. Segment uses dynamic IPs — do not hardcode IP addresses; use DNS hostnames.

### Destination Selection

```json
{
  "userId": "user_123",
  "event": "Signed Up",
  "integrations": {
    "All": false,
    "Mixpanel": true,
    "Amplitude": true
  }
}
```

Opt-out model: all destinations enabled unless explicitly disabled. Destination names are case-sensitive.

---

## Public API

Programmatic workspace management. Team and Business Tier only.

### Authentication

Bearer token from workspace settings. Only Workspace Owners can create tokens.

Path: **Settings → Workspace settings → Access Management → Tokens**

```
Authorization: Bearer {token}
```

Server-side only. Browser-side calls produce CORS errors.

### Security

- Plain-text token cannot be retrieved after creation — save in a secret manager
- GitHub Secret Scanning auto-revokes exposed tokens
- Lost tokens require regeneration

### API Version

v73.0.0 (as of 2026-03-28). Full reference at `docs.segmentapis.com`.

### API Categories

| Category | Key Operations |
|----------|---------------|
| **Connections** | Create/list/delete Sources, Destinations, Warehouses. Manage write keys, labels, Functions, Reverse ETL. Delivery metrics. |
| **Engage** | Audiences (create/list/schedule/preview), Activations, Messaging subscriptions, Batch profile queries |
| **Protocols** | Tracking Plans (CRUD + rules), Transformations |
| **Unify** | Computed Traits, Space Filters |
| **Admin** | IAM (Users, Groups, Roles), Labels, Audit Trail |
| **Usage** | Daily API calls per source/workspace, Monthly Tracked Users |
| **Monitoring** | Event volume |

### SDKs

Official SDKs: JavaScript, TypeScript, Go, Java, Swift, C#

### Key Destination Management Endpoints

```bash
# Create a destination
POST https://api.segmentapis.com/destinations
Authorization: Bearer {token}
Content-Type: application/json

{
  "sourceId": "SOURCE_ID",
  "name": "my-destination",
  "enabled": true,
  "settings": { "apiKey": "DEST_API_KEY" }
}

# Create a destination filter (FQL)
POST https://api.segmentapis.com/destination/{id}/filters
Authorization: Bearer {token}
Content-Type: application/json

{
  "sourceId": "SOURCE_ID",
  "destinationId": "DEST_ID",
  "title": "Drop anonymous events",
  "if": "length(userId) < 1",
  "actions": [{ "type": "DROP" }],
  "enabled": true
}
```

### Filter Query Language (FQL)

Used in Destination Filters API. Key operators:

| Operator | Description |
|----------|-------------|
| `contains` | String contains |
| `glob matches` | Case-sensitive wildcard matching |
| `is` / `is not` | Equality (string or number) |
| `is null` / `is not null` | Null check |
| `is true` / `is false` | Boolean check |
| `length()` | String/array length |

Filter application order: Sample → Drop → Drop Properties → Allow Properties

Filters are case-sensitive. Cannot filter properties with spaces in names (use Insert Functions instead).

---

## Config API (Deprecated)

Legacy workspace management API. **New tokens cannot be created as of Feb 2024.** Migrate to the Public API.

### Base URL

```
https://platform.segmentapis.com/v1beta/
```

### Authentication

```
Authorization: Bearer $ACCESS_TOKEN
```

### Available Services

Access Tokens, Source Catalog, Destination Catalog, Workspaces, Sources, Destinations, Tracking Plans, Event Delivery Metrics, Destination Filters, IAM, Functions

### Example

```bash
curl -X GET \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  https://platform.segmentapis.com/v1beta/workspaces
```

```json
{
  "workspaces": [{
    "name": "workspaces/myworkspace",
    "display_name": "My Space",
    "id": "e5bdb0902b",
    "create_time": "2018-08-08T13:24:02.651Z"
  }],
  "next_page_token": ""
}
```

For new Config API tokens, contact `friends@segment.com`.

---

## SDK Quick Reference

### Node.js

```bash
npm install @segment/analytics-node  # Requires Node 18+
```

```javascript
import { Analytics } from "@segment/analytics-node";

const analytics = new Analytics({ writeKey: "YOUR_WRITE_KEY" });

analytics.track({
  userId: "user_123",
  event: "Item Purchased",
  properties: { item: "widget", price: 9.99 }
});

// Serverless: create new instance per invocation, flush before exit
await analytics.flush({ close: true, timeout: 5000 });
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `writeKey` | string | Required | Source write key |
| `host` | string | `https://api.segment.io` | API base URL |
| `path` | string | `/v1/batch` | API path |
| `maxRetries` | number | `3` | Retry attempts |
| `flushAt` | number | `15` | Messages before flush |
| `flushInterval` | number | `10000` | Ms before auto-flush |
| `httpRequestTimeout` | number | `10000` | HTTP timeout in ms |
| `disable` | boolean | `false` | Disable for testing |

EU region: `{ host: "https://eu1.api.segmentapis.com" }`

### Analytics.js (Browser)

```html
<script>
  !function(){/* Segment snippet */}();
  analytics.load("YOUR_WRITE_KEY");
  analytics.page();
</script>
```

```javascript
// NPM package
import { AnalyticsBrowser } from "@segment/analytics-next";
const analytics = AnalyticsBrowser.load({ writeKey: "YOUR_WRITE_KEY" });
```

Key methods: `identify()`, `track()`, `page()`, `group()`, `alias()`, `reset()`

Helpers:
- `trackLink(element, event, properties)` — delays navigation 300ms for Track completion
- `trackForm(form, event, properties)` — delays form submission 300ms
- `ready(callback)` — fires when Analytics.js + destination SDKs finish loading
- `debug(true/false)` — toggle debug logging

### Client Library Retry Policies

| Library | Initial Wait | Growth | Max Wait | Max Attempts |
|---------|-------------|--------|----------|-------------|
| Node.js | 100ms | Exponential | 400ms | 3 |
| JavaScript | 1s | Exponential | 1h | 10 |
| Go | 100ms | Exponential | 10s | 10 |
| Python | 1s | Exponential | 34m | 10 |
| Java | 15s | Exponential | 1h | 50 |
| Ruby | 100ms | Exponential | 10s | 10 |
| PHP | 100ms | Exponential | 6.4s | 7 |
| .NET | 100ms | Exponential | 6.4s | 7 |
| C++ | 1s | None | 1s | 5 |
| Clojure | 15s | Exponential | 1h | 50 |

Segment-to-destination retries: failed calls retried for **4 hours** with randomized exponential backoff.

### Mobile SDKs

| Platform | Package | Min Version | Flush Default |
|----------|---------|-------------|---------------|
| Apple (Swift) | `analytics-swift` (SPM) | iOS 13+ | 20 events / 30s |
| Android (Kotlin) | `analytics-kotlin` | API 21+ | 20 events / 30s |
| React Native | `@segment/analytics-react-native` | RN 0.65+ | 20 events / 30s |
| Flutter | `analytics_flutter` | Pilot/Beta | — |

Mobile SDKs default to cloud-mode. Device-mode requires bundling destination SDK plugin.
