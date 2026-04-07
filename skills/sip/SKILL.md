---
name: "sip"
description: "Twilio development skill: sip"
---

---
name: sip
description: Twilio Programmable SIP (SIP Interface / SIP Domains) development guide. Use when building SIP-connected voice applications — PBX integration, softphone registration, SIP-to-PSTN bridging, custom SIP header routing, or choosing between SIP Interface and Elastic SIP Trunking.
---

# Programmable SIP (SIP Interface)

Twilio SIP Interface connects SIP infrastructure (IP-PBX, softphones, SBCs) to Twilio Programmable Voice via SIP Domains. Inbound SIP INVITEs trigger TwiML webhooks; outbound calls reach SIP endpoints via `<Dial><Sip>`. This is the programmable layer — every call hits your webhook for dynamic routing, unlike Elastic SIP Trunking which provides a static PSTN pipe.

Evidence date: 2026-03-28 | Account: ACxx...xx | Test domain: SD88afbff... (cleaned up)

## Scope

**What SIP Interface does:**

- Receives SIP INVITEs at `{your-domain}.sip.twilio.com` and invokes your Voice URL for TwiML-based call handling
- Sends outbound SIP via `<Dial><Sip>` to any SIP URI (your PBX, another provider, registered endpoints)
- Supports SIP Registration so softphones/desk phones can register and receive calls without static IPs
- Passes custom `X-` SIP headers bidirectionally between your infrastructure and webhooks
- Authenticates via IP ACL, digest credentials, or both
- Supports TLS signaling + SRTP media encryption (secure mode)
- Supports emergency calling (E911) on SIP Domains

**What SIP Interface CANNOT do:**

- **Cannot provide a PSTN phone number directly** — SIP Domains have no phone numbers. To receive PSTN calls on a SIP endpoint, route a Twilio number's Voice URL to return `<Dial><Sip>`. To originate PSTN calls from SIP, your webhook dials the PSTN number via `<Dial><Number>`.
- **Cannot do IP-only auth for registrations** — Registration always requires digest credentials. IP ACL auth only applies to INVITE (call) authentication.
- **Cannot validate remote TLS certificates** — Twilio accepts self-signed certs. TLS alone is not authentication and does not prevent MITM. You must also configure IP ACL or credential auth.
- **Cannot pass standard SIP headers to webhooks** — Only `X-` prefixed custom headers and four specific standard headers (`User-to-User`, `Remote-Party-ID`, `P-Preferred-Identity`, `P-Called-Party-ID`) are forwarded. All other standard headers are stripped.
- **Cannot use custom headers with BYOC trunks** — Custom SIP headers from BYOC trunk calls are silently discarded. This only works with Programmable Voice SIP.
- **Cannot use IPv6 in IP ACLs** — IPv4 only, no wildcard IPs.
- **Cannot retrieve credential passwords** — Passwords are MD5-hashed at creation and cannot be read back.
- **Cannot exceed 100 SIP Domains per account** — Hard limit. Plan domain naming carefully.

**Out of scope (covered by other skills):**

- Elastic SIP Trunking (carrier-grade PSTN pipe) — see the elastic-sip-trunking skill (in progress)
- BYOC Trunks — see the elastic-sip-trunking skill
- Call recording on SIP calls — see [recordings skill](/skills/recordings/SKILL.md)
- Conference bridging SIP legs — see [conference skill](/skills/conference/SKILL.md)

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Connect PBX to PSTN via Twilio | Elastic SIP Trunking | Static trunk, no per-call webhook logic needed |
| Dynamic call routing per SIP INVITE | SIP Interface (this skill) | Every call hits your webhook for TwiML decisions |
| Softphone/desk phone registration | SIP Interface with `sipRegistration: true` | Only SIP Domains support SIP REGISTER |
| Bring your own carrier to Twilio | BYOC Trunk | Carrier interconnect with Twilio call control |
| Pass metadata in SIP headers | SIP Interface | Custom `X-` headers flow to/from webhooks |
| Simple PSTN origination/termination | Elastic SIP Trunking | No TwiML needed, straight PSTN pipe |
| SIP-to-SIP call bridging | SIP Interface | Use `<Dial><Sip>` in your webhook handler |
| Voice AI agent answering SIP calls | SIP Interface | Webhook returns ConversationRelay TwiML |

## Decision Frameworks

### Authentication Model

SIP Domains support two auth mechanisms. If both are configured, **both are enforced** (AND, not OR). The `authType` field on the domain reflects the current state.

