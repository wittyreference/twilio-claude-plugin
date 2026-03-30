---
name: "android-sdk"
description: "Twilio development skill: android-sdk"
---

---
name: android-sdk
description: Twilio Voice and Video Android SDK development guide. Use when building native Android calling apps, configuring FCM push notifications, integrating ConnectionService, managing Android audio devices, setting up Gradle dependencies, handling runtime permissions, or testing on Android Emulator.
---

# Android SDK Development Skill

Android-specific guide for building native Voice and Video applications with Twilio's Android SDKs. Load this skill when working on Android-native Twilio integrations — Gradle setup, FCM push, ConnectionService, permissions, audio routing, emulator testing, and platform gotchas.

This skill covers the **Android implementation layer** only. For general Voice SDK concepts (AccessToken generation, TwiML App setup, edge locations, call lifecycle), see `/skills/voice-sdks.md`. For Video room types, recording, and compositions, see `/skills/video/SKILL.md`.

Evidence date: 2026-03-29. SDK versions: Voice 6.10.x, Video 7.10.x, AudioSwitch 1.2.5.

---

## Scope

### CAN

- Build native Android calling apps with Voice SDK (Kotlin/Java)
- Build native Android video apps with Video SDK
- Receive incoming calls via FCM push notifications (background + foreground)
- Integrate with Android Telecom framework via ConnectionService
- Route audio between earpiece, speaker, Bluetooth, and wired headset
- Run preflight connectivity tests (Voice SDK 6.7.0+)
- Send/receive custom parameters on calls via `ConnectOptions.params()` and `CallInvite.getCustomParameters()`
- Capture real-time call quality stats via `Call.getStats()`
- Test on Android Emulator with virtual microphone and network simulation
- Coexist Voice + Video SDKs in the same app (separate WebRTC namespaces)

### CANNOT

- **Record audio locally on device** — all recording is server-side via TwiML or REST API
- **Use Capability Tokens** — Android SDK requires Access Tokens (JWT); Capability Tokens cause auth errors
- **Receive incoming calls without FCM** — push notifications are the only delivery mechanism when the app is backgrounded; foreground-only signaling is not reliable for production
- **Run on API < 25** — Voice and Video SDKs require Android 7.1+ (Nougat MR1); ConnectionService flavor requires API 26+
- **Use Elastic SIP Trunking** — SDKs connect via Programmable Voice only
- **Mix WebRTC libraries freely on pre-6.x Voice SDK** — Voice SDK < 3.2.0 used `org.webrtc.*` namespace, conflicting with third-party WebRTC. 3.2.0+ remapped to `tvo.webrtc.*`
- **Access system call log with SELF_MANAGED PhoneAccount** — self-managed ConnectionService does not appear in the system dialer or call history

---

## Quick Decision

| Need | Approach | Why |
|------|----------|-----|
| Simple calling app, no system integration | Standard flavor + AudioSwitch | Simpler setup, AudioSwitch handles device routing automatically |
| System dialer integration, car kit, wearables | ConnectionService flavor | Registers with Android Telecom framework |
| Video rooms in Android app | Video SDK standalone | Independent from Voice SDK, different dependency |
| Voice + Video in same app | Both SDKs, separate deps | Different WebRTC namespaces (`tvo.*` vs `tvi.*`), no conflicts |
| Audio routing (speaker/bluetooth/earpiece) | AudioSwitch library OR ConnectionService | AudioSwitch: automatic discovery. ConnectionService: `setAudioRoute()` |
| Background incoming calls | FCM push + push credential | Only reliable mechanism for backgrounded apps |
| Call quality monitoring | `Call.getStats()` callback | Returns `StatsReport` with jitter, MOS, packet loss per second |

---

## Decision Frameworks

### Standard vs ConnectionService Flavor

| Factor | Standard (AudioSwitch) | ConnectionService |
|--------|----------------------|-------------------|
| Min SDK | API 25 | API 26 |
| Audio routing | `audioSwitch.selectDevice()` | `connection.setAudioRoute()` |
| Device discovery | Automatic callback | Manual BroadcastReceivers |
| System integration | None | Android Telecom (car kit, wearables, Wear OS) |
| Call log visibility | Not in system call log | Not in call log (SELF_MANAGED) |
| Complexity | Lower | Higher — Connection lifecycle, PhoneAccount registration |
| Dependency | `com.twilio:audioswitch:1.2.5` | Android platform APIs only |

**Choose Standard** when: building a standalone VoIP app, prototyping, or targeting broad device support.

**Choose ConnectionService** when: integrating with car Bluetooth systems, Android Auto, Wear OS, or other Telecom-aware accessories.

### FCMv1 vs Legacy FCM

