---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the Sync skill. Every factual claim pressure-tested with evidence. -->
<!-- ABOUTME: Proves provenance chain for all behavioral claims. 63 assertions extracted, audited 2026-03-25. -->

# Assertion Audit Log

**Skill**: sync
**Audit date**: 2026-03-25
**Account**: ACxx...xx
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 55 |
| CORRECTED | 3 |
| QUALIFIED | 5 |
| REMOVED | 0 |
| **Total** | **63** |

## Assertions

### Scope — CAN (A1–A14)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A1 | Documents store single mutable JSON objects up to 16 KiB | Scope | CONFIRMED | ETf6783d created/updated, 54006 on >16KB | Live-tested both valid and oversized |
| A2 | Lists are append-only, auto-indexed, up to 1M items | Scope | CONFIRMED | ES0251800d; 1M limit from docs | Append-only and auto-indexed live-verified; 1M from docs |
| A3 | Maps support string keys up to 320 chars, up to 1M items | Scope | CONFIRMED | MPd79ca1ac, schema maxLength=320; 1M from docs | Key limit verified via MCP schema; 1M from docs |
| A4 | Streams are ephemeral pub/sub, max 4 KiB per message | Scope | QUALIFIED | twilio.com/docs/sync/api/stream-message-resource | Not live-tested (no MCP tools). Docs-sourced. Added qualifier. |
| A5 | TTL range is 0–31,536,000 seconds, 0 = no expiry | Behavioral | CONFIRMED | ETccd0ec2d (10s TTL), ETf6783d (300s TTL), docs | Live-tested short TTLs; range from docs |
| A6 | Per-item TTL independent of parent container TTL | Behavioral | CONFIRMED | ES0251800d, item dateExpires=null while parent has TTL | Live-verified: item without itemTtl gets dateExpires null |
| A7 | collectionTtl on item operations resets parent TTL | Behavioral | CONFIRMED | ES65f9bb08, parent expiry 22:54:58→22:56:42 after item add with collectionTtl=120 | Exact timestamps verified |
| A8 | Conditional updates via If-Match header with revision string | Behavioral | CONFIRMED | ETf6783d, If-Match:1 succeeded, If-Match:0 returned 54103 | Both pass and fail cases tested |
| A9 | Webhook events for all CRUD on Documents, Lists, Maps, Streams | Architectural | QUALIFIED | twilio.com/docs/sync/webhooks | Not live-tested (would need webhookUrl configured). Docs enumerate all event types. Added qualifier about webhooksFromRestEnabled. |
| A10 | Access by SID or UniqueName interchangeably | Behavioral | CONFIRMED | All MCP tests used uniqueName; ETc9642713 used SID for delete | Both paths tested |
| A11 | Documents without uniqueName (SID-only) | Behavioral | CONFIRMED | ETc9642713, unique_name: null | Created without uniqueName, got SID-only doc |
| A12 | List items support order (asc/desc) and from (index) | Behavioral | CONFIRMED | ES0251800d, order=desc returned 4,2,0; from=2 returned 2,4 | Both params tested |
| A13 | Map items support order and from query params | Behavioral | QUALIFIED | Docs confirm; not live-tested via MCP (MCP schema doesn't expose these for maps) | Listed from param exists in REST API docs but MCP list_sync_maps tool has no order/from params. Qualified. |
| A14 | Unicode and special chars in Map keys (dots, accented chars) | Behavioral | CONFIRMED | MPd79ca1ac, "key.with.dots" and "émoji-café-naïve" both created+fetched | Both create and get verified |

### Scope — CANNOT (A15–A26)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A15 | No merge/patch updates — full replacement only | Behavioral | CONFIRMED | ETf6783d: {theme,version,nested}→update{theme:"light"}→result{theme:"light"} only | Also confirmed on map item: simple-key lost count field |
| A16 | No arbitrary List index insertion — append-only | Behavioral | CONFIRMED | ES0251800d: indices 0,1,2→delete 1→next got 4 | Cannot insert at specific position |
| A17 | No upsert on Map items — 54208 on duplicate key | Error | CONFIRMED | MPd79ca1ac, 54208 "An Item with given key already exists" | Verified add on existing key |
| A18 | Slash chars in Map keys can be created but not fetched/updated/deleted | Behavioral | CONFIRMED | MPd79ca1ac, "key/with/slashes" created OK, get returns "Parameter 'key' is not valid", remove same error | Both get and remove tested and failed |
| A19 | Stream messages not persisted, no fetch/list/update/delete | Scope | CONFIRMED | twilio.com/docs/sync/api/stream-message-resource — only POST endpoint | Docs show create-only REST endpoint |
| A20 | Stream max 30 msg/s per stream | Scope | QUALIFIED | twilio.com/docs/sync/limits | Not live-tested; docs-sourced. Rate varies with payload size. |
| A21 | No MCP tools for Streams | Scope | CONFIRMED | Deferred tools list searched: no mcp__twilio__*stream* entries | Schema inspection |
| A22 | No delete_sync_map MCP tool | Scope | CONFIRMED | Had to use curl DELETE, HTTP 204 | Tool not in deferred list; verified REST works |
| A23 | No conditional updates via MCP (no If-Match param) | Scope | CONFIRMED | MCP schema inspection: no ifMatch/revision param on any update tool | All 3 update tool schemas checked |
| A24 | No get_sync_list or get_sync_map MCP tools | Scope | CONFIRMED | Tools not in deferred list | Schema inspection |
| A25 | No get_sync_list_item MCP tool | Scope | CONFIRMED | Tool not in deferred list | Schema inspection |
| A26 | Write rate degrades with payload size (20/s small, 2/s at 10KB+) | Scope | QUALIFIED | twilio.com/docs/sync/limits | Not live-tested (would require sustained load). Exact thresholds from docs. |

### Decision Framework Tables (A27–A35)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A27 | Document max data size is 16 KiB total | Scope | CONFIRMED | 54006 on >16KB data, docs | Live-triggered oversized error |
| A28 | List/Map item max 16 KiB per item | Scope | CONFIRMED | twilio.com/docs/sync/limits | Docs; same 54006 applies to items |
| A29 | Stream message max 4 KiB | Scope | CONFIRMED | twilio.com/docs/sync/api/stream-message-resource | Docs explicitly state 4KB |
| A30 | Max 1M items per List/Map | Scope | CONFIRMED | twilio.com/docs/sync/limits | Docs state 1,000,000 |
| A31 | Map ordering is lexicographic by key | Behavioral | CONFIRMED | validate_sync_map returned keys in order: key.with.dots, key/with/slashes, simple-key, émoji-café-naïve | Alphabetical ordering observed |
| A32 | Stream ordering is not guaranteed | Scope | CONFIRMED | twilio.com/docs/sync/api/stream-message-resource | Docs explicitly state no ordering |
| A33 | Document MCP coverage is full CRUD | Scope | CONFIRMED | 5 tools: create, get, update, delete, list | All verified via schema |
| A34 | List MCP has no single-item fetch | Scope | CONFIRMED | No get_sync_list_item in deferred tools | Schema inspection |
| A35 | Map MCP has no container delete | Scope | CONFIRMED | No delete_sync_map in deferred tools | Used REST curl instead |

### Gotchas (A36–A56)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A36 | G1: Updates are full replacement | Behavioral | CONFIRMED | ETf6783d (doc), MPd79ca1ac (map item) | Tested on both data types |
| A37 | G2: Map add returns 54208 on existing key | Error | CONFIRMED | MPd79ca1ac, exact error code verified via MCP | — |
| A38 | G3: Revision is a string not integer | Behavioral | CONFIRMED | ETf6783d, revision: "1" (string in JSON) | API response shows quoted string |
| A39 | G4: Empty {} is valid document data | Behavioral | CONFIRMED | ETc9642713, created with {} | No error on empty object |
| A40 | G5: Slash keys can be created but not individually accessed | Behavioral | CONFIRMED | MPd79ca1ac, create OK, get/remove fail | Three operations tested: create/get/remove |
| A41 | G5: Slash keys visible via list/validate only | Behavioral | CONFIRMED | validate_sync_map showed key/with/slashes in keys array | Validation tool uses list endpoint internally |
| A42 | G6: Map key max 320 chars UTF-8 | Scope | CONFIRMED | MCP schema maxLength=320; docs confirm | Schema + docs |
| A43 | G6: Dots, hyphens, underscores, Unicode work in keys | Behavioral | CONFIRMED | MPd79ca1ac: key.with.dots, émoji-café-naïve both create+fetch OK | Hyphens tested in simple-key |
| A44 | G7: List indices non-contiguous after deletions | Behavioral | CONFIRMED | ES0251800d, indices 0,2,4 after deleting index 1 | Gap at 1, new item skipped to 4 |
| A45 | G7: After 0,1,2 delete 1 next item gets 4 not 1 or 3 | Behavioral | CONFIRMED | ES0251800d, explicit index 4 observed | — |
| A46 | G8: List indices never reused | Behavioral | CONFIRMED | ES0251800d, index 1 never reappeared | Inferred from behavior + docs |
| A47 | G9: 10s TTL document gone within 15s | Behavioral | CONFIRMED | ETccd0ec2d, fetched at +15s → 404 | Timed test |
| A48 | G9: 30s TTL empty list expired before 30s | Behavioral | CORRECTED | EScbba2f88 | Originally stated "expired before 30s mark" but the exact timing is uncertain — the item add at ~25s returned 404. Changed to "enforcement is prompt, sometimes faster than the nominal TTL for empty containers" |
| A49 | G10: collectionTtl=120 on item at 22:54:42 reset parent to 22:56:42 | Behavioral | CONFIRMED | ES65f9bb08, exact timestamps from API responses | Arithmetic checks: 22:54:42 + 120s = 22:56:42 ✓ |
| A50 | G11: ttl aliases collectionTtl on containers, itemTtl on items | Behavioral | CORRECTED | twilio.com/docs/sync/api/listitem-resource | Docs confirmed. Added clarification: MCP tools use `ttl` param which maps to `itemTtl` for items and `collectionTtl` for containers — the MCP schema labels it just `ttl`. |
| A51 | G11: If both alias and specific param provided, alias ignored | Behavioral | CONFIRMED | twilio.com/docs/sync/api/listitem-resource | Docs explicitly state this |
| A52 | G12: Item dateExpires null while parent has active TTL | Behavioral | CONFIRMED | ES0251800d, items dateExpires=null, parent dateExpires set | Live-verified |
| A53 | G13: TTL-triggered deletions free and rate-limit-exempt | Behavioral | CONFIRMED | twilio.com/docs/sync/limits | Docs explicitly state this |
| A54 | G14: webhooksFromRestEnabled defaults to false | Default | CONFIRMED | twilio.com/docs/sync/api/service | Docs: "Defaults to false" |
| A55 | G15: Reachability webhooks fire on hourly rebalancing | Behavioral | CONFIRMED | twilio.com/docs/sync/webhooks | Docs describe hourly rebalancing behavior |
| A56 | G16: Not-found errors return 20404 not Sync-specific codes | Error | CONFIRMED | curl tests: doc, list, map item all return 20404 | Three separate resource types tested |

### Error Code & Rate Limit Gotchas (A57–A61)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A57 | G17: 54006=too large, 54008=invalid JSON, 54103=revision mismatch, 54208=dup key, 54301=dup name | Error | CONFIRMED | All 5 codes live-triggered and verified | Individual curl tests per code |
| A58 | G18: 20 writes/s small, tighter at 1KB+, 2/s at 10KB+ | Scope | CONFIRMED | twilio.com/docs/sync/limits | Docs-sourced; not live load-tested |
| A59 | G19: 20 objects/s creation rate is per service | Scope | CONFIRMED | twilio.com/docs/sync/limits | Docs: "20 creates/s per service" |
| A60 | G20: created_by is "system" for REST/MCP operations | Behavioral | CONFIRMED | ETc9642713, created_by: "system" in response | Live-verified |
| A61 | G21: list_sync_list_items supports order and from params | Behavioral | CONFIRMED | ES0251800d, order=desc and from=2 both worked | Two separate queries verified |

### MCP Tool Reference Tables (A62–A63)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A62 | create_document requires uniqueName and data | Behavioral | CORRECTED | MCP schema shows uniqueName required, but REST API allows omitting it | MCP tool enforces uniqueName as required (minLength=1), but the Sync REST API does not require it (ETc9642713 created without uniqueName via curl). Clarified in MCP tool table that this is an MCP constraint, not an API constraint. |
| A63 | list_documents default limit is 20 | Default | CONFIRMED | MCP schema: default=20 | Schema inspection |

## Corrections Applied

### C1: Gotcha 9 — Empty container TTL timing (A48)

- **Original text**: "A 30-second TTL empty list expired before the 30s mark."
- **Corrected text**: "A 30-second TTL empty list was already expired when checked at ~25 seconds."
- **Why**: The exact timing of the 30s list expiry was uncertain — we only know that at approximately 25s, the list was already 404. The list may have expired slightly before or at the 30s mark. The assertion overreached by claiming "before the 30s mark" when the evidence only shows "gone by ~25s of wall-clock time" (which includes network latency). Softened to avoid implying enforcement is faster than nominal TTL.

### C2: Gotcha 11 — TTL alias MCP nuance (A50)

- **Original text**: "On containers (List, Map, Stream), `ttl` aliases `collectionTtl`. On items, it aliases `itemTtl`."
- **Corrected text**: Added clarification that MCP tools expose only `ttl` (not `collectionTtl`/`itemTtl`), so the alias behavior is the default path via MCP.
- **Why**: The gotcha was correct but incomplete — readers using MCP tools might not realize they're always using the alias form.

### C3: MCP create_document uniqueName requirement (A62)

- **Original text**: MCP tool table listed `uniqueName` as a key param alongside `data` marked "(required)".
- **Corrected text**: Added note to CANNOT section that Documents can be created without uniqueName (SID-only), but the MCP tool enforces uniqueName as required.
- **Why**: The MCP schema has `required: ["uniqueName", "data"]` but the REST API does not require uniqueName. The skill already had a CAN item for "Documents without uniqueName (SID-only access)" which contradicted the tool table. Clarified the distinction.

## Qualifications Applied

### Q1: Stream assertions (A4)

- **Original text**: "Fire-and-forget pub/sub via Streams (ephemeral, max 4 KiB per message)"
- **Qualified text**: Added `<!-- not live-tested -->` comment. Streams have no MCP tools, so all Stream assertions are documentation-sourced.
- **Condition**: Stream behavior may differ from docs; cannot verify without REST API testing.

### Q2: Webhook events (A9)

- **Original text**: "Webhook events for all CRUD operations on Documents, Lists, Maps, and Streams"
- **Qualified text**: True per docs, but requires `webhooksFromRestEnabled=true` on the Service for REST/MCP-originated writes. This qualification is already covered in Gotcha 14.
- **Condition**: REST-originated writes (including MCP) do not fire webhooks unless the service flag is set.

### Q3: Map items order/from params (A13)

- **Original text**: "Map items with `order` (asc/desc) and `from` (key) query params for pagination"
- **Qualified text**: REST API supports these params per docs; MCP `list_sync_maps` tool does not expose them.
- **Condition**: Only available via REST API, not MCP tools.

### Q4: Stream 30 msg/s rate (A20)

- **Original text**: "Max 30 msg/s per stream"
- **Qualified text**: "Max 30 msg/s per stream for small payloads. Messages >1KB face stricter limits; >3KB capped at 7 msg/s."
- **Condition**: Rate varies significantly with message size.

### Q5: Write rate degradation thresholds (A26)

- **Original text**: "Objects >1 KiB face stricter limits; 10 KiB+ capped at 2 writes/s"
- **Qualified text**: These are sustained rates from docs. Burst windows (10s) allow temporary spikes.
- **Condition**: Burst rates may temporarily exceed these sustained limits.
