---
name: "proxy"
description: "Twilio development skill: proxy"
---

---
name: proxy
description: Twilio Proxy number masking guide. Use when building anonymous communication between two parties (rider/driver, buyer/seller), managing proxy number pools, or debugging masked call/SMS flows.
---

<!-- verified: twilio.com/docs/proxy, twilio.com/docs/proxy/api/service, twilio.com/docs/proxy/api/session, twilio.com/docs/proxy/api/participant, twilio.com/docs/proxy/api/interaction, twilio.com/docs/proxy/api/phone-number, twilio.com/docs/proxy/reserved-phone-numbers + live testing 2026-03-25 -->

# Twilio Proxy

Anonymous number masking between two parties. Covers session lifecycle, participant management, number pool strategy, webhook types, and error handling. **Proxy is Public Beta, closed to new customers** — existing customers can continue using it but it is not covered by Twilio SLA.

Evidence date: 2026-03-25. Account prefix: ACb4de. Services: KS7631760e (deleted), KS9493ceb9 (deleted).

## Scope

### CAN

- Mask phone numbers between exactly 2 participants per session <!-- verified: KP6aef10ec + KPbe9b838f, both got proxy +12067597288 -->
- Voice calls and SMS through masked proxy numbers, configurable per session mode <!-- verified: KC3dce86d0, mode=voice-and-message -->
- Auto-assign proxy numbers from the service's number pool based on geo-matching and stickiness <!-- verified: KP6aef10ec, auto-assigned from pool -->
- Three session modes: `voice-and-message`, `voice-only`, `message-only` <!-- verified: KC3dce86d0 -->
- TTL-based session expiry with reset on each interaction <!-- verified: twilio.com/docs/proxy/api/session -->
- Explicit `dateExpiry` (absolute timestamp) that overrides TTL <!-- verified: KC264a8191, dateExpiry set while ttl also stored -->
- Service-level `defaultTtl` as fallback when sessions omit TTL <!-- verified: KS7631760e, defaultTtl=300 -->
- Close sessions programmatically (`Status=closed`) with `closedReason: "api"` <!-- verified: KC3dce86d0 -->
- **Reopen closed sessions** to `in-progress` status — participants and proxy assignments preserved <!-- verified: KC3dce86d0, both participants survived close→reopen -->
- Three webhook types: informational callback, intercept (gating), out-of-session <!-- verified: twilio.com/docs/proxy/api/webhooks -->
- Intercept callback: return 403 to block an interaction before it connects <!-- verified: twilio.com/docs/proxy/api/webhooks -->
- Out-of-session callback: auto-create sessions via JSON response when no active session matches <!-- verified: twilio.com/docs/proxy/out-session-callback-response-guide -->
- Number pool with reserved/unreserved distinction and `inUse` counter <!-- verified: PNe9f78a15, isReserved=true, inUse=0 -->
- Geo-matching: `country` (global), `area-code` (NA only), `extended-area-code` (NA only) <!-- verified: KS7631760e, geoMatchLevel=country -->
- Number selection: `prefer-sticky` (reuse proxy per real number) vs `avoid-sticky` (maximum privacy) <!-- verified: KS7631760e, numberSelectionBehavior=avoid-sticky -->
- Read-only interaction log with inbound/outbound legs linking to Call/Message SIDs <!-- verified: twilio.com/docs/proxy/api/interaction -->

### CANNOT

<!-- verified: all CANNOT items live-tested 2026-03-25 unless noted -->

