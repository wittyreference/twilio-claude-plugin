---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Version compatibility matrix for Twilio Voice and Video iOS SDKs. -->
<!-- ABOUTME: Covers SDK versions, minimum iOS/Xcode requirements, framework formats, and recent changelog highlights. -->

# SDK Versions & Compatibility

## Current Versions (as of 2026-03-29)

| SDK | Version | Min iOS | Xcode | WebRTC Base | Framework |
|-----|---------|---------|-------|-------------|-----------|
| Voice | 6.13.6 | 12.0 | 14.0+ | Chromium 124 | XCFramework |
| Video | 5.11.2 | 12.2 (runtime) | 16.4+ | Chromium 124 | XCFramework |

## Voice SDK 6.x Changelog Highlights

| Version | Key Change |
|---------|-----------|
| 6.13.6 | Fix: AVAudioSession property access in route-change handler (main thread unresponsiveness) |
| 6.13.5 | Fix: Crash when CallInvite cancelled while TVOCallInvite deallocated |
| 6.13.4 | Fix: Preflight delegate method typo (`didCompleteWitReport` → `didCompleteWithReport`) |
| 6.13.3 | Deprecation: `AVAudioSessionCategoryOptionAllowBluetooth` → use `.allowBluetoothHFP` |
| 6.13.2 | Static XCFramework added. Min iOS raised to 12.0 |
| 6.13.0 | Internal audio device thread safety improvement |
| 6.12.0 | Preflight test APIs added (`TVOPreflightTest`, `TVOPreflightReport`). iOS 18 ICE fix |
| 6.11.3 | SNI support in TLS. Known issue: `contentType` on CallMessage has no effect |

## Video SDK 5.x Changelog Highlights

| Version | Key Change |
|---------|-----------|
| 5.11.2 | Fix: Metal renderer symbol conflict with third-party WebRTC builds |
| 5.11.1 | Fix: CFBundleExecutable key causing App Store submission failure |
| 5.11.0 | Virtual background support (iOS 17+, private beta). Xcode 16.4 required |
| 5.10.1 | `TVITrackPriority` APIs deprecated |
| 5.10.0 | Min iOS raised to 12.2. Static XCFramework. Real-time transcription (beta) |
| 5.9.0 | Krisp 7.0.1 noise cancellation. Audio device thread safety fix |
| 5.8.4 | Fix: TVIVideoView double init assertion on iOS 18 |
| 5.8.3 | Fix: ICE gathering / network handover on iOS 18 |

## Known Persistent Issues (Video SDK)

| Issue | Impact | Workaround |
|-------|--------|-----------|
| Mac Mini simulator audio playback | Audio fails on Mac Mini sims | Use physical device |
| Track republishing visibility | Republished tracks may not appear | Disconnect and reconnect |
| H.264 corruption after network handoff | Rare visual artifacts | VP8 fallback or reconnect |
| H.264 encoder limit (3 devices) | Max 3 simultaneous HW encoders | VP8 software fallback |
| H.264 resolution cap | 1280x720 @ 30fps max | Sufficient for most use cases |

## Info.plist Requirements

| Key | Required For | Value |
|-----|-------------|-------|
| `NSMicrophoneUsageDescription` | Voice SDK, Video SDK | String explaining mic usage |
| `NSCameraUsageDescription` | Video SDK | String explaining camera usage |
| `UIBackgroundModes` | Voice SDK (VoIP push) | Array containing `voip` |
| `UIBackgroundModes` | Video SDK (background audio) | Array containing `audio` |
| `NSLocalNetworkUsageDescription` | Video SDK (P2P, iOS 14+) | String explaining local network usage |

## API Key Classes (Voice SDK 6.x)

| Class | Purpose |
|-------|---------|
| `TwilioVoiceSDK` | Entry point: connect, register, handle notifications, preflight |
| `TVOCall` | Active call: mute, hold, disconnect, send digits, send message, stats |
| `TVOCallInvite` | Incoming invite: accept, reject, custom parameters, caller info |
| `TVOCancelledCallInvite` | Cancelled invite (terminal state) |
| `TVOConnectOptions` / Builder | Outgoing call configuration |
| `TVOAcceptOptions` / Builder | Incoming call accept configuration |
| `TVOAudioDevice` / `TVODefaultAudioDevice` | Audio I/O management |
| `TVOPreflightTest` / Report / Options | Network connectivity testing |
| `TVOCallMessage` / Builder | In-call user-defined messages |
| `TVOCallerInfo` | SHAKEN/STIR attestation on incoming calls |

## API Key Classes (Video SDK 5.x)

| Class | Purpose |
|-------|---------|
| `TwilioVideoSDK` | Entry point: connect to rooms |
| `Room` | Connected room: participants, local participant, state |
| `LocalParticipant` | Publish/unpublish tracks |
| `RemoteParticipant` | Subscribe to remote tracks |
| `TVICameraSource` | Camera capture (nil on simulator) |
| `TVILocalAudioTrack` / `TVILocalVideoTrack` | Local media tracks |
| `TVIRemoteAudioTrack` / `TVIRemoteVideoTrack` | Remote media tracks |
| `LocalDataTrack` | Real-time data exchange (not recorded) |
| `TVIVideoView` | UIView subclass for rendering video |
| `TVIReplayKitVideoSource` | Screen share via Broadcast Extension |
| `ConnectOptions` / Builder | Room connection configuration |

## Delegate Protocols (Voice SDK)

| Protocol | Methods |
|----------|---------|
| `TVOCallDelegate` | `callDidConnect`, `call:didFailToConnectWithError:`, `call:didDisconnectWithError:`, `callDidStartRinging:`, `call:isReconnectingWithError:`, `callDidReconnect:`, `call:didReceiveQualityWarnings:previousWarnings:` |
| `TVONotificationDelegate` | `callInviteReceived:`, `cancelledCallInviteReceived:error:` |
| `TVOCallMessageDelegate` | Message send/receive callbacks |
| `TVOPreflightDelegate` | `preflightTest:didConnect:`, `preflightTest:didFail:`, `preflightTest:didCompleteWithReport:` |

## Delegate Protocols (Video SDK)

| Protocol | Key Methods |
|----------|------------|
| `RoomDelegate` | `roomDidConnect`, `roomDidDisconnect`, `participantDidConnect`, `participantDidDisconnect`, `roomDidStartRecording`, `transcriptionReceived` |
| `LocalParticipantDelegate` | Track publication success/failure |
| `RemoteParticipantDelegate` | Track subscription, track enabled/disabled |
| `TVICameraSourceDelegate` | Camera errors, interruptions |

## Quality Warning Thresholds (Voice SDK)

| Warning | Trigger | Samples |
|---------|---------|---------|
| HighRtt | RTT > 400ms | 3 of 5 |
| HighJitter | Jitter > 30ms | 3 of 5 |
| HighPacketsLostFraction | Loss > 3% | 7-sample average |
| LowMos | MOS < 3.5 | 3 of 5 |
| ConstantAudioInputLevel | No variance when active | Continuous |
| ConstantAudioOutputLevel | No variance when not held | Continuous |