| Configuration | `authType` value | Behavior |
|--------------|-----------------|----------|
| No auth configured | `""` (empty) | Domain rejects all traffic |
| IP ACL only | `"IP_ACL"` | Source IP must match ACL entry |
| Credentials only | `"CREDENTIAL_LIST"` | 407 challenge, digest auth required |
| Both | `"CREDENTIAL_LIST,IP_ACL"` | IP must match AND credentials must pass |

[Evidence: SD88afbff... — tested all four states, authType field values confirmed]

**Legacy vs v2 Auth API paths:** The API exposes two paths for mapping ACLs and credential lists to domains — "legacy" top-level mappings (`/Domains/{SD}/IpAccessControlListMappings`) and "v2" auth-scoped mappings (`/Domains/{SD}/Auth/Calls/IpAccessControlListMappings`). These share the same backend storage — mapping via one path prevents mapping via the other (error 21231). Use the v2 paths for clarity: they separate call auth from registration auth. See [auth-model reference](references/auth-model.md) for the full mapping.

### Call Direction

| Direction | How it works | Auth required | Webhook triggered |
|-----------|-------------|---------------|------------------|
| **Inbound** (SIP → Twilio) | Your infra sends INVITE to `{domain}.sip.twilio.com` | IP ACL and/or credentials | Domain's `voiceUrl` |
| **Outbound** (Twilio → SIP) | TwiML returns `<Dial><Sip>sip:user@host</Sip></Dial>` | Optional (`username`/`password` on `<Sip>`) | `<Sip url="">` for screening, `<Dial action="">` on completion |
| **Registered** (registered endpoint → Twilio) | Endpoint sends INVITE to its registration edge | Credential auth (registration + call) | Domain's `voiceUrl` |

### Transport Selection

| Transport | URI parameter | Default port | When to use |
|-----------|--------------|-------------|-------------|
| UDP | `transport=udp` (default) | 5060 | Standard, lowest latency |
| TCP | `transport=tcp` | 5060 | Large SIP messages, reliable delivery |
| TLS | `transport=tls` | 5061 | Encrypted signaling (combine with `secure: true` for SRTP) |

### Codecs

SIP Interface supports the same codecs as Elastic SIP Trunking:

| Codec | Availability | Sample Rate |
|-------|-------------|-------------|
| G.711 μ-law (PCMU) | GA | 8 kHz |
| G.711 A-law (PCMA) | GA | 8 kHz |
| G.729 | Limited Availability | 8 kHz |
| Opus | Limited Availability | 8-48 kHz |
| AMR-NB | Limited Availability | 8 kHz |

Default negotiation uses PCMU/PCMA. If your PBX only supports G.729 or other non-G.711 codecs, you must enroll in Limited Availability through Twilio. Calls to endpoints offering only unsupported codecs receive SIP 488 Not Acceptable Here.

### Edge/Region Selection (Outbound)

Controls where Twilio's SIP-out traffic originates. Append to the SIP URI: `sip:user@host;region=us1`.

| Region | Edge | Location |
|--------|------|----------|
| `us1` | `ashburn` | Virginia (default) |
| `us2` | `umatilla` | Oregon |
| `ie1` | `dublin` | Ireland |
| `de1` | `frankfurt` | Germany |
| `sg1` | `singapore` | Singapore |
| `jp1` | `tokyo` | Japan |
| `br1` | `sao-paulo` | Brazil |
| `au1` | `sydney` | Australia |

For registered endpoints, the edge parameter on `<Sip>` is ignored — traffic originates from the registration edge.

## Inbound SIP Call Flow

```
Your PBX/Softphone
  │ SIP INVITE → {domain}.sip.{edge}.twilio.com
  │
  ├── Auth: IP ACL check (if configured)
  ├── Auth: 407 challenge (if credentials configured)
  │
  └── Twilio fetches voiceUrl with standard + SIP-specific params:
        SipCallId, SipDomain, SipDomainSid, SipSourceIp,
        SipHeader_X-{name} (custom headers)
        │
        └── Your TwiML response handles the call
```

### Inbound Webhook Parameters

Standard Voice parameters (`CallSid`, `From`, `To`, `AccountSid`, etc.) plus:

| Parameter | Description |
|-----------|-------------|
| `SipCallId` | SIP Call-ID header from the INVITE |
| `SipDomain` | Host portion of the SIP Request-URI |
| `SipDomainSid` | SD-prefixed SID of the matched domain |
| `SipSourceIp` | Source IP of the SIP signaling |
| `SipHeader_X-{Name}` | Custom X-prefixed headers from the INVITE |
| `SipHeader_User-to-User` | User-to-User header (if present) |

