---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Comprehensive reference for all 85 Voice SDK events in Twilio Voice Insights. -->
<!-- ABOUTME: Covers trigger thresholds, WebRTC state machines, event sequence patterns, and diagnostic correlation. -->

# SDK Events — Complete Reference

All events emitted by Twilio Voice SDKs and surfaced through Voice Insights event streams. This is the diagnostic bible for understanding what happened during a call at the WebRTC layer.

## 1. Event API Overview

### Endpoint

Events are retrieved via the Voice Insights Events API:

```
GET /v2/Voice/{CallSid}/Events
```

Use `list_call_events` MCP tool. Returns events sorted by timestamp ascending.

### Prerequisites

- **Voice Insights Advanced Features** must be enabled on the account. Without it, the API returns 401.
- Events are only generated for calls that use Twilio Voice SDKs (JS, iOS, Android). PSTN-to-PSTN calls via `<Dial>` do not produce SDK events.

### Event Object Schema

Each event contains:

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | ISO 8601 | When the event occurred (client-side clock) |
| `call_sid` | string | The call this event belongs to |
| `edge` | string | Which edge reported: `sdk_edge`, `carrier_edge`, `sip_edge`, `client_edge` |
| `group` | string | Event category (e.g., `ice-connection-state`, `connection`, `network-quality-warning-raised`) |
| `name` | string | Specific event within the group (e.g., `high-rtt`, `connected`, `checking`) |
| `level` | string | Severity: `DEBUG`, `INFO`, `WARNING`, `ERROR` |

**sdk_edge payload** (present when `edge` = `sdk_edge`):

| Field | Description |
|-------|-------------|
| `sdk_edge.client_name` | The identity from the access token |
| `sdk_edge.location` | Twilio region (e.g., `us1`, `ie1`, `au1`) |
| `sdk_edge.sdk.type` | `twilio-voice-js`, `twilio-voice-ios`, `twilio-voice-android` |
| `sdk_edge.sdk.version` | SDK version string |
| `sdk_edge.sdk.platform` | OS/browser (e.g., `Chrome 120 / macOS 14.2`) |
| `sdk_edge.error.code` | Twilio error code (present on `error` events) |

### Availability Timing

Events appear in the API approximately **90 seconds** after they occur on the client. Do not poll immediately after a call ends — wait at least 2 minutes for the full event stream to be available.

### Platform Key

| Symbol | Meaning |
|--------|---------|
| JS | Twilio Voice JavaScript SDK (browsers, Node.js) |
| iOS | Twilio Voice iOS SDK |
| Android | Twilio Voice Android SDK |
| All | Available on all three platforms |

---

## 2. ERROR/WARNING Events (23 Actionable Events)

These are the events that indicate something went wrong. When diagnosing a call, filter for `level` = `WARNING` or `ERROR` first.

### 2a. Network Quality Warnings (8 events)

Group: `network-quality-warning-raised` | Level: WARNING

These use a **sliding window** algorithm. The SDK samples metrics every second. A warning fires when the threshold is exceeded in N of M recent samples.

| Name | Threshold | Window | Platform | Trigger Condition | Recommended Action |
|------|-----------|--------|----------|-------------------|--------------------|
| `high-rtt` | > 400 ms | 3 of 5 | All | Round-trip time exceeds 400ms in 3 of the last 5 one-second samples | Check network path latency. Consider wired connection. Verify edge region is geographically close. |
| `low-mos` | < 3.5 | 3 of 5 | All | Mean Opinion Score drops below 3.5 in 3 of 5 samples. Composite of jitter, loss, and latency. | This is a summary metric. Check which underlying warning also fired (jitter, loss, RTT) to find root cause. |
| `high-jitter` | > 30 ms | 3 of 5 | All | Jitter exceeds 30ms in 3 of 5 samples | Network congestion or WiFi interference. Reduce competing traffic. Switch to wired. |
| `high-packet-loss` | > 1% | 3 of 5 | All | Packet loss exceeds 1% in 3 of 5 samples | Network dropping packets. Check for bandwidth saturation, poor signal strength, or ISP issues. |
| `high-packets-lost-fraction` | > 3% | 7 of 10 | iOS, Android | Packet loss fraction exceeds 3% in 7 of 10 samples. More tolerant window for mobile networks. | Mobile-specific. Check signal strength. Consider that cellular handoffs cause transient loss. |
| `low-bytes-received` | 0 bytes | 3 consecutive seconds | JS | Zero bytes received for 3 straight seconds. Remote audio has stopped arriving. | Far-end may have network failure, or the media path is broken. Check ICE state. Correlate with remote-side events. |
| `low-bytes-sent` | 0 bytes | 3 consecutive seconds | JS | Zero bytes sent for 3 straight seconds. Local audio is not being transmitted. | Check if muted. Check mic permissions. Verify getUserMedia succeeded. |
| `ice-connectivity-lost` | ICE disconnected | Immediate | JS | ICE transport transitions to disconnected state after having been connected. | Transient if followed by reconnection. Fatal if followed by `ice-connection-state: failed`. |

