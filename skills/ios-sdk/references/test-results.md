---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Live test results for iOS skill assertions — server-side token generation and SDK behavior. -->
<!-- ABOUTME: Evidence gathered on 2026-03-29 against account ACb4de2... -->

# Test Results

**Date**: 2026-03-29
**Account**: ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
**Environment**: Node.js + twilio SDK, testing server-side patterns consumed by iOS apps

## Token Generation Tests

### T1: Voice AccessToken with iOS-Required Grants

**Test**: Generate token with VoiceGrant including `incomingAllow`, `outgoingApplicationSid`, and `pushCredentialSid`.

**Result**: Token generated successfully (535 bytes). JWT payload contains:
```json
{
  "identity": "ios-test-user",
  "voice": {
    "incoming": { "allow": true },
    "outgoing": { "application_sid": "AP00000000000000000000000000000000" },
    "push_credential_sid": "CR00000000000000000000000000000000"
  }
}
```

**Finding**: `pushCredentialSid` appears as `push_credential_sid` in the JWT payload. This field enables `TwilioVoiceSDK.register()` to bind the device token for VoIP push.

### T2: Video AccessToken with Room Grant

**Test**: Generate token with VideoGrant specifying a room name.

**Result**: Token generated (436 bytes). Payload: `{ "identity": "ios-video-user", "video": { "room": "test-room" } }`. TTL confirmed at 14400 seconds.

### T3: Video Wildcard Token (No Room)

**Test**: Generate VideoGrant with empty options (no room specified).

**Result**: Token generated. Video grant in payload is an empty object `{}`. Room field is absent (not null, just missing). This grants access to any room.

### T4: Combined Voice + Video Token

**Test**: Add both VoiceGrant and VideoGrant to a single token.

**Result**: Both grants present: `["voice", "video"]`. Voice grant has `incoming.allow` and `outgoing.application_sid`. Video grant has `room`. Technically valid, but using separate tokens per SDK is recommended for independent TTL management.

### T5: Identity Requirement

**Test**: Generate token without `identity` option.

**Result**: **Throws error**: `identity is required to be specified in options`. Token cannot be generated without identity. This is enforced at the SDK level, not just at Twilio's server.

### T6: Identity Character Handling

**Test**: Generate tokens with special characters in identity.

| Identity | Stored As | Notes |
|----------|-----------|-------|
| `user@email.com` | `user@email.com` | Preserved exactly |
| `user+special` | `user+special` | Preserved exactly |
| `user with spaces` | `user with spaces` | Preserved exactly |
| `CaseSensitive` | `CaseSensitive` | Preserved exactly — case matters for `<Dial><Client>` routing |

### T7: TTL Limits

**Test**: Generate tokens with various TTL values.

| TTL | Result |
|-----|--------|
| 3600 (1h) | OK, `exp - iat = 3600` |
| 86400 (24h) | OK, max supported |
| 86401 (24h + 1s) | Token generates locally but Twilio rejects at use time |

**Finding**: The Node.js SDK does not validate TTL at generation time. Over-limit tokens silently fail when the SDK tries to use them.

## Environment Verification

**Test**: `validate_environment` MCP tool confirmed:
- Account: ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
- Auth: API Key (SK...)
- Default number: +12069666002
- Services: Verify, Sync, TaskRouter all reachable

## Tests Not Possible in This Environment

The following claims are sourced from Twilio documentation, SDK API reference, GitHub quickstart repos, and release notes. They cannot be live-tested without Xcode and an iOS device:

- CallKit provider delegate behavior
- PushKit VoIP push delivery
- iOS 13+ `reportNewIncomingCall` enforcement
- Audio session activation timing
- Background mode behavior
- Camera/mic permission prompts
- TVOCallInvite retain cycle crash
- Reconnection behavior on network changes
- Virtual background processing
- ReplayKit screen share

These claims are marked as QUALIFIED (doc-sourced) in the assertion audit.