There is no choice — **use FCMv1**. Legacy FCM server keys were deprecated June 2023 and removed June 2024. The Voice Android SDK already supports FCMv1 credentials. Create credentials via Firebase Console → Project Settings → Service Accounts → "Generate New Private Key" → upload JSON to Twilio Push Credentials dashboard.

---

## Setup

### Gradle Dependencies

```kotlin
// app/build.gradle.kts
dependencies {
    // Voice SDK
    implementation("com.twilio:voice-android:6.10.+")

    // Video SDK (if needed)
    implementation("com.twilio:video-android:7.10.+")

    // Audio routing (standard flavor — omit for ConnectionService)
    implementation("com.twilio:audioswitch:1.2.5")

    // Firebase for push notifications
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-messaging-ktx")
}
```

Java 8 compatibility required:
```kotlin
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = "1.8"
    }
}
```

### Android Manifest Permissions

```xml
<!-- Both flavors -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Video SDK only -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- ConnectionService flavor only -->
<uses-permission android:name="android.permission.MANAGE_OWN_CALLS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" /> <!-- API 31+ -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" /> <!-- API 33+ -->
```

Runtime permission requests are required for `RECORD_AUDIO`, `CAMERA`, `BLUETOOTH_CONNECT` (API 31+), and `POST_NOTIFICATIONS` (API 33+).

### ProGuard / R8 Rules

```proguard
# Voice SDK (v3.2.0+)
-keep class com.twilio.voice.** { *; }
-keep class tvo.webrtc.** { *; }
-dontwarn tvo.webrtc.**
-keepattributes InnerClasses

# Video SDK
-keep class com.twilio.video.** { *; }
-keep class tvi.webrtc.** { *; }
-keepattributes InnerClasses
```

The WebRTC namespace differs: `tvo.webrtc` for Voice, `tvi.webrtc` for Video. This separation (introduced Voice v3.2.0) allows both SDKs and third-party WebRTC libraries to coexist.

---

## FCM Push Notification Integration

### Server-Side Token Generation

The token endpoint must include `pushCredentialSid` when generating Access Tokens for Android clients:

```javascript
// Token server (Node.js)
const voiceGrant = new VoiceGrant({
  outgoingApplicationSid: twimlAppSid,
  pushCredentialSid: process.env.TWILIO_ANDROID_PUSH_CREDENTIAL_SID,
});
```

See `__tests__/e2e/voice-sdk/server.js` for the shared token server implementation.

### Android-Side Registration

```kotlin
// After obtaining access token and FCM token
Voice.register(accessToken, Voice.RegistrationChannel.FCM, fcmToken,
    object : RegistrationListener {
        override fun onRegistered(accessToken: String, fcmToken: String) {
            Log.d(TAG, "Registered for push")
        }
        override fun onError(error: RegistrationException, accessToken: String, fcmToken: String) {
            Log.e(TAG, "Registration error: ${error.message}")
        }
    })
```

### Handling Incoming Push

```kotlin
class FcmService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        // Re-register with Twilio immediately
    }

    override fun onMessageReceived(message: RemoteMessage) {
        Voice.handleMessage(applicationContext, message.data,
            object : MessageListener {
                override fun onCallInvite(callInvite: CallInvite) {
                    // Show notification, start ringing
                }
                override fun onCancelledCallInvite(
                    cancelledCallInvite: CancelledCallInvite,
                    callException: CallException?
                ) {
                    // Dismiss notification
                }
            })
    }
}
```

### Push Registration Limits

- TTL: 1 year from last activity
- Max 10 active registrations per identity — Twilio notifies only the 10 most recent devices
- Unregister when switching user identities to avoid delivering pushes to the wrong user

---

## ConnectionService Integration

### PhoneAccount Registration

```kotlin
val phoneAccountHandle = PhoneAccountHandle(
    ComponentName(context, VoiceConnectionService::class.java),
    appName
)
val phoneAccount = PhoneAccount.Builder(phoneAccountHandle, appName)
    .setCapabilities(
        PhoneAccount.CAPABILITY_SELF_MANAGED  // VoIP apps manage own UI
    )
    .build()
telecomManager.registerPhoneAccount(phoneAccount)
```

### Manifest Registration

```xml
<service android:name=".VoiceConnectionService"
    android:label="@string/connection_service_name"
    android:permission="android.permission.BIND_TELECOM_CONNECTION_SERVICE"
    android:exported="false">
    <intent-filter>
        <action android:name="android.telecom.ConnectionService" />
    </intent-filter>
</service>
```

### Call Flow Architecture

The Twilio Voice SDK call and the Android Telecom notification are **parallel paths**, not sequential:

