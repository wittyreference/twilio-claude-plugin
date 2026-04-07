---
name: "segment"
description: "Twilio development skill: segment"
---

---
name: segment
description: Twilio Segment Connections development guide. Use when building data pipelines, collecting analytics events, routing data to destinations, writing custom Functions, setting up Reverse ETL, or integrating Segment with Twilio products.
---

<!-- ABOUTME: Twilio Segment Connections skill covering sources, destinations, functions, Reverse ETL, and the Segment Spec. -->
<!-- ABOUTME: Use when building data pipelines, choosing connection modes, writing Functions, or integrating Segment with Twilio. -->

# Segment Connections

Covers the Segment Connections product: Sources, Destinations, Functions, Reverse ETL, Storage, the Segment Spec, and APIs. Use this skill when building data pipelines with Segment, choosing between source/destination types, writing custom Functions, or integrating Segment events with Twilio products.

**Evidence basis**: Twilio Segment documentation + live API testing (2026-03-28). Tested against workspace `ikUoh88ZQxogSEEEABjp3k` using HTTP Tracking API and Public API (v73.0.0). **50 MCP tools available in P2 tier** (42 management + 8 tracking) — not loaded by default. Enable with `toolTiers: ['P0', 'P2', 'validation']` or `['all']`.

## Scope

### CAN

- Collect events from websites (Analytics.js), mobile apps (Swift, Kotlin, React Native), and servers (Node.js, Python, Go, Java, Ruby, etc.)
- Route events to 400+ destinations via cloud-mode or device-mode connections
- Transform, enrich, and filter data in-flight using three Function types (Source, Destination, Insert)
- Extract data from warehouses and sync to destinations via Reverse ETL (BigQuery, Snowflake, Redshift, Databricks, Postgres)
- Enforce data quality with Schema controls and Tracking Plans (Business Tier)
- Block events at the source level to exclude them from billing (MTU/API call calculations)
- Test connections with Event Tester (all enabled mappings) and Mappings Tester (single mapping)
- Manage workspace resources programmatically via the Public API (Team and Business Tier)
- Route traffic through NAT gateway for IP allowlisting (Business Tier)

### CANNOT

- **No bidirectional sync** — data flows Source → Segment → Destination. Destinations do not push data back to Segment (except Cloud App Sources, which are separate source integrations).
- **No real-time streaming to warehouses** — warehouse destinations load in bulk at regular intervals, not per-event.
- **No cross-event context in mappings** — Destination Actions cannot reference data from a previous event to enrich the current one.
- **No device-mode for server sources** — server-side libraries only support cloud-mode.
- **No Alias in Unify** — `alias()` merges identities in downstream destinations only; it cannot merge profiles in Segment Unify. Use Identity Resolution instead.
- **No multi-instance device-mode** — only one device-mode destination instance per non-mobile source (up to 25 cloud-mode instances).
- **No Schema API** — schema controls are UI-only; no REST API for programmatic schema management.
- **No guaranteed event ordering** — events may arrive at destinations in a different order than sent.
- **No IPv6 auto-collection** — IP auto-collection only works with IPv4.
- **No trait blocking in device-mode** — blocked Identify/Group traits still flow to device-mode destinations.
- **No custom responses from Source Functions** — they can only return success or failure, not custom HTTP response bodies.

## Quick Decision Reference

| Need | Use | Why |
|------|-----|-----|
| Track website user behavior | Analytics.js (JavaScript Source) | Auto-collects page, UTM, device context; plugin architecture |
| Track mobile app behavior | Swift/Kotlin SDK | Native performance, lifecycle auto-tracking |
| Send events from backend | Node.js / Python / Go SDK | Cloud-mode only, no destination SDK bundling needed |
| Send from environment without a library | HTTP Tracking API | Direct POST to `api.segment.io/v1/` |
| Track email opens/clicks (no code execution) | Pixel Tracking API | 1x1 pixel, works in email clients |
| Ingest from unsupported third-party | Source Function | Webhook receiver, transforms to Segment Spec |
| Send to unsupported third-party | Destination Function | Replaces a destination; full JS runtime |
| Enrich/filter before an existing destination | Insert Function | Middleware — sits between source and destination |
| AI-assisted Function creation | Functions Copilot | No-code Function generation |
| Sync warehouse data to marketing tools | Reverse ETL | Query → sync to Braze, HubSpot, Salesforce, etc. |
| Store raw data for analysts | Warehouse destination | Bulk-loaded, auto-schema-adjusted |
| Block specific events without removing code | Schema controls | Business Tier; blocked events excluded from billing |
| Test destination configuration | Event Tester / Mappings Tester | Sends real events; validates API calls |
| Manage workspace programmatically | Public API | CRUD sources, destinations, tracking plans, functions |

