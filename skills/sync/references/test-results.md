---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Live test evidence for Sync skill assertions. Every behavioral claim traces back to a SID. -->
<!-- ABOUTME: Use when verifying skill claims or reproducing test scenarios. -->

# Sync Skill — Live Test Results

Evidence date: 2026-03-25. Account: ACxx...xx. Service: IS8d793d6cb78bcc3367d66a7eb9ab1f0b.

All tests run via MCP tools and direct REST API (`curl`). Resources cleaned up after testing.

## Test 1: Document CRUD

| Operation | Result | Evidence |
|-----------|--------|----------|
| Create with uniqueName + TTL (300s) | SID `ETf6783d3629b37c7aef74caa92081bf9e`, `dateExpires` set 5min out | ETf6783d |
| Create without uniqueName | Works, `unique_name: null`, `created_by: "system"` | ETc9642713abdd05e9dd1436aef2d91489 |
| Create with empty `{}` data | Valid, revision "0" | ETc9642713 |
| Fetch by uniqueName | Returns full document with data, revision, dates | ETf6783d |
| Fetch nonexistent | Error 20404 "resource was not found" (NOT 54100) | curl test |
| Update (full replace test) | Original: `{theme,version,nested}` → update `{theme:"light"}` → result: `{theme:"light"}` only. **Confirmed full replace.** | ETf6783d |
| Update increments revision | "0" → "1" after update | ETf6783d |
| Delete by uniqueName | Success | ETf6783d |
| Delete by SID | Success | ETc9642713 |
| Duplicate uniqueName | Error 54301 "Unique name already exists" (HTTP 409) | curl test |

## Test 2: TTL Enforcement

| Test | Setup | Result | Evidence |
|------|-------|--------|----------|
| Short TTL expiry | Document with `ttl=10` | Gone within 15 seconds (fetched at +15s → 404) | ETccd0ec2d806036981dc4de26a9278984 |
| Empty container TTL | List with `ttl=30` | Expired before 30s mark (item add at ~25s → 404) | EScbba2f8800dd0d4a8c5485f525867368 |
| `dateExpires` accuracy | Document `ttl=10`, created 22:51:03 | `dateExpires: 22:51:13` (exact +10s) | ETccd0ec2d |
| `dateExpires` on container | List `ttl=300`, created 22:49:27 | `dateExpires: 22:54:27` (exact +300s) | ES0251800d |
| Item without `itemTtl` | Added to list with parent TTL | `dateExpires: null` on item | ES0251800d, index 0 |

## Test 3: collectionTtl Reset

| Step | Timestamp | State | Evidence |
|------|-----------|-------|----------|
| Create list with `ttl=60` | 22:53:58 | `dateExpires: 22:54:58` | ES65f9bb08c02020bb81c4d538401675b0 |
| Wait 30 seconds | 22:54:28 | List should expire in ~30s | — |
| Add item with `collectionTtl=120` | 22:54:42 | Item `dateExpires: null` (no itemTtl) | ES65f9bb08, index 0 |
| Check parent list | 22:54:42 | `dateExpires: 22:56:42` (**reset to item_time + 120s**) | ES65f9bb08 |

**Confirmed**: `collectionTtl` on item write resets parent's expiration to `now + collectionTtl`, regardless of original TTL.

## Test 4: List Index Behavior

| Operation | Index Assigned | Evidence |
|-----------|---------------|----------|
| Add item 1 | 0 | ES0251800de6ccbaeab0c4ce903ee5709c |
| Add item 2 | 1 | ES0251800d |
| Add item 3 | 2 | ES0251800d |
| Delete index 1 | — | ES0251800d |
| Add item 4 | **4** (skipped 3) | ES0251800d |
| List all (asc) | Returns indices 0, 2, 4 | ES0251800d |
| List all (desc) | Returns indices 4, 2, 0 | ES0251800d |
| List from=2 (asc) | Returns indices 2, 4 (inclusive) | ES0251800d |

**Confirmed**: Indices are non-contiguous, never reused, new indices may skip values.

## Test 5: Map Key Characters

All tests on map `MPd79ca1ac4adc289b0f342744c59212d8`.