```
Outgoing call:
  1. Voice.connect(context, options, listener)  ← actual Twilio call
  2. telecomManager.placeCall(uri, extras)       ← Telecom framework notification
  3. onCreateOutgoingConnection() callback       ← Connection object created

Incoming call:
  1. FCM → Voice.handleMessage() → CallInvite
  2. telecomManager.addNewIncomingCall(handle, extras)
  3. onCreateIncomingConnection() callback → connection.setRinging()
  4. User answers → callInvite.accept(context, listener)
  5. connection.setActive()
```

The Connection object mirrors the Twilio call state but does not control it.

### Audio Routing via ConnectionService

```kotlin
// In ConnectionService, use Connection.setAudioRoute()
connection.setAudioRoute(CallAudioState.ROUTE_SPEAKER)
connection.setAudioRoute(CallAudioState.ROUTE_EARPIECE)
connection.setAudioRoute(CallAudioState.ROUTE_BLUETOOTH)
connection.setAudioRoute(CallAudioState.ROUTE_WIRED_HEADSET)
```

This replaces AudioSwitch — do not use both simultaneously.

---

## Audio Device Management (Standard Flavor)

```kotlin
val audioSwitch = AudioSwitch(applicationContext)

audioSwitch.start { audioDevices, selectedDevice ->
    // audioDevices: List<AudioDevice> — available devices
    // selectedDevice: AudioDevice? — currently selected
    // AudioDevice types: BluetoothHeadset, WiredHeadset, Earpiece, Speakerphone
}

// Select a device
audioSwitch.selectDevice(speakerphone)

// Activate when call connects (acquires USAGE_VOICE_COMMUNICATION focus)
audioSwitch.activate()

// Deactivate when call ends (releases audio focus)
audioSwitch.deactivate()

// Cleanup in onDestroy — also calls deactivate()
audioSwitch.stop()
```

Priority order (automatic): Bluetooth > Wired Headset > Earpiece > Speakerphone.

---

## Video SDK on Android

### Room Connection

```kotlin
val localAudioTrack = LocalAudioTrack.create(context, true, "mic")
val cameraCapturer = Camera2Capturer(context, frontCameraId)
val localVideoTrack = LocalVideoTrack.create(context, true, cameraCapturer)

val options = ConnectOptions.Builder(accessToken)
    .roomName(roomName)
    .audioTracks(listOf(localAudioTrack))
    .videoTracks(listOf(localVideoTrack))
    .enableNetworkQuality(true)
    .networkQualityConfiguration(
        NetworkQualityConfiguration(
            NetworkQualityVerbosity.NETWORK_QUALITY_VERBOSITY_MINIMAL,
            NetworkQualityVerbosity.NETWORK_QUALITY_VERBOSITY_MINIMAL
        )
    )
    .build()

room = Video.connect(context, options, roomListener)
```

### Track Lifecycle

Always release tracks when done:
```kotlin
localVideoTrack?.release()
localAudioTrack?.release()
localDataTrack?.release()
```

Failing to release tracks leaks native resources and can cause the camera to remain active.

---

## Emulator Testing

### Network Configuration

Android Emulator maps `10.0.2.2` to the host machine's `localhost`. Token servers running on `localhost:3333` are reached at `http://10.0.2.2:3333` from the emulator.

### Network Degradation

Use `adb emu network` and iptables for chaos testing:

```bash
# Latency simulation
adb emu network delay 200          # 200ms latency

# Throughput throttling
adb emu network speed edge         # EDGE-speed

# Packet loss via iptables (emulator runs as root)
adb shell "su -c 'iptables -A OUTPUT -m statistic --mode random --probability 0.05 -j DROP'"

# Restore clean network
adb emu network delay 0
adb emu network speed full
adb shell "su -c 'iptables -F OUTPUT'"
```

### FCM on Emulator

FCM push notifications work on emulator images that include Google APIs (e.g., `system-images;android-34;google_apis;arm64-v8a`). Standard AOSP images lack Play Services and cannot receive FCM pushes.

### Evidence Collection

The android-sdk-lab uses a TestBridge HTTP server pattern (port 8765) to export SDK telemetry from the app process to the Espresso test process. Evidence JSON files are written to `/sdcard/insights-evidence/` and pulled via `adb pull` after test completion. See `infrastructure/android-sdk-lab/CLAUDE.md` for the full architecture.

---

## Gotchas

### Threading & Lifecycle

1. **All Voice SDK calls must be on the main Looper thread**: Calling Voice SDK methods from background threads causes crashes or undefined behavior. The quickstart asserts `Looper.myLooper() == Looper.getMainLooper()` in its service connection manager.

2. **CallInvite must be kept alive until signaling completes**: Accepting, rejecting, or canceling a `CallInvite` involves asynchronous signaling. Releasing the object before completion causes crashes. Hold a reference until the call connects or the invite is canceled.

