---
name: "conversationrelay"
description: "Twilio development skill: conversationrelay"
---

---
name: conversationrelay
description: Twilio ConversationRelay voice AI guide. Use when building LLM-powered voice agents, connecting phone calls to WebSocket servers, configuring STT/TTS providers, handling real-time speech, or choosing between ConversationRelay and Media Streams.
allowed-tools: mcp__twilio__*, Read, Grep, Glob, Bash
---

# ConversationRelay Skill

Decision-making guide for building voice AI agents with Twilio ConversationRelay. ConversationRelay handles STT, TTS, interruption, and DTMF — you provide a WebSocket server with your LLM logic.

All claims backed by live testing (2026-03-28, account ACxx...xx). See [references/test-results.md](references/test-results.md) for call SIDs.

---

## Scope

### What ConversationRelay Does

- Real-time bidirectional text communication between phone calls and your WebSocket server
- Built-in STT (Google, Deepgram) and TTS (Google, Amazon Polly, ElevenLabs)
- Automatic interruption handling (caller speech stops TTS playback)
- DTMF detection and sending
- Welcome greeting with configurable interruptibility
- Partial transcript streaming (`partialPrompts`)
- Audio playback via `play` message (URL-based)
- Mid-session language switching via `language` message
- Voice Intelligence v2 integration via `intelligenceService` attribute
- Debug telemetry (round-trip latency, speaker events, tokens played)
- X-Twilio-Signature on WebSocket handshake for request validation
- Custom parameters passed from TwiML to WebSocket setup message
- Session handoff with data passed to `<Connect action>` callback
- Studio widget for no-code integration

### What ConversationRelay Does NOT Do

1. **No raw audio access** — text in, text out. For raw audio use `<Connect><Stream>` (see [media-streams skill](/skills/media-streams/SKILL.md))
2. **No custom STT/TTS engines** — limited to Google + Deepgram (STT) and Google + Amazon + ElevenLabs (TTS)
3. **No WebSocket auto-reconnection** — if WS drops, call disconnects. Implement recovery via `<Connect action>` URL
4. **No mid-session voice/provider changes** — voice and provider are set at TwiML time. Only language can be switched mid-session via the `language` WebSocket message
5. **No SMS/messaging** — voice only
6. **No built-in memory/context** — BYO conversation history and context management
7. **Not PCI compliant with Voice Intelligence v2** — do not enable `intelligenceService` in PCI workflows
8. **No LLM integration** — pure transport layer. You bring your own LLM via the WebSocket server
9. **Cannot mix with Media Streams** — `<Connect><Stream>` and `<Connect><ConversationRelay>` are mutually exclusive on the same call
10. **No server-side recording** — use `<Start><Recording>` or call-level `record` parameter separately. Recording must be set up before `<Connect>` in TwiML
11. **ElevenLabs requires account enablement** — accounts without ElevenLabs access get error 64101 with `block_elevenlabs`. Voice IDs (not human names) required: e.g., `UgBBYS2sOqTuMpoF3BR0`

---

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| LLM-powered voice agent | **ConversationRelay** | Built-in STT/TTS, JSON protocol, fastest path |
| Custom STT/TTS engine | **Media Streams** | Raw audio access via `<Connect><Stream>` |
| Real-time transcription alongside other TwiML | **`<Start><Transcription>`** | Non-blocking, runs in background |
| Voice + SMS from one codebase | **Twilio APIs** | Build channel routing with Programmable Voice + Messaging APIs |
| Post-call transcript analysis | **Voice Intelligence v2** | Batch processing of recordings |
| Simple speech input (menus, numbers) | **`<Gather>`** | Single-turn input, no WebSocket needed |

---

## Decision Frameworks

### STT Provider Selection