### 2b. Audio Warnings (2 events)

Group: `audio-level-warning-raised` | Level: WARNING

| Name | Threshold | Platform | Trigger Condition | Recommended Action |
|------|-----------|----------|-------------------|--------------------|
| `constant-audio-input-level` | 20 seconds unchanged | JS | Audio input level has not changed for 20 seconds. In JS SDK 1.13.0+: standard deviation < 1% of max over 10s. | Mic may be muted at hardware level, browser permission revoked, or wrong device selected. Check getUserMedia. |
| `constant-audio-output-level` | 20 seconds unchanged | JS | Audio output level has not changed for 20 seconds. | Remote party may not be sending audio, or speaker/output device is misconfigured. |

### 2c. Audio Device Errors (2 events)

Group: `audio-device` | Level: ERROR

| Name | Platform | Trigger Condition | Recommended Action |
|------|----------|-------------------|--------------------|
| `ringtone-devices-set-failed` | JS | Application called `Device.audio.ringtoneDevices.set()` but the browser rejected the device selection. | Verify device ID is valid. Check that the device is still connected. |
| `speaker-devices-set-failed` | JS | Application called `Device.audio.speakerDevices.set()` but the browser rejected it. | Same as above. Device may have been unplugged. |

### 2d. Connection Errors (2 events)

Group: `connection` | Level: varies

| Name | Level | Platform | Trigger Condition | Recommended Action |
|------|-------|----------|-------------------|--------------------|
| `listening-error` | WARNING | iOS, Android | Error during push notification registration or listening for incoming calls. | Check push credential configuration. Verify FCM/APNs setup. |
| `error` | ERROR | All | Call encountered a fatal or significant error. The `sdk_edge.error.code` field contains the Twilio error code. | Look up the error code in the Twilio error dictionary. Common: 31003 (connection error), 31005 (WebSocket error), 31009 (transport error). |

### 2e. ICE/WebRTC Errors (4 events)

These are state transitions that indicate WebRTC connectivity failure.

| Group | Name | Level | Platform | Trigger Condition | Recommended Action |
|-------|------|-------|----------|-------------------|--------------------|
| `pc-connection-state` | `failed` | WARNING | JS | Peer connection aggregate state is failed. Combines ICE + DTLS. | Check ICE state. If ICE also failed, network is blocking all paths. Verify TURN server access. |
| `ice-gathering-state` | `none` | WARNING | All | ICE gathering produced no candidates at all. | Severe: no network interfaces available. Check that the device has network access. |
| `ice-gathering-state` | `timeout` | WARNING | All | ICE gathering timed out before completing. | STUN/TURN servers may be unreachable. Check firewall rules for UDP 3478 and TCP 443 (TURN TLS). |
| `ice-connection-state` | `failed` | ERROR | All | All ICE candidate pairs exhausted. No viable media path exists. | Total ICE failure. Firewall blocking all UDP and TCP relay paths. Only fix: network configuration change or TURN over TCP 443. |

### 2f. Media Access Errors (2 events)

Group: `get-user-media` | Level: ERROR

| Name | Platform | Trigger Condition | Recommended Action |
|------|----------|-------------------|--------------------|
| `failed` | JS | `getUserMedia()` threw an error. Device may be locked by another application. | Check if another tab/app has exclusive mic access. Try closing other audio applications. |
| `denied` | JS | User denied microphone permission, or permission was previously blocked. | Prompt user to allow mic access in browser settings. Cannot proceed without it. |

### 2g. Registration Errors (4 events)

Group: `registration` | Level: ERROR

