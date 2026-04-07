---
name: "elastic-sip-trunking"
description: "Twilio development skill: elastic-sip-trunking"
---

---
name: elastic-sip-trunking
description: Elastic SIP Trunking deep guide — trunk lifecycle, origination/termination routing, recording, security, auth, disaster recovery, capacity planning. Use when connecting enterprise PBX/SBC to PSTN via Twilio trunking, configuring origination URLs, setting up trunk recording, or debugging SIP connectivity.
---

<!-- ABOUTME: Deep guide for Twilio Elastic SIP Trunking — trunk lifecycle, routing, recording, security, and diagnostics. -->
<!-- ABOUTME: Covers everything beyond the overview in sip-byoc.md: live-tested API behaviors, edge cases, and provisioning patterns. -->

# Elastic SIP Trunking

Deep guide for Twilio Elastic SIP Trunking. For the high-level comparison of SIP Interface vs Elastic SIP Trunking vs BYOC, see `/skills/sip-byoc.md`. This skill covers the trunking-specific depth: full API surface, live-tested behaviors, provisioning patterns, and diagnostics.

Evidence date: 2026-03-28. Tested against account prefix `AC1cb3`.

---

## Scope

### CAN

- Provide a pure PSTN conduit between your PBX/SBC and the public telephone network
- Route inbound PSTN calls to your infrastructure via configurable origination URLs with priority/weight failover
- Route outbound calls from your PBX through Twilio to the PSTN (termination)
- Record all calls on a trunk (trunk-level recording with 5 mode options)
- Authenticate via IP ACL, credential list, or both simultaneously
- Enable TLS/SRTP encryption (secure trunking) per trunk
- Assign Twilio phone numbers to trunks for inbound routing
- Configure disaster recovery URLs for failover
- Enable CNAM lookup on inbound calls
- Control SIP REFER transfer behavior per trunk
- Monitor call quality via Voice Insights (`callType=trunking`)
- Use multiple origination URLs per trunk for load balancing and failover
- Associate multiple IP ACLs and credential lists per trunk

### CANNOT

- Run TwiML, Studio Flows, or any Programmable Voice logic — calls bypass PV entirely
- Record individual calls selectively — trunk recording is all-or-nothing for the trunk
- Use `<Gather>`, `<Conference>`, `<Enqueue>`, or any TwiML verbs
- Use TaskRouter, ConversationRelay, or any PV-dependent features
- Register SIP endpoints — trunking is INVITE-only (registration is a SIP Interface feature)
- Set per-call webhooks or status callbacks — there is no webhook surface
- Use real-time transcription (`<Start><Transcription>`) on trunk calls
- Route based on caller ID, time of day, or any call attribute — routing is trunk-level, not per-call
- Port numbers between trunks without removing and re-associating them
- Use Answering Machine Detection (AMD) — AMD does not work with SIP Trunking
- Use non-G.711 codecs (G.729, Opus, AMR-NB) without Limited Availability enrollment

---

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| PSTN pipe, no call logic needed | Elastic SIP Trunking | Cheapest, bypasses PV |
| PSTN pipe + IVR/TwiML/Studio | SIP Interface | Full PV surface |
| PSTN pipe + keep carrier numbers | BYOC (SIP Interface subtype) | No porting required |
| Record specific calls only | SIP Interface + per-call recording | Trunk recording is all-or-nothing |
| Real-time speech/AI on calls | SIP Interface + ConversationRelay | CRelay requires PV |
| Multiple PBX failover | Elastic SIP Trunking with priority/weight origination URLs | Built-in priority/weight failover + DisasterRecoveryUrl as last resort |
| Regulatory compliance recording | Elastic SIP Trunking + trunk recording | Records every call, sends to VI for transcription |

---

## Decision Frameworks

### Authentication Method

| Scenario | Use | Why |
|----------|-----|-----|
| SBC with static public IPs | IP ACL only | Simplest, no credential management |
| Cloud PBX with dynamic IPs | Credential list only | IPs change, can't maintain ACL |
| High-security requirements | IP ACL + credential list | Defense in depth — both must pass |
| Multiple SBCs, same credentials | One credential list, multiple IP ACLs | Shared auth, per-SBC IP whitelisting |