- **Max 2 participants per session** — Adding a 3rd returns error 80609. This is a hard platform limit, not configurable. For multi-party masking, create multiple sessions. <!-- verified: 80609 "A Session may have at most 2 participants" -->
- **Cannot reopen a session to `open` status** — Closed sessions can only be reopened to `in-progress`. Attempting `Status=open` returns error 80608: "To re-open a session, choose In Progress." <!-- verified: KC3dce86d0, 80608 -->
- **Cannot use fake phone numbers as participant identifiers** — Proxy validates reachability. Numbers like `+15551234567` return error 80404 "does not appear to be a valid, reachable identity." Use real phone numbers only. <!-- verified: 80404 on +15551234567 -->
- **Cannot auto-assign reserved numbers** — Reserved numbers are excluded from the auto-assignment pool. Adding a participant when only reserved numbers exist returns error 80207. Explicit assignment via `ProxyIdentifierSid` also fails in practice despite documentation suggesting otherwise. <!-- verified: KCec4577f8, 80207 even with ProxyIdentifierSid -->
- **Service deletion cascades silently** — Deleting a Proxy Service returns HTTP 204 and destroys all sessions, participants, interactions, and number assignments without warning or confirmation. There is no "are you sure" guard. <!-- verified: KS7631760e deleted with active sessions, HTTP 204 -->
- **Proxy overwrites phone number webhooks** — Adding a number to a Proxy pool changes its voice and SMS webhook URLs. When the service is deleted, webhooks revert to Twilio demo defaults, NOT the original values. Back up webhook configuration before adding numbers to Proxy. <!-- verified: PNe9f78a15, voiceUrl changed to demo.twilio.com after proxy add/delete cycle -->
- **MCP tools require P2 tier** — 17 Proxy tools exist in `proxy.ts` but are in the P2 tier (not loaded by default). Enable with `toolTiers: ['P0', 'P2', 'validation']` or `['all']`. Without P2, use REST API directly. <!-- verified: proxy.ts has 17 createTool() calls, registered in tierRegistry P2 -->
- **Cannot create interactions directly** — Interactions are read-only resources created automatically when participants communicate. No POST endpoint exists.
- **A number cannot belong to multiple Proxy Services** — Error 80104 if you try to add a number already in another service's pool. <!-- verified: 80104 -->
- **`dateExpiry` is null until first interaction** — Even with TTL set, `dateExpiry` remains null on the session until the TTL timer starts (triggered by interaction or explicit dateExpiry). <!-- verified: KC3dce86d0, ttl=600 but dateExpiry=null -->
- **Public Beta, closed to new customers** — Not covered by Twilio SLA. New accounts cannot enable Proxy. Existing customers can continue using it. <!-- verified: twilio.com/docs/proxy -->

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Rider/driver masking | Session per ride, TTL = ride duration + buffer | Auto-cleanup, both parties share 1 proxy number |
| Buyer/seller marketplace | Session per transaction, `prefer-sticky` | Same proxy number across messages builds trust |
| Support callback masking | Session per ticket, close on resolution | Agent's real number never exposed |
| Maximum privacy between sessions | `avoid-sticky` on service | Different proxy number each time |
| Published business number + masking | Reserved number + explicit assignment | Number stays consistent, still routed through Proxy |
| Block abusive callers | Intercept callback returning 403 | Per-interaction gating before connection |
| Handle calls after session ends | Out-of-session callback | Auto-create new session or play TwiML message |
| Drain a number before removing | Mark as `isReserved=true` | Stops new assignments, existing sessions finish |

## Decision Frameworks

### Session Mode Selection

| Mode | Voice | SMS | When to use |
|------|-------|-----|-------------|
| `voice-and-message` | Yes | Yes | Default — ride-sharing, marketplace, support |
| `voice-only` | Yes | No | Call centers, privacy-sensitive voice scenarios |
| `message-only` | No | Yes | Chat-only marketplace, delivery notifications |

### Number Pool Strategy

| Strategy | `numberSelectionBehavior` | Pool Size Guidance | Use Case |
|----------|--------------------------|-------------------|----------|
| Maximum privacy | `avoid-sticky` | Larger pool needed | Each session gets a different proxy number |
| Familiar numbers | `prefer-sticky` | Smaller pool OK | Same real person gets same proxy across sessions |
| Dedicated numbers | Reserved (`isReserved=true`) | 1:1 mapping | Published numbers, business cards |
| Number draining | Mark as reserved | N/A | Stop new assignments before removing |

### Geo-Matching

| Level | Scope | Availability | Best for |
|-------|-------|-------------|----------|
| `country` | Same country only | Global | International services |
| `area-code` | Same NPA (area code) | North America only | Local feel for US/Canada users |
| `extended-area-code` | Same local rate center | North America only | Maximum local appearance |