## Decision Frameworks

### Source Type Selection

| Scenario | Source Type | Key Consideration |
|----------|------------|-------------------|
| Website with rich analytics | Analytics.js | 70% smaller than v1; plugin architecture for extensions |
| React/Vue/Angular SPA | Analytics.js | Call `page()` on virtual route changes — no auto-fire on SPA navigation |
| iOS/macOS/watchOS app | Apple (Swift) SDK | Type-safe; supports all Apple platforms including Catalyst |
| Android/Fire app | Kotlin SDK (not legacy Java) | Legacy Java SDK end-of-support March 2026 |
| React Native cross-platform | React Native SDK | Bridges to native; cloud-mode by default |
| Node.js microservice | `@segment/analytics-node` | Requires Node 18+; create new instance per Lambda invocation |
| AWS Lambda / serverless | Node.js SDK with `flush()` | Must `await analytics.flush()` before function exits |
| Webhook from third-party | Source Function | POST-only; 5-second timeout; 512 KiB max payload |
| Pull data from SaaS tool | Cloud App Source | Object (warehouse-only) or Event (warehouse + destinations) |
| Warehouse as source | Reverse ETL | BigQuery, Snowflake, Redshift, Databricks, Postgres |

### Connection Mode Selection

| Factor | Cloud-Mode | Device-Mode |
|--------|-----------|-------------|
| Performance impact | Minimal — one Segment call | Higher — loads destination SDK |
| Ad blocker resilience | Unaffected | Blocked with analytics script |
| Destination feature access | May be limited | Full SDK features available |
| Server sources | Only option | Not available |
| Website sources | Optional (CDN cache up to 30 min) | Default for most web destinations |
| Mobile sources | Default | Requires bundling destination SDK |
| Features requiring device-mode | — | A/B testing, heatmaps, push notifications, live chat, in-app surveys, view-through attribution |
| Multi-instance support | Up to 25 per source | One per non-mobile source |

### Functions Type Selection

| Need | Function Type | Pipeline Position |
|------|--------------|-------------------|
| Ingest external webhook data into Segment | Source Function | Before Segment receives events |
| Replace a destination with custom logic | Destination Function | Replaces destination entirely |
| Enrich/transform data before existing destination | Insert Function | After Destination Filters, before mapping triggers |
| Filter with complex business rules | Insert Function | Regex, nested conditions, external API calls |
| PII tokenization/encryption before destination | Insert Function | Compliance layer in the pipeline |
| Send to destination not in catalog | Destination Function | Full HTTP client available |

**Pipeline execution order**: Source → Protocols Schema Filters → Protocols Transformations (source-scoped) → Destination Filters → Insert Functions → Mapping Triggers → Actions/Destination → Protocols Transformations (destination-scoped)

### Destination Actions vs Classic Destinations

| Factor | Destination Actions | Classic |
|--------|-------------------|---------|
| Transparency | See exact data sent per mapping | Black-box translation |
| Customization | Control triggers + field mapping | Settings-based |
| Max mappings | 50 per destination | N/A |
| Trigger conditions (self-service) | Max 2 per trigger | N/A |
| Trigger conditions (other plans) | Max 250 per trigger | N/A |
| Migration | Manual; use FQL `received_at` cutover | — |

## Gotchas

### Source Configuration

1. **Auto-disable after 14 days**: Sources with no enabled destinations are automatically disabled after 14 days, even if actively receiving events. Workspace owner gets an email beforehand. Submit an exception request via Airtable form if needed.

2. **Source type is immutable**: Cannot change a source's type after creation. Plan your source-per-data-type strategy upfront.

3. **One `page()` call required per load**: Many web destinations require at least one `analytics.page()` call to initialize. Analytics.js fires one automatically on `analytics.load()`, but SPAs need manual calls on route changes.

4. **`trackLink`/`trackForm` take DOM elements, not CSS selectors**: Passing a CSS selector string silently fails. Must pass the actual DOM element reference.

