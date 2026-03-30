---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Live test evidence for Elastic SIP Trunking skill assertions. -->
<!-- ABOUTME: 31 tests executed against live Twilio API on 2026-03-28, account AC1cb3. -->

# Elastic SIP Trunking — Live Test Results

Tests executed 2026-03-28 against account prefix `AC1cb3`.

## Test Trunk Resources

| Resource | SID | Purpose |
|----------|-----|---------|
| Test trunk (primary) | `TK6767b214fb69136855bb6a69e0ad0bca` | Main test subject |
| Test trunk (65-char name) | `TK4ee41ca...` | FriendlyName length test |
| Test trunk (empty name) | `TKd22c4693fcb80b7e8e99074a57cf84a5` | Null FriendlyName test |
| Test trunk (no name) | `TKc6a41f5cd6a5fd8a3230a8a925bd7a80` | No FriendlyName param |
| SIP Lab trunk (existing) | `TK8b2bdbd54a36235ca82915f7cbe85439` | Reference, not modified |
| Test ACL 1 | `AL3949f0d2cb6eee8c88678365ed67d840` | Multiple ACL test |
| Test ACL 2 | `AL176854a819cdce6d23528385cdeacb04` | Multiple ACL test |
| Test credential list | `CL04a2fd0a4ed8147fddc4d2571ff92a2a` | Auth type test |

All test resources were cleaned up after testing. Only the SIP Lab trunk remains.

---

## Configuration Tests

| # | Test | Input | Result | Key Finding |
|---|------|-------|--------|-------------|
| 1 | Set domain name | `DomainName=skill-test-trunk.pstn.twilio.com` | Success | Domain accepted with full `.pstn.twilio.com` suffix |
| 2 | Enable secure | `Secure=true` | `secure: true` | Toggles correctly |
| 3 | Enable CNAM | `CnamLookupEnabled=true` | `cnam_lookup_enabled: true` | Toggles correctly |
| 4 | TransferMode=enable-all | `TransferMode=enable-all` | `transfer_mode: "enable-all"` | Accepted |
| 5 | TransferCallerId=from-transferor | `TransferCallerId=from-transferor` | `transfer_caller_id: "from-transferor"` | Accepted |
| 6 | Disaster recovery URL | `DisasterRecoveryUrl=https://example.com/dr` | Success | URL and method saved |
| 7 | SymmetricRtpEnabled=true | `SymmetricRtpEnabled=true` | `symmetric_rtp_enabled: false` | **Silently ignored** — stayed false |
| 12 | TransferMode=sip-only | `TransferMode=sip-only` | `transfer_mode: "sip-only"` | Third mode confirmed |
| 14 | Full trunk GET | GET after all updates | All fields populated | Confirmed all property types |

## Validation Tests (Error Cases)

| # | Test | Input | Result | Error |
|---|------|-------|--------|-------|
| 8 | Invalid TransferMode | `TransferMode=invalid` | Error 20001 | "Invalid parameter" |
| 9 | TransferMode=sip-refer | `TransferMode=sip-refer` | Error 20001 | Not a valid value |
| 11 | Duplicate domain name | `DomainName=skill-test-trunk.pstn.twilio.com` (on new trunk) | Error 21248 | Domain already in use |
| 18 | Domain without suffix | `DomainName=my-short-name` | Error 21245 | Must end with `twilio.com` |
| 22 | Invalid SIP URL scheme | `SipUrl=http://example.com` | Error | Must be `sip:` or `sips:` |
| 23 | Invalid TransferCallerId | `TransferCallerId=invalid` | Error 20001 | Must be `from-transferee` or `from-transferor` |

## Recording Tests

| # | Test | Mode | Result |
|---|------|------|--------|
| 10a | do-not-record | `Mode=do-not-record` | Accepted |
| 10b | record-from-ringing | `Mode=record-from-ringing` | Accepted |
| 10c | record-from-answer | `Mode=record-from-answer` | Accepted |
| 10d | record-from-ringing-dual | `Mode=record-from-ringing-dual` | Accepted |
| 10e | record-from-answer-dual | `Mode=record-from-answer-dual` | Accepted |
| 13 | Trim do-not-trim | `Trim=do-not-trim` | `trim: "do-not-trim"` |

All 5 recording modes and both trim options confirmed working.

## Origination URL Tests

| # | Test | Input | Result | Key Finding |
|---|------|-------|--------|-------------|
| 15 | Priority=0 | `Priority=0, Weight=1` | Accepted | Minimum priority is 0 |
| 16 | Priority=65535 | `Priority=65535, Weight=65535` | Accepted | Maximum values confirmed |
| 17 | Weight=0 | `Priority=10, Weight=0` | Accepted | Weight=0 is valid (some docs say min=1) |
| 21 | sips: scheme | `SipUrl=sips:192.168.1.4:5061;transport=tls` | Accepted | TLS URLs work |
| 22 | http: scheme | `SipUrl=http://example.com` | Error | Rejected — must be sip/sips |

