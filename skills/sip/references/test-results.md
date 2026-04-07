---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Live test results for SIP Interface skill assertions. -->
<!-- ABOUTME: Evidence SIDs and API responses from 2026-03-28 testing. -->

# SIP Interface Skill — Live Test Results

Evidence date: 2026-03-28 | Account: ACxx...xx

## Test Environment

- Auth method: API Key (SK...)
- Existing SIP lab resources: ALf9e969314dee4888e1595b3eca763398 (IP ACL), CL174442222ec27318af176b4d9d59dd69 (Credential List)
- Test domain created and cleaned up within this session

## Test Results

### T1: Create SIP Domain — No Auth

**Action**: `POST /SIP/Domains.json` with DomainName and FriendlyName only

**Result**:
- SID: `SD88afbff455158e914746c49219ca7c4c`
- Domain: `sip-skill-test-125934.sip.twilio.com`
- `auth_type`: `""` (empty string)
- `sip_registration`: `false`
- `secure`: `false`
- `emergency_calling_enabled`: `false`
- `voice_url`: `null`
- `voice_fallback_url`: `null`

**Confirms**: authType is empty when no auth configured. sipRegistration, secure both default to false.

---

### T2: Legacy ACL Mapping

**Action**: `POST /SIP/Domains/{SD}/IpAccessControlListMappings` with ALf9e96...

**Result**:
- 200 OK — mapping created
- `auth_type` on domain: `"IP_ACL"`

**Confirms**: Legacy ACL mapping updates authType to "IP_ACL".

---

### T3: v2 ACL Mapping (Same ACL)

**Action**: `POST /SIP/Domains/{SD}/Auth/Calls/IpAccessControlListMappings` with same ALf9e96...

**Result**:
- 400 error, code 21231: "IpAccessControlList already associated with this domain"

**Confirms**: Legacy and v2 auth paths share the same backend storage. Cannot map the same ACL via both paths.

---

### T4: v2 Credential List Mapping (Calls)

**Action**: `POST /SIP/Domains/{SD}/Auth/Calls/CredentialListMappings` with CL174442...

**Result**:
- 200 OK — mapping created
- `auth_type` on domain: `"CREDENTIAL_LIST,IP_ACL"` (alphabetical, comma-delimited)

**Confirms**: Both auth types show in authType when both are configured. Values are alphabetical.

---

### T5: Enable SIP Registration

**Action**: `POST /SIP/Domains/{SD}.json` with `SipRegistration=true`

**Result**:
- `sip_registration`: `True`

**Confirms**: sipRegistration can be toggled via API update.

---

### T6: Registration Auth Credential List Mapping

**Action**: `POST /SIP/Domains/{SD}/Auth/Registrations/CredentialListMappings` with CL174442...

**Result**:
- 200 OK — mapping created (same CL as call auth, no conflict)

**Confirms**: Registration auth is independent from call auth. Same credential list can be mapped to both without conflict.

---

### T7: List All Auth Mappings

**Action**: GET on all four mapping endpoints

**Result**:
| Endpoint | Count |
|----------|-------|
| Legacy ACL mappings | 1 |
| v2 Auth Calls ACL mappings | 1 |
| v2 Auth Calls CL mappings | 1 |
| v2 Auth Registrations CL mappings | 1 |

**Confirms**: Legacy and v2 ACL mappings show the same single entry (shared storage). Registration CL mappings are separate.

---

### T8: Duplicate Domain Name

**Action**: `POST /SIP/Domains.json` with same DomainName as existing domain

**Result**:
- 400 error, code 21232: "Domain sip-skill-test-125934.sip.twilio.com already exists."

**Confirms**: Domain names are globally unique. Clear error code on collision.

---

### T9: Enable Secure Mode

**Action**: `POST /SIP/Domains/{SD}.json` with `Secure=true`

**Result**:
- `secure`: `True`

**Confirms**: Secure mode can be toggled via API update.

---

### T10: validate_sip on Domain

**Action**: `validate_sip(domainSid: "SD88afbff...")`

**Result**:
- `success`: false
- `domain`: passed — "Domain 'skill-test-domain' exists"
- `domainVoiceUrl`: failed — "No voiceUrl configured — inbound calls will fail"
- `domainIpAcl`: passed — "1 IP ACL mapping(s)"
- `domainCredentials`: passed — "1 credential list mapping(s)"
- `debugger`: failed — 26 SIP errors (account-wide 64102 errors from ConversationRelay, not related to test domain)