| Key | Create | Get | Update | Remove |
|-----|--------|-----|--------|--------|
| `simple-key` | ✓ | ✓ | ✓ (full replace confirmed: lost `count` field) | ✓ |
| `key/with/slashes` | ✓ | ✗ "Parameter 'key' is not valid" | ✗ same | ✗ same |
| `key.with.dots` | ✓ | ✓ | not tested | not tested |
| `émoji-café-naïve` | ✓ | ✓ | not tested | not tested |

**Confirmed**: Slashes break individual access. Dots and Unicode work. Slash-keyed items visible in `validate_sync_map` output (uses list endpoint).

## Test 6: Map Upsert Behavior

| Operation | Result | Evidence |
|-----------|--------|----------|
| `add_sync_map_item` with existing key | Error 54208 "An Item with given key already exists in the Map" (HTTP 409) | MPd79ca1ac |
| `update_sync_map_item` on existing key | Success, full replace | MPd79ca1ac, key "simple-key" |
| `update_sync_map_item` on nonexistent key | Error 20404 "resource was not found" | MPd79ca1ac, key "nonexistent-key" |

**Confirmed**: Add is NOT upsert. Must use update for existing keys.

## Test 7: Conditional Updates (If-Match)

All tests on document `ETf6783d3629b37c7aef74caa92081bf9e` (revision "1" at time of test).

| If-Match Value | Result | Evidence |
|----------------|--------|----------|
| `0` (wrong) | Error 54103 "revision does not match" (HTTP 412) | curl test |
| `1` (correct) | Success, revision incremented to "2" | curl test |
| Omitted | Success, unconditional write (last-write-wins) | MCP tool update |

**Confirmed**: `If-Match` header works for optimistic concurrency. MCP tools always omit it.

## Test 8: Error Code Verification

All via direct `curl` to capture raw JSON responses:

| Trigger | Code | HTTP | Message |
|---------|------|------|---------|
| Fetch nonexistent document | 20404 | 404 | "The requested resource ... was not found" |
| Fetch nonexistent list | 20404 | 404 | Same |
| Fetch nonexistent map item | 20404 | 404 | Same |
| Create with >16 KiB data | 54006 | 413 | "Request entity too large" |
| Invalid JSON in Data | 54008 | 400 | "Invalid request body: the type of one of the attributes is invalid" |
| Duplicate uniqueName | 54301 | 409 | "Unique name already exists" |
| Duplicate map key | 54208 | 409 | "An Item with given key already exists in the Map" |
| Wrong If-Match revision | 54103 | 412 | "The revision of the Document does not match the expected revision" |

## Test 9: Validation Tools

| Tool | Input | Result | Evidence |
|------|-------|--------|----------|
| `validate_sync_document` | expectedKeys=["theme"], strictKeys=true | Pass, 0 errors, 224ms | ETf6783d |
| `validate_sync_list` | minItems=3, maxItems=3, expectedItemKeys=["order","label"] | Pass, 0 errors, 312ms | ES0251800d |
| `validate_sync_map` | expectedKeys=["simple-key","key.with.dots","émoji-café-naïve"] | Pass, all found, 309ms. Also listed `key/with/slashes` in keys array. | MPd79ca1ac |

**Confirmed**: Validation tools work. `validate_sync_map` can enumerate slash-keyed items (uses list endpoint internally).

## Test 10: MCP Tool Gap Verification

| Operation | MCP Tool Exists? | Verified How |
|-----------|-----------------|-------------|
| Delete map | No | Used `curl -X DELETE`, got HTTP 204 |
| Fetch list metadata | No | — |
| Fetch map metadata | No | — |
| Fetch single list item by index | No | — |
| Any stream operation | No | Searched deferred tools list |
| Conditional update (If-Match) | No | MCP schema inspection: no ifMatch/revision param |

## Cleanup

All test resources deleted after testing:
- `skill-test-doc-alpha` (ETf6783d) — deleted via MCP
- `ETc9642713` (no uniqueName) — deleted via MCP
- `skill-test-ttl-short` (ETccd0ec2d) — TTL-expired
- `skill-test-list-alpha` (ES0251800d) — deleted via MCP
- `skill-test-ttl-reset` (EScbba2f88) — TTL-expired
- `skill-test-ttl-reset2` (ES65f9bb08) — deleted via MCP
- `skill-test-map-alpha` (MPd79ca1ac) — deleted via REST (no MCP tool)
- `skill-test-toobig2` — never created (54006 error)
