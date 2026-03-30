---
name: "voice-sdks"
description: "Twilio development skill: voice-sdks"
---

---
name: voice-sdks
description: Twilio Voice SDK development guide (JS, iOS, Android, React Native). Use when building browser softphones, mobile calling apps, WebRTC integration, AccessToken generation, or TwiML App configuration for SDK clients.
---

# Voice SDK Development Skill

Guide for building voice applications using Twilio's client-side SDKs. Load this skill when building browser-based softphones, mobile calling apps, or any application where end users make/receive calls through a Twilio SDK rather than a PSTN phone.

---

## Scope

### CAN

- Build browser-based softphones (JavaScript SDK)
- Build native mobile calling apps (iOS, Android SDKs)
- Build cross-platform calling apps (React Native SDK)
- Make outbound calls from client to PSTN, SIP, or other clients
- Receive inbound calls routed to SDK clients via `<Dial><Client>`
- Run preflight connectivity tests before calls
- Select audio input/output devices (JS SDK)
- Send/receive custom messages during calls (UserDefinedMessages / Call Message Events)
- Use edge locations for latency optimization
- Integrate with Conference, Recording, and all TwiML verbs

### CANNOT

- **Work without a server-side token endpoint** — SDK clients require a short-lived AccessToken generated server-side with the Voice grant
- **Operate without a TwiML App** — All SDK calls route through a TwiML Application that defines the Voice URL
- **Run without HTTPS** — Browser SDK requires secure context (HTTPS or localhost)
- **Use Elastic SIP Trunking** — SDKs connect via Programmable Voice only
- **Record client-side** — All recording is server-side via TwiML or API

---

## Quick Decision

| Need | SDK Platform | Why |
|------|-------------|-----|
| Browser softphone / call center agent UI | JavaScript | No install, works in Chrome/Firefox/Safari/Edge |
| Native iOS calling with CallKit | iOS (Swift) | CallKit integration, background audio, push notifications |
| Native Android calling | Android (Kotlin/Java) | ConnectionService, FCM push, background audio |
| Cross-platform mobile app | React Native | Single codebase, native bridge to iOS/Android SDKs |
| Server-to-server calls only | No SDK needed | Use Calls API directly |

---

## Architecture

```
┌──────────────┐     AccessToken     ┌──────────────┐
│  Your Server │◄────────────────────│  SDK Client   │
│  (Token +    │     (JWT, short-    │  (Browser or  │
│   TwiML)     │      lived)         │   Mobile)     │
└──────┬───────┘                     └──────┬────────┘
       │                                    │
       │ TwiML App Voice URL                │ WebRTC / SRTP
       │                                    │
       ▼                                    ▼
┌──────────────────────────────────────────────────┐
│              Twilio Voice Infrastructure          │
│  (Edge locations, SRTP, PSTN gateway)            │
└──────────────────────────────────────────────────┘
```

### AccessToken Generation (Server-Side)

Every SDK client needs a JWT AccessToken with a Voice grant:

```javascript
// ABOUTME: Generate AccessToken for Voice SDK clients
// ABOUTME: Server-side only — never expose Account SID or API Key Secret to clients

const AccessToken = require('twilio').jwt.AccessToken;
const VoiceGrant = AccessToken.VoiceGrant;

const token = new AccessToken(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_API_KEY,
  process.env.TWILIO_API_SECRET,
  { identity: 'agent-alice' }  // unique per user
);

const voiceGrant = new VoiceGrant({
  outgoingApplicationSid: 'APxxxxx',  // TwiML App SID
  incomingAllow: true                  // allow inbound calls to this identity
});

token.addGrant(voiceGrant);
return token.toJwt();
```

**Token lifetime:** Max 24 hours. Set `ttl` in seconds when creating (e.g., `3600` for 1 hour). SDK uses the token until expiry. Implement a refresh mechanism before expiry.

### TwiML App Configuration

The TwiML App is the bridge between SDK calls and your server logic:

- **Voice URL** — Webhook called when SDK client makes a call (receives `To`, `From`, `CallSid`, custom parameters)
- **Voice Fallback URL** — Called if Voice URL fails
- **Voice Status Callback** — Receives call lifecycle events
- **Voice Method** — POST (recommended) or GET

---

## Platform-Specific Notes

### JavaScript SDK