**Status callback for inbound SIP:** Only the `completed` event is delivered. You do not get `initiated`, `ringing`, or `answered` events.

## Outbound SIP (`<Dial><Sip>`)

```xml
<Response>
  <Dial callerId="sip:agent@example.com">
    <Sip username="myuser" password="mypass"
         statusCallback="https://example.com/sip-status"
         statusCallbackEvent="initiated ringing answered completed">
      sip:dest@pbx.example.com;transport=tls?x-route-id=42&amp;User-to-User=abc%3Bencoding%3Dhex
    </Sip>
  </Dial>
</Response>
```

### `<Sip>` Noun Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `username` | (none) | SIP digest auth username for the target |
| `password` | (none) | SIP digest auth password for the target |
| `url` | (none) | Call screening URL — TwiML fetched when callee answers, before connecting |
| `method` | POST | HTTP method for the `url` attribute |
| `statusCallback` | (none) | URL for call status events |
| `statusCallbackMethod` | POST | HTTP method for status callback |
| `statusCallbackEvent` | (none) | Space-separated: `initiated`, `ringing`, `answered`, `completed` |

All standard `<Dial>` attributes also apply: `record`, `timeout`, `hangupOnStar`, `callerId`, `action`, `timeLimit`, `ringTone`, etc.

### SIP URI Format

```
sip:user@host[:port][;uri-params][?headers]
```

- **URI parameters** (after `;`): `transport=tls`, `region=ie1`, `edge=dublin`
- **Headers** (after `?`): `x-mycustomheader=value`, `User-to-User=abc%3Bencoding%3Dhex`
- Max 1024 characters total for custom headers
- XML-encode `&` as `&amp;` in TwiML

### DNS Resolution for Outbound SIP URIs

Twilio resolves hostname-based SIP URIs (`sip:sbc.example.com:5060`) via A/AAAA DNS records only. RFC 3263 NAPTR/SRV resolution is **not** performed on the target hostname. This means:

- SRV records advertising ports, transports, or weights for your SIP domain are ignored by Twilio's outbound SIP stack
- The port and transport must be specified explicitly in the URI (e.g., `sip:sbc.example.com:5060;transport=tls`)
- If no port is specified, Twilio uses the default for the scheme (5060 for `sip:`, 5061 for `sips:`)

If your infrastructure relies on DNS SRV for failover or load distribution, use Twilio-side mechanisms instead: Elastic SIP Trunking origination URL priority/weight routing, or multiple `<Sip>` nouns in TwiML.

### Outbound Caller ID

- Does not require a validated Twilio phone number
- Can be alphanumeric with `+-_.` characters (no whitespace)
- Set via `callerId` on `<Dial>` or `From` on the parent call

### Action Callback Parameters

After the SIP leg completes, the `<Dial action="">` URL receives:

| Parameter | Description |
|-----------|-------------|
| `DialSipCallId` | SIP Call-ID from the INVITE |
| `DialSipResponseCode` | SIP response code (200, 486, 408, etc.) |
| `DialSipHeader_X-{Name}` | Custom X-headers from the final SIP response |

See [sip-headers reference](references/sip-headers.md) for the full header passthrough rules.

## SIP Registration

Enable `sipRegistration: true` on the domain, then map at least one Credential List to the domain's **Registration** auth. Endpoints REGISTER at `{domain}.sip.{edge}.twilio.com` and can then receive calls and place outbound calls through the domain.

See [registration reference](references/registration.md) for lifecycle, limits, edge locations, and calling patterns.

### Registration Quick Reference

| Parameter | Value |
|-----------|-------|
| Min expiry | 600 seconds (10 min) |
| Max expiry | 3600 seconds (1 hour) |
| Recommended refresh | Half of expiry |
| Max registrations per AOR | 10 (all ring simultaneously) |
| Max registrations per domain | 1,000,000 |
| Auth method | Digest credentials only (no IP ACL for REGISTER) |

## Gotchas

### Setup

1. **No auth = no traffic**: A SIP Domain with no auth mappings (empty `authType`) silently rejects all inbound SIP. There is no error message — calls simply never arrive. Always verify `authType` is populated after setup. [Evidence: SD88afbff... — confirmed empty authType accepts nothing]

2. **No voiceUrl = call failure**: Inbound SIP calls to a domain without a `voiceUrl` configured will fail. `validate_sip` catches this. [Evidence: validate_sip on SD88afbff...]

