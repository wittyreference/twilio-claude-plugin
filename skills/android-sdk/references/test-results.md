---
name: "references"
description: "Twilio development skill: references"
---

# ABOUTME: Test results and evidence for Android SDK skill assertions.
# ABOUTME: Combines Twilio docs research, quickstart repo analysis, and android-sdk-lab code patterns.

# Android SDK Skill — Test Results

Evidence date: 2026-03-29. Sources: Twilio documentation, `twilio/voice-quickstart-android` repo, `infrastructure/android-sdk-lab/` codebase.

---

## T1: SDK Version & Dependency Coordinates

| Test | Result | Evidence |
|------|--------|----------|
| Voice SDK artifact | `com.twilio:voice-android:6.10.+` | Twilio docs + quickstart `build.gradle` |
| Video SDK artifact | `com.twilio:video-android:7.10.+` | Twilio docs |
| AudioSwitch artifact | `com.twilio:audioswitch:1.2.5` | Twilio docs + quickstart `build.gradle` |
| Voice min SDK | API 25 (standard), API 26 (ConnectionService) | Twilio docs `/voice/sdks/android` |
| Video min SDK | API 25 | Twilio docs `/video/android-getting-started` |
| Supported ABIs | armeabi-v7a, arm64-v8a, x86, x86_64 | Twilio docs |
| Java 8 required | Yes, sourceCompatibility/targetCompatibility | Twilio docs + quickstart |

## T2: WebRTC Namespace Separation

| Test | Result | Evidence |
|------|--------|----------|
| Voice WebRTC package | `tvo.webrtc.*` (since v3.2.0) | Twilio docs ProGuard section |
| Video WebRTC package | `tvi.webrtc.*` | Twilio docs ProGuard section |
| Pre-3.2.0 Voice package | `org.webrtc.*` (conflicts with third-party) | Twilio docs migration note |
| Both SDKs coexist | Yes, different namespaces prevent collision | Confirmed by android-sdk-lab `build.gradle.kts` importing both |

## T3: FCM Push Registration

| Test | Result | Evidence |
|------|--------|----------|
| Registration API | `Voice.register(token, FCM, fcmToken, listener)` | Twilio docs quickstart |
| Max registrations per identity | 10 | Twilio docs push section |
| Push TTL | 1 year from last activity | Twilio docs push section |
| FCMv1 required | Yes, legacy removed June 2024 | Twilio docs migration notice |
| google-services.json required | Yes, build fails without it | Twilio docs + quickstart |
| Google APIs emulator image required | Yes, AOSP images lack Play Services | android-sdk-lab CLAUDE.md |

## T4: ConnectionService Architecture

| Test | Result | Evidence |
|------|--------|----------|
| PhoneAccount type | SELF_MANAGED | quickstart `VoiceConnectionService.java` line 153 |
| setCapabilities overwrites | Yes, second call replaces first | quickstart source code analysis |
| Voice.connect before placeCall | Yes, Twilio call starts first | quickstart `VoiceObserver` flow analysis |
| Connection mirrors call state | Yes, setRinging/setActive/setDisconnected parallel Twilio state | quickstart `VoiceConnectionService.java` |
| Required permission | `MANAGE_OWN_CALLS` | quickstart `AndroidManifest.xml` |
| Min SDK for ConnectionService | API 26 | Twilio docs + quickstart `productFlavors` |

## T5: Audio Routing

| Test | Result | Evidence |
|------|--------|----------|
| AudioSwitch priority | Bluetooth > Wired > Earpiece > Speaker | Twilio docs AudioSwitch section |
| AudioSwitch.stop() calls deactivate() | Yes | Twilio docs |
| ConnectionService uses setAudioRoute() | Yes, `CallAudioState.ROUTE_*` constants | quickstart `VoiceConnectionService.java` |
| BLUETOOTH_CONNECT runtime required API 31+ | Yes | Twilio docs AudioSwitch section |

## T6: Threading Requirements

| Test | Result | Evidence |
|------|--------|----------|
| Main Looper thread required | Yes, all Voice SDK API calls | Twilio docs "important" callout |
| Quickstart enforces assertion | `assert(Looper.myLooper() == Looper.getMainLooper())` | quickstart `VoiceApplication.java` |

## T7: Emulator Networking

| Test | Result | Evidence |
|------|--------|----------|
| Host localhost mapping | `10.0.2.2` | android-sdk-lab `TokenService.kt` |
| Network delay via adb | `adb emu network delay <ms>` | android-sdk-lab `network-conditioner.sh` |
| Packet loss via iptables | `iptables -A OUTPUT -m statistic --mode random --probability <p> -j DROP` | android-sdk-lab `network-conditioner.sh` |
| Speed throttling | `adb emu network speed edge` | android-sdk-lab `network-conditioner.sh` |

## T8: Stale Notification Behavior

| Test | Result | Evidence |
|------|--------|----------|
| Device off caches push | Yes, FCM delivers after boot | Twilio docs "stale notification" callout |
| Recommended mitigation | Server timestamp in TwiML `<Parameter>`, discard if > 60s | Twilio docs |

## T9: Call Quality Stats

| Test | Result | Evidence |
|------|--------|----------|
| Stats API | `call.getStats { reports -> }` | Twilio docs + android-sdk-lab VoiceManager.kt |
| StatsReport contents | `remoteAudioTrackStats` with jitter, mos, packetsLost, codec, audioLevel | android-sdk-lab VoiceManager.kt |
| Sample rate | ~1 sample/second via Timer | android-sdk-lab VoiceManager.kt implementation |

## T10: Access Token vs Capability Token

| Test | Result | Evidence |
|------|--------|----------|
| Access Token required | Yes, JWT format | Twilio docs authentication section |
| Capability Token rejected | Yes, causes auth errors | Twilio docs "important" callout |
| Max token expiry | 86399 seconds | Twilio docs |
| Identity must be non-empty | Yes | Twilio docs |

## Surprising Discoveries

1. **setCapabilities() overwrites bug in official quickstart**: The Twilio quickstart calls `setCapabilities()` twice on both PhoneAccount and Connection, with only the last value taking effect. This is a real bug in the reference implementation.

2. **Voice.connect() precedes TelecomManager.placeCall()**: Counterintuitively, the actual Twilio call is established before the Android Telecom framework is notified. ConnectionService is a parallel observer, not the call path.

3. **ConnectionService docs return 404**: The dedicated `/docs/voice/sdks/android/connection-service` page no longer exists. Implementation details live only in the quickstart GitHub repo.

4. **Preflight test available since 6.7.0**: The `Voice.runPreflight()` API exists but is not prominently documented. Returns jitter, packet loss, and RTT via JSONObject report.
