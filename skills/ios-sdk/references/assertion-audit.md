---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the iOS skill — provenance chain for every factual claim. -->
<!-- ABOUTME: Produced during Phase 4 of skill-builder on 2026-03-29 against account ACb4de2... -->

# Assertion Audit Log

**Skill**: ios-sdk
**Audit date**: 2026-03-29
**Account**: ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 21 |
| CORRECTED | 0 |
| QUALIFIED | 18 |
| REMOVED | 0 |
| **Total** | **39** |

## Assertions

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 1 | Voice SDK current version is 6.13.6 | Default | CONFIRMED | GitHub releases page fetched 2026-03-29 | Latest release Feb 3, 2025 |
| 2 | Video SDK current version is 5.11.2 | Default | CONFIRMED | GitHub releases page fetched 2026-03-29 | Latest release Feb 19, 2025 |
| 3 | Voice SDK min iOS is 12.0 | Compatibility | CONFIRMED | GitHub releases 6.13.2 changelog: "Minimum iOS deployment target raised to iOS 12.0" | |
| 4 | Video SDK min iOS is 12.2 (runtime) | Compatibility | CONFIRMED | GitHub releases 5.10.0 changelog: "Minimum iOS deployment target raised to iOS 12.2" | Build time still 9.0 per docs but runtime is 12.2 |
| 5 | Voice SDK requires Xcode 14.0+ | Compatibility | CONFIRMED | Twilio Voice iOS SDK docs page | |
| 6 | SDKs connect via Programmable Voice only, not Elastic SIP Trunking | Scope | QUALIFIED | Twilio docs + voice-sdks skill. SDKs use WebRTC to Twilio edge, not SIP | **Caveat**: SIP Interface domains can register SIP endpoints but that's not the iOS SDK |
| 7 | iOS SDK cannot record client-side | Scope | CONFIRMED | Voice SDK API reference — no recording methods on TVOCall. Recording is TwiML/API only | |
| 8 | Token requires identity | Behavioral | CONFIRMED | Live test T5 — throws "identity is required to be specified in options" | |
| 9 | Identity is case-sensitive | Behavioral | CONFIRMED | Live test T6 — `CaseSensitive` preserved exactly. voice-sdks skill gotcha #10 confirms routing case-sensitivity | |
| 10 | Token max TTL is 86400s (24h) | Default | CONFIRMED | Live test T7 — 86400s generates OK; Twilio docs confirm max 24h | |
| 11 | Over-max TTL generates locally but rejected at use time | Behavioral | CONFIRMED | Live test T7 — 86401s token generated; SDK does not validate locally | |
| 12 | pushCredentialSid appears as push_credential_sid in JWT | Behavioral | CONFIRMED | Live test T1 — JWT payload contains `push_credential_sid` field | |
| 13 | Combined Voice+Video grants work in one token | Behavioral | CONFIRMED | Live test T4 — both grants present in payload | |
| 14 | Video wildcard token (no room) produces empty grant object | Behavioral | CONFIRMED | Live test T3 — `video: {}` in payload, no room field | |
| 15 | VoIP push requires CallKit on iOS 13+ | Architectural | QUALIFIED | Apple documentation, Twilio quickstart README. Cannot live-test without iOS device | **Caveat**: Source is Apple PushKit documentation and Twilio quickstart, not live-tested |
| 16 | App terminated if reportNewIncomingCall not called in PushKit handler | Behavioral | QUALIFIED | Apple WWDC 2019, Twilio iOS 13 migration guide referenced in quickstart | **Caveat**: Doc-sourced, not live-tested. Behavior enforced by iOS, not Twilio |
| 17 | Sandbox vs production push credentials must be separate | Architectural | QUALIFIED | Twilio quickstart README: "strongly recommend using different Twilio accounts (or subaccounts)" | **Caveat**: Recommendation, not hard enforcement. Mixing CAN work but causes delivery issues |
| 18 | `-ObjC` linker flag required for manual/static installs | Compatibility | CONFIRMED | Twilio docs (both Voice and Video) explicitly state this requirement | |
| 19 | UIBackgroundModes must include voip | Architectural | CONFIRMED | Twilio Voice quickstart README, Info.plist docs | |
| 20 | NSMicrophoneUsageDescription mandatory | Architectural | CONFIRMED | Both SDK docs require this Info.plist key | |
| 21 | NSCameraUsageDescription mandatory for Video | Architectural | CONFIRMED | Video SDK docs specify this with AVCaptureDevice.requestAccess | |
| 22 | NSLocalNetworkUsageDescription needed for P2P on iOS 14+ | Compatibility | QUALIFIED | Video SDK docs. Only for peer-to-peer with TVILocalNetworkPrivacyPolicyAllowAll | **Caveat**: New accounts may only support group rooms, making this moot |
| 23 | audioDevice.isEnabled must be set in didActivate callback | Behavioral | QUALIFIED | Twilio quickstart code pattern. Not live-tested | **Caveat**: Doc-sourced from quickstart repo |
| 24 | TVOCallInvite must be retained until call completes | Behavioral | QUALIFIED | Voice SDK 6.13.5 changelog: "Corrected crash when SDK received Call Invite cancellation while TVOCallInvite object was released" | **Caveat**: Bug fix confirmed in changelog; retain as best practice |
| 25 | AVAudioSessionCategoryOptionAllowBluetooth deprecated | Behavioral | CONFIRMED | Voice SDK 6.13.3 changelog: "Deprecated...in favor of AVAudioSessionCategoryOptionAllowBluetoothHFP" | |
| 26 | Token refresh at 75% TTL recommended | Architectural | QUALIFIED | Common industry pattern, referenced in voice-sdks skill gotcha #5 | **Caveat**: 75% is a guideline, not SDK-enforced |
| 27 | Simulator has no camera (TVICameraSource returns nil) | Compatibility | QUALIFIED | Video quickstart README: "Local video will not be shared since the Simulator cannot access a camera" | **Caveat**: Doc-sourced |
| 28 | TVOCallMessageBuilder.contentType has no effect | Behavioral | CONFIRMED | Voice SDK 6.11.3 changelog: "known issue: TVOCallMessageBuilder.contentType has no effect" | |
| 29 | Reconnection fires isReconnectingWithError then callDidReconnect | Behavioral | CONFIRMED | TVOCallDelegate API reference documents both methods with error codes | |
| 30 | ICE gathering issue on iOS 18 fixed in 6.12.0 / 5.8.3 | Behavioral | CONFIRMED | Both SDK changelogs explicitly reference iOS 18 ICE fix | |
| 31 | Only group room type on new accounts | Scope | QUALIFIED | Video skill documents error 53126 for legacy types | **Caveat**: "after specific date" is vague — depends on account creation date |
| 32 | Virtual backgrounds require iOS 17+ | Compatibility | CONFIRMED | Video SDK 5.11.0 changelog states iOS 17+ requirement | |
| 33 | H.264 max 3 simultaneous hardware encoders | Compatibility | QUALIFIED | Video SDK known issues list | **Caveat**: Hardware-dependent; specific to Apple silicon encoder limits |
| 34 | Screen share requires Broadcast Upload Extension | Architectural | QUALIFIED | Video quickstart includes ReplayKit example. iOS platform restriction, not Twilio-specific | **Caveat**: iOS platform constraint, not directly Twilio-verified |
| 35 | TVITrackPriority APIs deprecated in 5.10.x | Behavioral | CONFIRMED | Video SDK 5.10.1 changelog: "TVITrackPriority enum and all related priority-based APIs deprecated" | |
| 36 | Carthage not supported for Video SDK | Compatibility | CONFIRMED | Video SDK docs: "Carthage doesn't currently work with .xcframeworks" | |
| 37 | Voice SDK manages audio session automatically for voice calls | Behavioral | QUALIFIED | Voice SDK docs. SDK sets category/mode internally | **Caveat**: When using CallKit, CallKit manages activation; SDK manages configuration |
| 38 | Quality warnings: HighRtt > 400ms, HighJitter > 30ms, HighPacketsLostFraction > 3%, LowMos < 3.5 | Default | CONFIRMED | TVOCallDelegate API reference documents exact thresholds and sample counts | |
| 39 | ConversationRelay connects PSTN to WebSocket, not SDK clients | Scope | CONFIRMED | ConversationRelay skill CANNOT list and architecture docs | |