3. **Domain names are globally unique**: `{name}.sip.twilio.com` is unique across all Twilio accounts. Error 21232 on collision. Use descriptive prefixes (e.g., `mycompany-prod.sip.twilio.com`). [Evidence: duplicate create returned 21232]

4. **Legacy and v2 auth paths share storage**: Mapping an ACL via `/Domains/{SD}/IpAccessControlListMappings` and then via `/Domains/{SD}/Auth/Calls/IpAccessControlListMappings` returns error 21231 "already associated." They are the same mapping viewed from two API paths. Pick one path (v2 recommended) and stick with it. [Evidence: SD88afbff... — tested legacy then v2, got 21231]

### Authentication

5. **Both auth types enforced simultaneously**: When both IP ACL and credential list are mapped, the caller must pass BOTH checks — source IP must be in the ACL AND credentials must authenticate. This is AND logic, not OR. [Evidence: authType shows `"CREDENTIAL_LIST,IP_ACL"` — both listed]

6. **IP ACL is not enough for multi-tenant providers**: If your PBX is hosted on a shared platform (e.g., cloud PBX provider), multiple customers may share the same IP. IP ACL alone cannot distinguish between them — add credential auth.

7. **Registration requires credentials, not IP ACL**: The registration auth path (`/Auth/Registrations/CredentialListMappings`) only accepts credential lists. There is no IP ACL option for SIP REGISTER. This is by design — registering endpoints are typically on dynamic IPs.

8. **Credential passwords: min 12 chars, mixed case, digit required**: Passwords are MD5-hashed and irrecoverable. If lost, delete and recreate the credential. Username max 32 characters.

### Headers

9. **Only X-prefixed custom headers pass through**: Standard SIP headers are stripped. Exceptions: `User-to-User`, `Remote-Party-ID`, `P-Preferred-Identity`, `P-Called-Party-ID` — these four standard headers also pass through on outbound `<Sip>` URIs.

10. **BYOC trunks discard custom headers**: If the call arrives via a BYOC trunk, all custom SIP headers are silently dropped. This only works with Programmable Voice SIP Interface.

11. **1024 character limit on outbound headers**: Total length of all custom headers in the `<Sip>` URI query string. URL-encoding counts toward this limit.

12. **Action URL does not receive standard headers**: The `<Dial action="">` callback receives `DialSipHeader_X-*` (custom headers from the SIP response) but does not receive the four standard headers.

### Registration

13. **Edge parameter ignored for registered endpoints**: When dialing a registered endpoint via `<Dial><Sip>`, the `edge` or `region` URI parameter is ignored. Traffic originates from the edge where the endpoint registered.

14. **Multiple registrations fork the call**: If the same AOR has multiple active registrations (max 10), an inbound call to that AOR rings all registered endpoints simultaneously (forked INVITE).

15. **E.164 required for PSTN from registered endpoints**: Calls from registered endpoints to PSTN must use E.164 format and the number must be verified in the Twilio Console.

16. **Twilio sends E.164 with `+` prefix to your PBX**: Inbound calls via SIP domains arrive with full E.164 formatting (e.g., `+15551234567`). PBXes configured for 10-digit or 11-digit dialing patterns will fail to match. Your dialplan must handle the `+` prefix — in Asterisk, use `_+.` pattern alongside `_X.` patterns.

### DTMF

17. **DTMF mode must be RFC 2833/4733**: Twilio uses RFC 2833 (telephone-event) for DTMF relay. PBXes configured for SIP INFO DTMF (e.g., Cisco CUCM default) or inband DTMF detection will lose all touchtone capability — no `<Gather>` digits, no payment entry, no conference controls. No error appears in the debugger; the call works but DTMF is silently lost. Configure your PBX for RFC 2833/4733 DTMF.

### Security

18. **TLS ≠ authentication**: Enabling `secure: true` enforces TLS signaling + SRTP media, but Twilio does not validate remote certificates. Self-signed certs are accepted. TLS prevents eavesdropping but not spoofing — always pair with IP ACL or credential auth.

19. **Secure mode applies to the entire domain**: You cannot selectively enforce TLS for some endpoints and not others on the same domain. If you need mixed security levels, use separate SIP Domains.

20. **SIP session timers (RFC 4028) can drop long calls**: Twilio uses session timers on SIP legs. If your PBX does not respond to session refresh re-INVITEs, the call is torn down after the session timer expires (typically 1800s / 30 minutes). This manifests as clean BYEs with no Twilio-side error. Contact center hold scenarios, conference bridges, and IVR parking are most affected. Ensure your PBX supports RFC 4028 session timer refreshes.

