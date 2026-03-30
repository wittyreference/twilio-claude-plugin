---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: SIP Registration deep-dive for Twilio SIP Domains. -->
<!-- ABOUTME: Covers lifecycle, edge locations, calling patterns, and limits. -->

# SIP Registration

## Overview

SIP Registration binds a SIP endpoint's Address of Record (AOR) with its current network location. This allows softphones, desk phones, and SIP clients on dynamic IPs to receive inbound calls and place outbound calls through a Twilio SIP Domain without a static IP or firewall changes.

Format: `sip:username@{domain}.sip.twilio.com`

## Prerequisites

1. SIP Domain with `sipRegistration: true`
2. At least one Credential List mapped to the domain's **Registration** auth path (`/Auth/Registrations/CredentialListMappings`)
3. A credential in that list whose username matches the endpoint's registration username

## Registration Flow

```
Softphone                          Twilio SIP Registrar
   │                                      │
   │ REGISTER sip:{domain}.sip.{edge}.twilio.com
   │─────────────────────────────────────→│
   │                                      │
   │ 407 Proxy Authentication Required    │
   │←─────────────────────────────────────│
   │                                      │
   │ REGISTER (with digest credentials)   │
   │─────────────────────────────────────→│
   │                                      │
   │ 200 OK (Contact binding stored)      │
   │←─────────────────────────────────────│
   │                                      │
   │ Re-REGISTER (before expiry)          │
   │─────────────────────────────────────→│
```

## Edge Locations

Endpoints register to a specific Twilio edge location. The REGISTER URI includes the edge:

| Edge URI suffix | Location | Region code |
|----------------|----------|-------------|
| `ashburn.twilio.com` | Virginia | us1 |
| `umatilla.twilio.com` | Oregon | us2 |
| `dublin.twilio.com` | Ireland | ie1 |
| `frankfurt.twilio.com` | Germany | de1 |
| `singapore.twilio.com` | Singapore | sg1 |
| `tokyo.twilio.com` | Japan | jp1 |
| `sao-paulo.twilio.com` | Brazil | br1 |
| `sydney.twilio.com` | Australia | au1 |

**Example**: `sip:alice@mycompany.sip.dublin.twilio.com` registers Alice at the Dublin edge.

**Default**: If no edge is specified (`sip:alice@mycompany.sip.twilio.com`), registration uses the Virginia (Ashburn) edge.

## Expiration and Refresh

| Parameter | Value |
|-----------|-------|
| Minimum expiry | 600 seconds (10 minutes) |
| Maximum expiry | 3,600 seconds (1 hour) |
| Recommended refresh interval | Half of expiry value |

- If the endpoint requests an expiry below 600, Twilio sets it to 600
- If the endpoint requests an expiry above 3600, Twilio sets it to 3600
- Failing to re-register before expiry removes the binding — the endpoint becomes unreachable
- To explicitly unregister, send a REGISTER with `Expires: 0`

## Calling Registered Endpoints

To call a registered endpoint, use `<Dial><Sip>` with the domain (without the edge):

```xml
<Response>
  <Dial>
    <Sip>sip:alice@mycompany.sip.twilio.com</Sip>
  </Dial>
</Response>
```

The `edge` or `region` URI parameter is **ignored** for registered endpoints. Twilio routes the call to the edge where the endpoint is registered, regardless of what edge you specify in the URI.

### Forked Calls (Multiple Registrations)

If the same AOR has multiple active registrations (e.g., Alice is registered from her desk phone and her laptop), the INVITE is forked — all registered endpoints ring simultaneously. The first to answer wins.

Maximum 10 active registrations per AOR.

## Calling From Registered Endpoints

A registered endpoint can place outbound calls by sending a SIP INVITE to its registration edge:

```
INVITE sip:+15551234567@mycompany.sip.dublin.twilio.com
```

Flow:
1. Twilio authenticates the INVITE against the domain's **Call** auth (not registration auth)
2. Twilio fetches the domain's `voiceUrl` with the call details
3. Your TwiML handler processes the call (e.g., `<Dial><Number>+15551234567</Number></Dial>`)

**Requirements for PSTN calls from registered endpoints:**
- Dialed number must be in E.164 format
- The E.164 number must be verified in the Twilio Console (or you must have a geographic number to use as callerId)
- Your `voiceUrl` handler must extract the dialed number and route appropriately

## Auth Separation: Registration vs Calls

Registration auth and call auth are configured separately:

| Auth Type | Controls | API Path |
|-----------|----------|----------|
| Registration | Who can REGISTER (bind their AOR) | `/Auth/Registrations/CredentialListMappings` |
| Calls | Who can send INVITEs (make calls) | `/Auth/Calls/CredentialListMappings` + `/Auth/Calls/IpAccessControlListMappings` |

You can use the same credential list for both, or different lists. A common pattern:

- **Same list**: Simple setup — anyone who can register can also call
- **Different lists**: Restrict calling to a subset of registered users, or require additional credentials for call origination

## Limits

| Resource | Limit |
|----------|-------|
| Active registrations per AOR | 10 |
| Active registrations per domain | 1,000,000 |
| Credential Lists per domain (registration) | 100 |
| Credentials per list | 1,000 |

## Softphone Configuration Example

For a softphone (e.g., Ooma, Zoiper, Linphone) connecting to a Twilio SIP Domain:

| Setting | Value |
|---------|-------|
| SIP Server / Registrar | `{domain}.sip.{edge}.twilio.com` |
| Username | Must match a credential username |
| Password | The credential password |
| Transport | UDP (5060) or TLS (5061) |
| Auth Type | Digest |
| Register | Yes |
| Register Interval | 300 seconds (for 600s expiry) |

## Diagnostics

- **Registration failures**: Check credential username matches exactly (case-sensitive)
- **Calls not arriving**: Verify `sipRegistration: true` on the domain, verify registration auth credential list is mapped, check that the endpoint's re-registration hasn't expired
- **Calls not originating**: Registered endpoint must also pass call auth (separate from registration auth). Verify call auth credentials or IP ACL.
- **Wrong edge**: Check the endpoint's REGISTER URI includes the intended edge location