### TTL Strategy

| Scenario | TTL | Why |
|----------|-----|-----|
| Ride-sharing | 3600 (1 hour) | Ride + buffer. Resets on each call/text |
| Marketplace listing | 86400 (24 hours) | Buyer has a day to communicate |
| Support ticket | 0 (no expiry) | Close manually on ticket resolution |
| Quick verification | 300 (5 minutes) | Just enough for a callback |

## Session Lifecycle

```
                    create
                      │
                      ▼
                   ┌──────┐
                   │ open │ ← dateStarted=null, dateExpiry=null
                   └──┬───┘
                      │ first interaction
                      ▼
               ┌─────────────┐
               │ in-progress │ ← dateStarted set, TTL timer active
               └──────┬──────┘
                      │ close (API or TTL expiry)
                      ▼
                  ┌────────┐
                  │ closed │ ← closedReason set, dateEnded set
                  └───┬────┘
                      │ update Status=in-progress
                      ▼
               ┌─────────────┐
               │ in-progress │ ← reopened, participants preserved
               └─────────────┘
```

**Status transitions**: `open` → `in-progress` (on interaction) → `closed` (API or TTL) → `in-progress` (reopen). Cannot go back to `open`.

## Webhook Reference

### Informational Callback (`callbackUrl`)

Fires on each interaction. Cannot block. Use for logging, analytics.

### Intercept Callback (`interceptCallbackUrl`)

Fires **before** each interaction connects.

| Response | Effect |
|----------|--------|
| Any 2xx | Allow the interaction |
| 403 | Block the interaction |
| Timeout | Allow (fail-open) |

Key payload fields: `inboundParticipantSid`, `outboundParticipantSid`, `interactionSid`, `interactionType` (`voice` or `message`).

### Out-of-Session Callback (`outOfSessionCallbackUrl`)

Fires when an inbound call/SMS arrives on a proxy number with no matching active session.

**Response options**:
1. Return TwiML (`Content-Type: application/xml`) — play a message, gather input
2. Return JSON (`Content-Type: application/json`) — auto-create a new session with `participantIdentifier` (required), optional `mode`, `ttl`, `uniqueName`

## Error Codes — Live Verified

| Code | HTTP | Message | Trigger |
|------|------|---------|---------|
| 80103 | 400 | Participant already added to session | Duplicate identifier in same session |
| 80104 | 400 | PhoneNumber already added to service | Duplicate number in pool |
| 80207 | 400 | No compatible proxy numbers | Empty pool or all numbers reserved |
| 80404 | 400 | Invalid/unreachable participant identifier | Fake or invalid phone number |
| 80603 | 400 | Session UniqueName must be unique | Duplicate session name in service |
| 80608 | 400 | Session status change not supported | Trying to set status to `open` (use `in-progress`) |
| 80609 | 400 | Max 2 participants per session | Adding 3rd participant |

## Gotchas

### Service Configuration

1. **Service deletion cascades silently**: Deleting a Proxy Service immediately destroys all sessions, participants, interactions, and number assignments. HTTP 204, no confirmation prompt. Always close sessions and remove numbers first if you need an audit trail. [Evidence: KS7631760e deleted with active session + 2 participants]

2. **Proxy overwrites phone number webhooks**: When you add a number to a Proxy pool, its voice and SMS webhook URLs are overwritten. When the service is deleted, webhooks revert to Twilio demo defaults (`demo.twilio.com`), NOT the original values. Back up webhook configuration before adding to Proxy. [Evidence: PNe9f78a15, original empty URLs → demo URLs after proxy lifecycle]

3. **A number can only belong to one Proxy Service**: Adding a number already in another service returns 80104. Remove it from the first service before adding to another.

### Session Lifecycle

4. **Session stays `open` until first interaction**: Adding participants does not change status to `in-progress`. The session transitions only when actual communication occurs. `dateStarted` and `dateExpiry` remain null until then. [Evidence: KC3dce86d0, 2 participants but status=open, dateStarted=null]

