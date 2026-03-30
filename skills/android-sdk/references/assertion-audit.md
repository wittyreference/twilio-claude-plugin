---
name: "references"
description: "Twilio development skill: references"
---

# ABOUTME: Adversarial assertion audit for Android SDK skill — provenance chain for every factual claim.
# ABOUTME: Every assertion verified against Twilio docs, quickstart repo source, or android-sdk-lab code.

# Assertion Audit Log

**Skill**: android-sdk
**Audit date**: 2026-03-29
**Auditor**: Claude
**Sources**: Twilio docs (twilio.com/docs/voice/sdks/android, /video/android-getting-started), twilio/voice-quickstart-android GitHub repo, infrastructure/android-sdk-lab codebase

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 38 |
| CORRECTED | 1 |
| QUALIFIED | 3 |
| REMOVED | 0 |
| **Total** | **42** |

## Assertions

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 1 | Voice SDK artifact is `com.twilio:voice-android` | behavioral | CONFIRMED | Twilio docs + quickstart build.gradle | — |
| 2 | Video SDK artifact is `com.twilio:video-android` | behavioral | CONFIRMED | Twilio docs | — |
| 3 | AudioSwitch artifact is `com.twilio:audioswitch:1.2.5` | behavioral | CONFIRMED | Twilio docs + quickstart build.gradle | — |
| 4 | Voice min SDK API 25 (standard) | requirement | CONFIRMED | Twilio docs `/voice/sdks/android` | — |
| 5 | Voice min SDK API 26 (ConnectionService) | requirement | CONFIRMED | quickstart `productFlavors` block | — |
| 6 | Video min SDK API 25 | requirement | CONFIRMED | Twilio docs `/video/android-getting-started` | — |
| 7 | Java 8 sourceCompatibility required | requirement | CONFIRMED | Twilio docs setup section | — |
| 8 | Voice WebRTC namespace is `tvo.webrtc.*` | architectural | CONFIRMED | Twilio docs ProGuard section | — |
| 9 | Video WebRTC namespace is `tvi.webrtc.*` | architectural | CONFIRMED | Twilio docs ProGuard section | — |
| 10 | Pre-3.2.0 Voice used `org.webrtc.*` | compatibility | CONFIRMED | Twilio docs ProGuard migration note | — |
| 11 | Both SDKs can coexist due to namespace separation | interaction | CONFIRMED | android-sdk-lab build.gradle.kts imports both | — |
| 12 | FCM registration API: `Voice.register(token, FCM, fcmToken, listener)` | behavioral | CONFIRMED | Twilio docs quickstart | — |
| 13 | Max 10 push registrations per identity | scope | CONFIRMED | Twilio docs push notification section | — |
| 14 | Push TTL is 1 year | default | CONFIRMED | Twilio docs push notification section | — |
| 15 | Legacy FCM removed June 2024, FCMv1 required | requirement | CONFIRMED | Twilio docs migration notice | — |
| 16 | google-services.json missing causes build failure | error | CONFIRMED | Twilio docs + Firebase Gradle plugin behavior | — |
| 17 | Google APIs emulator image required for FCM | requirement | CONFIRMED | android-sdk-lab CLAUDE.md | Standard AOSP images lack Play Services |
| 18 | PhoneAccount uses SELF_MANAGED capability | architectural | CONFIRMED | quickstart VoiceConnectionService.java L153 | — |
| 19 | setCapabilities() overwrites previous value | behavioral | CONFIRMED | quickstart source code — two sequential calls, second wins | Bug in official quickstart |
| 20 | Voice.connect() fires before TelecomManager.placeCall() | architectural | CONFIRMED | quickstart VoiceObserver.connectCall() flow | — |
| 21 | ConnectionService mirrors Twilio call state | architectural | CONFIRMED | quickstart setRinging/setActive/setDisconnected pattern | — |
| 22 | MANAGE_OWN_CALLS permission required for ConnectionService | requirement | CONFIRMED | quickstart AndroidManifest.xml | — |
| 23 | AudioSwitch priority: Bluetooth > Wired > Earpiece > Speaker | default | CONFIRMED | Twilio docs AudioSwitch section | — |
| 24 | AudioSwitch.stop() calls deactivate() | behavioral | CONFIRMED | Twilio docs | — |
| 25 | ConnectionService uses Connection.setAudioRoute() | behavioral | CONFIRMED | quickstart VoiceConnectionService.selectAudioDevice() | — |
| 26 | BLUETOOTH_CONNECT runtime permission required API 31+ | requirement | CONFIRMED | Twilio docs AudioSwitch section | — |
| 27 | All Voice SDK calls must be on main Looper thread | requirement | CONFIRMED | Twilio docs + quickstart assertion | — |
| 28 | CallInvite must be kept alive until signaling completes | requirement | CONFIRMED | Twilio docs lifecycle section | — |
| 29 | Emulator uses 10.0.2.2 for host localhost | behavioral | CONFIRMED | android-sdk-lab TokenService.kt | Standard Android emulator behavior |
| 30 | adb emu network delay/speed for network simulation | behavioral | CONFIRMED | android-sdk-lab network-conditioner.sh | — |
| 31 | iptables for packet loss on emulator | behavioral | CONFIRMED | android-sdk-lab network-conditioner.sh | — |
| 32 | Stale push: device off caches notifications | behavioral | CONFIRMED | Twilio docs callout | — |
| 33 | call.getStats returns StatsReport with jitter, MOS, etc. | behavioral | QUALIFIED | android-sdk-lab VoiceManager.kt | See Q1 below |
| 34 | Access Token required, not Capability Token | requirement | CONFIRMED | Twilio docs authentication section | — |
| 35 | Max token expiry 86399 seconds | scope | CONFIRMED | Twilio docs | — |
| 36 | Identity must be non-empty | requirement | CONFIRMED | Twilio docs | — |
| 37 | SELF_MANAGED PhoneAccount not in system call log | scope | CONFIRMED | Android Telecom docs + quickstart SELF_MANAGED usage | — |
| 38 | Recording is server-side only, no local recording | scope | CONFIRMED | Twilio docs — no local recording API | — |
| 39 | POST_NOTIFICATIONS required API 33+ | requirement | QUALIFIED | Android platform docs | See Q2 below |
| 40 | Preflight test available since Voice 6.7.0 | compatibility | QUALIFIED | Twilio docs reference to runPreflight | See Q3 below |
| 41 | VPN breaks GLL routing | behavioral | CONFIRMED | Twilio docs edge location section | — |
| 42 | SDK supports armeabi-v7a, arm64-v8a, x86, x86_64 | compatibility | CONFIRMED | Twilio docs | — |

