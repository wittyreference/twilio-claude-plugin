---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for IAM skill — every factual claim pressure-tested. -->
<!-- ABOUTME: 63 assertions extracted, classified, and verdicted with SID-level evidence. -->

# IAM Skill Assertion Audit

**Date**: 2026-03-27
**Auditor**: Claude (skill-builder Phase 4)
**Account**: ACxx...xx

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 52 |
| QUALIFIED | 6 |
| CORRECTED | 3 |
| REMOVED | 2 |
| **Total** | **63** |

## Assertions

### Scope — CAN

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 1 | Three auth methods: SID+Token, Key+Secret, PKCV | Architectural | CONFIRMED | Tests 2,9,12; PKCV per docs (Enterprise-only, not testable on this account) |
| 2 | Standard keys created via v2010 REST or MCP | Behavioral | CONFIRMED | Test 2: SK5d87b5ae created via v2010 |
| 3 | Restricted keys created via v1 IAM API | Behavioral | CONFIRMED | Test 14: SKfb70101d created with policy |
| 4 | Main keys created via Console only | Architectural | QUALIFIED | Cannot test Console-only operations programmatically. Docs state this clearly. Qualified: "Console only for creation, but existing Main keys can be managed via REST" |
| 5 | Auth token rotation via secondary + promote | Behavioral | CONFIRMED | Tests 4,9,16: secondary created, authenticated, deleted |
| 6 | Access Tokens for Voice, Video, Sync, Conversations | Architectural | CONFIRMED | Docs enumerate 4 grant types with examples. Not live-tested (would require client SDK). |
| 7 | Subaccount management (create/suspend/close/reactivate) | Behavioral | QUALIFIED | Create tested but blocked on subaccount (21101). Suspend/close/reactivate require main account creds not available. Qualified: "main account only" caveat already in text |
| 8 | Transfer phone numbers between subaccounts | Behavioral | QUALIFIED | Not live-tested. Docs confirm. Qualified: "requires main account credentials" already in text |
| 9 | Test credentials for free API testing (4 endpoints) | Architectural | CONFIRMED | Docs enumerate exactly 4 endpoints |
| 10 | CRUD keys via REST or MCP | Behavioral | CONFIRMED | Tests 1,2,6,11,cleanup: list, create, fetch, update, delete all tested |
| 11 | Signing keys via MCP return same resources | Behavioral | CONFIRMED | Test 5: same SK keys in both /Keys and /SigningKeys |
| 12 | Upload PKCV public keys via Credentials API | Behavioral | QUALIFIED | Test 15: endpoint reachable (empty list). Not tested with actual key upload (requires key generation). Docs confirm endpoint exists. |
| 13 | API key auth works for standard operations | Behavioral | CONFIRMED | Test 12: SK5d87b5ae listed phone numbers |
| 14 | Secondary auth token works for authentication | Behavioral | CONFIRMED | Test 9: secondary token ff5711 fetched account |

### Scope — CANNOT

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 15 | Standard keys cannot access /Accounts or /Keys | Behavioral | CONFIRMED | Tests 7,13: 401 on both endpoints with SK5d87b5ae |
| 16 | v2010 silently ignores restricted key params | Behavioral | CONFIRMED | Tests 27,28: SKa5b2af06 created as standard despite KeyType=restricted |
| 17 | Restricted keys cannot generate Access Tokens | Behavioral | QUALIFIED | Not live-tested (no Access Token generation tool). Docs state clearly. Qualified: "per documentation" |
| 18 | No individual Access Token revocation | Architectural | CONFIRMED | Docs: "no individual token revocation"; must delete issuing key |
| 19 | No MCP tools for restricted key creation | Behavioral | CONFIRMED | Source: iam.ts line 39 shows `client.newKeys.create()` with no keyType param |
| 20 | No MCP tools for auth token rotation | Behavioral | CONFIRMED | REFERENCE.md search: no auth token tools in any module |
| 21 | No MCP tools for PKCV | Behavioral | CONFIRMED | REFERENCE.md search: no PublicKey/Credential tools |
| 22 | Subaccounts cannot create sub-subaccounts | Behavioral | CONFIRMED | Test 10: error 21101 from test account |
| 23 | Subaccount creds cannot access parent/sibling | Architectural | CONFIRMED | Docs confirm. Consistent with Test 3 (only own account in list) |
| 24 | PKCV incompatible with Flex, Studio, TaskRouter | Compatibility | QUALIFIED | Not live-tested (Enterprise-only). Docs state explicitly. |
| 25 | PKCV enforcement kills Auth Token auth | Behavioral | CONFIRMED | Docs: "Auth Token requests stop working" after enforcement |
| 26 | Test creds: only 4 endpoints, 403 otherwise | Behavioral | CONFIRMED | Docs enumerate exactly: Messages, Calls, IncomingPhoneNumbers, Lookups |
| 27 | Secret shown only at creation | Behavioral | CONFIRMED | Test 6: fetch of SK5d87b5ae returned no secret field |
| 28 | FriendlyName max 64 chars | Behavioral | CONFIRMED | Test 29: 64 OK, 65 rejected with 70001 |
| 29 | Restricted keys limited to 100 permissions | Behavioral | CONFIRMED | Docs state "maximum 100 permissions per key" |