| Name | Platform | Trigger Condition | Recommended Action |
|------|----------|-------------------|--------------------|
| `unsupported-cancel-message-error` | iOS, Android | Push notification cancel message format not supported by this SDK version. | Update SDK to latest version. |
| `registration-error` | iOS, Android | Failed to register for incoming calls via push notifications. | Check access token grants. Verify push credential SID. Check network connectivity. |
| `unregistration-error` | iOS, Android | Failed to unregister from push notifications. | Usually non-fatal. May cause phantom incoming call notifications. |
| `unregistration-registration-error` | iOS, Android | Unregistration followed by re-registration both failed. | Token may be expired. Network may be down. Regenerate access token and retry. |

---

## 3. INFO/DEBUG Events (62 Normal-Flow Events)

These events represent normal call operation and recovery signals. Use them to reconstruct the timeline of what happened.

### 3a. Network Quality Warning-Cleared (4 INFO events)

Group: `network-quality-warning-cleared` | Level: INFO

| Name | Meaning |
|------|---------|
| `high-rtt` | RTT returned below 400ms threshold |
| `high-jitter` | Jitter returned below 30ms threshold |
| `high-packet-loss` | Packet loss returned below 1% threshold |
| `low-mos` | MOS returned above 3.5 threshold |

**Key insight**: Seeing `warning-raised` followed by `warning-cleared` means the issue was transient and self-resolved. Warnings that are never cleared indicate sustained degradation for the rest of the call.

### 3b. Audio Warning-Cleared (2 INFO events)

Group: `audio-level-warning-cleared` | Level: INFO

| Name | Meaning |
|------|---------|
| `constant-audio-input-level` | Audio input level is varying again (mic active) |
| `constant-audio-output-level` | Audio output level is varying again (remote audio flowing) |

### 3c. Audio Device Info (3 INFO events, JS only)

Group: `audio-device` | Level: INFO

| Name | Meaning |
|------|---------|
| `speaker-devices-set` | Speaker output device successfully changed |
| `ringtone-devices-set` | Ringtone output device successfully changed |
| `device-change` | A media device was added or removed from the system |

### 3d. Connection Lifecycle (21 INFO events)

Group: `connection` | Level: INFO

This is the largest event group. These events track the call from offer to teardown.

| Name | Platform | Meaning |
|------|----------|---------|
| `incoming` | All | Inbound call offer received |
| `outgoing` | All | Outbound call initiated |
| `outgoing-ringing` | JS | Outbound call is ringing (SIP 180) |
| `ringing` | iOS, Android | Call is ringing |
| `accepted-by-local` | All | Local party accepted the call |
| `accepted-by-remote` | All | Remote party accepted the call |
| `connected` | All | Media path established, call is active |
| `disconnected-by-local` | All | Local party hung up |
| `disconnected-by-remote` | All | Remote party hung up |
| `ignored-by-local` | All | Local party ignored the incoming call |
| `rejected-by-local` | All | Local party explicitly rejected the call |
| `cancel` | All | Call cancelled before answer |
| `muted` | All | Local audio muted |
| `unmuted` | All | Local audio unmuted |
| `hold` | All | Call placed on hold |
| `unhold` | All | Call taken off hold |
| `listen` | JS | Listening for incoming calls started |
| `listening` | JS | Device is actively listening |
| `reconnecting` | JS | Connection lost, SDK attempting ICE restart |
| `reconnected` | JS | Connection restored after ICE restart |
| `disconnect-called` | JS | Application called `disconnect()` |

**Key insight**: `reconnecting` followed by `reconnected` means the SDK detected media failure and recovered via ICE restart. The call survived but had a brief audio interruption. If `reconnecting` is NOT followed by `reconnected`, the recovery failed and the call dropped.

### 3e. ICE Connection States (10 DEBUG events)

Group: `ice-connection-state` | Level: DEBUG (except `failed` which is ERROR)

| Name | Meaning |
|------|---------|
| `new` | ICE agent created |
| `checking` | Connectivity checks in progress |
| `connected` | At least one viable candidate pair found |
| `completed` | Best candidate pair selected, all checks done |
| `disconnected` | Current path lost, may recover |
| `failed` | All paths exhausted (this one is ERROR level — see Section 2e) |
| `closed` | ICE agent shut down |
| `gathering` | Candidate gathering in progress |
| `connecting` | Attempting connection (Android/iOS variant) |
| `none` | No ICE state available |

### 3f. Peer Connection States (5 DEBUG events, JS only)

Group: `pc-connection-state` | Level: DEBUG (except `failed` which is WARNING)

