---
name: "sync"
description: "Twilio development skill: sync"
---

---
name: sync
description: Twilio Sync development guide. Use when building real-time state synchronization, key-value stores, ordered lists, ephemeral messaging, or choosing between Documents, Lists, Maps, and Streams.
---

<!-- verified: twilio.com/docs/sync/api, twilio.com/docs/sync/api/document-resource, twilio.com/docs/sync/api/list-resource, twilio.com/docs/sync/api/listitem-resource, twilio.com/docs/sync/api/map-resource, twilio.com/docs/sync/api/map-item-resource, twilio.com/docs/sync/api/stream-resource, twilio.com/docs/sync/api/stream-message-resource, twilio.com/docs/sync/limits + live testing 2026-03-25 -->

# Twilio Sync

Real-time state synchronization via four primitives: Documents (single JSON objects), Lists (ordered collections), Maps (key-value stores), and Streams (ephemeral pub/sub). Covers data type selection, TTL lifecycle, conflict resolution, MCP tool coverage, and error handling.

Evidence date: 2026-03-25. Account prefix: AC... Service: IS8d793d.

> **WARNING: Slash characters in Map keys cause silent data loss.** Keys containing `/` can be created but cannot be fetched, updated, or deleted via REST API or MCP tools. They become permanently orphaned. The MCP `add_sync_map_item` tool validates against this. See Gotcha #5.

## Scope

### CAN

- Store JSON state in Documents (single mutable objects, up to 16 KiB) <!-- verified: ETf6783d -->
- Append-only ordered items in Lists (auto-indexed, up to 1M items per list) <!-- verified: ES0251800d -->
- Key-value lookups in Maps (string keys up to 320 chars, up to 1M items per map) <!-- verified: MPd79ca1ac -->
- Fire-and-forget pub/sub via Streams (ephemeral, max 4 KiB per message)
- TTL on all object types: 0–31,536,000 seconds (0 = no expiry) <!-- verified: ETccd0ec2d, 10s TTL enforced within 15s -->
- Per-item TTL on List items and Map items independent of parent container TTL <!-- verified: ES0251800d, item dateExpires=null with parent TTL active -->
- `collectionTtl` on item operations to reset parent container's TTL (keep-alive pattern) <!-- verified: ES65f9bb08, parent expiry reset from 22:54:58 to 22:56:42 -->
- Conditional updates via `If-Match` header with revision string (optimistic concurrency) <!-- verified: ETf6783d, revision "1" matched, "0" rejected with 54103 -->
- Webhook events for all CRUD operations on Documents, Lists, Maps, and Streams
- Access documents/lists/maps/streams by SID or UniqueName interchangeably in URL paths <!-- verified: all tests used uniqueName in MCP tools -->
- Documents without uniqueName (SID-only access) <!-- verified: ETc9642713 -->
- List items with `order` (asc/desc) and `from` (index) query params for pagination <!-- verified: ES0251800d, order=desc returned 4,2,0; from=2 returned 2,4 -->
- Map items with `order` (asc/desc) and `from` (key) query params for pagination (REST API only; MCP `list_sync_maps` does not expose these)
- Unicode and special characters in Map keys (dots, accented characters) <!-- verified: MPd79ca1ac, "key.with.dots" and "émoji-café-naïve" both work -->
- Empty object `{}` as valid Document data <!-- verified: ETc9642713 -->

### CANNOT

<!-- verified: all CANNOT items live-tested 2026-03-25 unless noted -->