5. **Android SDK end-of-support**: The legacy Java Android SDK reaches end-of-support March 2026. Migrate to Analytics-Kotlin.

### Server & Serverless

6. **Node.js SDK requires new instance per Lambda invocation**: Reusing an Analytics instance across Lambda invocations produces "Overlapping flush calls" warnings. Create a fresh instance each time.

7. **Must `await analytics.flush()` before serverless function exits**: Events are batched (default: 15 messages or 10 seconds). Serverless functions exit before the flush interval — you must flush explicitly.

8. **EU workspace endpoint differs**: EU workspaces must use `eu1.api.segmentapis.com`. Using the standard `api.segment.io` endpoint silently fails for EU workspaces.

### Destinations

9. **Destination Filters are Business Tier only**: Cannot conditionally filter events per-destination on lower tiers. Use the `integrations` object in code as a free-tier alternative for basic routing.

10. **Destination Filters ignore Event Tester events**: Events sent via Event Tester bypass all destination filters by design. This shows raw data but can mislead filter validation.

11. **Blocked traits still flow to device-mode destinations**: Schema-level trait blocking only works for cloud-mode. Device-mode destinations receive blocked traits regardless.

12. **Max 10 filters per destination**: Destination Filters are capped at 10 per source-destination pair.

13. **Filter names cannot contain properties with spaces**: Cannot filter on property or trait names containing spaces. Use Insert Functions for these cases.

14. **Batch failures mark all events with same status**: In bulk batching, if any event in the batch fails, the entire batch may be marked as failed (error amplification).

15. **Replay is Business Tier only**: Cannot replay historical data to destinations on lower tiers. Lost events are unrecoverable.

### Functions Runtime

16. **5-second execution timeout**: All three Function types (Source, Destination, Insert) time out at 5 seconds. External API calls within Functions must be fast.

17. **Global variables leak across instances**: Functions run on AWS Lambda. Settings declared as global variables leak between function instances sharing the same codebase. Declare settings variables inside the handler function (`onRequest`, `onTrack`, etc.).

18. **Source Functions accept POST only**: GET requests to a Source Function webhook are rejected. Configure third-party webhooks accordingly.

19. **Insert Functions must return the event**: If an Insert Function handler doesn't `return event`, the event is silently dropped. Removing a handler entirely blocks that event type.

20. **Insert Functions cannot change events to match mapping triggers**: The trigger check happens on the original event before the Insert Function runs. Modifying an event in an Insert Function cannot cause it to match a trigger it didn't previously match.

21. **`console.log` only visible for errors in Destination Functions**: Successful event logs from Destination Functions are not visible in Event Delivery. Only errored payloads show logs.

22. **Twilio SDK version in Functions is pinned at v3.68.0**: The `twilio` package in the Functions runtime is version 3.68.0. Features from newer Twilio SDK versions are not available without workarounds.

### Data & Timing

23. **`sentAt` timestamp changes offline event behavior**: New Swift/Kotlin/C# SDKs add `sentAt` at batch delivery time, not event creation time. Events queued offline will have timestamps reflecting receive time, not occurrence time.

24. **Debugger shows sampled events only (max 500)**: The Source Debugger is not exhaustive. Attach a raw storage destination (warehouse or S3) for reliable records.

25. **Schema blocking takes up to 6 hours for full propagation**: While most blocking takes effect immediately, rare cases require up to 6 hours. Do not rely on instant blocking for compliance-critical flows.

26. **Rate limit: 1,000 req/sec per workspace**: The HTTP Tracking API caps at 1,000 requests per second per workspace. Batch endpoint accepts up to 500 KB per request with 32 KB per individual event.

27. **`messageId` 100-char limit is not enforced at ingestion**: Docs claim 100-char max, but live testing shows 150-char messageIds are accepted with 200 OK. Downstream processing behavior with oversized messageIds is undefined. [Evidence: live test — 150-char messageId → 200 OK]

### API & Auth

28. **Invalid write keys return 200 OK (silent data loss)**: The HTTP Tracking API returns `{"success": true}` for any non-empty write key, even completely invalid ones. Only a missing key (no auth) returns 400. Events sent with wrong write keys are silently dropped. This is the most dangerous silent failure mode in Segment. [Evidence: live test — `totally-not-a-key` → 200 OK, empty auth → 400]

