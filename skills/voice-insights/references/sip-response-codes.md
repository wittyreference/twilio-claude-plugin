---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Comprehensive SIP response code reference for Voice Insights call diagnostics. -->
<!-- ABOUTME: Covers range-based classification, top 25 specific codes, and carrier-origin actionability notes. -->

# SIP Response Code Reference

## Range-Based Classification

| Range | Class | Meaning | General Action |
|-------|-------|---------|----------------|
| 1xx | Provisional | Request received, continuing to process | Informational only; no action needed |
| 2xx | Success | Request successfully received, understood, and accepted | Call connected; no action needed |
| 3xx | Redirection | Further action needed to complete the request | Usually handled automatically; check routing config if persistent |
| 4xx | Client Error | Request contains bad syntax or cannot be fulfilled at this server | Caller-side or configuration issue; check TwiML, number format, auth |
| 5xx | Server Error | Server failed to fulfill an apparently valid request | Carrier or Twilio infrastructure issue; retry, check status page |
| 6xx | Global Failure | Request cannot be fulfilled at any server | Destination problem; all endpoints rejected or unreachable |

## Top 25 SIP Response Codes

| Code | Meaning | Typical Cause | Recommended Action |
|------|---------|---------------|-------------------|
| 100 | Trying | Call is being routed | No action; normal provisional response |
| 180 | Ringing | Remote party's device is ringing | No action; normal flow |
| 183 | Session Progress | Early media negotiation in progress | No action; common with carriers providing ringback tone |
| 200 | OK | Call answered successfully | None needed |
| 300 | Multiple Choices | Multiple redirect targets available | Check SIP routing configuration |
| 302 | Moved Temporarily | Destination redirected to new URI | Usually automatic; check redirect loop if call fails |
| 400 | Bad Request | Malformed SIP message or invalid parameters | Check TwiML for syntax errors, verify number format (E.164) |
| 401 | Unauthorized | Authentication required but missing or invalid | Check SIP trunk credentials, IP ACL lists |
| 403 | Forbidden | Server understood but refuses to authorize | Check account status, IP ACLs, geographic permissions |
| 404 | Not Found | Destination user/number does not exist at this domain | Verify destination number, check SIP domain routing |
| 407 | Proxy Authentication Required | Proxy-level auth needed | Check SIP proxy credentials, trunk authentication settings |
| 408 | Request Timeout | No response received within timeout period | Network connectivity issue; check carrier availability, retry |
| 480 | Temporarily Unavailable | Callee device is off, unreachable, or not registered | Retry later; check if device is powered on and connected |
| 484 | Address Incomplete | Dialed number is too short or missing digits | Verify E.164 format (+country code + number), check dial plan |
| 486 | Busy Here | Callee is currently on another call | Retry later, offer voicemail, implement busy-handling TwiML |
| 487 | Request Terminated | Transaction cancelled before completion | See note below; often normal behavior |
| 488 | Not Acceptable Here | Media capabilities incompatible | Check SIP trunk codec configuration (G.711 mu-law/a-law, Opus) |
| 491 | Request Pending | Request received while another is still being processed | Usually auto-resolves on retry; indicates SIP transaction collision |
| 500 | Server Internal Error | Twilio or carrier internal failure | Retry the call; check Twilio status page for incidents |
| 502 | Bad Gateway | Upstream server returned invalid response | Carrier-side failure; retry, escalate if persistent |
| 503 | Service Unavailable | Server temporarily overloaded or in maintenance | Rate limit your requests; retry with exponential backoff |
| 504 | Server Timeout | Upstream gateway did not respond in time | Carrier latency issue; retry, consider alternate carrier |
| 600 | Busy Everywhere | All known endpoints for callee are busy | All devices occupied; offer callback or voicemail |
| 603 | Decline | Callee explicitly rejected the call | Call was intentionally refused; no retry will help |
| 604 | Does Not Exist Anywhere | Destination number/user does not exist in any location | Verify the destination number is valid and in service |

## Important Notes

### SIP 487 (Request Terminated) Is Often Normal

SIP 487 means the INVITE transaction was cancelled before the call was answered. This is the **expected** response when:

- The caller hangs up during ringing (before the callee picks up)
- A `<Dial>` with a `timeout` expires without an answer
- The application programmatically cancels the call via the REST API
- A `<Dial>` with `sequential` ring reaches a later target and the earlier leg is cancelled

Only investigate SIP 487 if calls are being terminated unexpectedly (e.g., premature cancellation before the caller intended to hang up). Check the `disconnected_by` property in the call summary and correlate with call duration to distinguish normal from abnormal.

### Carrier-Origin SIP Errors Are Not Directly Actionable

When a SIP error originates from the carrier network (visible on `carrier_edge`), there is limited direct remediation available:

- **4xx from carrier**: The carrier rejected the call. Common causes include invalid routing, number porting issues, or carrier-level blocking. Verify the destination number is valid and properly formatted.
- **5xx from carrier**: The carrier experienced an internal failure. These are transient in most cases. Retry the call.
- **Persistent carrier errors**: If a specific carrier error impacts your users consistently, contact **Twilio Support** with the affected call SIDs. Twilio can investigate the carrier-side issue.
- **SIP Interface / Elastic SIP Trunking**: For self-managed SIP infrastructure, compare your local SIP logs and packet captures (pcaps) with Twilio's public pcap to identify where the failure occurs.

### SIP Codes in Voice Insights

The `properties.last_sip_response_num` field in the Call Summary contains the final SIP response code for the call. Use this field for programmatic classification:

- **2xx**: Call was answered; any quality issues are post-connect
- **3xx**: Redirect occurred; check if the redirect destination was reached
- **4xx**: Client/caller-side error; the call was not established
- **5xx**: Server/carrier-side error; the call was not established
- **6xx**: Global failure; the call cannot be established to any endpoint

A non-200 SIP response sets `abnormalSession: true` in the call summary, making it discoverable via `list_call_summaries(abnormalSession: true)`.
