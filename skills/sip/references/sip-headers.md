---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Custom SIP header passthrough rules for Twilio SIP Interface. -->
<!-- ABOUTME: Covers inbound, outbound, action callbacks, and standard header exceptions. -->

# SIP Header Passthrough Reference

## Overview

Twilio SIP Interface passes a subset of SIP headers between your infrastructure and webhooks. The rules differ by direction (inbound vs outbound) and callback type (voice URL vs action URL vs status callback).

## Inbound SIP (Your Infra → Twilio)

When your PBX sends a SIP INVITE to a Twilio SIP Domain, the domain's `voiceUrl` webhook receives:

### Custom Headers

Any header with an `X-` prefix is forwarded to the webhook as a parameter:

| SIP Header | Webhook Parameter |
|------------|------------------|
| `X-MyHeader: value` | `SipHeader_X-MyHeader=value` |
| `X-Route-Id: 42` | `SipHeader_X-Route-Id=42` |

- Multi-value headers arrive intact: `X-Test: a=1;b=2` → `SipHeader_X-Test=a=1;b=2`
- Header names are case-preserved
- Hyphens in header names become hyphens in parameter names (not underscores)

### Standard Header Exception

| SIP Header | Webhook Parameter |
|------------|------------------|
| `User-to-User` | `SipHeader_User-to-User` |

This is the only standard (non-X) header forwarded on inbound SIP.

### Always-Available SIP Parameters

These are set by Twilio from the INVITE metadata, not from custom headers:

| Parameter | Source |
|-----------|--------|
| `SipCallId` | Call-ID header |
| `SipDomain` | Host portion of Request-URI |
| `SipDomainSid` | Matched SIP Domain SID |
| `SipSourceIp` | Source IP of signaling |

## Outbound SIP (Twilio → Your Infra)

When TwiML returns `<Dial><Sip>`, custom headers are appended to the SIP URI as query parameters:

```xml
<Sip>sip:user@host?x-mycustomheader=foo&amp;User-to-User=abc%3Bencoding%3Dhex</Sip>
```

### Custom Headers (X-prefixed)

| URI Query Parameter | SIP INVITE Header |
|--------------------|-------------------|
| `x-mycustomheader=foo` | `X-Mycustomheader: foo` |
| `x-route-id=42` | `X-Route-Id: 42` |

### Standard Headers (Outbound-Only)

These four standard headers can be set on outbound SIP without the `X-` prefix:

| URI Query Parameter | SIP INVITE Header |
|--------------------|-------------------|
| `User-to-User=abc%3Bencoding%3Dhex` | `User-to-User: abc;encoding=hex` |
| `Remote-Party-ID=...` | `Remote-Party-ID: ...` |
| `P-Preferred-Identity=...` | `P-Preferred-Identity: ...` |
| `P-Called-Party-ID=...` | `P-Called-Party-ID: ...` |

### Constraints

- **Max 1024 characters** total for all headers in the query string
- URL-encoding counts toward this limit
- XML-encode `&` as `&amp;` in TwiML
- URL-encode special characters in values (`;` → `%3B`, `=` → `%3D`)

## Call Screening URL (`<Sip url="">`)

When the outbound SIP call is answered, Twilio fetches the screening URL before connecting the legs. This URL receives:

| Parameter | Description |
|-----------|-------------|
| `SipCallId` | Call-ID from the INVITE |
| `SipDomain` | Host portion of the SIP URI |
| `SipDomainSid` | SD-prefixed SID |
| `SipHeader_X-{Name}` | Custom X-headers from the 200 OK response |
| `SipSourceIp` | Source IP of the signaling |

The screening URL does NOT receive the four standard headers (`User-to-User`, `Remote-Party-ID`, etc.) even if they were sent in the INVITE.

## Action Callback (`<Dial action="">`)

After the SIP leg completes (answered or failed), the action URL receives:

| Parameter | Description |
|-----------|-------------|
| `DialSipCallId` | Call-ID from the outbound INVITE |
| `DialSipResponseCode` | SIP response code (200, 486, 408, etc.) |
| `DialSipHeader_X-{Name}` | Custom X-headers from the final SIP response |

The action URL does NOT receive standard headers. Only X-prefixed custom headers from the SIP response are forwarded.

### Common SIP Response Codes

| Code | Meaning | Typical cause |
|------|---------|---------------|
| 200 | OK | Call answered |
| 408 | Request Timeout | Endpoint didn't respond |
| 480 | Temporarily Unavailable | Endpoint offline/busy |
| 486 | Busy Here | Endpoint explicitly busy |
| 487 | Request Terminated | Caller hung up during ring |
| 503 | Service Unavailable | Destination server error |
| 603 | Decline | Endpoint rejected the call |

## Status Callback

Status callbacks (`statusCallback` on `<Sip>`) receive standard Twilio Voice callback parameters but NOT SIP-specific headers. Use the action callback for SIP response codes and headers.

## Header Flow Summary

| Callback | Custom X-Headers | Standard 4 Headers | SIP Response Code | SipCallId |
|----------|:---:|:---:|:---:|:---:|
| Inbound voiceUrl | yes | User-to-User only | n/a | yes |
| Outbound screening url | yes (from 200 OK) | no | n/a | yes |
| Outbound action | yes (from response) | no | yes | yes |
| Status callback | no | no | no | no |

## BYOC Restriction

Custom SIP headers from BYOC trunk calls are silently discarded. All header passthrough documented here applies only to Programmable Voice SIP Interface (SIP Domains). If you need metadata from a BYOC trunk, use a different transport mechanism (e.g., SIP URI user part encoding, or a lookup service keyed on caller/called number).