| Factor | Google | Deepgram |
|--------|--------|----------|
| Default (post-Sept 2025 accounts) | No | **Yes** |
| Default (pre-Sept 2025 accounts) | **Yes** | No |
| Model for phone audio | `telephony` | `flux-general-en` (recommended), `nova-3-general` |
| Smart formatting (numbers, dates) | No | `deepgramSmartFormat="true"` (default on) |
| Attribute to select | `transcriptionProvider="Google"` | `transcriptionProvider="Deepgram"` |

**Recommendation**: Deepgram `flux-general-en` for voice AI agents (optimized for turn-taking). Fallback: `nova-3-general` if Flux unavailable. Google `telephony` only if you need specific Google Cloud Speech features. For full model compatibility matrix, see the [Deepgram skill](/skills/deepgram/SKILL.md).

### TTS Provider Selection

| Factor | Google | Amazon Polly | ElevenLabs |
|--------|--------|-------------|------------|
| Voice quality | Neural2 (high), Chirp3-HD (highest) | Standard to Neural | Flash 2/2.5 (highest) |
| Latency | Low | Low | Variable |
| Voice format | `Google.en-US-Neural2-F` or `en-US-Chirp3-HD-Aoede` | `Polly.Amy` | Voice ID (e.g., `UgBBYS2sOqTuMpoF3BR0`) |
| Account requirement | None | None | Must be enabled (64101 if blocked) |
| Text normalization | Automatic | Automatic | Manual or `elevenlabsTextNormalization="on"` |
| Chirp3-HD naming | Omit `Google.` prefix | N/A | N/A |

**Recommendation**: ElevenLabs for production voice quality (requires account enablement). Default voice: Jessica (`cgSgspJ2msm6clMCkdW9`). Always set `elevenlabsTextNormalization: "on"`. Fallback: Google Neural2 if ElevenLabs not enabled on account.

### When to Add Recording

| Pattern | Method | Placement | Channels |
|---------|--------|-----------|----------|
| Record full call including CR audio | `<Start><Recording>` before `<Connect>` | TwiML, before ConversationRelay | Dual (caller + agent) |
| Record via API on outbound call | `record: true` on `client.calls.create()` | REST API parameter | Configurable |
| Record in conference with CR agents | `record="record-from-start"` on `<Conference>` | Conference TwiML | Mixed |

Always place `<Start><Recording>` **before** `<Connect><ConversationRelay>` in TwiML — `<Connect>` blocks subsequent verbs.

---

## TwiML Configuration

### Minimal Setup

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
const connect = twiml.connect();
connect.conversationRelay({
  url: 'wss://your-server.com/ws',
});
return callback(null, twiml);
```

### Full Configuration

```javascript
const twiml = new Twilio.twiml.VoiceResponse();

// Optional: background recording (must be BEFORE <Connect>)
const start = twiml.start();
start.recording({
  recordingStatusCallback: `https://${context.DOMAIN_NAME}/callbacks/recording-complete`,
  recordingStatusCallbackEvent: 'completed',
  recordingStatusCallbackMethod: 'POST',
  trim: 'trim-silence',
});