**Confirms**: validate_sip correctly identifies missing voiceUrl. Debugger errors are account-wide, not filtered to the specific domain.

---

### T11: Cleanup

**Action**: DELETE all mappings, then DELETE domain

**Result**: All 204 No Content — clean removal

**Confirms**: Reverse-order cleanup works. Remove mappings before deleting domain.

---

## Phase C: Live Call Testing (SIP Lab)

Test date: 2026-03-28 | PBX: Asterisk 20.15.2 @ 45.55.35.107 (DigitalOcean)
SIP Domain: SDf3f5fa51086812b5e4a8310093bdd883 (sip-lab-iface-0006e0.sip.twilio.com) — cleaned up

### T12: Inbound SIP — PBX to SIP Domain

**Action**: Asterisk sends SIP INVITE from dialplan context `outbound-via-sip-domain` to `PJSIP/100@twilio-sip-domain` (contact: `sip:sip-lab-iface-0006e0.sip.twilio.com`)

**SIP Exchange**:
1. INVITE → 100 Trying → 407 Proxy Auth Required (IP ACL passed, credentials challenged)
2. ACK + re-INVITE with digest auth
3. 200 OK — call connected

**Result**:
- Call SID: `CA42432b7c5c38a6fcc2c42bee5e52cfd1`
- Direction: `inbound`
- Status: `completed`
- voiceUrl webhook received SIP params: `SipDomain`, `SipDomainSid`, `SipCallId`, `SipSourceIp`
- No notifications (clean call)

**Confirms**: Inbound SIP INVITE to SIP Domain triggers voiceUrl, SIP-specific webhook params are populated.

---

### T13: Inbound SIP — Custom Header Passthrough

**Action**: Same as T12 but with `b()` pre-dial handler setting `X-Route-Id` and `X-Test-Timestamp` headers on the PJSIP channel via `PJSIP_HEADER(add,...)`.

**Result**:
- Call SID: `CA241d4ccb7e42fdd1cbfcc5a8623c07ed`
- Function logs: `SipHeader_X-Route-Id: phase-c-validation`, `SipHeader_X-Test-Timestamp: 1774760072`
- Both custom headers arrived in the webhook as `SipHeader_X-{Name}` parameters

**Confirms**: Custom X-prefixed SIP headers pass through from the INVITE to the voiceUrl webhook. Header names are preserved.

---

### T14: Outbound SIP — `<Dial><Sip>` to PBX

**Action**: API call to `+15551234567` with TwiML URL `/sip/dial-sip`, which returns `<Dial><Sip>sip:100@45.55.35.107:5060?x-test-header=skill-validation</Sip></Dial>`.

**Result**:
- Parent call: `CAe8da88b6b2086724ae70cf50b89a0523` (completed, 15s)
- Child SIP leg: `CA286ee3600f76fd0f371204edbc65cc21` (completed, 14s, `sip:100@45.55.35.107:5060`)
- Dial-complete action callback received:
  - `DialSipResponseCode: 200`
  - `DialSipCallId: d0947d027a811d54845414eb778b1812@0.0.0.0`
  - `DialCallStatus: completed`
- Asterisk answered with extension 100 (hello-world playback)
- No notifications (clean call)

**Confirms**: `<Dial><Sip>` sends SIP INVITE to target URI, action callback receives `DialSipResponseCode` and `DialSipCallId`.

---

### T15: Inbound Status Callback — Completed Only

**Action**: Reviewed status callback function logs for all 3 inbound SIP calls (CA42432b, CA4fa405a, CA241d4cc).

**Result**: All 3 calls received exactly one status callback event:
- `CallStatus: completed`
- No `initiated`, `ringing`, or `answered` events

**Confirms**: Inbound SIP to a SIP Domain only fires the `completed` status callback event, not the full set available on outbound.

---

### T16: ACL IP Mismatch — Error 32201

**Action**: Initial test with stale IP (203.0.113.10) in ACL while PBX was at 45.55.35.107.

**Result**:
- SIP exchange: INVITE → 100 Trying → 403 Forbidden
- `X-Twilio-Error: 32201 Authentication failure - source IP Address not in ACL`

