---
name: "ios-sdk"
description: "Twilio development skill: ios-sdk"
---

---
name: ios-sdk
description: Twilio iOS SDK development guide (Voice + Video). Use when building native iOS calling apps, video conferencing, CallKit integration, VoIP push notifications, or debugging iOS-specific platform issues.
---

# iOS SDK Development Skill

iOS-specific platform guide for building native apps with Twilio Voice SDK 6.x and Video SDK 5.x. Load this skill when working on Swift/Objective-C code that integrates Twilio SDKs, or when debugging iOS-specific issues like CallKit, PushKit, background modes, or audio session conflicts. Medium degree of freedom — preferred patterns exist but vary by app architecture.

Evidence date: 2026-03-29. Account: ACxx...xx SDK versions: Voice 6.13.6, Video 5.11.2.

---

## Scope

### CAN

- Guide native iOS app development with Twilio Voice SDK (PSTN calling, client-to-client)
- Guide native iOS app development with Twilio Video SDK (group rooms, tracks, recording)
- Configure CallKit for native call UI integration (incoming and outgoing)
- Set up VoIP push notifications via PushKit for backgrounded incoming calls
- Handle iOS audio session management (categories, modes, interruptions, routing)
- Handle iOS permission flows (microphone, camera, local network)
- Generate server-side AccessTokens with Voice and Video grants for iOS clients
- Debug iOS-specific issues (audio routing, background mode, push registration)
- Advise on app lifecycle concerns (foreground, background, suspended, terminated)

### CANNOT

- **Build or compile iOS apps** — This skill advises on patterns; Xcode is required to build
- **Test on iOS simulator for media** — Simulator has no camera; microphone support is limited
- **Use Elastic SIP Trunking from iOS SDK** — SDKs connect via Programmable Voice only
- **Record client-side** — All recording is server-side via TwiML or Calls API
- **Run without a server-side token endpoint** — iOS SDK requires AccessToken JWT from your backend
- **Use Video SDK without API Key auth** — Video AccessTokens require API Key + Secret, not Auth Token
- **Receive VoIP pushes without CallKit on iOS 13+** — Apple requires `reportNewIncomingCall` inside PushKit callback; without it, the system terminates your app
- **Share screen on iOS via Video SDK without ReplayKit** — Screen capture requires a Broadcast Upload Extension
- **Use Carthage with Video SDK** — Carthage does not support `.xcframeworks`
- **Mix ConversationRelay WebSocket with iOS Voice SDK** — ConversationRelay connects a PSTN call to a WebSocket server, not an SDK client; the iOS SDK connects via WebRTC

---

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Native iOS calling app with system call UI | Voice SDK + CallKit | CallKit gives lock screen UI, call history, Siri integration |
| Video conferencing in iOS app | Video SDK (group rooms) | Server-routed media, up to 50 participants, recording support |
| Cross-platform mobile app | React Native SDK | Single codebase bridging to native iOS/Android SDKs |
| Voice AI agent callable from phone | ConversationRelay (not iOS SDK) | AI connects via WebSocket to PSTN call; no native SDK needed |
| Browser-based calling on iOS Safari | JavaScript SDK | No app install; works in Safari with HTTPS |
| PSTN calling without native app | Calls API | Server-to-server; no client SDK involved |

---

## Decision Frameworks

### Voice SDK vs ConversationRelay on Mobile

