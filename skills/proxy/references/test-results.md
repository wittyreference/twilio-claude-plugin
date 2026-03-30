---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Live test evidence for Proxy skill assertions. Every behavioral claim traces back to a SID. -->
<!-- ABOUTME: Use when verifying skill claims or reproducing test scenarios. -->

# Proxy Skill — Live Test Results

Evidence date: 2026-03-25. Account: ACb4de. All tests via direct REST API (`curl`). Resources cleaned up after testing.

## Test Resources

| Resource | SID | Purpose |
|----------|-----|---------|
| Service 1 | KS7631760e2fe421e19bce81ac6848576e | Main test service (deleted) |
| Service 2 | KS9493ceb9b596a19be9a506bd01e955e9 | Reserved number tests (deleted) |
| Session 1 | KC3dce86d092f6353666e5ba2ba65085d5 | Lifecycle test (close/reopen) |
| Session 2 | KC264a8191dca0c19bf68345dced366e7d | dateExpiry test |
| Session 3 | KCec4577f8e948df0a25bc92902de98196 | Empty pool test |
| Participant (Rider) | KP6aef10ec5b1fb4c8f5b0db64049f6e46 | +12069666002 → proxy +12067597288 |
| Participant (Driver) | KPbe9b838fb207733a0b5379b0a5131e84 | +12065586395 → proxy +12067597288 |
| Pool Number | PNe9f78a15f8bda8406244a1636d7c5663 | +12067597288 (DTMF Injector) |

## Test 1: Service CRUD

| Operation | Result | Evidence |
|-----------|--------|----------|
| Create with all params | OK: uniqueName, geoMatchLevel=country, numberSelectionBehavior=avoid-sticky, defaultTtl=300 | KS7631760e |
| Delete with active sessions | HTTP 204 — **cascading delete, no warning** | KS7631760e |

## Test 2: Number Pool

| Operation | Result | Evidence |
|-----------|--------|----------|
| Add number by SID | OK: capabilities shown, inUse=0, isReserved=false | PNe9f78a15 in KS7631760e |
| Add duplicate number | Error 80104 "PhoneNumber already added to Service" | PNe9f78a15 |
| Add as reserved | OK: isReserved=true, inUse=0 | PNe9f78a15 in KS9493ceb9 |
| Webhook overwrite on add | voiceUrl/smsUrl changed from empty to demo.twilio.com | PNe9f78a15 |
| Webhook after service delete | Reverted to demo.twilio.com defaults, NOT original values | PNe9f78a15 |

## Test 3: Session Lifecycle

| Operation | Result | Evidence |
|-----------|--------|----------|
| Create with TTL=600 | status=open, dateExpiry=null, dateStarted=null | KC3dce86d0 |
| Create with dateExpiry + TTL | Both stored: ttl=600, dateExpiry=2026-03-26T01:00:00Z | KC264a8191 |
| Status with 2 participants (no interaction) | Remains `open`, not `in-progress` | KC3dce86d0 |
| Close (Status=closed) | closedReason="api", dateEnded set, dateStarted still null | KC3dce86d0 |
| Reopen to `open` | Error 80608: "choose In Progress" | KC3dce86d0 |
| Reopen to `in-progress` | Success: closedReason=null, dateEnded=null, participants preserved | KC3dce86d0 |
| Duplicate uniqueName | Error 80603 "Session UniqueName must be unique" | — |
| List interactions (no comms) | Empty array, 0 interactions | KC3dce86d0 |

## Test 4: Participants

| Operation | Result | Evidence |
|-----------|--------|----------|
| Add real number | OK: auto-assigned proxy from pool | KP6aef10ec |
| Add second participant | OK: same proxy number as first | KPbe9b838f |
| Add fake number (+15551234567) | Error 80404 "not valid, reachable identity" | — |
| Add 3rd participant | Error 80609 "max 2 participants" | — |
| Add duplicate identifier | Error 80103 "already added to Session" | — |
| Participants after close+reopen | Both preserved with same proxy assignments | KC3dce86d0 |

## Test 5: Reserved Number Behavior

| Operation | Result | Evidence |
|-----------|--------|----------|
| Auto-assign with only reserved numbers | Error 80207 "only matching candidates are marked as Reserved" | KCec4577f8 |
| Explicit assign via ProxyIdentifier | Error "Unmanaged Proxy Identifier not found" | KCec4577f8 |
| Explicit assign via ProxyIdentifierSid | Error 80207 — same as auto-assign | KCec4577f8 |

**Finding**: Reserved numbers cannot be explicitly assigned in practice, contradicting documentation. Workaround: keep numbers unreserved for active use.

## Test 6: Error Code Summary

| Code | HTTP | Verified Message |
|------|------|-----------------|
| 80103 | 400 | Participant has already been added to Session |
| 80104 | 400 | PhoneNumber has already been added to Service |
| 80207 | 400 | This Service has no compatible Proxy numbers for this Participant |
| 80404 | 400 | Participant identifier does not appear to be a valid, reachable identity |
| 80603 | 400 | Session UniqueName must be unique |
| 80608 | 400 | Session status change not supported. To re-open, choose In Progress |
| 80609 | 400 | A Session may have at most 2 participants |

## Cleanup

- Service KS7631760e: deleted (cascading)
- Service KS9493ceb9: deleted (cascading)
- PNe9f78a15: webhooks restored to empty strings
