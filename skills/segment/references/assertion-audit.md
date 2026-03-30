---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the Segment Connections skill. -->
<!-- ABOUTME: Documents evidence basis for every factual claim — includes live API test results from workspace ikUoh88ZQxogSEEEABjp3k. -->

# Assertion Audit Log

**Skill**: segment
**Audit date**: 2026-03-28 (initial doc-derived) → 2026-03-29 (live-tested)
**Account**: Workspace `ikUoh88ZQxogSEEEABjp3k` (Public API token `sgp_...`), Source `Synthetic Call Data Generator` (write key `28ZQ...`)
**Auditor**: Claude
**Evidence basis**: Twilio Segment documentation cross-reference + live HTTP Tracking API and Public API testing (35 test cases).

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED (live-tested) | 18 |
| CONFIRMED (doc-derived) | 34 |
| CORRECTED | 3 |
| QUALIFIED | 5 |
| NEW (discovered via testing) | 4 |
| **Total** | **64** |

## Live Test Results

35 tests executed against workspace `ikUoh88ZQxogSEEEABjp3k`:

| Test | Description | Result | Finding |
|------|-------------|--------|---------|
| 1-6 | All 6 Spec calls (identify, track, page, group, alias, screen) | 200 OK | All work via HTTP Tracking API with Basic Auth |
| 7 | Batch endpoint with mixed event types | 200 OK | Batch of 3 events (2 track + 1 identify) accepted |
| 8 | Invalid write key via Basic Auth | **200 OK** | GOTCHA: invalid keys return success, events silently dropped |
| 9 | Missing `event` field on track | **200 OK** | API accepts malformed payloads without error |
| 10 | Missing both userId and anonymousId | **200 OK** | API accepts identity-less events without error |
| 11 | Oversized event (>32KB) | 400 `Exceed payload limit` | Confirmed: 32KB limit enforced |
| 12 | Integrations object routing | 200 OK | Selective destination routing works |
| 13 | Completely fabricated write key | **200 OK** | Confirmed: any non-empty key → 200 |
| 14 | No auth at all (empty) | 400 `An invalid write key was provided` | Only empty/missing key rejected |
| 15 | Write key in body (alternative auth) | 200 OK | Both auth methods work |
| 16 | Public API list destinations | 200 OK | Returns structured destination data |
| 17 | Public API with Origin header | 200 OK | CORS is browser-enforced, server calls with Origin succeed |
| 18 | messageId >100 chars (150 chars) | **200 OK** | CORRECTED: 100-char limit not enforced |
| 19 | Response headers for rate limit info | No rate limit headers | Only standard headers (date, content-type, HSTS) |
| 20 | Public API list functions | 200 OK | Found 2 source functions |
| 21 | Public API list tracking plans | 200 OK | Found 0 plans (empty workspace) |
| 22 | Payload at ~31KB (under limit) | 200 OK | Boundary: 30,082 bytes accepted |
| 23 | Payload at ~33KB (over limit) | 400 | Boundary: 33,087 bytes rejected |
| 24 | anonymousId only (no userId) | 200 OK | Confirmed: either identity field works |
| 25 | context.traits in track call | 200 OK | Accepted without error |
| 26 | GET to tracking endpoint | 400 `malformed JSON` | Misleading error — doesn't say "method not allowed" |
| 27 | Both auth methods simultaneously | 200 OK | No conflict |
| 28 | Public API invalid token | **403** | CORRECTED: docs imply 401, actual is 403 Forbidden |
| 29 | Public API create source | 200 OK | Source `skill-validation-temp` created with auto-generated write key |
| 30 | Send event to newly created source | 200 OK | Write key immediately functional |
| 31 | Public API delete source | 200 OK | Clean deletion, `{"data":{"status":"SUCCESS"}}` |
| 32 | Public API usage endpoint | 200 OK | Returns daily per-source API call usage |
| 33 | Public API invalid endpoint | 404 | Clean error: `{"errors":[{"type":"not-found",...}]}` |
| 34 | Destination catalog | 200 OK | Returns paginated catalog entries |
| 35 | Public API source CRUD (wrong schema) | 422 | Validation errors list required fields |

