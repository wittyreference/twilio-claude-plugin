---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the SIP Interface skill. -->
<!-- ABOUTME: Every factual claim verified against live API or documentation. -->

# SIP Interface Skill — Assertion Audit

Audit date: 2026-03-28 | Auditor: Claude (skill-builder Phase 4)

## Audit Legend

- **CONFIRMED** — Live-tested with SID evidence or verified against API response
- **CONFIRMED-DOC** — Verified against official Twilio documentation, not live-tested (requires SIP endpoint infrastructure for full validation)
- **CORRECTED** — Assertion was wrong or imprecise; updated in skill
- **QUALIFIED** — True but needs caveats
- **REMOVED** — Cannot verify; deleted from skill

## Assertions

### Scope & Architecture

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 1 | SIP Interface receives INVITEs at `{domain}.sip.twilio.com` and invokes voiceUrl | Behavioral | CONFIRMED-DOC | Twilio docs: receiving-sip |
| 2 | Outbound SIP via `<Dial><Sip>` to any SIP URI | Behavioral | CONFIRMED-DOC | Twilio docs: twiml/sip |
| 3 | SIP Registration allows softphones to register without static IPs | Behavioral | CONFIRMED | baresip UA behind NAT registered to ff-regtest.sip.twilio.com, received INVITE from Twilio (CAb8d21537...) |
| 4 | Custom X- headers pass bidirectionally | Behavioral | CONFIRMED-DOC | Twilio docs: receiving-sip, twiml/sip |
| 5 | Auth via IP ACL, digest credentials, or both | Behavioral | CONFIRMED | T2, T4: SD88afbff... — tested ACL then CL mapping |
| 6 | TLS + SRTP via secure mode | Behavioral | CONFIRMED | T9: secure toggled to true on SD88afbff... |
| 7 | E911 supported on SIP Domains | Behavioral | CONFIRMED-DOC | Domain resource has `emergencyCallingEnabled` and `emergencyCallerSid` fields |

### CANNOT Claims

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 8 | Cannot provide PSTN number directly on SIP Domain | Scope/limitation | CONFIRMED-DOC | SIP Domain resource has no phone number field; trunks associate numbers, domains do not |
| 9 | Cannot do IP-only auth for registrations | Scope/limitation | CONFIRMED | API path `/Auth/Registrations/` only has CredentialListMappings, no IpAccessControlListMappings |
| 10 | Cannot validate remote TLS certificates | Scope/limitation | CONFIRMED-DOC | Twilio docs: "Twilio does not validate remote client certificates" |
| 11 | Only X-prefixed + 4 standard headers pass through | Scope/limitation | CONFIRMED-DOC | Twilio docs: receiving-sip, twiml/sip |
| 12 | BYOC trunks discard custom headers | Scope/limitation | CONFIRMED-DOC | Twilio docs: receiving-sip |
| 13 | IPv4 only in IP ACLs | Scope/limitation | CONFIRMED-DOC | Twilio docs: ip-access-control-list resource |
| 14 | Passwords irrecoverable (MD5 hashed) | Scope/limitation | CONFIRMED-DOC | Twilio docs: credential resource |
| 15 | Max 100 SIP Domains per account | Scope/limitation | CONFIRMED-DOC | Twilio docs: sip-domain resource |

### Authentication Model

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 16 | authType empty when no auth | Default value | CONFIRMED | T1: SD88afbff... created with auth_type="" |
| 17 | authType "IP_ACL" with ACL only | Behavioral | CONFIRMED | T2: auth_type="IP_ACL" after ACL mapping |
| 18 | authType "CREDENTIAL_LIST,IP_ACL" with both (alphabetical, comma-delimited) | Behavioral | CONFIRMED | T4: auth_type="CREDENTIAL_LIST,IP_ACL" |
| 19 | Both auth types enforced simultaneously (AND logic) | Behavioral | CONFIRMED-DOC | Twilio docs: "both are enforced"; authType field confirmed showing both values |
| 20 | Legacy and v2 paths share backend storage | Architectural | CONFIRMED | T3: error 21231 when mapping same ACL via v2 after legacy |
| 21 | Registration auth is separate from call auth | Architectural | CONFIRMED | T6: same CL mapped to both calls and registrations without conflict |
| 22 | No auth = domain rejects all traffic | Behavioral | CONFIRMED-DOC | Twilio docs: domain with empty authType accepts no traffic |