## Corrections Applied

None — all assertions confirmed or qualified with appropriate caveats.

## Qualifications Applied

| # | Original Text | Qualified Text | Condition |
|---|--------------|----------------|-----------|
| 6 | SDKs connect via Programmable Voice only | Added note that SIP Interface is a separate pathway | SIP domains can register endpoints but that's not the iOS Voice SDK |
| 15-16 | iOS 13+ CallKit requirement stated as fact | Marked as doc-sourced from Apple/Twilio docs | Cannot live-test without iOS device |
| 17 | Sandbox/production must be separate | Noted as strong recommendation, not hard enforcement | Mixing can work but causes delivery issues |
| 22 | NSLocalNetworkUsageDescription for P2P iOS 14+ | Added note that new accounts may not support P2P rooms | Group-only accounts don't need this |
| 23-24 | Audio activation timing, CallInvite retention | Marked as doc-sourced patterns | From quickstart code, not live-tested |
| 26 | 75% TTL refresh | Noted as guideline, not SDK-enforced | Industry standard, not Twilio-specific |
| 27 | Simulator has no camera | Marked as doc-sourced | From quickstart README |
| 31 | Only group rooms on new accounts | Acknowledged vagueness of "after specific date" | Account-creation-date dependent |
| 33 | H.264 encoder limit of 3 | Noted as hardware-dependent | Apple silicon specific |
| 34 | Screen share requires Broadcast Extension | Noted as iOS platform constraint | Not Twilio-specific behavior |
| 37 | SDK manages audio session | Clarified CallKit interaction | CallKit manages activation when present |