const connect = twiml.connect({
  action: `https://${context.DOMAIN_NAME}/callbacks/connect-action`,
});
connect.conversationRelay({
  url: context.CONVERSATION_RELAY_URL,
  // TTS
  ttsProvider: 'ElevenLabs',
  voice: 'cgSgspJ2msm6clMCkdW9',          // ElevenLabs Jessica
  elevenlabsTextNormalization: 'on',
  // STT
  transcriptionProvider: 'deepgram',
  speechModel: 'flux-general-en',
  // Language
  language: 'en-US',
  // Behavior
  dtmfDetection: 'true',
  interruptible: 'true',
  interruptSensitivity: 'high',
  // Optional
  welcomeGreeting: 'Hello! How can I help you today?',
  welcomeGreetingInterruptible: 'any',
  partialPrompts: 'true',
  hints: 'Twilio, ConversationRelay, Deepgram',
  // Observability
  intelligenceService: context.TWILIO_INTELLIGENCE_SERVICE_SID, // GA-prefixed SID (Voice Intelligence v2)
  debug: 'debugging speaker-events tokens-played',
});
return callback(null, twiml);
```

### Custom Parameters

Pass context from your TwiML function to the WebSocket server:

```javascript
const cr = connect.conversationRelay({ url: wsUrl, voice: 'Google.en-US-Neural2-F' });
cr.parameter({ name: 'customerId', value: event.CustomerId });
cr.parameter({ name: 'language', value: event.Language || 'en-US' });
```

Parameters arrive in the `setup` message's `customParameters` object.

### Action Callback

When the CR session ends, Twilio POSTs to the `<Connect action>` URL with:

| Field | Value | Notes |
|-------|-------|-------|
| `SessionId` | `VX...` | ConversationRelay session SID |
| `SessionStatus` | `completed` or `ended` | `completed` = call hung up; `ended` = WS sent `end` message |
| `SessionDuration` | seconds | Duration of the CR session |
| `HandoffData` | string | Only present if WS sent `end` with `handoffData` |
| `CallSid`, `CallStatus`, `From`, `To` | standard | Normal Twilio call parameters |

When `SessionStatus` is `ended`, the call is still alive — your action URL returns TwiML to continue (transfer, IVR, hangup).

For the complete TwiML attribute reference (21 attributes + child elements), see [references/attribute-reference.md](references/attribute-reference.md).

---

## WebSocket Server

### Architecture

```
Phone Call → Twilio → WSS → Your Server → LLM
                ↕                    ↕
           STT/TTS              Business Logic
```

Your WebSocket server receives structured JSON messages from Twilio and sends text responses back. Twilio handles all audio processing.

### Getting Started with ngrok

ConversationRelay requires a public `wss://` URL. For local development:

1. **Install ngrok**: `brew install ngrok`
2. **Configure auth**: `ngrok config add-authtoken YOUR_TOKEN`
3. **Start your WebSocket server** on a local port (e.g., 8080)
4. **Expose it**: `ngrok http 8080` (or `ngrok http 8080 --domain=your-domain.ngrok.dev` for stable URLs)
5. **Use the URL**: `wss://abc123.ngrok.dev` in your TwiML

For stable development URLs, use a custom ngrok domain (requires paid plan). Store in `.env` as `CONVERSATION_RELAY_URL`.

### Minimal WebSocket Server (Node.js)

```javascript
const http = require('http');
const { WebSocketServer } = require('ws');
const Anthropic = require('@anthropic-ai/sdk');

const PORT = process.env.PORT || 8080;
const anthropic = new Anthropic();
const server = http.createServer();
const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  const conversationHistory = [];
  let callSid = null;

  ws.on('message', async (data) => {
    const msg = JSON.parse(data.toString());

    switch (msg.type) {
      case 'setup':
        callSid = msg.callSid;
        console.log(`Call connected: ${callSid}`);
        break;

      case 'prompt':
        // Only process final transcripts
        if (!msg.last) return;

        conversationHistory.push({ role: 'user', content: msg.voicePrompt });

        // Stream response to reduce latency
        const stream = await anthropic.messages.stream({
          model: 'claude-sonnet-4-20250514',
          max_tokens: 256,
          system: 'You are a helpful voice assistant. Keep responses concise.',
          messages: conversationHistory,
        });

        let fullResponse = '';
        stream.on('text', (text) => {
          fullResponse += text;
          ws.send(JSON.stringify({ type: 'text', token: text }));
        });

        await stream.finalMessage();
        ws.send(JSON.stringify({ type: 'text', token: '', last: true }));
        conversationHistory.push({ role: 'assistant', content: fullResponse });
        break;

      case 'interrupt':
        // Caller interrupted — stop current LLM generation if possible
        console.log(`Interrupted after: "${msg.utteranceUntilInterrupt}"`);
        break;

      case 'dtmf':
        console.log(`DTMF: ${msg.digit}`);
        break;

      case 'error':
        console.log(`Error: ${msg.description}`);
        break;
    }
  });

  ws.on('close', () => console.log(`Call ended: ${callSid}`));
});

server.listen(PORT, () => console.log(`WS server on :${PORT}`));
```