| Name | Meaning |
|------|---------|
| `new` | Peer connection created |
| `connecting` | ICE + DTLS negotiation in progress |
| `connected` | Both ICE and DTLS established |
| `disconnected` | Transport disrupted |
| `failed` | Transport permanently failed (this one is WARNING level — see Section 2e) |

### 3g. ICE Gathering States (3 DEBUG events)

Group: `ice-gathering-state` | Level: DEBUG (except `none` and `timeout` which are WARNING)

| Name | Meaning |
|------|---------|
| `gathering` | Gathering ICE candidates from STUN/TURN servers |
| `complete` | All candidates gathered |
| `new` | Gathering not yet started or restarted |

### 3h. ICE Candidates (2 DEBUG events)

Group: `ice-candidate` | Level: DEBUG

| Name | Meaning |
|------|---------|
| `ice-candidate` | An ICE candidate was discovered. Payload includes candidate type (host/srflx/relay). |
| `selected-ice-candidate-pair` | The winning candidate pair that carries media. Check local and remote types. |

### 3i. Signaling States (5 DEBUG/INFO events)

Group: `signaling-state` | Level: DEBUG or INFO

| Name | Meaning |
|------|---------|
| `stable` | No offer/answer in progress. Normal resting state. |
| `have-local-offer` | Local SDP offer sent, awaiting answer |
| `have-remote-offer` | Remote SDP offer received, generating answer |
| `have-local-pranswer` | Provisional local answer sent (rare) |
| `have-remote-pranswer` | Provisional remote answer received (rare) |

### 3j. Media Access (1 INFO event)

Group: `get-user-media` | Level: INFO

| Name | Meaning |
|------|---------|
| `succeeded` | `getUserMedia()` succeeded. Mic access granted. |

### 3k. Settings (1 INFO event)

Group: `settings` | Level: INFO

| Name | Meaning |
|------|---------|
| `codec` | Reports the negotiated audio codec (opus, PCMU, PCMA). |

### 3l. Feedback (2 INFO events)

Group: `feedback` | Level: INFO

| Name | Meaning |
|------|---------|
| `received` | User submitted post-call quality feedback (1-5 score + issue tags) |
| `received-none` | Feedback solicited but user declined to provide any |

### 3m. Registration (2 INFO events, iOS/Android only)

Group: `registration` | Level: INFO

| Name | Meaning |
|------|---------|
| `registration` | Successfully registered for incoming calls via push |
| `unregistration` | Successfully unregistered from push notifications |

### 3n. Network Info (1 INFO event, JS only)

Group: `network-information` | Level: INFO

| Name | Meaning |
|------|---------|
| `network-change` | Network interface changed (e.g., WiFi to ethernet, cellular handoff). Often precedes ICE `disconnected` events. |

---

## 4. WebRTC State Machines

Voice calls use four interconnected state machines. Understanding these is essential for interpreting event sequences.

### 4a. ICE Connection State Machine

The most important state machine for diagnosing connectivity issues.

```
     new
      │
      ▼
   checking ◄──────────────────┐
      │                        │
      ▼                        │ (ICE restart)
   connected ──────────────────┘
      │         │
      │         ▼
      │    disconnected
      │         │       │
      │         │       ▼
      │         │    failed ──► closed
      │         │
      │         ▼
      │    connected (recovered)
      │
      ▼
   completed ──► closed (normal teardown)
```

**Valid transitions**:
- **Happy path**: `new` → `checking` → `connected` → `completed` → `closed`
- **Transient blip**: `connected` → `disconnected` → `connected` (normal on mobile, WiFi switches)
- **Permanent failure**: `connected` → `disconnected` → `failed` (10-30s of retries, then gives up)
- **ICE restart**: `completed` → `checking` → `connected` → `completed` (SDK-initiated recovery)

### 4b. Signaling State Machine

Tracks SDP offer/answer exchange.

```
                  ┌───────────────────────────────────────┐
                  │              stable                     │
                  │  (resting state, both descriptions set) │
                  └───────┬───────────────┬────────────────┘
                          │               │
              create offer│               │receive offer
                          ▼               ▼
               have-local-offer    have-remote-offer
                          │               │
              receive answer│         create answer│
                          ▼               ▼
                  ┌───────────────────────────────────────┐
                  │              stable                     │
                  └───────────────────────────────────────┘
```