| Factor | Voice SDK | ConversationRelay |
|--------|-----------|-------------------|
| User experience | Native app with CallKit UI | User calls a phone number (PSTN) |
| Network | WebRTC (SDK manages) | PSTN carrier network |
| Requires app install | Yes | No |
| Background reception | VoIP push + CallKit | N/A (it's a phone call) |
| Custom audio processing | Yes (TVOAudioDevice) | No (server-side STT/TTS) |
| Use case | Softphone, contact center agent | AI voice agent, IVR replacement |

### Installation Method

| Method | Voice SDK | Video SDK | Notes |
|--------|-----------|-----------|-------|
| Swift Package Manager | Preferred | Preferred | Add GitHub repo URL in Xcode |
| CocoaPods | Supported | Supported | `pod 'TwilioVoice', '~> 6.13'` / `pod 'TwilioVideo', '~> 5.11'` |
| Manual XCFramework | Supported | Supported | Download from GitHub releases, embed & sign |
| Carthage | N/A | Not supported | Carthage does not support `.xcframeworks` |

### Static vs Dynamic Framework

| Factor | Dynamic | Static |
|--------|---------|--------|
| App launch time | Slightly slower (dylib loading) | Faster (linked at build) |
| Binary size | Smaller app, separate framework | Larger app, single binary |
| Voice SDK name | `TwilioVoice` | `TwilioVoice-static` |
| Extra setup | None | Add `SystemConfiguration.framework` |
| Linker flag | None | Add `-ObjC` to Other Linker Flags |

### Audio Session Category for Voice vs Video

| Use Case | Category | Mode | Options |
|----------|----------|------|---------|
| Voice call (default) | `.playAndRecord` | `.voiceChat` | SDK manages automatically |
| Video call (default) | `.playAndRecord` | `.videoChat` | SDK manages automatically |
| Voice + Bluetooth | `.playAndRecord` | `.voiceChat` | `.allowBluetoothHFP` (not `.allowBluetooth` — deprecated for Xcode 26+) |
| Voice + speaker | `.playAndRecord` | `.voiceChat` | `.defaultToSpeaker` |

---

## Server-Side Token Endpoint

iOS apps need a backend endpoint that generates AccessTokens. This is the same for all platforms — see the [Voice SDKs skill](/skills/voice-sdks.md) for the canonical token generation code.

Key iOS-specific token considerations:

- **Push credential SID in Voice grant**: Include `pushCredentialSid: 'CRxxxxx'` to enable VoIP push registration
- **Identity is required**: Token generation throws if identity is omitted. Identity is case-sensitive and preserved exactly.
- **Separate tokens for Voice and Video**: While a single token CAN carry both grants, use separate tokens per SDK to simplify TTL management and grant rotation
- **TTL for mobile**: 1-4 hours recommended. Max is 86400s (24h). Implement proactive refresh at ~75% TTL.

```javascript
// ABOUTME: Voice AccessToken with push credential for iOS VoIP push registration.
// ABOUTME: The pushCredentialSid enables TwilioVoiceSDK.register() to bind the device token.

const voiceGrant = new VoiceGrant({
  outgoingApplicationSid: process.env.TWIML_APP_SID,
  incomingAllow: true,
  pushCredentialSid: process.env.PUSH_CREDENTIAL_SID  // CRxxxxx
});
```

---

## CallKit Integration

CallKit provides the native iOS call UI (lock screen, call history, Siri). It is mandatory for VoIP push on iOS 13+.

### Provider Configuration

```swift
let config = CXProviderConfiguration()
config.maximumCallGroups = 1
config.maximumCallsPerCallGroup = 1
config.supportsVideo = false
config.supportedHandleTypes = [.phoneNumber, .generic]
// Optional: config.iconTemplateImageData for custom icon
let provider = CXProvider(configuration: config)
provider.setDelegate(self, queue: nil)  // nil = main queue
```

### Incoming Call Flow (PushKit → CallKit → Answer)

1. PushKit delivers VoIP push → `pushRegistry(_:didReceiveIncomingPushWith:for:completion:)`
2. Call `TwilioVoiceSDK.handleNotification(payload, delegate: self)` → receives `TVOCallInvite`
3. Report to CallKit: `provider.reportNewIncomingCall(with: uuid, update: update)` — this MUST happen inside the PushKit callback on iOS 13+
4. User taps Answer → `provider(_:perform: CXAnswerCallAction)` fires
5. Accept invite: `callInvite.accept(with: delegate)` → returns `TVOCall`
6. Call `action.fulfill()` after accepting

### Outgoing Call Flow (CallKit → Connect)

1. Create `CXStartCallAction` with UUID and handle
2. Request via `CXCallController().request(CXTransaction(action:))`
3. In `provider(_:perform: CXStartCallAction)`, call `TwilioVoiceSDK.connect(options:delegate:)`
4. Call `action.fulfill()` after `callDidConnect` fires

### Audio Session Activation

CallKit manages the audio session lifecycle. The SDK needs to know when audio is activated:

```swift
func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    TwilioVoiceSDK.audioDevice.isEnabled = true
}

func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    TwilioVoiceSDK.audioDevice.isEnabled = false
}
```

Read [references/callkit-pushkit.md](references/callkit-pushkit.md) for the complete PushKit setup, certificate creation, and push credential registration.

---

## Gotchas

### Setup

1. **VoIP push requires CallKit on iOS 13+**: Apple mandates that `reportNewIncomingCall` is called inside the PushKit push handler. If you don't, Apple terminates your app and may stop delivering pushes entirely. There is no workaround — CallKit is not optional for VoIP push.

2. **Sandbox vs production push credentials**: Create separate Twilio push credentials (CRxxxxx) for development (sandbox) and production (App Store) builds. Twilio recommends using separate accounts or subaccounts for this. Mixing them causes silent push delivery failures.

3. **`-ObjC` linker flag for manual/static installs**: Without this flag in "Other Linker Flags", category methods in the SDK won't load, causing cryptic runtime crashes (unrecognized selector) that don't appear at compile time.

4. **`UIBackgroundModes` must include `voip`**: Without this Info.plist entry, PushKit won't deliver VoIP pushes when the app is backgrounded. This is the most common "incoming calls work in foreground but not background" issue.

5. **`NSMicrophoneUsageDescription` is mandatory for Voice**: iOS terminates the app without warning if you access the microphone without this Info.plist key. For Video, also add `NSCameraUsageDescription`.

6. **Video SDK needs `NSLocalNetworkUsageDescription` on iOS 14+**: Only required if using peer-to-peer rooms with `TVILocalNetworkPrivacyPolicyAllowAll`. Group rooms don't need this.

7. **Xcode 26 requires separate iOS platform download**: Run `xcodebuild -downloadPlatform iOS` or Xcode > Settings > Components. Without this, `xcodebuild` can't find any iOS Simulator destinations even though runtimes exist.

8. **SPM can't build iOS app targets directly**: `swift build --sdk iphonesimulator` doesn't work for app targets. Use `xcodegen` to generate `.xcodeproj` from `project.yml`, then `xcodebuild` with the generated project.

### Runtime

9. **CallKit audio session activation timing**: Do NOT play or record audio before CallKit calls `provider(_:didActivate:)`. The SDK's `audioDevice.isEnabled` must be set to `true` only in the `didActivate` callback. Setting it too early produces silence or crashes.

10. **`TVOCallInvite` must be retained until call completes**: If the invite object is deallocated while the call is active, the SDK crashes (fixed partially in 6.13.5, but retain the object as best practice). Store it in a property, not a local variable.

11. **`AVAudioSessionCategoryOptionAllowBluetooth` is deprecated**: Use `.allowBluetoothHFP` instead. The old option triggers a deprecation warning in Xcode 26+ builds (Voice SDK 6.13.3+).

12. **Token refresh must happen before expiry**: If the token expires mid-session, existing calls continue but new calls and registrations fail silently. Implement a timer at 75% of TTL to fetch a fresh token and re-register.

13. **Identity is case-sensitive across the system**: `<Dial><Client>agent-Alice</Client></Dial>` will NOT ring a client registered as `agent-alice`. This applies to push registration, token generation, and TwiML routing.

14. **Video SDK simulator has no camera**: `TVICameraSource` returns nil on simulator. Test video with a physical device. Audio works on some simulators but is unreliable.

15. **`TVOCallMessageBuilder.contentType` has no effect in 6.11.x**: Defaults to `application/json` regardless of what you set. Fixed tracking but not resolved as of 6.13.x. Use JSON format for call messages.

16. **Voice SDK `getStats` returns array, not flat object**: `call.getStats { reports in }` returns `[StatsReport]`, each with `remoteAudioTrackStats` containing jitter/MOS/packetsLost. Not `getStatsReport` and not a single callback with a flat stats object.

### Network

17. **Reconnection is automatic but app must handle UI**: Voice SDK fires `call(_:isReconnectingWithError:)` and `callDidReconnect(_:)` on network changes. Show a "Reconnecting..." indicator — the call may survive if the interruption is brief (cellular handoff, Wi-Fi switch).

18. **ICE gathering issue on iOS 18**: Fixed in Voice SDK 6.12.0 and Video SDK 5.8.3. If stuck on older versions, network handover during calls may fail silently. Update the SDK.

19. **Edge selection matters for mobile**: Default `roaming` works globally but adds a negotiation round-trip. For latency-sensitive apps targeting a specific region, pin the edge (e.g., `TwilioVoiceSDK.edge = "ashburn"`).

### Video-Specific

20. **Only `group` room type on new accounts**: Accounts created after specific date only support Group rooms. Attempting `peer-to-peer` or `small-group` returns error 53126. Check your account's room type support.

21. **Virtual backgrounds require iOS 17+**: The `TwilioVirtualBackgroundProcessors` framework (private beta, Video 5.11.0+) only works on iOS 17 and later.

22. **H.264 hardware encoder limit**: iOS devices support max 3 simultaneous H.264 hardware encoders. In multi-participant rooms with screen share, some tracks may fall back to VP8 software encoding.

23. **Screen share requires Broadcast Upload Extension**: iOS does not allow apps to capture the screen directly (except via ReplayKit). You must create a separate Broadcast Upload Extension target in Xcode and use `TVIReplayKitVideoSource`.

24. **`TVITrackPriority` APIs are deprecated in 5.10.x**: Priority-based bandwidth allocation methods are deprecated. Remove usage to avoid warnings.

---

## Related Resources

- [Voice SDKs Skill](/skills/voice-sdks.md) — Cross-platform Voice SDK guide (tokens, TwiML App, edge locations, call messages)
- [Video Skill](/skills/video/SKILL.md) — Video room types, recording, compositions, transcription
- [Video SDK Integration Reference](/skills/video/references/sdk-integration.md) — JS, iOS, Android connection patterns
- [IAM Skill](/skills/iam/SKILL.md) — API Key creation, AccessToken generation, credential management
- [Voice Insights Skill](/skills/voice-insights/SKILL.md) — SDK call quality diagnostics (iOS SDK generates Insights events)
- [Recordings Skill](/skills/recordings/SKILL.md) — Server-side recording methods (iOS SDK cannot record client-side)
- Twilio Voice iOS SDK API Reference: `https://twilio.github.io/twilio-voice-ios/docs/latest/`
- Twilio Voice iOS Quickstart: `https://github.com/twilio/voice-quickstart-ios`
- Twilio Video iOS Quickstart: `https://github.com/twilio/video-quickstart-ios`

---

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| CallKit + PushKit setup | [references/callkit-pushkit.md](references/callkit-pushkit.md) | Setting up incoming/outgoing calls with native UI |
| SDK versions and requirements | [references/sdk-versions.md](references/sdk-versions.md) | Checking compatibility, minimum iOS versions, Xcode requirements |
| Test evidence | [references/test-results.md](references/test-results.md) | Verifying claims about token generation and SDK behavior |
| Assertion audit | [references/assertion-audit.md](references/assertion-audit.md) | Reviewing provenance of all factual claims |
| Voice SDK ↔ SIP bridge | [/skills/sip/references/sdk-sip-bridge.md](/skills/sip/references/sdk-sip-bridge.md) | Bridging SDK calls to SIP endpoints, codec negotiation, decision matrix |