21. **Validate Twilio's TLS certificate on your PBX**: While Twilio accepts self-signed certs from your infrastructure, your PBX SHOULD validate Twilio's certificate (issued by DigiCert). Configure `verify_server=yes` (Asterisk) or equivalent. One-way validation prevents MITM on the Twilio→PBX leg. The SIP Lab's Asterisk config demonstrates this pattern.

22. **SRTP requires SDES key exchange (RFC 4568)**: Twilio uses SDES (Session Description Protocol Security Descriptions) for SRTP key negotiation. PBXes configured for DTLS-SRTP (common in WebRTC) or ZRTP will fail media negotiation — TLS handshake succeeds but audio fails. Configure your PBX for `media_encryption=sdes` (Asterisk) or equivalent SDES mode.

### TLS Version Compatibility

23. **TLS version negotiation failure is silent**: When `secure: true` is set on a SIP Domain, Twilio enforces TLS for signaling. If the remote endpoint only supports TLS 1.3 and Twilio's edge negotiates TLS 1.2, the handshake fails silently — no debugger error specifically indicates TLS version mismatch. **Diagnostic path**: (1) Verify calls work without `secure: true`, (2) Check remote endpoint's TLS version with `openssl s_client -connect <pbx>:5061 -tls1_2`, (3) If TLS 1.2 fails, the endpoint needs reconfiguration or use a separate unsecured domain with IP ACL auth.

24. **Mixed TLS environments**: Use separate SIP Domains for endpoints with different TLS capabilities — one `secure: true` (TLS 1.2-compatible) and one without (IP ACL-only security for incompatible endpoints).

### DNS

25. **No DNS SRV resolution on outbound targets**: When Twilio sends an outbound SIP INVITE via `<Dial><Sip>` to a hostname-based URI, it resolves the hostname via A/AAAA records only. RFC 3263 NAPTR/SRV lookups are not performed. If your PBX relies on SRV records for port/transport/weight discovery, those records are ignored. Use explicit port and transport in the URI, and handle failover via Twilio-side mechanisms (EST origination URL priority/weight, or multiple `<Sip>` nouns).

### Observability

26. **Inbound status callback: completed only**: Unlike outbound SIP (which supports `initiated`, `ringing`, `answered`, `completed`), inbound SIP to a domain only delivers the `completed` status event.

27. **Debugger SIP errors are account-wide**: The `validate_sip` tool checks debugger for SIP errors (13xxx, 64xxx) account-wide, not filtered to the specific domain. Noisy accounts may show errors from other SIP resources.

28. **SIP response codes are in DialSipResponseCode**: When an outbound SIP call fails, the SIP response code (486 Busy, 408 Timeout, 503 Unavailable, etc.) is available in the `<Dial action="">` callback as `DialSipResponseCode`. This is the primary diagnostic for outbound SIP failures.

## Resource Limits

| Resource | Limit |
|----------|-------|
| SIP Domains per account | 100 |
| IP Access Control Lists per account | 1,000 |
| IP addresses per ACL | 100 |
| Credential Lists per account | 100 |
| Credentials per list | 1,000 |
| Active registrations per AOR | 10 |
| Active registrations per domain | 1,000,000 |
| Registration expiry | 600–3,600 seconds |
| Custom SIP header total length | 1,024 characters |
| Domain friendlyName max | 64 characters |
| ACL friendlyName max | 255 characters |
| Credential username max | 32 characters |
| Credential password min | 12 characters |

## SID Reference

| Resource | Prefix |
|----------|--------|
| SIP Domain | `SD` |
| IP Access Control List | `AL` |
| IP Address | `IP` |
| Credential List | `CL` |
| Credential | `CR` |

## MCP Tools Quick Reference

| Operation | Tool | When |
|-----------|------|------|
| Validate domain + auth + debugger | `validate_sip(domainSid)` | After provisioning or when debugging |
| Create domain | `create_sip_domain` | Initial setup |
| Update domain config | `update_sip_domain` | Change voiceUrl, enable secure/registration |
| List domains | `list_sip_domains` | Discovery |
| Create IP ACL | `create_sip_ip_access_control_list` | Auth setup |
| Add IP to ACL | `create_sip_ip_address` | Auth setup |
| Create credential list | `create_sip_credential_list` | Auth setup |
| Add credential | `create_sip_credential` | Auth setup (password min 12, mixed case + digit) |
| Map ACL to domain (calls) | `create_sip_domain_auth_calls_ip_acl_mapping` | v2 auth path |
| Map CL to domain (calls) | `create_sip_domain_auth_calls_credential_list_mapping` | v2 auth path |
| Map CL to domain (registration) | `create_sip_domain_auth_registrations_credential_list_mapping` | Registration auth |

