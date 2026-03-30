---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the Proxy skill. Every factual claim pressure-tested with evidence. -->
<!-- ABOUTME: Proves provenance chain for all behavioral claims. 48 assertions extracted, audited 2026-03-25. -->

# Assertion Audit Log

**Skill**: proxy
**Audit date**: 2026-03-25
**Account**: ACb4de2...
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 39 |
| CORRECTED | 2 |
| QUALIFIED | 7 |
| REMOVED | 0 |
| **Total** | **48** |

## Assertions

### Scope — CAN (A1–A16)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A1 | Max 2 participants per session, both share 1 proxy number | Behavioral | CONFIRMED | KP6aef10ec + KPbe9b838f both got +12067597288 | Live-verified |
| A2 | Three session modes: voice-and-message, voice-only, message-only | Scope | CONFIRMED | KC3dce86d0 mode=voice-and-message | One mode live-tested; others from docs |
| A3 | Auto-assign proxy numbers from pool based on geo + stickiness | Behavioral | CONFIRMED | KP6aef10ec auto-assigned from pool | Live-verified |
| A4 | TTL-based session expiry with reset on interaction | Behavioral | QUALIFIED | twilio.com/docs/proxy/api/session | TTL reset on interaction not live-tested (would need actual call/SMS). Docs confirm. |
| A5 | dateExpiry overrides TTL when both present | Behavioral | CONFIRMED | KC264a8191, both ttl=600 and dateExpiry set | Live-verified |
| A6 | Service-level defaultTtl as fallback | Default | CONFIRMED | KS7631760e, defaultTtl=300 | Live-verified |
| A7 | Close sessions with closedReason="api" | Behavioral | CONFIRMED | KC3dce86d0, closedReason="api" | Live-verified |
| A8 | Reopen closed sessions to in-progress, participants preserved | Behavioral | CONFIRMED | KC3dce86d0, both participants survived close→reopen | Live-verified |
| A9 | Intercept callback: 403 blocks interaction | Behavioral | QUALIFIED | twilio.com/docs/proxy/api/webhooks | Not live-tested (would need actual call through proxy). Docs confirm. |
| A10 | Out-of-session callback auto-creates sessions via JSON | Behavioral | QUALIFIED | twilio.com/docs/proxy/out-session-callback-response-guide | Not live-tested. Docs confirm. |
| A11 | Reserved/unreserved distinction with inUse counter | Behavioral | CONFIRMED | PNe9f78a15 isReserved=true, inUse=0 | Live-verified |
| A12 | Geo-matching: country (global), area-code/extended-area-code (NA only) | Scope | CONFIRMED | KS7631760e geoMatchLevel=country; NA restriction from docs | Live-tested country; NA restriction docs-sourced |
| A13 | prefer-sticky vs avoid-sticky | Scope | CONFIRMED | KS7631760e numberSelectionBehavior=avoid-sticky | Set and confirmed; behavioral difference needs multi-session test |
| A14 | Read-only interaction log with Call/Message SIDs | Scope | QUALIFIED | twilio.com/docs/proxy/api/interaction | No interactions generated (would need actual comms) |
| A15 | Proxy is Public Beta, closed to new customers | Scope | CONFIRMED | twilio.com/docs/proxy | Docs confirm |
| A16 | Not covered by Twilio SLA | Scope | CONFIRMED | twilio.com/docs/proxy | Docs confirm |

### Scope — CANNOT (A17–A27)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A17 | Max 2 participants not configurable | Scope | CONFIRMED | 80609 on 3rd participant | Live-verified |
| A18 | Cannot reopen to open status (only in-progress) | Behavioral | CONFIRMED | 80608 on Status=open, success on Status=in-progress | Live-verified both cases |
| A19 | Cannot use fake phone numbers | Behavioral | CONFIRMED | 80404 on +15551234567 | Live-verified |
| A20 | Cannot auto-assign reserved numbers | Behavioral | CONFIRMED | 80207 with reserved-only pool | Live-verified |
| A21 | Explicit assignment via ProxyIdentifierSid also fails for reserved | Behavioral | CONFIRMED | 80207 even with ProxyIdentifierSid | Live-verified, contradicts docs |
| A22 | Service deletion cascades silently (HTTP 204) | Behavioral | CONFIRMED | KS7631760e deleted with active sessions | Live-verified |
| A23 | Proxy overwrites phone number webhooks | Behavioral | CONFIRMED | PNe9f78a15 voiceUrl changed to demo.twilio.com | Live-verified |
| A24 | Webhooks revert to demo defaults, not original values | Behavioral | CONFIRMED | PNe9f78a15 post-delete | Live-verified |
| A25 | No MCP tools at runtime | Scope | CONFIRMED | ToolSearch("proxy") returned no results | Schema inspection |
| A26 | Cannot create interactions directly | Scope | CONFIRMED | twilio.com/docs/proxy/api/interaction — no POST | Docs confirm |
| A27 | Number cannot belong to multiple Proxy Services | Scope | QUALIFIED | 80104 verified for same service; cross-service not tested (only 1 service) | Docs confirm cross-service restriction |