### Context Management

Voice calls can run many turns. Without management, LLM context windows overflow.

| Strategy | When | Trade-off |
|----------|------|-----------|
| **Sliding window** (keep last N messages) | Most voice agents | Loses early context |
| **Summarize + trim** | Long calls, complex topics | Extra LLM call, slight latency |
| **Full history** | Short interactions only | Context overflow risk |

```javascript
// Sliding window — strip to role+content for Anthropic API
function getMessages(history) {
  const WINDOW = 20;
  return history.slice(-WINDOW).map(m => ({ role: m.role, content: m.content }));
}
```

The `.map(m => ({ role: m.role, content: m.content }))` is critical — Anthropic's API rejects extra fields like timestamps.

For the complete WebSocket protocol reference (all message types, fields, examples), see [references/websocket-protocol.md](references/websocket-protocol.md).

---

## Integration Patterns

### ConversationRelay in Conferences

Each agent's CR runs on their individual call leg, while conference membership is on the parent leg. Audio bridges through.

```javascript
// Add a CR-enabled agent to a conference
await client.conferences(conferenceSid)
  .participants.create({
    from: servicePhone,
    to: agentPhone,  // Phone with CR webhook
  });
// Agent's webhook fires → CR on child leg
// Parent leg auto-joins conference → audio bridges
```

Do NOT use `make_call(url=conference-TwiML)` — the `url` parameter controls the parent leg only.

### ConversationRelay + Voice Intelligence v2

Add `intelligenceService` to get automatic post-call transcripts and Language Operator analysis without recording. The `intelligenceService` attribute accepts GA-prefixed SIDs (`GA...`) for Voice Intelligence v2.

```javascript
connect.conversationRelay({
  url: wsUrl,
  intelligenceService: context.TWILIO_INTELLIGENCE_SERVICE_SID, // GA-prefixed SID (Voice Intelligence v2)
  // ... other attributes
});
```

The transcript appears in Voice Intelligence v2 with:
- `source`: `"ConversationRelay"` (not "Recording")
- `source_sid`: The session VX SID
- Participants auto-labeled as "Virtual Agent" (channel 1) and customer phone (channel 2)
- Language Operators configured on the service auto-run after call ends

**Constraint**: `transcriptionLanguage` must match the Intelligence Service's language setting, or operators won't execute.

### Handoff to Human / IVR

Use the `end` message with `handoffData` to transfer call control back to TwiML:

```javascript
// WebSocket server sends:
ws.send(JSON.stringify({
  type: 'end',
  handoffData: JSON.stringify({ reason: 'transfer', department: 'billing' }),
}));
```

The `<Connect action>` URL receives `HandoffData` as a POST parameter. Return TwiML to continue the call (e.g., `<Dial>` to transfer, `<Enqueue>` for queue).

---

## Gotchas

### Startup & Configuration

1. **`interruptByDtmf` is not a valid attribute**: DTMF detection uses `dtmfDetection`, interruption uses `interruptible`. Combining the names into `interruptByDtmf` silently does nothing.

2. **Chirp3-HD voices omit the `Google.` prefix**: Use `en-US-Chirp3-HD-Aoede`, NOT `Google.en-US-Chirp3-HD-Aoede`. Neural2 voices keep the prefix: `Google.en-US-Neural2-F`. [Evidence: CA11513868]

3. **ElevenLabs requires account enablement**: Accounts without access get error 64101 with `block_elevenlabs`. Voices use opaque IDs (e.g., `UgBBYS2sOqTuMpoF3BR0`), not human names. [Evidence: CA05cc0dab]