3. **AudioSwitch.stop() calls deactivate() implicitly**: Calling `deactivate()` then `stop()` is safe but redundant. Forgetting `stop()` in `onDestroy()` leaks the audio focus listener.

### Capabilities & Configuration

4. **setCapabilities() and setConnectionCapabilities() overwrite, not OR**: Each call replaces the previous value. To combine capabilities, use bitwise OR in a single call: `setCapabilities(CAPABILITY_SELF_MANAGED or CAPABILITY_CALL_PROVIDER)`. The official quickstart has this bug — only the last-set capability takes effect.

5. **Voice.connect() fires before TelecomManager.placeCall()**: For outgoing calls, the Twilio call is already being established when the ConnectionService is notified. The ConnectionService is a parallel notification to Android Telecom, not the call routing mechanism.

6. **SELF_MANAGED PhoneAccount does not appear in system dialer**: Calls made through a self-managed ConnectionService are invisible in the system call log and dialer. The app must provide its own call history UI.

### Push Notifications

7. **google-services.json missing = build failure**: The Firebase Gradle plugin requires this file in the `app/` directory. Missing it causes a cryptic build error, not a runtime error.

8. **Legacy FCM credentials were removed June 2024**: Only FCMv1 credentials work. Create via Firebase Console → Service Accounts → "Generate New Private Key" (JSON format). Upload to Twilio Push Credentials dashboard.

9. **Stale push notifications after device off**: When a phone is powered off, FCM caches notifications and delivers them after boot — by which time the call has ended. Include a server timestamp in TwiML `<Parameter>`, compare with device time on receipt, and discard if the delta exceeds a threshold (60 seconds is reasonable).

10. **Max 10 push registrations per identity**: Twilio delivers push to the 10 most recently registered devices only. Unregister old devices and re-register on every app launch.

### WebRTC & SDK Compatibility

11. **Voice and Video SDKs use different WebRTC namespaces**: Voice uses `tvo.webrtc.*`, Video uses `tvi.webrtc.*`. This is intentional and allows both SDKs to coexist. ProGuard rules must keep both namespaces.

12. **Voice SDK < 3.2.0 conflicts with third-party WebRTC**: Older Voice SDK versions used `org.webrtc.*`, which collides with other WebRTC libraries. Upgrade to 3.2.0+ to avoid class conflicts.

13. **Access Token, not Capability Token**: Android SDK requires JWT Access Tokens. Passing a Capability Token (legacy format) produces auth errors with no clear error message.

### Network & Connectivity

14. **Corporate VPN/firewalls may block calls**: Restrictive networks can block WebRTC ICE. Provide TURN servers via `ConnectOptions.iceOptions()` using Twilio's Network Traversal Service.

15. **VPN breaks Global Low Latency routing**: GLL relies on latency-based DNS (RFC 7871). VPNs or non-local DNS resolvers cause suboptimal edge selection. Set edge explicitly with `Voice.setEdge("ashburn")` when users are on VPN.

16. **Emulator uses 10.0.2.2 for host localhost**: Direct `localhost` references from emulator code reach the emulator itself, not the host machine. The token server URL must use `http://10.0.2.2:<port>`.

### Permissions

17. **BLUETOOTH_CONNECT requires runtime request on API 31+**: Pre-API 31, Bluetooth permissions are auto-merged from AudioSwitch's manifest. On API 31+, you must request `BLUETOOTH_CONNECT` at runtime or AudioSwitch silently fails to detect Bluetooth devices.

18. **POST_NOTIFICATIONS required on API 33+**: Without this runtime permission, incoming call notifications are silently dropped on Android 13+. Request it during onboarding, not when the first call arrives.

---

## Related Resources

| Resource | Path | When to read |
|----------|------|-------------|
| Voice SDK concepts | `/skills/voice-sdks.md` | AccessToken, TwiML App, edge locations, SDK lifecycle |
| Video concepts | `/skills/video/SKILL.md` | Room types, recording, compositions, DataTrack |
| IAM / Access Tokens | `/skills/iam/SKILL.md` | Token generation, grants, key rotation |
| Voice Insights | `/skills/voice-insights/SKILL.md` | Call quality analysis, MOS thresholds, SIP codes |
| Android SDK Lab | `/infrastructure/android-sdk-lab/CLAUDE.md` | Emulator setup, Espresso tests, evidence collection |
| Token server | `/__tests__/e2e/voice-sdk/server.js` | Shared token endpoint with pushCredentialSid support |
| Mobile Insights validator | `/scripts/validate-mobile-insights.js` | Deferred Insights API correlation for mobile evidence |

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Test results & evidence | `references/test-results.md` | Reviewing SDK behavior evidence from emulator testing |
| Assertion audit | `references/assertion-audit.md` | Verifying provenance of every claim in this skill |