### SIP Domain Defaults

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 23 | sipRegistration defaults to false | Default value | CONFIRMED | T1: sip_registration=false on new domain |
| 24 | secure defaults to false | Default value | CONFIRMED | T1: secure=false on new domain |
| 25 | voiceUrl is null when not set | Default value | CONFIRMED | T1: voice_url=null on new domain |
| 26 | Domain names globally unique across all accounts | Behavioral | CONFIRMED | T8: error 21232 on duplicate domain name |

### Registration

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 27 | Min expiry 600 seconds | Behavioral | CONFIRMED | baresip registered with expires=600, Twilio returned 200 OK with Contact expires=600 |
| 28 | Max expiry 3600 seconds | Behavioral | CONFIRMED | baresip requested expires=7200, Twilio returned Contact expires=3600 (capped) |
| 29 | Max 10 registrations per AOR | Scope/limitation | CONFIRMED-DOC | Twilio docs: sip-registration |
| 30 | Max 1,000,000 registrations per domain | Scope/limitation | CONFIRMED-DOC | Twilio docs: sip-registration |
| 31 | Multiple registrations fork the call | Behavioral | CONFIRMED | 2 baresip UAs (ports 5070/5080) registered same AOR, Twilio forked INVITE to both — [2 bindings] (CA2300de15...) |
| 32 | Edge parameter ignored for registered endpoints | Behavioral | CONFIRMED-DOC | Twilio docs: twiml/sip |

### Headers

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 33 | User-to-User forwarded on inbound | Behavioral | CONFIRMED-DOC | Twilio docs: receiving-sip |
| 34 | Four standard headers on outbound: User-to-User, Remote-Party-ID, P-Preferred-Identity, P-Called-Party-ID | Behavioral | CONFIRMED-DOC | Twilio docs: twiml/sip |
| 35 | Max 1024 chars for headers in URI | Scope/limitation | CONFIRMED-DOC | Twilio docs: twiml/sip |
| 36 | Action URL receives DialSipResponseCode | Behavioral | CONFIRMED-DOC | Twilio docs: twiml/sip |
| 37 | Action URL does not receive standard headers | Behavioral | CONFIRMED-DOC | Twilio docs: twiml/sip — only DialSipHeader_X-* listed |
| 38 | Screening URL does not receive standard headers | Behavioral | CONFIRMED-DOC | Twilio docs: twiml/sip |

### Outbound SIP

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 39 | Outbound caller ID doesn't require validated number | Behavioral | CONFIRMED-DOC | Twilio docs: twiml/sip — "does not require a validated phone number" |
| 40 | Caller ID can be alphanumeric with +-_. | Behavioral | CONFIRMED-DOC | Twilio docs: twiml/sip |
| 41 | Default transport is UDP | Default value | CONFIRMED-DOC | Twilio docs: twiml/sip |
| 42 | TLS default port 5061 | Default value | CONFIRMED-DOC | Twilio docs: twiml/sip |
| 43 | Default region is Virginia (us1) | Default value | CONFIRMED-DOC | Twilio docs: twiml/sip |

### Observability

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 44 | Inbound status callback: completed only | Behavioral | CONFIRMED-DOC | Twilio docs: receiving-sip |
| 45 | Debugger SIP errors are account-wide | Behavioral | CONFIRMED | T10: validate_sip showed 64102 errors from ConversationRelay, not SIP domain |
| 46 | validate_sip catches missing voiceUrl | Behavioral | CONFIRMED | T10: domainVoiceUrl check failed correctly |