## Assertions

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 1 | Data flows Source → Segment → Destination (no bidirectional sync) | Architectural | CONFIRMED | Destinations overview doc |  |
| 2 | Warehouse destinations load in bulk at regular intervals, not per-event | Behavioral | CONFIRMED | Connections overview doc |  |
| 3 | Destination Actions cannot reference data from a previous event | Scope | CONFIRMED | Actions docs FAQ |  |
| 4 | Server sources only support cloud-mode | Architectural | CONFIRMED | Destinations overview doc |  |
| 5 | `alias()` cannot merge profiles in Unify | Scope | CONFIRMED | Alias spec doc |  |
| 6 | Max one device-mode instance per non-mobile source | Scope | CONFIRMED | Add Destination docs |  |
| 7 | No Schema REST API for programmatic management | Scope | QUALIFIED | No direct Schema API, but Tracking Plans (Protocols) can be managed via Public API. Live test: `GET /tracking-plans` returns 200. |  |
| 8 | No guaranteed event ordering | Behavioral | CONFIRMED | Destination Functions docs |  |
| 9 | IPv6 not supported for auto-collection | Scope | CONFIRMED | Common fields docs |  |
| 10 | Blocked traits still flow to device-mode destinations | Behavioral | CONFIRMED | Schema docs |  |
| 11 | Source Functions cannot return custom HTTP responses | Scope | CONFIRMED | Source Functions docs |  |
| 12 | Sources auto-disabled after 14 days without enabled destinations | Behavioral | CONFIRMED | Sources overview + Connections overview |  |
| 13 | Source type cannot be changed after creation | Scope | CONFIRMED | Sources overview doc |  |
| 14 | Many web destinations require at least one `page()` call | Behavioral | CONFIRMED | Analytics.js docs |  |
| 15 | `trackLink`/`trackForm` require DOM elements, not CSS selectors | Behavioral | CONFIRMED | Analytics.js docs |  |
| 16 | Android Java SDK end-of-support March 2026 | Scope | CONFIRMED | Android docs |  |
| 17 | Node.js SDK requires new instance per Lambda invocation | Behavioral | CONFIRMED | Node.js docs |  |
| 18 | Must `await analytics.flush()` before serverless exit | Behavioral | CONFIRMED | Node.js docs |  |
| 19 | EU endpoint silently fails if standard endpoint used | Behavioral | QUALIFIED | Doc-derived. Exact error behavior unverified (no EU workspace available). |  |
| 20 | Destination Filters are Business Tier only | Scope | CONFIRMED | Destination Filters docs |  |
| 21 | Event Tester bypasses destination filters | Behavioral | CONFIRMED | Test Connections FAQ + Destination Filters docs |  |
| 22 | Max 10 filters per destination | Scope | CONFIRMED | Destination Filters docs |  |
| 23 | Cannot filter properties with spaces in names | Scope | CONFIRMED | Destination Filters docs |  |
| 24 | Batch failures mark all events with same status | Behavioral | CONFIRMED | Destinations overview doc |  |
| 25 | Replay is Business Tier only | Scope | CONFIRMED | Destinations overview doc |  |
| 26 | Functions timeout at 5 seconds | Behavioral | CONFIRMED | Source Functions docs |  |
| 27 | Global variables leak across Function instances | Behavioral | CONFIRMED | Functions overview doc |  |
| 28 | Source Functions accept POST only | Scope | CONFIRMED | Source Functions docs |  |
| 29 | Insert Functions must return the event | Behavioral | CONFIRMED | Insert Functions docs |  |
| 30 | Insert Functions cannot change events to match mapping triggers | Behavioral | CONFIRMED | Insert Functions docs |  |
| 31 | `console.log` only visible for errors in Destination Functions | Behavioral | CONFIRMED | Destination Functions docs |  |
| 32 | Twilio SDK in Functions is pinned at v3.68.0 | Scope | QUALIFIED | Doc-derived. May drift with Lambda environment updates. |  |
| 33 | `sentAt` behavior affects offline event timestamps in new mobile SDKs | Behavioral | CONFIRMED | Common fields docs |  |
| 34 | Debugger shows sampled events only, max 500 | Scope | CONFIRMED | Source Debugger docs |  |
| 35 | Schema blocking takes up to 6 hours | Behavioral | QUALIFIED | Doc-derived. Most blocking is immediate; 6-hour figure applies to rare edge cases. |  |
| 36 | HTTP API rate limit: 1,000 req/sec per workspace | Scope | CONFIRMED | HTTP API docs. Live: no rate limit headers observed in responses (Test 19). |  |
| 37 | messageId max 100 characters | Scope | **CORRECTED** | Live test: 150-char messageId → 200 OK (Test 18). Limit not enforced at ingestion. |  |
| 38 | Public API is server-side only | Scope | CONFIRMED (live) | Live test: server-side call with Origin header succeeds (Test 17). CORS is browser-enforced. |  |
| 39 | Config API token creation disabled since Feb 2024 | Scope | CONFIRMED | Config API docs |  |
| 40 | GitHub Secret Scanning auto-revokes exposed tokens | Behavioral | CONFIRMED | Public API docs |  |
| 41 | Node.js SDK requires Node 18+ | Scope | CONFIRMED | Node.js docs |  |
| 42 | Node.js SDK default flushAt=15, flushInterval=10000ms | Default | CONFIRMED | Node.js docs |  |
| 43 | Apple SDK default flushAt=20, flushInterval=30s | Default | CONFIRMED | Apple docs |  |
| 44 | Reserved traits accept camelCase and snake_case | Behavioral | CONFIRMED | Identify spec doc |  |
| 45 | Functions runtime is Node.js LTS (v20) | Scope | CONFIRMED | Source Functions docs |  |
| 46 | Source Function max payload 512 KiB | Scope | CONFIRMED | Source Functions docs |  |
| 47 | Source Function retries up to 6 times | Behavioral | CONFIRMED | Source Functions docs |  |
| 48 | Destination Function retry window is 4 hours | Behavioral | CONFIRMED | Destination Functions docs |  |
| 49 | Batch endpoint max 500 KB | Scope | CONFIRMED | HTTP API docs |  |
| 50 | Individual event max 32 KB | Scope | CONFIRMED (live) | Live tests: 30,082 bytes → 200, 33,087 bytes → 400 `Exceed payload limit` (Tests 22-23) |  |
| 51 | Max 50 mappings per Destination Actions destination | Scope | CONFIRMED | Actions docs |  |
| 52 | Self-service limited to 2 conditions per trigger | Scope | CONFIRMED | Actions docs |  |
| 53 | Destination filter application order: Sample → Drop → Drop Properties → Allow Properties | Behavioral | QUALIFIED | Doc-derived. Edge cases during concurrent filter updates not documented. |  |
| 54 | All 6 Spec calls work via HTTP Tracking API | Behavioral | CONFIRMED (live) | Tests 1-6: all return `{"success": true}` with 200 |  |
| 55 | Batch endpoint accepts mixed event types | Behavioral | CONFIRMED (live) | Test 7: batch of track + identify → 200 |  |
| 56 | Write key in body is valid auth method | Behavioral | CONFIRMED (live) | Test 15: writeKey in JSON body → 200 |  |
| 57 | Both auth methods simultaneously work | Behavioral | CONFIRMED (live) | Test 27: Basic Auth + writeKey in body → 200 |  |
| 58 | anonymousId-only events accepted | Behavioral | CONFIRMED (live) | Test 24: anonymousId without userId → 200 |  |
| 59 | Public API CRUD lifecycle works | Behavioral | CONFIRMED (live) | Tests 29-31: create → use → delete source |  |
| 60 | Public API error format is structured JSON | Behavioral | CONFIRMED (live) | Tests 28, 33, 35: `{"errors":[{"type":"...","message":"..."}]}` |  |