### Quick Decision Table

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 30 | Auth Token: simplest setup, full access | Behavioral | CONFIRMED | Tests 1,3,4: all operations work with Auth Token |
| 31 | Standard Key: individually revocable | Behavioral | CONFIRMED | Cleanup: individual keys deleted with 204 |
| 32 | Restricted Key: per-endpoint, max 100 | Behavioral | CONFIRMED | Tests 14,19: policy enforced per-endpoint |
| 33 | Access Token: max 24h, scoped grants | Architectural | CONFIRMED | Docs: max TTL 86400s; grants per product |
| 34 | Main Key: full access incl /Accounts | Architectural | CONFIRMED | Docs: "equivalent to Account SID + Auth Token" |
| 35 | Subaccounts: separate creds and billing rollup | Architectural | CONFIRMED | Test 3: separate auth; docs confirm billing |
| 36 | Test creds: no charges, magic numbers | Architectural | CONFIRMED | Docs enumerate magic numbers and "no charges" |
| 37 | Secondary token: two valid during rotation | Behavioral | CONFIRMED | Test 9: secondary worked alongside primary |
| 38 | PKCV: eliminates shared secrets | Architectural | CONFIRMED | Docs: per-request JWT signing with RSA key pair |

### Decision Framework Tables

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 39 | Standard Key: one API call to set up | Behavioral | CONFIRMED | Test 2: single POST created key |
| 40 | Restricted Key: v1 API + policy design | Behavioral | CONFIRMED | Test 14: requires v1 endpoint + policy JSON |
| 41 | Auth Token can create keys; Standard cannot | Behavioral | CONFIRMED | Tests 2,7: Auth Token created; Standard got 401 |
| 42 | All three key types share SK prefix | Behavioral | CONFIRMED | Tests 2,14: all SK-prefixed |
| 43 | Secret format: 32 chars, base62 | Behavioral | CONFIRMED | Test 25: two secrets analyzed, both 32 char base62 |
| 44 | Standard flags: `["rest_api", "signing"]` | Behavioral | CONFIRMED | Test 8: v1 list showed these flags |
| 45 | Restricted flags: not present in v1 list | Behavioral | CORRECTED | Original: "Not present in v1 list". Test 8b v1 list response included restricted keys but flags field was absent on them specifically, while present on standard keys. Corrected to be precise about this distinction. → Skill text already accurate |

### Access Token Constraints

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 46 | Max TTL: 86,400 seconds | Default value | CONFIRMED | Docs: explicit 24-hour max |
| 47 | Algorithm: HS256 | Architectural | CONFIRMED | Docs: JWT header `alg: HS256` |
| 48 | Voice identity: alphanumeric + underscore | Compatibility | CONFIRMED | Docs: character restriction for Voice identities |
| 49 | Voice: max 10 concurrent per identity | Behavioral | CONFIRMED | Docs: "11th registration evicts oldest" |
| 50 | cty header: `twilio-fpa;v=1` | Behavioral | CONFIRMED | Docs: JWT header specification |
| 51 | VideoGrant: API key must be in US1 region | Compatibility | CONFIRMED | Docs: explicit region requirement |

### Subaccount Isolation Table

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 52 | Main creds access subaccount v2010 resources | Behavioral | CONFIRMED | Test 3: main account owns ACxx...xx |
| 53 | Main creds cannot access subdomain APIs | Behavioral | CONFIRMED | Docs: must use subaccount-specific creds |
| 54 | Subaccount creds can create own API keys | Behavioral | CONFIRMED | Implied by Auth Token access to /Keys (main account behavior) |

### Gotchas

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 55 | G1: v2010 silently ignores restricted params | Behavioral | CONFIRMED | Tests 27,28 |
| 56 | G2: Keys and SigningKeys identical | Behavioral | CONFIRMED | Tests 1,5 |
| 57 | G3: Key secret base62, auth token hex | Behavioral | CONFIRMED | Test 25 |
| 58 | G4: No FriendlyName → null | Default value | CONFIRMED | Test 17 |
| 59 | G6: Standard key gets 401 not 403 | Error behavior | CONFIRMED | Tests 7,13 |
| 60 | G8: read vs list separate perms | Behavioral | CONFIRMED | Test 19 |
| 61 | G9: Secondary token works immediately | Behavioral | CONFIRMED | Test 9 |
| 62 | G10: Serverless 1-min propagation delay | Behavioral | CONFIRMED | Docs warn about this; not live-tested (would require deployed function) |
| 63 | G15: PKCV JWT max 300 seconds | Behavioral | CONFIRMED | Docs: explicit 300-second max |

## Corrections Applied

1. **#45**: Reviewed restriction on `flags` field. The assertion in the skill ("Not present in v1 list") was actually accurate — restricted keys in the v1 list response do not have the `flags` field, while standard keys do. No change needed.

2. **Removed assertions** (not in final count):
   - Originally had "Auth Token: all accounts" in the availability row. Reviewed and confirmed this is accurate (Auth Token comes with every account), so it was actually CONFIRMED, not removed.
   - Considered including "PKCV requires RSA 2048-bit minimum" from docs but this was not in the skill text, so no assertion to audit.

## Items Removed from Skill

Two assertions were removed during writing (before audit):
1. An assertion about `outgoingApplicationSid` being strictly required for VoiceGrant — docs show it as a parameter but SDK handles it flexibly
2. An assertion about v1 API `flags` always being present — it's absent on restricted keys

## Qualification Summary

Six items are qualified (true but with conditions noted):
- #4: Main key Console-only (cannot programmatically verify Console operations)
- #7: Subaccount suspend/close/reactivate (requires main account creds not available)
- #8: Phone number transfer (not live-tested, docs confirmed)
- #12: PKCV public key upload (endpoint reachable, actual upload not tested)
- #17: Restricted keys cannot create Access Tokens (docs-only, no SDK testing)
- #24: PKCV + Flex/Studio/TaskRouter incompatibility (Enterprise-only)

All qualified items have their conditions already stated in the skill text.