- **Supported browsers:** Chrome, Firefox, Safari, Edge (current and N-2 versions)
- **Electron:** Latest release supported
- **Security:** TLS for signaling, DTLS-SRTP for media
- **Audio management:** `device.audio` accessor for device selection (microphone, speaker)
- **Preflight test:** `Device.runPreflight(token)` — tests connectivity, codec negotiation, ICE candidate gathering before real calls

### iOS SDK

- **CallKit integration** — Native iOS calling UI
- **Push notifications** — VoIP push for incoming calls when app is backgrounded
- **Audio session** — Managed by SDK, handles interruptions (other calls, Siri)

### Android SDK

- **ConnectionService** — Android Telecom framework integration
- **FCM** — Firebase Cloud Messaging for incoming call notifications
- **Audio focus** — Managed by SDK

### React Native SDK

- **Bridge to native SDKs** — Wraps iOS and Android SDKs
- **Single API surface** — Unified TypeScript/JavaScript API across platforms

---

## Edge Locations

SDK clients connect to the nearest Twilio edge for lowest latency:

| Edge | Location |
|------|----------|
| `ashburn` | US East |
| `dublin` | Ireland |
| `frankfurt` | Germany |
| `singapore` | Singapore |
| `sydney` | Australia |
| `tokyo` | Japan |
| `sao-paulo` | Brazil |
| `roaming` | Auto-select nearest (default) |

Set via `Device` constructor options `edge` property (JS) or `ConnectOptions` (mobile). Default is `roaming`.

---

## Call Message Events (UserDefinedMessages)

Send custom data between your server and SDK client during an active call:

**Server → Client:** POST to `/Calls/{CallSid}/UserDefinedMessages`
**Client → Server:** SDK `.sendMessage()` method → delivered to your status callback

Use cases: agent screen pops, real-time sentiment scores, CRM data injection, AI-generated suggestions during calls.

---

## Gotchas

1. **AccessToken must be server-generated**: Never embed API Key Secret in client code. The token endpoint is a hard server-side requirement.

2. **TwiML App is mandatory**: SDK calls don't work without a TwiML Application SID in the Voice grant. The TwiML App's Voice URL receives the webhook when the client initiates a call.

3. **Identity must be unique per user**: If two SDK clients register with the same identity, incoming calls will ring both. Use deterministic, unique identifiers (user ID, agent ID).

4. **HTTPS required for JS SDK**: Browser microphone access requires secure context. Only `localhost` is exempt. Self-signed certs don't work in most browsers.

5. **Token refresh before expiry**: If the token expires mid-session, existing calls may continue but new calls and registrations fail. Implement proactive token refresh (e.g., at 75% of TTL).

6. **Preflight test is not a call**: `Device.runPreflight(token)` validates connectivity but does not create a Twilio Call resource. It cannot test TwiML App configuration or webhook reachability.

7. **Edge selection affects quality**: Default edge is `roaming` (auto-select). For latency-sensitive deployments, consider pinning to a specific edge near your users. The `roaming` default works well for global deployments but adds a small negotiation step.

8. **Push notifications require separate setup**: Mobile SDKs need VoIP push (iOS) or FCM (Android) configured on the Twilio Console for incoming calls when the app is backgrounded. This is a common "it works in foreground but not background" debugging trap.

9. **Browser autoplay policies**: Browsers may block audio playback without user interaction. The SDK ringtone may be silent until the user interacts with the page. Handle the user gesture requirement for audio playback.

10. **`<Dial><Client>` identity is case-sensitive**: Routing to `agent-Alice` vs `agent-alice` targets different clients.

---

## Related Resources

- [Voice Skill](/skills/voice/SKILL.md) — Core voice decision frameworks
- [iOS SDK Skill](/skills/ios-sdk/SKILL.md) — iOS-specific: CallKit, PushKit, background modes, permissions, audio session
- [Conference Skill](/skills/conference/SKILL.md) — Conference integration with SDK clients
- [Voice Insights Skill](/skills/voice-insights/SKILL.md) — SDK call quality diagnostics
- [Android SDK Skill](/skills/android-sdk/SKILL.md) — Android-specific: Gradle, FCM, ConnectionService, permissions, emulator testing
- [Twilio Voice JS SDK Docs](https://www.twilio.com/docs/voice/sdks/javascript)
- [Twilio Voice iOS SDK Docs](https://www.twilio.com/docs/voice/sdks/ios)
- [Twilio Voice Android SDK Docs](https://www.twilio.com/docs/voice/sdks/android)
- [Twilio Voice React Native SDK Docs](https://www.twilio.com/docs/voice/sdks/react-native)