4. **Voice/provider mismatch → error 64101**: A Google voice with `ttsProvider="ElevenLabs"` (or vice versa) causes connection failure. Voice name format must match the selected provider.

5. **Default STT provider depends on account age**: Accounts created after Sept 2025 default to Deepgram. Older accounts default to Google. Code without explicit `transcriptionProvider` may behave differently across accounts.

6. **`<Connect>` blocks subsequent TwiML**: Place `<Start><Recording>` and `<Say>` BEFORE `<Connect><ConversationRelay>`. Anything after `<Connect>` never executes.

7. **Predictive and Generative AI/ML Features Addendum**: Must be enabled in Console (Voice > Settings > General) before ConversationRelay works.

### Protocol & Runtime

8. **Use `last`, not `isFinal`**: Prompt messages use `{ last: true }`. Checking `isFinal` (a Media Streams pattern) silently drops all transcripts. [Evidence: all test calls]

9. **`confidence` field is absent from prompt messages**: Despite being documented in some references, live testing confirms prompt messages only contain `type`, `voicePrompt`, `lang`, and `last`. Do not rely on `confidence`. [Evidence: CA9819c407, all prompts across 12 calls]

10. **10 consecutive malformed messages = disconnection**: Error 64105 with WebSocket close code 1007 and reason "Too many consecutive malformed messages." Individual malformed messages trigger 64107 but don't disconnect.

11. **`console.error()` → error 82005**: In Twilio Functions, use `console.log()` for all logging. `console.error()` generates debugger alerts. `console.warn()` → 82004.

12. **WebSocket URL must be `wss://`**: HTTP/WS URLs cause 64102. Always use secure WebSocket.

### Behavioral

13. **`interruptible` enum values changed**: Now accepts `"none"`, `"dtmf"`, `"speech"`, `"any"`. Boolean `true`/`false` still works for backward compatibility (`true` = `"any"`, `false` = `"none"`).

14. **`reportInputDuringAgentSpeech` enables speech events while non-interruptible**: With `interruptible="none"` and `reportInputDuringAgentSpeech="speech"`, prompts arrive during agent speech but don't interrupt TTS. Useful for capturing what callers say while your agent talks. [Evidence: CAeebc1434]

15. **`partialPrompts` delivers progressive transcripts**: Each partial prompt contains the full utterance so far (not deltas). Pattern: `"Thank you for"` → `"Thank you for calling"` → `"Thank you for calling Acme"` → final `last: true`. [Evidence: CA9819c407]

16. **`debug` produces `type: "info"` messages**: Three debug channels via space-separated values — `debugging` (roundTripDelayMs), `speaker-events` (agentSpeaking/clientSpeaking on/off), `tokens-played` (tokensPlayed with text). [Evidence: CA235cd451]

### Observability

17. **Voice Intelligence v2 transcripts don't need recordings**: `intelligenceService` creates transcripts directly from the CR session via Voice Intelligence v2. Source is `"ConversationRelay"` with `source_sid` = VX session SID. No `<Start><Recording>` required. [Evidence: CAb46f3db6 → GTa86955e6]

18. **Voice Intelligence v2 is post-call only**: Language Operators execute after the CR session ends (when call hangs up or WS sends `end`). No real-time operator results during the call.

19. **Voice Intelligence v2 is not PCI compliant**: Do not enable `intelligenceService` in workflows that handle payment card data.

20. **LLM response burst after connectivity gap**: If your LLM provider becomes temporarily unreachable while the WebSocket stays open, STT transcripts queue on Twilio's side. When connectivity resumes, your server receives a burst of queued transcripts. Do not process all of them — discard transcripts older than a threshold (e.g., 5 seconds) since the conversation context has moved on. Responding to stale transcripts creates a garbled experience where the AI addresses things the caller said 10+ seconds ago.

### Session Lifecycle