**Confirms**: IP ACL is enforced. Mismatched IP produces 403 with descriptive X-Twilio-Error header. The error code (32201) and header are useful for diagnostics.

---

### T17: validate_sip on Live Domain

**Action**: `validate_sip(domainSid: "SDf3f5fa...")` on fully configured domain with voiceUrl, ACL, and credentials.

**Result**: All domain-specific checks passed (domain exists, voiceUrl configured, 1 ACL mapping, 1 CL mapping). Debugger showed 17 unrelated 64102 errors from ConversationRelay.

**Confirms**: validate_sip correctly validates domain configuration. Debugger check is account-wide (not domain-filtered).

---

## Registration Tests (2026-03-29)

Tool: baresip v4.6.0 (arm64/Darwin) — local SIP UA behind NAT

### T18: SIP Registration — Full Lifecycle

**Action**: baresip registered `siplab-e7f2a9c1` to `ff-regtest.sip.twilio.com` (SD9d8fda047eba67ef2447a026c6e03e22) with `sipRegistration: true` and credential list mapped to registration auth.

**Result** (SIP trace):
1. `REGISTER` → Twilio (no auth, CSeq 62480)
2. `407 Proxy Authentication required` ← Twilio (realm=`sip.twilio.com`, qop=auth, nonce provided)
3. `REGISTER` → Twilio (Proxy-Authorization with MD5 digest, CSeq 62481)
4. `200 OK` ← Twilio — Contact binding stored: `expires=600`, `[1 binding]`
5. `REGISTER expires=0` → Twilio (clean unregister on shutdown, CSeq 62482)
6. `200 OK` ← Twilio — binding removed

**Confirms**: Registration lifecycle (REGISTER → 407 → auth → 200), min expiry 600s accepted, clean unregister with Expires: 0, digest auth with realm `sip.twilio.com`.

---

### T19: Inbound Call to Registered Endpoint

**Action**: While baresip was registered, initiated API call `To=sip:siplab-e7f2a9c1@ff-regtest.sip.twilio.com` with TwiML `<Say>`.

**Result**:
- Call SID: `CAb8d21537a4b7eb64107b88a7c2582425`
- Twilio sent INVITE from `54.172.60.0:5060` to baresip's registered contact
- baresip sent `180 Ringing`, then `200 OK` (auto-answer)
- Call status: `completed`, duration: `5s`
- From header in INVITE: `sip:+15551234567@ff-regtest.sip.twilio.com`

**Confirms**: Twilio routes INVITE to registered endpoint's contact address (works through NAT). Softphone on dynamic IP receives inbound calls. Registration without static IP validated.

---

### T20: Expiry Capping — Request Above Maximum

**Action**: baresip registered with `regint=7200` (above 3600 max) to `ff-regtest-v2.sip.twilio.com` (SDe8f8f709cafbe5ec5c178e48c304b1b6).

**Result** (SIP trace):
- Outbound REGISTER Contact: `expires=7200`
- Twilio 200 OK Contact: `expires=3600` (capped to maximum)

**Confirms**: Twilio caps registration expiry above 3600 to exactly 3600 seconds. Assertion #28 validated.

---

### T21: Call Forking — Multiple Registrations per AOR

**Action**: Two baresip instances (UA1 on port 5070, UA2 on port 5080) registered the same AOR (`siplab-e7f2a9c1@ff-regtest-v2.sip.twilio.com`) with different `+sip.instance` UUIDs. Then called the AOR via REST API.

**Result**:
- UA1 registered → `[1 binding]`
- UA2 registered → `[2 bindings]` (Twilio confirmed both)
- API call `CA2300de15f446d6313b89e5ef9a7acec3`:
  - **UA1** received: `INVITE sip:siplab-e7f2a9c1@100.64.0.1:5070` → 180 Ringing → 200 (answered)
  - **UA2** received: `INVITE sip:siplab-e7f2a9c1@100.64.0.1:5080` → 180 Ringing → 200 (answered)
- Call status: `completed`, duration: `3s` (first answerer won)

**Confirms**: Multiple registrations per AOR cause call forking — Twilio sends INVITE to all registered contacts simultaneously. First to answer wins. Assertion #31 validated.