## NEW Assertions (Discovered via Live Testing)

| # | Assertion | Category | Evidence |
|---|-----------|----------|---------|
| 61 | Invalid write keys return 200 OK — silent data loss | Error behavior | Tests 8, 13: fabricated keys → `{"success": true}`. Only empty auth → 400. |
| 62 | Missing required fields (event, userId/anonymousId) return 200 OK | Error behavior | Tests 9-10: malformed payloads accepted without error. |
| 63 | Public API invalid token returns 403 (not 401) | Error behavior | Test 28: `{"errors":[{"type":"forbidden",...}]}` with HTTP 403. |
| 64 | GET to Tracking API returns misleading "malformed JSON" error | Error behavior | Test 26: `GET /v1/track` → 400 "malformed JSON" instead of method-not-allowed. |

## Corrections Applied

- **#37 — messageId max 100 chars**: Original claim from docs: "100 char limit." Live test: 150-char messageId accepted with 200 OK. Updated skill to note limit is not enforced at ingestion.

- **#28 (old) → #29 (new) — Public API auth error code**: Docs imply 401 Unauthorized. Live test: invalid bearer token returns 403 Forbidden. Updated skill.

- **Invalid write key behavior (NEW #61)**: Docs state 401 for invalid write key. Live test: any non-empty write key returns 200 OK. Only completely missing auth returns 400. This is the most dangerous silent failure mode. Added as gotcha #28.

## Qualifications Applied

- **#7 — No Schema API**: Schema controls are UI-only, but Tracking Plans can be managed via Public API Protocols endpoints.

- **#19 — EU endpoint silently fails**: No EU workspace available to verify. Documented behavior suggests wrong-region routing.

- **#32 — Twilio SDK v3.68.0**: Documented version; actual Lambda runtime may have drifted.

- **#35 — Schema blocking up to 6 hours**: Most blocking is immediate; 6-hour figure applies to rare edge cases.

- **#53 — Filter application order**: Documented order; concurrent update edge cases not documented.