- **No merge/patch updates** — Document and Map Item updates are full replacement. Updating `{theme: "light"}` on a document containing `{theme: "dark", version: "1.0", nested: {key: "value"}}` produces `{theme: "light"}` — the other fields are gone. Read-modify-write is required for partial updates. <!-- verified: ETf6783d, version and nested keys lost -->
- **No arbitrary List index insertion** — List indices are append-only. You cannot insert at a specific position. Indices are non-contiguous after deletions and never reused. After adding items 0,1,2, deleting 1, the next item gets index 4 (not 1 or 3). <!-- verified: ES0251800d -->
- **No upsert on Map items** — `add_sync_map_item` (create) errors with 54208 if the key exists. You must use `update_sync_map_item` for existing keys. This is NOT a set-or-create operation. <!-- verified: MPd79ca1ac, "An Item with given key already exists" -->
- **No slash characters in Map keys** — Keys containing `/` can be created but **cannot be individually fetched, updated, or deleted** via REST API because the slash is interpreted as a URL path separator. They become orphaned — visible only via list/validate operations. This applies to both MCP tools and direct REST calls. <!-- verified: MPd79ca1ac, "key/with/slashes" created OK, get/remove returns "Parameter 'key' is not valid" -->
- **Stream messages are not persisted** — No fetch, list, update, or delete operations exist. Messages are fire-and-forget with no delivery guarantee and no ordering guarantee. Max 30 msg/s per stream. <!-- verified: twilio.com/docs/sync/api/stream-message-resource -->
- **MCP Stream tools cover lifecycle and publish only** — `create_sync_stream`, `list_sync_streams`, `delete_sync_stream`, and `publish_stream_message` are available via MCP. Stream messages themselves cannot be fetched, updated, or deleted (they are ephemeral).
- **`delete_sync_map` MCP tool exists** — Maps can be deleted via MCP (`mcp__twilio__delete_sync_map`) or REST API (`DELETE /v1/Services/{ServiceSid}/Maps/{MapSid}`, returns 204).
- **No conditional updates via MCP** — `If-Match` header for optimistic concurrency is REST-only. MCP update tools always perform unconditional last-write-wins. <!-- verified: MCP tool schemas have no ifMatch/revision parameter -->
- **No `get_sync_list` or `get_sync_map` MCP tools** — Cannot fetch container metadata (revision, dateExpires) via MCP. Use `validate_sync_list` / `validate_sync_map` as a workaround.
- **No `get_sync_list_item` MCP tool** — Cannot fetch a single List item by index via MCP. Use `list_sync_list_items` with `from` param as a workaround.
- **TTL enforcement is not instantaneous** — Twilio docs say "there can be a delay between the expiration time and the resource's deletion." In practice, enforcement is prompt (10s TTL gone within 15s), but do not rely on exact-second deletion. <!-- verified: ETccd0ec2d expired within 15s of 10s TTL -->
- **Write rate degrades with payload size** — Sustained 20 writes/s per object for small payloads. Objects >1 KiB face stricter limits; 10 KiB+ capped at 2 writes/s. Stream messages >3 KiB capped at 7 msg/s. <!-- verified: twilio.com/docs/sync/limits -->

### Beyond Platform: Real-Time Dashboards

Sync provides the **data transport layer** for real-time dashboards (Documents for agent state, Maps for queue metrics, Streams for event feeds), but the dashboard itself — UI, visualization, aggregation, filtering — is entirely your application. Twilio does not provide a workforce management dashboard. Common pattern: Sync webhooks push state changes to your web app via WebSocket, which renders them in a frontend framework (React, Vue, etc.).

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Call state across webhooks | Document per CallSid with TTL | Single mutable object, predictable name, auto-cleanup |
| Configuration / settings | Document with uniqueName | Simple key-value, fetch by name |
| Activity feed / event log | List with TTL | Ordered, append-only, paginate with `order=desc` |
| User sessions / presence | Map with item TTL | Key per user, independent expiry per item |
| Real-time typing indicators | Stream | Ephemeral, no persistence needed |
| Payment state tracking | Document (polled by name) | Agent server polls document by well-known name |
| Queue of work items | List | Ordered, process from index 0, remove after processing |
| Feature flags / config store | Map | Key per flag, update independently |
| Temporary test validation | Document with 24h TTL | Callback logging, auto-cleanup |

## Decision Frameworks