Note: SIP tools are P3 tier in the MCP server. `validate_sip` is always available; CRUD tools load on demand.

## Common Patterns

### Inbound SIP → TwiML Handler

```javascript
// ABOUTME: Webhook handler for inbound SIP calls to a Twilio SIP Domain.
// ABOUTME: Routes calls based on custom SIP header or dialed extension.
exports.handler = function (context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  const routeId = event.SipHeader_X_Route_Id;
  const calledNumber = event.To;

  if (routeId === 'support') {
    twiml.dial().queue('support-queue');
  } else if (calledNumber.includes('8001')) {
    twiml.dial().conference('room-8001');
  } else {
    twiml.say('No route configured for this destination.');
    twiml.hangup();
  }

  callback(null, twiml);
};
```

### Outbound SIP with Custom Headers

```javascript
// ABOUTME: Places an outbound call that bridges to a SIP endpoint.
// ABOUTME: Passes custom headers and uses TLS transport.
exports.handler = function (context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  const dial = twiml.dial({
    callerId: 'sip:ivr@example.com',
    action: '/sip/dial-complete',
    timeout: 30,
  });

  dial.sip({
    username: context.SIP_USERNAME,
    password: context.SIP_PASSWORD,
    statusCallback: `https://${context.DOMAIN_NAME}/callbacks/sip-status`,
    statusCallbackEvent: 'initiated ringing answered completed',
  }, 'sip:agent@pbx.example.com;transport=tls?x-call-id=abc123&x-tenant=acme');

  callback(null, twiml);
};
```

### Dial Action Handler (SIP Response Codes)

```javascript
// ABOUTME: Handles the result of an outbound SIP dial attempt.
// ABOUTME: Routes based on SIP response code for retry or voicemail.
exports.handler = function (context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  const sipCode = event.DialSipResponseCode;
  const dialStatus = event.DialCallStatus;

  if (dialStatus === 'completed') {
    twiml.hangup();
  } else if (sipCode === '486') {
    // Busy — offer voicemail
    twiml.say('The extension is busy. Please leave a message.');
    twiml.record({ maxLength: 120, action: '/recordings/save' });
  } else if (sipCode === '408' || sipCode === '480') {
    // Timeout or temporarily unavailable — retry on backup
    twiml.dial().sip('sip:agent@backup-pbx.example.com');
  } else {
    twiml.say('Unable to connect your call. Goodbye.');
    twiml.hangup();
  }

  callback(null, twiml);
};
```

## Related Resources

- **[Voice skill](/skills/voice/SKILL.md)** — TwiML reference, `<Dial>` attributes, call lifecycle
- **[Recordings skill](/skills/recordings/SKILL.md)** — Recording SIP call legs
- **[Conference skill](/skills/conference/SKILL.md)** — Bridging SIP participants into conferences
- **[Real-time Transcription skill](/skills/real-time-transcription/SKILL.md)** — Live transcription on SIP calls
- **SIP Lab** — `infrastructure/sip-lab/CLAUDE.md` (Asterisk PBX test infrastructure)
- **SIP Lab E2E tests** — `__tests__/e2e/sip-lab/` (termination and PSTN connectivity tests)
- **Voice use case map** — `/skills/voice-use-case-map/SKILL.md` (product selection guide)

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Auth model (legacy vs v2, setup order) | [references/auth-model.md](references/auth-model.md) | Setting up or debugging SIP Domain authentication |
| Custom SIP headers (passthrough rules) | [references/sip-headers.md](references/sip-headers.md) | Passing metadata between SIP infrastructure and webhooks |
| SIP Registration (lifecycle, edges) | [references/registration.md](references/registration.md) | Registering softphones, desk phones, or SIP endpoints |
| Live test results (evidence) | [references/test-results.md](references/test-results.md) | Verifying specific claims or checking evidence SIDs |
| Assertion audit | [references/assertion-audit.md](references/assertion-audit.md) | Reviewing provenance chain for skill claims |
| Voice SDK ↔ SIP bridge | [references/sdk-sip-bridge.md](references/sdk-sip-bridge.md) | Bridging Voice SDK (WebRTC) calls to SIP endpoints, decision matrix |