5. **TTL doesn't create a `dateExpiry` until interaction**: Setting `ttl=600` on creation does NOT set `dateExpiry`. The countdown starts on the first interaction. Use explicit `dateExpiry` if you need a hard deadline regardless of interaction. [Evidence: KC3dce86d0, ttl=600 but dateExpiry=null]

6. **`dateExpiry` overrides `ttl`**: When both are provided, `dateExpiry` wins for determining when the session expires. Both values are stored. [Evidence: KC264a8191, both ttl=600 and dateExpiry set]

7. **Closed sessions can be reopened**: Set `Status=in-progress` to reopen. Participants and proxy assignments are preserved. Setting `Status=open` returns error 80608. [Evidence: KC3dce86d0, successfully reopened after close]

8. **`closedReason` values**: `"api"` for programmatic close, other values for TTL expiry or system events. Cleared on reopen. [Evidence: KC3dce86d0, closedReason="api" then null after reopen]

### Participants & Numbers

9. **Participant identifiers must be real, reachable numbers**: Proxy validates phone number reachability on add. Fake test numbers (like `+15551234567`) return 80404. Use real Twilio numbers or real mobile numbers for testing. [Evidence: 80404 on +15551234567]

10. **Both participants share the same proxy number**: In a 2-party session with 1 pool number, both participants are assigned the same proxy number. Proxy routes based on who's calling — when A calls the proxy number, it connects to B, and vice versa. [Evidence: KP6aef10ec and KPbe9b838f both got +12067597288]

11. **Reserved numbers are excluded from auto-assignment**: Even with explicit `ProxyIdentifierSid`, reserved numbers may be rejected (80207). The documented behavior of explicit reserved number assignment did not work in live testing. To use a specific number, keep it unreserved. [Evidence: KCec4577f8, 80207 even with ProxyIdentifierSid]

12. **Max 2 participants is not configurable**: Hard platform limit. For multi-party scenarios, create multiple Proxy sessions. [Evidence: 80609]

13. **Duplicate participant identifier rejected**: Same phone number cannot appear twice in one session. Error 80103. [Evidence: duplicate +12069666002]

### Number Pool Limits

14. **5,000 reserved + 500 unreserved numbers per service**: Reserved numbers are for explicit assignment or draining. Unreserved numbers are the auto-assignment pool.

15. **`inUse` counter on pool numbers**: Shows how many active sessions use each number. Check before removing a number — removing an in-use number disrupts active sessions.

### MCP & API

16. **No MCP tools available at runtime**: All 17 Proxy tools exist in source but aren't loaded. Use REST API directly. This is the only Twilio domain with zero MCP tool availability.

17. **Proxy is Public Beta**: Closed to new customers, not covered by SLA. Existing accounts continue to work. Consider Twilio Conversations for new projects needing anonymous communication.

## SID Reference

| Prefix | Resource | Example |
|--------|----------|---------|
| `KS` | Service | KS7631760e2fe421e19bce81ac6848576e |
| `KC` | Session | KC3dce86d092f6353666e5ba2ba65085d5 |
| `KP` | Participant | KP6aef10ec5b1fb4c8f5b0db64049f6e46 |
| `KI` | Interaction | (read-only, auto-created) |

## Related Resources

- **Proxy CLAUDE.md** (`CLAUDE.md`) — File inventory, session flow diagram, intercept callback details
- **Phone Numbers skill** (`skills/phone-numbers/SKILL.md`) — Number management, webhook configuration (relevant since Proxy overwrites webhooks)
- **Voice skill** (`skills/voice/SKILL.md`) — Voice call handling patterns used alongside Proxy
- **Codebase functions**: `session-manager.protected.js`, `participant-manager.protected.js`, `intercept-callback.protected.js`
- **MCP source** (not loadable): `twilio/src/tools/proxy.ts` — 17 tool definitions
- **Unit tests**: `__tests__/unit/proxy/` — 86 test cases covering all 3 functions

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Test results | `references/test-results.md` | Live test evidence with SID references |
| Assertion audit | `references/assertion-audit.md` | Adversarial audit of every factual claim |