When both IP ACL and credential list are associated, the trunk's `auth_type` field dynamically reflects the combination (e.g., `"IP_ACL,CREDENTIAL_LIST"`). The `auth_type_set` array shows which auth methods are active. Adding/removing ACLs or credential lists updates these fields automatically.

### Recording Mode

| Mode | Records | Use when |
|------|---------|----------|
| `do-not-record` | Nothing | Default. Cost-sensitive, no compliance needs |
| `record-from-answer` | After answer | Standard compliance recording |
| `record-from-ringing` | Including ring | Need to capture IVR prompts or pre-answer audio |
| `record-from-answer-dual` | After answer, dual-channel | Need speaker separation for transcription/analytics |
| `record-from-ringing-dual` | Including ring, dual-channel | Full capture with speaker separation |

Dual-channel recordings produce separate audio tracks per call leg. Use dual-channel when sending recordings to Voice Intelligence for transcription — speaker separation produces better transcripts.

Trim options: `trim-silence` (remove leading/trailing silence) or `do-not-trim` (keep as-is).

### Transfer Mode

| Mode | Behavior |
|------|----------|
| `disable-all` | Default. SIP REFER transfers blocked |
| `enable-all` | Allow all transfer types (REFER + INVITE-based) |
| `sip-only` | Allow SIP REFER transfers only |

`transfer_caller_id` controls which party's caller ID appears on the transferred leg:
- `from-transferee` (default) — the party being transferred
- `from-transferor` — the party initiating the transfer

---

## Trunk Properties Reference

| Property | Type | Default | Notes |
|----------|------|---------|-------|
| `FriendlyName` | string | `null` | Optional. No length limit observed (65+ chars accepted). Can be null/empty. |
| `DomainName` | string | `null` | Must end with `.pstn.twilio.com`. Not auto-generated — must be explicitly set. Globally unique (error 21248 on collision). |
| `Secure` | boolean | `false` | Enables TLS for SIP signaling and SRTP for media |
| `CnamLookupEnabled` | boolean | `false` | CNAM lookup on inbound calls. Per-lookup charges apply. |
| `DisasterRecoveryUrl` | URL | `null` | Fallback URL if primary origination fails |
| `DisasterRecoveryMethod` | `GET`/`POST` | `POST` | HTTP method for disaster recovery URL |
| `TransferMode` | enum | `disable-all` | `disable-all`, `enable-all`, `sip-only` |
| `TransferCallerId` | enum | `from-transferee` | `from-transferee`, `from-transferor` |
| `SymmetricRtpEnabled` | boolean | `false` | Symmetric RTP for NAT traversal. May require account-level enablement — setting to `true` via API was silently ignored in testing. |

Read-only computed fields:
- `auth_type` — string describing active auth methods (e.g., `"IP_ACL"`, `"CREDENTIAL_LIST"`, `"IP_ACL,CREDENTIAL_LIST"`)
- `auth_type_set` — array of active auth method strings

### Domain Name Rules

- Must end with `.pstn.twilio.com` (error 21245 otherwise)
- Globally unique across all Twilio accounts (error 21248 on collision)
- Not auto-generated at creation — new trunks have `domain_name: null`
- Format: `sip:{E.164-number}@{domain_name}` for termination
- Used by your PBX to send outbound SIP INVITEs to Twilio

---

## Origination URL Routing

Origination URLs define where inbound PSTN calls are routed — your PBX/SBC endpoints.

### Priority and Weight

Routing follows a DNS SRV-inspired selection algorithm (priority then weighted distribution), applied at the Twilio platform layer — not via actual DNS SRV lookups:

1. Sort origination URLs by `priority` (ascending — lower number = higher priority)
2. Among URLs with equal priority, distribute by `weight` (higher = more traffic, proportional)
3. If the selected URL fails, try the next by priority

| Parameter | Range | Meaning |
|-----------|-------|---------|
| `priority` | 0–65535 | Lower = tried first. Use for failover tiers. |
| `weight` | 0–65535 | Relative distribution within same priority. Weight=0 is accepted. |

**Failover example:**
```javascript
// Primary datacenter (tried first)
await client.trunking.v1.trunks(trunkSid).originationUrls.create({
  friendlyName: 'DC-East Primary',
  sipUrl: 'sip:sbc-east.example.com:5060',
  priority: 10,
  weight: 10,
  enabled: true,
});

// Secondary datacenter (failover)
await client.trunking.v1.trunks(trunkSid).originationUrls.create({
  friendlyName: 'DC-West Backup',
  sipUrl: 'sip:sbc-west.example.com:5060',
  priority: 20,
  weight: 10,
  enabled: true,
});
```