## Corrections Applied

1. **#19 — setCapabilities behavior**
   - **Original text**: Skill initially described using OR to combine capabilities
   - **Corrected text**: Added gotcha #4 explicitly warning that `setCapabilities()` overwrites rather than ORs, and that the official quickstart has this bug
   - **Why**: Source code analysis of quickstart confirmed the overwite behavior

## Qualifications Applied

**Q1 — Assertion #33: call.getStats returns StatsReport**
- **Original text**: "call.getStats returns StatsReport with jitter, MOS, packetsLost, codec, audioLevel"
- **Qualified text**: Fields available depend on the `StatsReport` implementation; `remoteAudioTrackStats` contains jitter, MOS, and packetsLost. Exact field availability may vary by SDK version and call state.
- **Condition**: Stats are only available when call state is CONNECTED. Pre-connect or post-disconnect calls to getStats return empty reports.

**Q2 — Assertion #39: POST_NOTIFICATIONS required API 33+**
- **Original text**: "Without this permission, incoming call notifications are silently dropped on Android 13+"
- **Qualified text**: Added "silently dropped" qualifier. The app can still function for outgoing calls; only incoming call notifications are affected.
- **Condition**: Only affects incoming calls in background. Foreground calls handled via in-app UI are not affected.

**Q3 — Assertion #40: Preflight test available since 6.7.0**
- **Original text**: "Run preflight connectivity tests (Voice SDK 6.7.0+)"
- **Qualified text**: The `Voice.runPreflight()` API is documented but not prominently featured. The exact version introduction (6.7.0) comes from Twilio docs but the feature may have been available earlier in preview.
- **Condition**: Version number sourced from Twilio docs, not independently verified via changelog.