**Valid transitions**:
- **Caller**: `stable` → `have-local-offer` → `stable`
- **Callee**: `stable` → `have-remote-offer` → `stable`
- **Renegotiation**: Multiple `stable` → `have-local-offer` → `stable` cycles (normal if codec/bandwidth adapting)
- **Red flag**: Rapid cycling without settling = possible renegotiation storm

### 4c. Peer Connection State Machine (JS only)

Aggregate of ICE transport + DTLS transport states.

```
   new → connecting → connected → closed
                  │
                  ▼
            disconnected → failed
```

**Valid transitions**:
- **Happy path**: `new` → `connecting` → `connected`
- **Disruption**: `connected` → `disconnected` → `connected` (recovered) or → `failed` (permanent)
- This mirrors the ICE state machine but includes DTLS handshake status

### 4d. ICE Gathering State Machine

Tracks candidate discovery from STUN/TURN servers.

```
   new → gathering → complete
```

**Valid transitions**:
- `new` → `gathering` → `complete` (always this sequence)
- **Trickle ICE** (default): Candidates are sent to the remote peer as they're discovered during `gathering`. Faster call setup.
- **Vanilla ICE**: All candidates gathered before any are sent. Slower but more reliable behind some firewalls.
- If stuck in `gathering`: STUN/TURN servers may be unreachable. Check UDP 3478 and TCP 443.

---

## 5. Event Sequence Patterns

Concrete patterns showing what you would see in `list_call_events` output. Use these to quickly identify what happened during a call.

### Pattern A: Normal Successful Call

Setup time: ~500ms-2s. This is what a healthy call looks like.

```
[T+0.0s]  signaling-state: have-local-offer        → INFO
[T+0.1s]  ice-gathering-state: gathering            → DEBUG
[T+0.2s]  ice-candidate: ice-candidate (host)       → DEBUG
[T+0.3s]  ice-candidate: ice-candidate (srflx)      → DEBUG
[T+0.5s]  ice-gathering-state: complete             → DEBUG
[T+0.6s]  ice-connection-state: checking            → DEBUG
[T+0.8s]  ice-connection-state: connected           → DEBUG
[T+0.9s]  ice-candidate: selected-ice-candidate-pair → DEBUG  (type: host)
[T+1.0s]  connection: accepted-by-remote            → INFO
[T+1.1s]  ice-connection-state: completed           → DEBUG
[T+1.2s]  signaling-state: stable                   → DEBUG
[T+1.3s]  settings: codec                           → INFO   (opus)
           ... stable operation, no state change events ...
[T+182s]  connection: disconnected-by-local         → INFO
```

**Diagnosis**: Everything normal. Host candidate won (best case — direct path). Codec is opus. Clean disconnect.

### Pattern B: Behind Restrictive Firewall (TURN Relay)

Setup time: 3-5s. Host and srflx candidates fail; only relay works.

```
[T+0.0s]  signaling-state: have-local-offer        → INFO
[T+0.1s]  ice-gathering-state: gathering            → DEBUG
[T+0.2s]  ice-candidate: ice-candidate (host)       → DEBUG
[T+0.3s]  ice-candidate: ice-candidate (srflx)      → DEBUG
[T+0.8s]  ice-candidate: ice-candidate (relay)      → DEBUG
[T+1.5s]  ice-gathering-state: complete             → DEBUG
[T+1.6s]  ice-connection-state: checking            → DEBUG
[T+3.2s]  ice-connection-state: connected           → DEBUG
[T+3.3s]  ice-candidate: selected-ice-candidate-pair → DEBUG  (type: relay)
[T+3.5s]  connection: accepted-by-remote            → INFO
[T+3.8s]  ice-connection-state: completed           → DEBUG
[T+4.0s]  signaling-state: stable                   → DEBUG
```

**Diagnosis**: `selected-ice-candidate-pair` shows type `relay`. Firewall is blocking direct UDP and STUN paths. Call works but with added relay latency (~50-100ms extra RTT). May see `high-rtt` warnings during the call. If TURN were also blocked, this would become Pattern D.

### Pattern C: Mobile Network Handoff (Transient Blip)

WiFi to cellular transition or cell tower handoff. Brief audio drop, automatic recovery.

```
           ... stable call in progress ...
[T+45.0s] ice-connection-state: disconnected        → DEBUG
           [1-3 seconds of silence]
[T+46.5s] ice-connection-state: connected           → DEBUG
           ... call continues normally ...
```