**Load balancing example (equal priority, different weights):**
```javascript
// 70% to primary, 30% to secondary
{ sipUrl: 'sip:sbc-1.example.com:5060', priority: 10, weight: 70 }
{ sipUrl: 'sip:sbc-2.example.com:5060', priority: 10, weight: 30 }
```

### SIP URL Formats

Both `sip:` and `sips:` schemes are accepted:
- `sip:192.168.1.1:5060` — standard SIP over UDP/TCP
- `sips:192.168.1.1:5061;transport=tls` — SIP over TLS
- `sip:sbc.example.com:5060` — hostname-based

Invalid schemes (e.g., `http://`) are rejected.

### Disaster Recovery URL

The `DisasterRecoveryUrl` is a trunk-level webhook fallback invoked when all origination URLs fail for an inbound PSTN call.

**Trigger conditions** — the DR URL is invoked when:
- All origination URLs are unreachable (connection timeout, connection refused, DNS resolution failure)
- All origination URLs return SIP 5xx server errors
- No origination URLs are configured on the trunk
- All origination URLs are disabled (`enabled: false`)

**Not triggered by:**
- Individual SIP 4xx responses from reachable endpoints (486 Busy, 404 Not Found) — these indicate the endpoint answered the INVITE but rejected it
- A single origination URL failing when others at a lower priority are still available

**Scope:** Per-trunk, not per-call. One DR URL applies to all inbound calls on the trunk. You cannot customize failover behavior per-call at the trunk level. For per-call control, use SIP Interface with TwiML routing instead.

**Configuration:**
```javascript
await client.trunking.v1.trunks(trunkSid).update({
  disasterRecoveryUrl: 'https://your-fallback.example.com/dr-handler',
  disasterRecoveryMethod: 'POST',
});
```

**Response format and parameters:** [UNVERIFIED] Twilio documentation does not fully specify the parameters sent to the DR URL or the expected response format. Test your DR URL behavior in a staging environment by disabling all origination URLs and inspecting the incoming webhook with a request inspection tool.

**Relationship to origination URL routing:**
1. Twilio attempts origination URLs in priority order (lower number first)
2. Within same priority, URLs are load-balanced by weight
3. If all URLs at all priority tiers fail → DR URL is invoked
4. If no DR URL is configured → call is rejected

---

## Provisioning Patterns

### Setup Order (Dependencies)

Resources must be created in dependency order:

```
1. IP Access Control Lists (AL) — account-level
   └── IP Addresses within each ACL
2. Credential Lists (CL) — account-level
   └── Credentials within each list
3. SIP Trunk (TK)
   ├── Associate IP ACLs to trunk
   ├── Associate credential lists to trunk
   ├── Create origination URLs on trunk
   ├── Configure recording on trunk
   └── Associate phone numbers to trunk
```

### Teardown Order (Reverse Dependencies)

Teardown must reverse the setup order. Deleting a trunk with associated subresources will fail:

```
1. Remove phone numbers from trunk
2. Remove IP ACL associations from trunk
3. Remove credential list associations from trunk
4. Delete origination URLs from trunk
5. Delete the trunk
6. (Optional) Delete IP ACLs and credential lists if not shared
```

The SIP Lab (`infrastructure/sip-lab/scripts/teardown-sip-lab.js`) demonstrates this pattern with proper error handling for already-deleted resources.

### Provisioning with the SDK

```javascript
const client = require('twilio')(accountSid, authToken);

// 1. Create ACL with IP address
const acl = await client.sip.ipAccessControlLists.create({
  friendlyName: 'Production SBCs',
});
await client.sip.ipAccessControlLists(acl.sid)
  .ipAddresses.create({
    friendlyName: 'Primary SBC',
    ipAddress: '203.0.113.10',
  });

// 2. Create trunk
const trunk = await client.trunking.v1.trunks.create({
  friendlyName: 'production-trunk',
  domainName: 'mycompany-prod.pstn.twilio.com',
  secure: false,
});

// 3. Associate ACL
await client.trunking.v1.trunks(trunk.sid)
  .ipAccessControlLists.create({
    ipAccessControlListSid: acl.sid,
  });

// 4. Create origination URL
await client.trunking.v1.trunks(trunk.sid)
  .originationUrls.create({
    friendlyName: 'Primary SBC',
    sipUrl: 'sip:203.0.113.10:5060',
    priority: 10,
    weight: 10,
    enabled: true,
  });

// 5. Configure recording
await client.trunking.v1.trunks(trunk.sid)
  .recording().update({
    mode: 'record-from-answer-dual',
    trim: 'trim-silence',
  });

// 6. Associate phone number
await client.trunking.v1.trunks(trunk.sid)
  .phoneNumbers.create({
    phoneNumberSid: 'PNxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  });
```