21. **`SessionStatus` values differ by end reason**: `completed` = call hung up normally. `ended` = WebSocket sent `end` message. When `ended`, the call is still alive — action URL TwiML takes over. [Evidence: CA92eb48b1]

22. **WebSocket disconnect = call disconnect**: No auto-reconnect. If your server crashes, the call ends. Implement redundancy at the server level, not the protocol level.

23. **`handoffData` is a string, not parsed JSON**: The action callback receives `HandoffData` as a raw string. If you send JSON, the receiver must `JSON.parse()` it. [Evidence: CA92eb48b1]

### Operational Failure Modes

24. **LLM credential expiration mid-conversation**: If your LLM API key expires or is rate-limited during an active call, the WebSocket stays open but your server stops sending `text` messages. Twilio's behavior: the caller hears silence indefinitely. After 10 consecutive empty/malformed responses, error 64105 fires and the WebSocket closes, ending the call. **Detection**: Track time-since-last-text-sent. If >5 seconds with pending prompts, your LLM is likely failing. **Recovery**: Send an `end` message with `handoffData` containing the failure reason, then return fallback TwiML from the action URL (e.g., `<Say>` an apology + `<Enqueue>` for a human agent).

25. **LLM provider connectivity vs credential failure**: A network timeout returns a retryable error; an expired API key returns 401. Your WebSocket server must distinguish these — retry on timeout (with backoff), gracefully end on auth failure. If you retry auth failures, you burn through the 10-malformed-message budget sending empty responses while the caller waits.

26. **Heartbeat pattern for LLM health**: Send a lightweight LLM request (e.g., single-token completion) every 30 seconds during idle periods. If it fails, proactively send an `end` message before the caller notices degradation. This catches credential expiration before it affects an active conversation turn.

---

## Error Codes

| Code | Name | Cause | Fix |
|------|------|-------|-----|
| 64101 | Invalid Parameter | Bad TwiML attribute value, voice/provider mismatch, blocked provider | Check attribute values match provider. Verify ElevenLabs enabled |
| 64102 | Unable to Connect | WebSocket URL unreachable or invalid | Verify `wss://` URL is publicly accessible. Check ngrok tunnel |
| 64105 | WebSocket Ended | Server disconnect or 10+ consecutive malformed messages | Check server health. Validate outbound message format |
| 64107 | Invalid Message | Unrecognized message type or invalid fields | Verify message format against protocol spec. Check for error objects leaking into WS |

---

## Related Resources

| Topic | Resource |
|-------|----------|
| Deepgram STT config | [Deepgram skill](/skills/deepgram/SKILL.md), especially [CR reference](/skills/deepgram/references/conversation-relay.md) |
| Raw audio WebSocket | [Media Streams skill](/skills/media-streams/SKILL.md) |
| Call recording with CR | [Recordings skill](/skills/recordings/SKILL.md) |
| Voice use case routing | [Voice Use Case Map](/skills/voice-use-case-map/SKILL.md) |
| Real-time transcription | [RTT skill](/skills/real-time-transcription/SKILL.md) |
| Voice Intelligence v2 | `/voice-intelligence` skill (private beta — gitignored) |
| Domain functions | `` ([CLAUDE.md](../../CLAUDE.md)) |
| MCP tools | `mcp__twilio__make_call`, `mcp__twilio__validate_call`, `mcp__twilio__get_call` |

---

## Reference Files

| Topic | File | When to Read |
|-------|------|-------------|
| Full TwiML attribute reference (21 attrs + child elements) | [references/attribute-reference.md](references/attribute-reference.md) | When configuring ConversationRelay TwiML |
| Complete WebSocket protocol (all message types, fields) | [references/websocket-protocol.md](references/websocket-protocol.md) | When building a WebSocket server |
| Live test results with SID evidence | [references/test-results.md](references/test-results.md) | When verifying claims or debugging |
| Assertion audit (280 claims verified) | [references/assertion-audit.md](references/assertion-audit.md) | When questioning a specific claim's provenance |