### Data Type Selection

| Criterion | Document | List | Map | Stream |
|-----------|----------|------|-----|--------|
| Data model | Single JSON object | Ordered JSON items | Keyed JSON items | Ephemeral JSON messages |
| Max data size | 16 KiB total | 16 KiB per item | 16 KiB per item | 4 KiB per message |
| Max items | 1 (it's one object) | 1,000,000 | 1,000,000 | N/A (not stored) |
| Access pattern | By name/SID | By index or range | By key | Subscribe only |
| Ordering | N/A | Insertion order (indices) | Lexicographic by key | None guaranteed |
| TTL support | On document | On list + per item | On map + per item | On stream |
| Webhook events | create/update/remove | create/remove + item add/update/remove | create/remove + item add/update/remove | message_published |
| MCP tool coverage | Full CRUD | Most operations (no single-item fetch) | Most operations (no container fetch) | Create, list, delete stream + publish message |
| Conflict resolution | Last-write-wins (or If-Match) | Last-write-wins per item | Last-write-wins per item | N/A |

### TTL Strategy

| Scenario | TTL approach | Why |
|----------|-------------|-----|
| Call-scoped state | Document TTL = 1 hour | Call won't last longer; auto-cleanup |
| Test validation data | Document TTL = 24 hours | Enough time to inspect, then gone |
| User presence with heartbeat | Map item TTL = 5 min, refresh on heartbeat | Auto-offline if heartbeat stops |
| Activity feed with retention | List TTL = 7 days | Keep recent history, auto-prune |
| Long-lived configuration | No TTL (ttl=0) | Persist until explicitly deleted |
| Keep-alive on active lists | `collectionTtl` on item writes | Parent container stays alive while items flow |

### When to Use If-Match (Conditional Updates)

| Scenario | Use If-Match? | Why |
|----------|--------------|-----|
| Multiple writers to same document | Yes | Prevents silent overwrites, detects conflicts |
| Single writer (webhook handler) | No | Only one writer, no conflict possible |
| Append-only list items | No | Each item gets a unique index, no conflicts |
| Map items with known ownership | No | One writer per key, last-write-wins is fine |
| Counter/accumulator patterns | Yes | Read-modify-write needs atomicity |

Note: If-Match requires REST API. MCP tools always use unconditional writes.

## MCP Tool Reference

### Documents (5 tools — full CRUD)

| Tool | Operation | Key params |
|------|-----------|-----------|
| `mcp__twilio__create_document` | Create | `uniqueName` (MCP-required; REST API allows omitting), `data` (required), `ttl` |
| `mcp__twilio__get_document` | Fetch | `documentSidOrName` |
| `mcp__twilio__update_document` | Update (full replace) | `documentSidOrName`, `data` (required), `ttl` |
| `mcp__twilio__delete_document` | Delete | `documentSidOrName` |
| `mcp__twilio__list_documents` | List all | `limit` (1–100, default 20) |

### Lists (7 tools — no single-item fetch, no container fetch)

| Tool | Operation | Key params |
|------|-----------|-----------|
| `mcp__twilio__create_sync_list` | Create list | `uniqueName`, `ttl` |
| `mcp__twilio__list_sync_lists` | List all lists | `limit` |
| `mcp__twilio__delete_sync_list` | Delete list + all items | `listSidOrName` |
| `mcp__twilio__add_sync_list_item` | Append item | `listSidOrName`, `data` (required), `ttl` |
| `mcp__twilio__list_sync_list_items` | List items | `listSidOrName`, `order` (asc/desc), `from` (index), `limit` |
| `mcp__twilio__update_sync_list_item` | Update item (full replace) | `listSidOrName`, `index`, `data` (required), `ttl` |
| `mcp__twilio__remove_sync_list_item` | Delete item | `listSidOrName`, `index` |

### Maps (7 tools — no container fetch)

| Tool | Operation | Key params |
|------|-----------|-----------|
| `mcp__twilio__create_sync_map` | Create map | `uniqueName`, `ttl` |
| `mcp__twilio__list_sync_maps` | List all maps | `limit` |
| `mcp__twilio__delete_sync_map` | Delete map + all items | `mapSidOrName` |
| `mcp__twilio__add_sync_map_item` | Create item (NOT upsert) | `mapSidOrName`, `key` (required), `data` (required), `ttl` |
| `mcp__twilio__get_sync_map_item` | Fetch item by key | `mapSidOrName`, `key` |
| `mcp__twilio__update_sync_map_item` | Update item (full replace) | `mapSidOrName`, `key`, `data` (required), `ttl` |
| `mcp__twilio__remove_sync_map_item` | Delete item by key | `mapSidOrName`, `key` |

### Streams (4 tools — create, list, delete stream + publish message)

| Tool | Operation | Key params |
|------|-----------|-----------|
| `mcp__twilio__create_sync_stream` | Create stream | `uniqueName`, `ttl` |
| `mcp__twilio__list_sync_streams` | List all streams | `limit` |
| `mcp__twilio__delete_sync_stream` | Delete stream | `streamSidOrName` |
| `mcp__twilio__publish_stream_message` | Publish message (ephemeral) | `streamSidOrName`, `data` (required, max 4 KiB) |

### Validation (3 tools)

| Tool | Purpose | Key params |
|------|---------|-----------|
| `mcp__twilio__validate_sync_document` | Verify document data structure | `documentSidOrName`, `expectedKeys`, `expectedTypes`, `strictKeys` |
| `mcp__twilio__validate_sync_list` | Verify list item count + structure | `listSidOrName`, `minItems`/`maxItems`/`exactItems`, `expectedItemKeys` |
| `mcp__twilio__validate_sync_map` | Verify map keys + value structure | `mapSidOrName`, `expectedKeys`, `expectedValueKeys` |

### MCP Gaps — REST API Required

| Operation | REST method | Notes |
|-----------|------------|-------|
| Fetch a List by SID | `GET /v1/Services/{ServiceSid}/Lists/{ListSid}` | For dateExpires, revision |
| Fetch a Map by SID | `GET /v1/Services/{ServiceSid}/Maps/{MapSid}` | For dateExpires, revision |
| Fetch single List item | `GET /v1/Services/{ServiceSid}/Lists/{ListSid}/Items/{Index}` | By index |
| Conditional update | Any update with `If-Match: {revision}` header | Optimistic concurrency |
| Fetch/update Sync Service | `GET/POST /v1/Services/{ServiceSid}` | webhookUrl, aclEnabled, etc. |

## Gotchas

### Data & Updates

1. **Updates are full replacement, not merge**: Both Document updates and Map Item updates replace the entire `data` object. If you update a document containing 5 fields with an object containing 1 field, the other 4 fields are permanently lost. Always read-modify-write for partial updates. [Evidence: ETf6783d, lost `version` and `nested` keys]

2. **Map add is not upsert**: `add_sync_map_item` / `create` returns error 54208 if the key already exists. For set-or-create semantics, catch the error and fall back to `update`, or fetch first to decide. [Evidence: MPd79ca1ac, 54208 on duplicate key]

3. **Revision is a string, not an integer**: Revisions look numeric ("0", "1", "2") but are returned as strings in the API. Don't compare with `===` against integers. [Evidence: ETf6783d, revision: "1"]

4. **Empty object `{}` is valid data**: Documents and items can hold empty JSON objects. This is not an error condition. [Evidence: ETc9642713]

### Map Keys

5. **Slashes in Map keys are a trap**: Keys containing `/` can be created successfully but become individually inaccessible — `get`, `update`, and `remove` all fail with "Parameter 'key' is not valid" because the REST API interprets `/` as a URL path separator. These orphaned items are only visible via list or validate operations. Avoid `/` in Map keys entirely. [Evidence: MPd79ca1ac, "key/with/slashes"]

6. **Map key max 320 characters (UTF-8)**: Same limit as UniqueName. Dots, hyphens, underscores, and Unicode characters all work. [Evidence: MPd79ca1ac, "key.with.dots" and "émoji-café-naïve" both OK]

### List Indices

7. **List indices are non-contiguous after deletions**: Deleting an item leaves a permanent gap. New items are appended with indices that may skip values unpredictably. After items 0,1,2 → delete 1 → next item gets index 4, not 1 or 3. Do not use List indices as array positions. [Evidence: ES0251800d, indices 0,2,4 after one deletion]

8. **List indices are never reused**: A deleted index is permanently consumed. Lists are not arrays — they are append-only logs with stable identifiers.

### TTL

9. **TTL enforcement is prompt but not instantaneous**: A 10-second TTL document was gone within 15 seconds. A 30-second TTL empty list was already expired when checked at ~25 seconds. Do not rely on exact-second deletion timing, but expect enforcement within seconds. [Evidence: ETccd0ec2d, EScbba2f88]

10. **`collectionTtl` on item operations resets parent's TTL**: Adding or updating an item with `collectionTtl=N` resets the parent List/Map's expiration to N seconds from the operation time — regardless of the original TTL value. This is a keep-alive mechanism. [Evidence: ES65f9bb08, parent expiry jumped from 22:54:58 to 22:56:42]

11. **`ttl` parameter is an alias**: On containers (List, Map, Stream), `ttl` aliases `collectionTtl`. On items, it aliases `itemTtl`. If both the alias and the specific parameter are provided, the alias is silently ignored. MCP tools expose only the `ttl` param (not `collectionTtl`/`itemTtl`), so via MCP you are always using the alias form. <!-- verified: twilio.com/docs/sync/api/listitem-resource -->

12. **Item TTL is independent of container TTL**: A List item can have `dateExpires: null` (no item TTL) while the parent List has an active TTL. The item outlives its container's original expiry only if collectionTtl is extended. [Evidence: ES0251800d, items with null dateExpires in list with 300s TTL]

13. **TTL-triggered deletions are free and rate-limit-exempt**: Manual deletes count toward the 20 creates/deletes per second per service limit. TTL-triggered deletions do not. Prefer TTL for cleanup of ephemeral data. <!-- verified: twilio.com/docs/sync/limits -->

### Webhooks

14. **`webhooksFromRestEnabled` defaults to false**: Webhooks only fire for SDK-originated mutations unless you explicitly enable REST webhook firing on the Sync Service. MCP tool writes are REST writes — they will not trigger webhooks unless this flag is enabled. <!-- verified: twilio.com/docs/sync/api/service -->

15. **Reachability webhooks fire on hourly rebalancing**: Twilio rebalances connections hourly, generating `endpoint_disconnected` → `endpoint_connected` webhook pairs that are NOT actual user disconnections. Use `reachabilityDebouncingEnabled` with a debounce window to filter these out. <!-- verified: twilio.com/docs/sync/webhooks -->

### Error Codes

16. **Not-found errors return generic 20404**: Document, List, Map, and item not-found errors all return error code 20404 ("The requested resource was not found"), not Sync-specific codes. The domain CLAUDE.md previously listed incorrect 54xxx codes for not-found errors. [Evidence: live curl tests on nonexistent doc, list, map item]

17. **Know the actual 54xxx codes**: The codes you will encounter in practice: 54006 (entity too large, HTTP 413), 54008 (invalid JSON/request body, HTTP 400), 54103 (revision mismatch on If-Match, HTTP 412), 54208 (duplicate Map key, HTTP 409), 54301 (uniqueName already exists, HTTP 409). [Evidence: all live-verified 2026-03-25]

### Rate Limits

18. **Write rate degrades with payload size**: Sustained 20 writes/s per object for small payloads. At 1 KiB+, limits tighten. At 10 KiB+, you're capped at 2 writes/s. Design accordingly — if you need high write throughput, keep payloads small. <!-- verified: twilio.com/docs/sync/limits -->

19. **Object creation/deletion rate is per service**: 20 objects/s per service, not per object type. Creating 20 documents/s leaves no room for creating lists or maps in the same second. <!-- verified: twilio.com/docs/sync/limits -->

### Burst Rate Limits

Sync enforces per-object write rate limits:
- **Documents**: 1 write/second per document
- **Map Items**: 1 write/second per item, 20 writes/second per map
- **List Items**: 1 write/second per item, 20 writes/second per list

**High-volume patterns** (e.g., call tracking writing attribution on every inbound call): use Sync Maps with unique keys per call instead of updating a single Document. For burst scenarios (100+ concurrent writes), consider:
- Fire-and-forget pattern: write asynchronously, don't block the TwiML response
- Use `batchWithRateLimit()` from `helpers/resilience-patterns.private.js` with `concurrency: 1, delayMs: 50`
- For analytics aggregation, batch writes via Event Streams → external datastore instead of direct Sync writes

### MCP-Specific

20. **`created_by` is always "system" for MCP/REST operations**: SDK operations show the token identity. This matters for audit trails and webhook payloads. [Evidence: ETc9642713, created_by: "system"]

21. **MCP `list_sync_list_items` supports order and from**: Unlike some MCP tools that strip query params, the Sync list items tool properly supports `order` (asc/desc) and `from` (index) for pagination. [Evidence: ES0251800d, order=desc returned 4,2,0]

### Production Monitoring

Sync operations can fail silently when called in fire-and-forget patterns (common in callback handlers and event pipelines). A Function that catches a Sync error and logs it continues executing — the call or message succeeds, but the data write is lost.

**Monitoring patterns:**
- **Wrap writes in try/catch with structured logging**: Log Sync failures to `console.log` (not `console.error` — see serverless invariants) with the operation type, key, and error code. Alert on error code patterns: 54006 (payload too large), 54007 (rate limit exceeded), 20404 (service/resource not found).
- **Periodic state validation**: Use `validate_sync_document`, `validate_sync_list`, or `validate_sync_map` MCP tools to verify expected state exists. Schedule validation checks after batch operations.
- **Rate limit awareness**: Sync enforces 1 write/second per Document, 20 operations/second per Service. If you observe 54007 errors, redesign the data model — use multiple Map items instead of a single Document with frequent updates.
- **Credential rotation**: After rotating `TWILIO_SYNC_SERVICE_SID` or auth credentials, redeploy all Functions that reference Sync. Deployed Functions cache environment variables at deploy time — changing `.env` without redeploying leaves Functions using stale SIDs, producing silent 20404 errors.

## Related Resources

- **Sync CLAUDE.md** (`CLAUDE.md`) — File inventory, action-routed pattern, SDK code examples, error handling patterns
- **Sync REFERENCE.md** (`REFERENCE.md`) — Detailed API examples, webhook events table, common patterns (call state, presence, activity feed)
- **Conference skill** (`skills/conference/SKILL.md`) — Uses Sync indirectly for call state in some patterns
- **Payments skill** (`skills/payments.md`) — `payment-status-sync.protected.js` uses Sync Document for real-time payment state polling
- **MCP tool reference** (`twilio/REFERENCE.md`) — Full tool inventory, response shape gotchas
- **Codebase functions**: `document-crud.protected.js`, `list-crud.protected.js`, `map-crud.protected.js`
- **Callback logger**: `sync-logger.private.js` — Shared utility for callback → Sync Document logging pattern

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Error codes | `references/error-codes.md` | Debugging Sync API errors, correcting wrong error code assumptions |
| Test results | `references/test-results.md` | Live test evidence with SID references for every behavioral claim |
| Assertion audit | `references/assertion-audit.md` | Adversarial audit of every factual claim with verdicts |