---

## Secure Trunking (TLS/SRTP)

Setting `Secure=true` on a trunk enables:
- **TLS** for SIP signaling (port 5061)
- **SRTP** for media encryption

Requirements:
- Your PBX/SBC must support TLS and SRTP
- Use `sips:` scheme in origination URLs for inbound
- Your PBX sends to `sips:{number}@{domain_name}` for outbound
- Self-signed certificates work for the PBX side (Twilio validates its own certs)

The SIP Lab demonstrates secure trunking with Asterisk PJSIP and self-signed certificates generated at container startup (`infrastructure/sip-lab/asterisk/entrypoint.sh`).

---

## Twilio SIP Signaling IPs

Your firewall must allow traffic from Twilio's SIP signaling IPs. These vary by edge location:

| Edge | Region | IP Ranges |
|------|--------|-----------|
| ashburn | US East | See Twilio IP ranges doc |
| umatilla | US West | See Twilio IP ranges doc |
| dublin | Europe | See Twilio IP ranges doc |
| frankfurt | Europe | See Twilio IP ranges doc |
| sao-paulo | South America | See Twilio IP ranges doc |
| singapore | Asia Pacific | See Twilio IP ranges doc |
| tokyo | Asia Pacific | See Twilio IP ranges doc |
| sydney | Asia Pacific | See Twilio IP ranges doc |

Twilio publishes current IP ranges at the SIP trunking IP addresses documentation page. These IPs can change — use a firewall that supports DNS/FQDN-based rules, or subscribe to Twilio's IP range change notifications.

Media (RTP) uses a separate, larger IP range from signaling (SIP).

---

## Voice Insights Integration

Trunking calls appear in Voice Insights with `callType: "trunking"` and `direction: "trunking_originating"`. They are distinct call SIDs from the API-initiated parent call.

| API | Works for trunking? | Notes |
|-----|-------------------|-------|
| Call Events (`/Voice/{CallSid}/Events`) | Yes | Connection lifecycle events on carrier_edge |
| Call Summary (`/Voice/{CallSid}/Summary`) | Yes | Available after processing (~5-15 min) |
| Call Summaries list (`CallType=trunking`) | Yes | **Must use `ProcessingState=all`** to see partial results — default filter excludes them during processing |

Query trunking calls via MCP:
```
mcp__twilio__list_call_summaries(callType: "trunking", processingState: "all")
```

The trunk-leg `To` field is a SIP URI (e.g., `sip:+15550100005@203.0.113.10:5060`), not E.164. The `From` field is the original caller's E.164 number.

**Processing delay**: Trunking call summaries take longer to process than carrier calls (~5-15 minutes vs ~2-4 minutes). Always use `processingState: "all"` when querying recent trunk calls.

Voice Insights Advanced Features must be enabled at the account level (Console → Voice → Settings → Voice Insights Advanced Features).

[Evidence: SIP Lab live test — `CA1ec6f0cf01690634d2bb4ef08a9bc6cd` appears as `callType: "trunking"`, `direction: "trunking_originating"`, `callState: "completed"`, `duration: 9`]

---

## Scale and Limits

| Resource | Standard Account | Trial Account |
|----------|-----------------|---------------|
| SIP Trunks | 100 per account | 1 |
| Origination phone numbers | Unlimited | 1 |
| Termination CPS (calls per second) | 1 default, self-serve to 5 via Console | 1 |
| Origination CPS | No explicit limit (subject to your infrastructure capacity and Twilio account concurrency limits) | No explicit limit |
| Concurrent calls | Unlimited (carrier-dependent) | 4 |
| Max call duration | 24 hours | 24 hours |