**Diagnosis**: Normal on mobile. The `disconnected` → `connected` transition took ~1.5s. Audio dropped briefly. If this happens frequently (>3 times per call), the network is unstable. Not a problem unless it progresses to `failed`.

### Pattern D: Network Failure (Permanent)

ICE cannot recover. Call is lost.

```
           ... stable call in progress ...
[T+60.0s]  ice-connection-state: disconnected       → DEBUG
[T+60.0s]  network-quality-warning-raised: low-bytes-received → WARNING
[T+61.0s]  network-quality-warning-raised: low-bytes-sent    → WARNING
            [10-30 seconds of retry attempts]
[T+85.0s]  ice-connection-state: failed             → ERROR
[T+85.1s]  pc-connection-state: failed              → WARNING
[T+85.2s]  connection: error                        → ERROR   (code: 31003)
[T+85.3s]  connection: disconnected-by-local        → INFO
```

**Diagnosis**: ICE went `disconnected` → `failed` after ~25s of retries. The `low-bytes-*` warnings confirm no media was flowing. Error code 31003 = connection error. Network went down completely (laptop lid closed, ISP outage, entered elevator).

### Pattern E: ICE Restart Recovery

SDK detects failure and initiates ICE restart. Call survives with brief interruption.

```
           ... stable call, quality degrading ...
[T+90.0s]  network-quality-warning-raised: high-rtt    → WARNING
[T+95.0s]  connection: reconnecting                     → INFO
[T+95.1s]  ice-connection-state: checking               → DEBUG
[T+95.5s]  ice-candidate: ice-candidate (host)          → DEBUG
[T+95.8s]  ice-candidate: ice-candidate (srflx)         → DEBUG
[T+96.5s]  ice-connection-state: connected              → DEBUG
[T+96.6s]  connection: reconnected                      → INFO
[T+97.0s]  network-quality-warning-cleared: high-rtt    → INFO
           ... call continues on new media path ...
```

**Diagnosis**: SDK proactively restarted ICE when it detected degradation. `reconnecting` → `reconnected` = success. New candidates were gathered and a new path was selected. The ~1.5s gap is the reconnection window. Audio dropped during this time but the call survived.

### Pattern F: One-Way Audio

Call connects but one direction of audio is silent. A frustrating and common issue.

```
[T+0.0s]   ... normal call setup (Pattern A) ...
[T+1.3s]   settings: codec                              → INFO   (opus)
            ... call appears connected but remote party can't hear caller ...
[T+21.3s]  audio-level-warning-raised: constant-audio-input-level → WARNING
            ... no corresponding output warning (remote IS sending audio) ...
```

**Diagnosis**: `constant-audio-input-level` after 20s means the local mic is not producing varying audio. But no `constant-audio-output-level` means remote audio IS arriving. This is one-way audio — the caller's mic is the problem. Check: hardware mute switch, browser mic permission, wrong input device selected, another app holding exclusive mic access.

If BOTH `constant-audio-input-level` AND `constant-audio-output-level` fire, the issue is likely network-level (media path broken despite ICE showing connected).

### Pattern G: Quality Degradation then Recovery

Transient network congestion that resolves on its own.

```
           ... stable call ...
[T+120.0s] network-quality-warning-raised: high-jitter      → WARNING
[T+122.0s] network-quality-warning-raised: high-packet-loss → WARNING
[T+124.0s] network-quality-warning-raised: low-mos          → WARNING
            ... choppy/degraded audio for ~30 seconds ...
[T+155.0s] network-quality-warning-cleared: high-jitter     → INFO
[T+156.0s] network-quality-warning-cleared: high-packet-loss → INFO
[T+157.0s] network-quality-warning-cleared: low-mos         → INFO
           ... quality restored, call continues ...
```

**Diagnosis**: Warnings fired in escalation order (jitter → loss → MOS), then cleared in the same order. This is transient network congestion — probably a bandwidth spike from another application or a brief WiFi interference event. The `warning-cleared` events confirm recovery. If warnings never clear, the congestion is sustained and the call quality remains degraded until disconnect.

---

## 6. ICE Candidate Types

ICE candidates represent possible network paths for media. The SDK discovers them during the gathering phase and tests them in preference order.

### Candidate Types (preference order, highest to lowest)