29. **Public API invalid token returns 403, not 401**: Documentation implies 401 for unauthorized. Actual behavior: invalid bearer tokens return `403 Forbidden` with `{"errors":[{"type":"forbidden","message":"Not authorized to perform this operation"}]}`. [Evidence: live test]

30. **Public API is server-side only**: Calling the Public API from browser-side code produces CORS errors. Server-side calls with an `Origin` header still succeed (CORS is browser-enforced). [Evidence: live test with Origin header → 200]

31. **Config API token creation disabled**: As of Feb 2024, new Config API tokens cannot be created in the Segment app. Migrate to Public API. Contact `friends@segment.com` for exceptions.

32. **GitHub Secret Scanning auto-revokes exposed tokens**: If a Segment Public API token appears in a public GitHub repository, it is automatically revoked.

33. **`messageId` over 100 chars is silently accepted**: Despite docs stating 100 char max, a 150-char messageId returns 200 OK with no error. Behavior of downstream processing with oversized messageIds is undefined. [Evidence: live test — 150-char messageId → 200 OK]

34. **GET requests to Tracking API return misleading error**: `GET /v1/track` returns `{"success":false,"message":"malformed JSON"}` rather than a method-not-allowed error. Debug by checking HTTP method, not just the error message. [Evidence: live test]

## Related Resources

### Segment Documentation
- [Connections Overview](https://www.twilio.com/docs/segment/connections)
- [Sources](https://www.twilio.com/docs/segment/connections/sources)
- [Destinations](https://www.twilio.com/docs/segment/connections/destinations)
- [Functions](https://www.twilio.com/docs/segment/connections/functions)
- [Reverse ETL](https://www.twilio.com/docs/segment/connections/reverse-etl)
- [Segment Spec](https://www.twilio.com/docs/segment/connections/spec)
- [Public API](https://www.twilio.com/docs/segment/public-api)
- [Rate Limits](https://www.twilio.com/docs/segment/connections/rate-limits)

### Related Skills
- `/event-streams` — Twilio Event Streams can deliver events to Segment sinks. See Event Streams skill for sink configuration.

### MCP Tools (P2 Tier — 50 tools)
- **Management** (42 tools): `segment_get_workspace`, `segment_create_source`, `segment_list_sources`, `segment_get_source`, `segment_update_source`, `segment_delete_source`, `segment_create_write_key`, `segment_delete_write_key`, `segment_create_destination`, `segment_list_destinations`, `segment_get_destination`, `segment_update_destination`, `segment_delete_destination`, `segment_list_destination_subscriptions`, `segment_get_delivery_metrics`, `segment_create_destination_filter`, `segment_list_destination_filters`, `segment_update_destination_filter`, `segment_delete_destination_filter`, `segment_preview_destination_filter`, `segment_create_function`, `segment_list_functions`, `segment_get_function`, `segment_update_function`, `segment_delete_function`, `segment_deploy_function`, `segment_list_function_versions`, `segment_restore_function_version`, `segment_create_tracking_plan`, `segment_list_tracking_plans`, `segment_get_tracking_plan`, `segment_update_tracking_plan`, `segment_delete_tracking_plan`, `segment_list_tracking_plan_rules`, `segment_update_tracking_plan_rules`, `segment_list_source_catalog`, `segment_list_destination_catalog`, `segment_get_source_metadata`, `segment_get_destination_metadata`, `segment_get_events_volume`, `segment_get_daily_api_calls`, `segment_get_daily_mtu`
- **Tracking** (8 tools): `segment_identify`, `segment_track`, `segment_page`, `segment_screen`, `segment_group`, `segment_alias`, `segment_batch`, `segment_validate_tracking`
- Requires `SEGMENT_API_KEY` (management) and/or `SEGMENT_WRITE_KEY` (tracking) in `.env`

## Reference Files

| Topic | File | When to Read |
|-------|------|-------------|
| Segment Spec (6 API calls, common fields, payloads) | `references/spec-reference.md` | When constructing Segment API calls or understanding event structure |
| Functions (Source, Destination, Insert — runtime, dependencies, patterns) | `references/functions-reference.md` | When writing custom Segment Functions |
| APIs (HTTP Tracking, Public API, Config API) | `references/api-reference.md` | When integrating with Segment APIs directly |
| Assertion audit log | `references/assertion-audit.md` | When verifying claims made in this skill |
| MCP tools spec | `references/mcp-tools-spec.md` | When implementing Segment MCP tools (50 tools across 3 files) |