Higher CPS limits require contacting Twilio Sales. An approved Business Profile is required for full concurrent call capacity.

**Platform SLA**: Twilio's published voice services SLA is **99.95%** uptime (~4.4 hours downtime/year). Requests for 99.99% or 99.999% availability exceed the standard platform guarantee and require a custom enterprise agreement negotiated through Twilio Sales. When planning HA architecture, calculate effective availability as the product of Twilio's SLA and your own infrastructure availability (PBX, SBC, network path).

---

## Codecs

| Codec | Availability | Notes |
|-------|-------------|-------|
| PCMU (G.711 mu-law) | GA | Default, highest compatibility |
| PCMA (G.711 A-law) | GA | Common in Europe |
| G.729 | Limited Availability | Contact Sales |
| Opus | Limited Availability | Contact Sales |
| AMR-NB | Limited Availability | Contact Sales, 8 encoding modes |

Origination SDP offer order: PCMU, PCMA. Termination matches the first supported codec in the offer.

---

## Recording Channel Assignment

Trunk recordings have different channel assignment than API-initiated recordings:

| Channel | Trunk Recording | API Recording |
|---------|----------------|---------------|
| Channel 1 | Twilio/originating side | TO (called party) |
| Channel 2 | SIP/terminating side (PBX) | FROM (caller) |

This matters when sending recordings to Voice Intelligence — getting channels wrong swaps speaker labels in transcripts. The recording SID for trunk calls is on the **trunk leg's call SID**, not the parent API call SID. You must find the trunk-direction call to list its recordings.

---

## Disaster Recovery / Failover

### Trunk Failover

Twilio does NOT auto-failover between trunks. If your primary trunk's origination URIs become unreachable:
- Inbound calls to numbers on the trunk return SIP 503
- No automatic rerouting to a backup trunk

Three failover patterns exist, each at a different layer:

**1. Within-trunk failover (automatic — recommended)**

Add multiple origination URIs to a single trunk with priority tiers. Twilio fails over automatically:
1. Add origination URIs pointing to different PBX/SBC endpoints on the same trunk
2. Set priority: primary PBX = 10, secondary PBX = 20 (lower number = tried first)
3. If the primary URI is unreachable, Twilio tries the next priority tier automatically
4. For geographic redundancy, origination URIs can point to PBX instances in different regions
5. Monitor trunk health via Voice Insights and configure alerting on SIP 503 spikes

**2. Cross-trunk failover (scripted — not automatic)**