| Type | Full Name | How Discovered | What It Reveals | Latency |
|------|-----------|----------------|-----------------|---------|
| `host` | Host candidate | Local network interface enumeration | Direct path. Device has routable IP or is on same LAN. | Lowest |
| `srflx` | Server reflexive | STUN server response | NAT traversal. STUN server revealed the public IP:port. Works through most NATs. | Low |
| `prflx` | Peer reflexive | Discovered during connectivity checks | Unexpected path found during ICE negotiation. Uncommon. | Varies |
| `relay` | Relay candidate | TURN server allocation | All direct paths blocked. Media relayed through Twilio TURN server. | Highest (+50-100ms) |

### Interpreting Selected Candidates

The `selected-ice-candidate-pair` event reveals which path won:

- **host ↔ host**: Best case. Both sides on direct-access networks.
- **srflx ↔ srflx**: Normal. Both sides behind NAT but STUN succeeded.
- **relay ↔ anything**: One side is behind a restrictive firewall. Adds latency. May trigger `high-rtt` warnings.
- **Only relay candidates gathered**: Firewall is blocking all UDP. TURN over TCP 443 is the last resort. If that also fails → `ice-connection-state: failed`.

### Candidate Gathering Failure Modes

| Situation | What You See | Root Cause |
|-----------|-------------|------------|
| No candidates at all | `ice-gathering-state: none` (WARNING) | No network interfaces, or STUN/TURN servers completely unreachable |
| Only host candidates | `ice-candidate: host` then `ice-gathering-state: complete` | STUN/TURN servers blocked. Will only work on same LAN. |
| Only relay candidates | `ice-candidate: relay` (no host or srflx) | Extremely restrictive firewall. Works but with relay latency penalty. |
| Gathering timeout | `ice-gathering-state: timeout` (WARNING) | STUN/TURN servers partially reachable but too slow to respond |

---

## 7. Gateway Events Gap

Twilio does **not** publish a reference for gateway event names. Events from `carrier_edge`, `sip_edge`, and `client_edge` represent call progress on Twilio's infrastructure side (initiated, ringing, answered, completed, etc.), but the specific `name` and `group` values for these edges are not documented.

What this means in practice:

- You will see events with `edge` = `carrier_edge` or `sip_edge` in `list_call_events` output
- These events have their own `group` and `name` values that differ from `sdk_edge` events
- The values must be discovered empirically by examining real call event streams
- Gateway events are useful for understanding Twilio-side timing (when did Twilio's infrastructure see the call progress?) but their schema is undocumented

When analyzing events, focus diagnostic effort on `sdk_edge` events (documented above). Use gateway events for timeline correlation only.

---

## 8. Event-to-Tag Correlation

Voice Insights Call Summary tags (from `get_call_summary`) are generated from aggregated metrics, not directly from SDK events. However, the same underlying conditions trigger both. SDK events fire in real-time with more sensitive thresholds; tags are computed post-call with stricter thresholds.

| SDK Event (real-time) | Call Summary Tag (post-call) | Threshold Difference |
|------------------------|------------------------------|---------------------|
| `high-rtt` (WARNING, >400ms RTT) | `high_latency` | Tag uses >150ms one-way RTP latency. SDK event is much more sensitive. |
| `high-jitter` (WARNING, >30ms) | `high_jitter` | Similar thresholds but tag uses aggregate statistics over the call. |
| `high-packet-loss` (WARNING, >1%) | `high_packet_loss` | Tag threshold is also based on aggregate, may require higher sustained loss. |
| `low-mos` (WARNING, <3.5) | `low_mos` | Both use MOS 3.5 but tag is computed from full-call RTP metrics, not samples. |
| `constant-audio-input-level` (WARNING) | `silence` | Tag fires only if RTP-level silence is detected. SDK event is mic-level only. |
| `ice-connection-state: failed` (ERROR) | `ice_failure` | Direct correlation. Both indicate total ICE failure. |
| `low-bytes-received` / `low-bytes-sent` (WARNING) | `short_call` or `silence` | Zero-byte periods may produce silence tag; very short zero-byte calls get short_call. |

**Key principle**: SDK event thresholds are intentionally more sensitive than tag thresholds. Events are designed for real-time early warning during a call. Tags are designed for post-call triage across many calls. A call can have SDK warnings without earning the corresponding tag if the issue was brief or borderline.

When debugging: if a call has a tag, look for the corresponding SDK events to find exactly when the issue occurred. If a call has SDK warnings but no tag, the issue was transient and resolved before it crossed the tag threshold.