## FriendlyName Tests

| # | Test | Input | Result |
|---|------|-------|--------|
| 25 | 65-char name | `FriendlyName=AAAA...A (65)` | Accepted |
| 26 | Empty name | `FriendlyName=` | `friendly_name: null` |
| 27 | No name param | (omitted) | `friendly_name: null` |

## Authentication Tests

| # | Test | Action | auth_type After |
|---|------|--------|-----------------|
| 28a | Associate ACL 1 | Add ACL to trunk | `"IP_ACL"` |
| 28b | Associate ACL 2 | Add second ACL | `"IP_ACL"` |
| 29 | Associate credential list | Add CL to trunk | `"IP_ACL,CREDENTIAL_LIST"` |
| 30 | Remove both ACLs | Remove ACLs | `"CREDENTIAL_LIST"` (with possible caching delay) |

Confirms `auth_type` and `auth_type_set` are dynamically computed from associated resources.

## Voice Insights

| # | Test | Query | Result |
|---|------|-------|--------|
| 24 | Trunking call type | `CallType=trunking` filter | 0 results (SIP Lab not running) |
| 31 | Insights API trunking filter | `callType=trunking` on Summaries API | Confirmed filter accepted |

The `callType=trunking` filter is accepted by the Voice Insights API but returns 0 results even after successful trunk calls with Advanced Features enabled. See SIP Lab live tests below.

---

## SIP Lab Live Tests (2026-03-29)

Droplet restored from snapshot 220969006 → new IP 68.183.158.165. Asterisk rebuilt with correct `external_media_address`.

### Termination Call 1 (API → Trunk → Asterisk)

| Field | Value |
|-------|-------|
| API call SID | `CAe846aea8958fc6918d49d3374915bc58` |
| Status | completed |
| Duration | 15s |
| Recording SID | `REb0b8c0db726c9abbc204c1d046f31a5b` |
| Recording source | `OutboundAPI` |
| Recording channels | 1 |
| TwiML | `<Pause length="15"/>` |
| Audio path | Twilio → trunk → Asterisk (played careless-whisper.wav) |

### Termination Call 2 (Trunk Recording Active, Dual-Channel)

| Field | Value |
|-------|-------|
| API call SID | `CAea6521e79a66b1da403423a81e59953e` |
| Trunk leg call SID | `CA1ec6f0cf01690634d2bb4ef08a9bc6cd` |
| Status | completed |
| Duration | 9s |
| Trunk recording SID | `REd57bb70cc0ad176ca05f800c3de840b1` |
| Recording source | `Trunking` |
| Recording channels | **2** (dual-channel confirmed) |
| Trunk leg direction | `trunking-originating` |
| Trunk leg To | `sip:+12293635283@68.183.158.165:5060` |
| Recording mode | `record-from-answer-dual` |

**Key finding**: The trunk recording (`REd57bb7...`) is on the trunk-leg call SID (`CA1ec6f0...`), NOT on the API-initiated call SID (`CAea6521...`). The API call's recording list is empty. This confirms gotcha #24.

### validate_sip Result

All 7 checks passed:
- Trunk exists (domain: sip-lab-e7f2a9.pstn.twilio.com, secure: false)
- 1 IP ACL associated, PBX IP 68.183.158.165 found
- 1 credential list associated
- 1 origination URL enabled (sip:68.183.158.165:5060, priority 10)
- 1 phone number associated (+12293635283)
- 0 SIP errors in debugger (300s lookback)

### Voice Insights Findings

| Check | Result |
|-------|--------|
| Advanced Features enabled | Yes (`advancedFeatures: true`) |
| Call Events for trunk leg | **Yes** — 3 events (initiated/answered/completed) on carrier_edge, ashburn/us1 |
| Call Summary for trunk leg | **No** — returns null |
| `callType=trunking` filter | Returns 0 results |
| `direction=trunking-originating` filter | Returns 0 results |

**Conclusion**: Voice Insights Call Summaries DO include trunking calls, but **require `ProcessingState=all`**. The default `ProcessingState=completed` filter misses them during the extended processing window (~5-15 min for trunking vs ~2-4 min for carrier calls). With the correct filter, 10 trunking summaries were found including both successful calls (`CA1ec6f0...` completed/9s, `CAe41dbc...` completed/15s) and earlier failed calls from when the droplet was offline.