A phone number can only be associated with ONE trunk at a time (see Gotcha #17). Cross-trunk failover requires scripted number reassociation via the REST API — it is not instant and not automatic. Build automation to detect trunk failure and move numbers from the failed trunk to a pre-configured backup trunk:
1. Pre-provision a backup trunk with origination URIs, ACLs, and credentials ready
2. Monitor the primary trunk for sustained SIP 503 or origination failures
3. On failure detection, call `POST /v1/Trunks/{BackupTrunkSid}/PhoneNumbers` to reassociate numbers
4. Numbers must first be removed from the failed trunk (`DELETE /v1/Trunks/{FailedTrunkSid}/PhoneNumbers/{PhoneNumberSid}`)
5. Reassociation is not instant — expect seconds to low tens of seconds of downtime per number during the move

**3. DisasterRecoveryUrl (trunk-level last resort — inbound only)**

The `DisasterRecoveryUrl` is a trunk-level fallback webhook invoked when ALL origination URLs fail for an inbound call. It returns TwiML for emergency routing (e.g., forward to a cell phone, play a message, enqueue to a different system). See the Disaster Recovery URL section above for trigger conditions, configuration, and scope. This does not help with outbound calls.

---

## Gotchas

### Configuration

1. **Domain name is not auto-generated**: New trunks have `domain_name: null`. Your PBX cannot send outbound SIP until you explicitly set `DomainName`. This is easy to miss because the trunk creation succeeds without it. [Evidence: Test 14, 27]

2. **Domain name must end with `.pstn.twilio.com`**: Error 21245 if you omit the suffix. The name portion before `.pstn.twilio.com` is your custom identifier. [Evidence: Test 18]

3. **Domain names are globally unique**: Error 21248 if the domain is already in use by any Twilio account. Use organization-specific prefixes to avoid collisions. [Evidence: Test 11]

4. **`SymmetricRtpEnabled` may require account enablement**: Setting to `true` via API silently returns `false`. This field may be gated behind an account-level flag or support request. Do not assume the API accepted the change — always verify the response. [Evidence: Test 7]

5. **FriendlyName can be null**: Unlike most Twilio resources, trunk FriendlyName is optional and defaults to `null`, not an auto-generated string. This can cause issues if you filter or display trunks by name. [Evidence: Test 26, 27]

### Authentication

6. **`auth_type` is computed, not settable**: The `auth_type` and `auth_type_set` fields auto-update when you associate/dissociate IP ACLs and credential lists. You cannot set them directly. [Evidence: Test 28, 29]

7. **Multiple ACLs allowed per trunk**: You can associate more than one IP ACL with a trunk. All IPs across all associated ACLs are allowed. This is useful for managing IP lists per datacenter. [Evidence: Test 28]

8. **Auth with no ACL and no credential list**: A trunk with no auth associations accepts no inbound SIP. Outbound works (your PBX sends to Twilio's domain), but inbound calls cannot route without origination URLs and your PBX won't authenticate without some mechanism.

### Recording

9. **Trunk recording is all-or-nothing**: Records every call on the trunk. Cannot selectively record individual calls. If you need per-call control, use SIP Interface with `<Start><Recording>` instead.

10. **Dual-channel recording always produces 2 channels**: `record-from-answer-dual` and `record-from-ringing-dual` produce 2-channel audio regardless of call state. Channel assignment is: channel 0 = inbound leg, channel 1 = outbound leg.

11. **Recording + Voice Intelligence**: Trunk recordings can be sent to Voice Intelligence for transcription. Use dual-channel modes for better speaker separation in transcripts.

### Routing

12. **Priority is ascending — lower number wins**: Priority=10 is tried before priority=20. This is the opposite of what some expect (not "higher priority = higher number"). [Evidence: Test 15, 16]

13. **Weight=0 is accepted**: Despite some documentation suggesting minimum weight of 1, the API accepts weight=0. A URL with weight=0 will receive no traffic when other URLs at the same priority have weight > 0. [Evidence: Test 17]

14. **Origination URL SIP scheme — docs vs reality**: Twilio docs state only `sip:` is supported for origination URLs. However, live testing confirmed `sips:` is also accepted (Test 21). Use `sips:` for secure origination with TLS. Invalid schemes (http, https) are rejected. [Evidence: Test 21, 22]

15. **Disabled origination URLs are skipped**: Setting `enabled: false` on an origination URL removes it from routing without deleting it. Useful for maintenance windows.

### Phone Numbers

16. **Number on trunk loses voiceUrl**: Assigning a number to a trunk makes it route via origination URLs. The number's voiceUrl/smsUrl webhooks are bypassed. Remove from trunk to restore webhook behavior.

17. **One trunk per number**: A phone number can only be associated with one trunk at a time. Attempting to associate it with a second trunk fails until removed from the first.

### Transfer

18. **Transfer is disabled by default**: `transfer_mode` defaults to `disable-all`. SIP REFER and INVITE-based transfers are blocked until explicitly enabled. [Evidence: Test 4, 8]

19. **Three transfer modes, not two**: The API accepts `disable-all`, `enable-all`, and `sip-only`. `sip-only` allows SIP REFER but blocks other transfer methods. [Evidence: Test 8, 9, 12]

### Credentials

20. **Credential passwords require 12+ chars, mixed case, and a digit**: The Twilio SIP credential API enforces this. The SIP Lab generates passwords with 20 chars, mixed case, digits, and excludes ambiguous characters.

### Codecs & Media

21. **G.711 only on standard accounts**: PCMU and PCMA are GA. G.729, Opus, and AMR-NB are Limited Availability — require contacting Twilio Sales. If your PBX offers a codec Twilio doesn't support, the call may fail with SIP 488 (Not Acceptable Here).

22. **AMD does not work with SIP Trunking**: Answering Machine Detection is incompatible with Elastic SIP Trunking, `<Dial><Client>`, `<Dial><Conference>`, and `<Dial><Queue>`. If you need AMD, use SIP Interface.

23. **DTMF mode must be RFC 2833/4733**: Twilio uses RFC 2833 (telephone-event) for DTMF relay on trunking calls. PBXes configured for SIP INFO DTMF (e.g., Cisco CUCM default) or inband DTMF detection will lose all touchtone capability. Since trunk calls bypass Programmable Voice, there is no `<Gather>` to fail — but DTMF-dependent IVR flows on the PBX side will be affected if the PBX expects a different DTMF method from Twilio's media relay. Configure your PBX for RFC 2833/4733 DTMF. No error appears in Twilio's debugger; DTMF is silently lost.

24. **Recording channel assignment differs from API recordings**: Trunk recordings use Channel 1 = Twilio/originating, Channel 2 = PBX/terminating. This is the inverse of API recording conventions. Getting it wrong swaps Voice Intelligence speaker labels.

25. **Trunk recording SID is on the trunk leg's call SID**: Not the parent API call. Query recordings from the trunk-direction call SID. The parent call shows 0 recordings.

### Signaling & Media

26. **SIP session timers (RFC 4028) can drop long calls**: Twilio uses session timers on trunking SIP legs. If your PBX/SBC does not respond to session refresh re-INVITEs, the call is torn down after the session timer expires (typically 1800s / 30 minutes). This manifests as clean BYEs with no Twilio-side error. Contact center hold queues, IVR parking, and long conference bridges are most affected. Ensure your PBX supports RFC 4028 session timer refreshes.

27. **SRTP requires SDES key exchange (RFC 4568)**: When `Secure=true`, Twilio uses SDES (Session Description Protocol Security Descriptions) for SRTP key negotiation. PBXes configured for DTLS-SRTP (common in WebRTC) or ZRTP will fail media negotiation — TLS handshake succeeds but audio fails. Configure your SBC for SDES-based SRTP (e.g., `media_encryption=sdes` in Asterisk PJSIP).

### Disaster Recovery

28. **DR URL is trunk-level, not per-call**: `DisasterRecoveryUrl` is configured once on the trunk and applies to all inbound calls. You cannot customize DR behavior per-call. For per-call failover logic, use SIP Interface with TwiML routing instead.

29. **DR URL trigger conditions are not fully documented**: Twilio docs do not exhaustively specify which SIP response codes or network errors trigger the DR URL invocation. Test your DR path by disabling all origination URLs and confirming the webhook fires. 4xx responses (486 Busy) from a reachable endpoint typically do not trigger DR — only wholesale origination failure does.

- **Pre-validate failover endpoint ACLs**: When configuring multiple origination URLs for failover, ensure ALL endpoint IPs (primary and backup) are included in the trunk's IP Access Control List BEFORE a DR event. A SIP 403 Forbidden from a reachable but misconfigured backup endpoint does NOT trigger the DisasterRecoveryUrl — Twilio only triggers DR when ALL origination URLs are unreachable, not when they reject with 4xx. Pre-validation checklist: (1) list all origination URL IPs across all data centers, (2) verify each IP appears in at least one associated IP ACL, (3) periodically test failover by temporarily disabling the primary endpoint.

30. **"SRV-style" routing is an analogy, not DNS**: Origination URL priority/weight routing uses an algorithm inspired by DNS SRV semantics, but it is applied at the Twilio platform layer. Your PBX hostname DNS resolution is separate — see the SIP Interface skill for DNS resolution details.

### TLS Version Compatibility

31. **TLS version mismatch produces silent SIP 503**: If your trunk is configured for TLS (`secure: true`) and the carrier/PBX only supports a TLS version that Twilio's edge doesn't negotiate, all calls fail with SIP 503 Service Unavailable. No Twilio debugger alert explains the root cause — you see 503s with no indication of TLS handshake failure. **Detection**: If all calls to a trunk fail with 503 and the trunk was recently configured (or a carrier recently upgraded), suspect TLS version mismatch. **Diagnostic**: Check your PBX/carrier's supported TLS versions. Twilio's SIP edge supports TLS 1.2. Some carriers have moved to TLS 1.3-only — Twilio may not negotiate TLS 1.3 on all edges. **Workaround**: If TLS 1.3-only is required, contact Twilio support to verify edge compatibility for your region. As a temporary measure, disable `secure` on the trunk to use unencrypted SIP (not recommended for production).

32. **Carrier compatibility checklist**: Before provisioning a trunk for a new carrier, verify: (1) TLS version support (1.2 minimum), (2) SRTP key exchange method (SDES required, not DTLS), (3) DTMF mode (RFC 2833 required), (4) codec support (G.711 µ-law/A-law, Opus if available), (5) session timer support (RFC 4028), (6) E.164 number format acceptance. A mismatch on any of these produces hard-to-diagnose failures because SIP signaling succeeds but media or features fail silently.

---

## MCP Tools

Trunking tools are P3 tier. They appear in the deferred tools list when P3 is enabled in `.mcp.json` configuration (`toolTiers: ['all']` or `toolTiers: ['P0', 'P3', 'validation']`).

| Operation | MCP Tool |
|-----------|----------|
| List trunks | `mcp__twilio__list_sip_trunks` |
| Get trunk | `mcp__twilio__get_sip_trunk` |
| Create trunk | `mcp__twilio__create_sip_trunk` |
| Update trunk | `mcp__twilio__update_sip_trunk` |
| Delete trunk | `mcp__twilio__delete_sip_trunk` |
| List origination URLs | `mcp__twilio__list_origination_urls` |
| Create origination URL | `mcp__twilio__create_origination_url` |
| Update origination URL | `mcp__twilio__update_origination_url` |
| Delete origination URL | `mcp__twilio__delete_origination_url` |
| List trunk IP ACLs | `mcp__twilio__list_trunk_ip_access_control_lists` |
| Associate IP ACL | `mcp__twilio__associate_ip_access_control_list` |
| Remove trunk IP ACL | `mcp__twilio__remove_trunk_ip_access_control_list` |
| List trunk credential lists | `mcp__twilio__list_trunk_credential_lists` |
| Associate credential list | `mcp__twilio__associate_credential_list` |
| Remove trunk credential list | `mcp__twilio__remove_trunk_credential_list` |
| List trunk phone numbers | `mcp__twilio__list_trunk_phone_numbers` |
| Associate phone number | `mcp__twilio__associate_phone_number_to_trunk` |
| Remove phone number | `mcp__twilio__remove_phone_number_from_trunk` |
| Get recording config | `mcp__twilio__get_trunk_recording` |
| Update recording config | `mcp__twilio__update_trunk_recording` |
| Validate SIP infrastructure | `mcp__twilio__validate_sip` |
| Voice Insights for trunking | `mcp__twilio__list_call_summaries(callType: "trunking")` |

---

## Error Codes

| Code | Meaning | Common Cause |
|------|---------|--------------|
| 21245 | Invalid domain name | Domain doesn't end with `.pstn.twilio.com` |
| 21248 | Domain name already in use | Another account/trunk has this domain |
| 20001 | Invalid parameter | Invalid `TransferMode` or `TransferCallerId` value |
| 13xxx | SIP signaling errors | Authentication failures, unreachable PBX, codec mismatch |
| 64xxx | Media/RTP errors | NAT issues, firewall blocking RTP, SRTP mismatch |

Use `mcp__twilio__validate_sip(trunkSid)` to check for debugger errors filtered to SIP error ranges (13xxx, 64xxx).

---

## Related Resources

| Resource | Path | When to read |
|----------|------|-------------|
| SIP product overview (SIP Interface + BYOC) | `/skills/sip-byoc.md` | Choosing between SIP Interface, Elastic SIP Trunking, and BYOC |
| Voice use case map | `/skills/voice-use-case-map/SKILL.md` | Deciding which Twilio voice product fits the use case |
| Recordings skill | `/skills/recordings/SKILL.md` | Trunk recording + Voice Intelligence integration |
| Voice Insights skill | `/skills/voice-insights/SKILL.md` | Diagnosing call quality on trunking calls |
| Phone numbers skill | `/skills/phone-numbers/SKILL.md` | Managing numbers assigned to trunks |
| SIP Lab infrastructure | `/infrastructure/sip-lab/CLAUDE.md` | Live testing with Asterisk PBX + Twilio trunk |
| SIP Lab E2E tests | `/__tests__/e2e/sip-lab/` | 16 automated tests covering connectivity, recording, security |
| MCP trunking tools source | `/twilio/src/tools/trunking.ts` | Tool schemas and implementation details |
| MCP tool reference | `/twilio/REFERENCE.md` | Full tool inventory |

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Live test evidence | `references/test-results.md` | Verifying specific API behavior claims |
| Assertion audit | `references/assertion-audit.md` | Reviewing provenance of every factual claim |