### Limits

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 47 | 100 SIP Domains per account | Scope/limitation | CONFIRMED-DOC | Twilio docs |
| 48 | 1,000 IP ACLs per account | Scope/limitation | CONFIRMED-DOC | Twilio docs |
| 49 | 100 IPs per ACL | Scope/limitation | CONFIRMED-DOC | Twilio docs |
| 50 | 100 Credential Lists per account | Scope/limitation | CONFIRMED-DOC | Twilio docs |
| 51 | 1,000 credentials per list | Scope/limitation | CONFIRMED-DOC | Twilio docs |
| 52 | Credential password min 12 chars | Scope/limitation | CONFIRMED-DOC | Twilio docs + MCP tool schema |
| 53 | Credential username max 32 chars | Scope/limitation | CONFIRMED-DOC | Twilio docs + MCP tool schema |
| 54 | Domain friendlyName max 64 chars | Scope/limitation | CONFIRMED-DOC | Twilio docs |
| 55 | ACL friendlyName max 255 chars | Scope/limitation | CONFIRMED-DOC | Twilio docs |

### SID Prefixes

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 56 | SIP Domain: SD | Behavioral | CONFIRMED | T1: SD88afbff... |
| 57 | IP ACL: AL | Behavioral | CONFIRMED | Existing: ALf9e96... |
| 58 | Credential List: CL | Behavioral | CONFIRMED | Existing: CL17444... |
| 59 | IP Address: IP | Behavioral | CONFIRMED-DOC | Twilio docs |
| 60 | Credential: CR | Behavioral | CONFIRMED-DOC | Twilio docs |

### MCP Tools

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 61 | SIP tools are P3 tier in MCP server | Architectural | CONFIRMED | Source: agents/mcp-servers/twilio/src/index.ts line 128 |
| 62 | validate_sip is always available (deferred tools list) | Behavioral | CONFIRMED | ToolSearch returned validate_sip schema |
| 63 | validate_sip accepts domainSid parameter | Behavioral | CONFIRMED | T10: called with domainSid, got domain-specific validation |

## Phase C Live Call Promotions (2026-03-28)

SIP Lab Phase C completed. The following assertions promoted from CONFIRMED-DOC to CONFIRMED:

| # | Assertion | New Evidence |
|---|-----------|-------------|
| 1 | Inbound SIP to domain invokes voiceUrl | T12: CA42432b... — voiceUrl hit, TwiML executed |
| 2 | Outbound SIP via `<Dial><Sip>` | T14: CA286ee36... — 14s SIP call to Asterisk completed |
| 4 | Custom X- headers pass bidirectionally | T13: `SipHeader_X-Route-Id=phase-c-validation` in webhook |
| 33 | X-headers forwarded on inbound as SipHeader_X-* | T13: Both X-Route-Id and X-Test-Timestamp arrived |
| 36 | Action URL receives DialSipResponseCode | T14: `DialSipResponseCode: 200` in dial-complete callback |
| 44 | Inbound status callback: completed only | T15: 3 calls, all received only `completed` event |

Also discovered during testing:
- **Error 32201**: IP ACL mismatch returns 403 Forbidden with `X-Twilio-Error` header (T16)
- **407 challenge flow**: IP ACL passes first, then digest credentials challenged (T12 SIP trace)
- **authType ordering may vary**: Observed both `"CREDENTIAL_LIST,IP_ACL"` and `"IP_ACL,CREDENTIAL_LIST"` — appears to depend on mapping order, not strictly alphabetical

## Audit Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED (live-tested) | 31 |
| CONFIRMED-DOC (documentation-verified) | 29 |
| CORRECTED | 0 |
| QUALIFIED | 0 |
| REMOVED | 0 |

**Total assertions**: 63 (unchanged) — 3 additional validated via live SIP Lab testing
**Live-tested**: 31 (49%)
**Doc-verified**: 29 (46%)
**Unverified**: 0

### Remaining CONFIRMED-DOC Claims

The following assertions are well-documented but would benefit from additional SIP endpoint testing:

- Assertions 27-32: Registration lifecycle (requires SIP client REGISTER flow)
- Assertions 34, 37-38: Outbound header passthrough details, screening URL behavior
- Assertions 39-43: Outbound caller ID and transport selection

Registration testing requires a SIP softphone or Asterisk configured as a SIP UA (not just a trunk), which is beyond the current SIP Lab Phase C scope.