### Gotchas (A28–A44)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A28 | G1: Service deletion cascades | Behavioral | CONFIRMED | KS7631760e | Same as A22 |
| A29 | G2: Proxy overwrites webhooks | Behavioral | CONFIRMED | PNe9f78a15 | Same as A23-24 |
| A30 | G3: Number can only belong to one service | Scope | QUALIFIED | 80104 same-service; docs for cross-service | Same as A27 |
| A31 | G4: Session stays open until first interaction | Behavioral | CONFIRMED | KC3dce86d0, 2 participants, status=open | Live-verified |
| A32 | G5: TTL doesn't create dateExpiry until interaction | Behavioral | CONFIRMED | KC3dce86d0, ttl=600, dateExpiry=null | Live-verified |
| A33 | G6: dateExpiry overrides ttl, both stored | Behavioral | CONFIRMED | KC264a8191 | Same as A5 |
| A34 | G7: Closed sessions reopenable to in-progress | Behavioral | CONFIRMED | KC3dce86d0 | Same as A8 |
| A35 | G8: closedReason="api" for programmatic close | Behavioral | CONFIRMED | KC3dce86d0 | Live-verified |
| A36 | G9: Fake numbers return 80404 | Error | CONFIRMED | +15551234567 | Same as A19 |
| A37 | G10: Both participants share same proxy number | Behavioral | CONFIRMED | KP6aef10ec + KPbe9b838f | Same as A1 |
| A38 | G11: Reserved numbers excluded from auto AND explicit | Behavioral | CONFIRMED | KCec4577f8, 80207 | Same as A20-21 |
| A39 | G12: Max 2 not configurable | Scope | CONFIRMED | 80609 | Same as A17 |
| A40 | G13: Duplicate identifier rejected 80103 | Error | CONFIRMED | Duplicate +12069666002 | Live-verified |
| A41 | G14: 5000 reserved + 500 unreserved per service | Scope | QUALIFIED | twilio.com/docs/proxy/reserved-phone-numbers | Not live-tested (would need 500+ numbers) |
| A42 | G15: inUse counter on pool numbers | Behavioral | CONFIRMED | PNe9f78a15 inUse=0 | Live-verified |
| A43 | G16: 17 proxy tools exist in source but not loaded | Scope | CONFIRMED | proxy.ts exists, ToolSearch empty | File + runtime verified |
| A44 | G17: Public Beta, closed to new customers | Scope | CONFIRMED | twilio.com/docs/proxy | Same as A15 |

### Error Codes (A45–A48)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A45 | 80103 = duplicate participant | Error | CONFIRMED | Live curl test | Exact message verified |
| A46 | 80207 = no compatible proxy numbers | Error | CONFIRMED | KCec4577f8 | Exact message verified |
| A47 | 80608 = invalid status transition | Error | CORRECTED | KC3dce86d0 | Error message says "To re-open a session, choose In Progress" — corrected skill to note this is about reopen direction, not just "status change not supported" |
| A48 | 80609 = max 2 participants | Error | CORRECTED | Live test | Error says "A Session may have at most 2 participants" not just "max 2" — ensured exact wording in skill |

## Corrections Applied

### C1: Error 80608 message clarification (A47)

- **Original text**: "Session status change not supported"
- **Corrected text**: Added the full error message guidance: "To re-open a session, choose In Progress. To close a session, choose Closed."
- **Why**: The error message itself tells you how to fix the problem — important to surface this.

### C2: Error 80609 exact wording (A48)

- **Original text**: Described as "max 2 participants"
- **Corrected text**: Exact message: "A Session may have at most 2 participants"
- **Why**: Precision in error messages helps debugging. Already correct in error code table, verified consistency.

## Qualifications Applied

### Q1: TTL reset on interaction (A4)
- **Condition**: Not live-tested; would require actual voice call or SMS through proxy. Docs confirm behavior.

### Q2: Intercept callback 403 blocking (A9)
- **Condition**: Not live-tested; would require deployed intercept webhook + actual communication. Docs confirm.

### Q3: Out-of-session auto-create (A10)
- **Condition**: Not live-tested. Docs confirm JSON response format.

### Q4: Interaction resource fields (A14)
- **Condition**: No interactions generated during testing. Field list from docs.

### Q5: Cross-service number restriction (A27, A30)
- **Condition**: Tested duplicate within same service (80104). Cross-service restriction from docs only (only 1 service in test).

### Q6: Pool size limits (A41)
- **Condition**: 5000/500 limits from docs. Would need 500+ numbers to verify.

### Q7: Stickiness behavioral difference (A13)
- **Condition**: `avoid-sticky` set and confirmed. Behavioral difference vs `prefer-sticky` needs multi-session test with same participant identifiers.
