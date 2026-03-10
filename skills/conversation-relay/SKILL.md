---
name: conversation-relay
description: Real-time voice AI with ConversationRelay WebSocket protocol. Use when building voice assistants, AI agents, or real-time transcription.
---

# ConversationRelay Skill

Knowledge for building Twilio ConversationRelay functions for real-time voice AI applications.

## What is Conversation Relay?

Real-time, bidirectional communication between phone calls and AI/LLM backends via WebSockets. Handles speech transcription, TTS, audio streaming, DTMF detection, and interruption handling.

**Not Media Streams** (`<Connect><Stream>`): Media Streams sends raw audio (mulaw 8kHz base64). ConversationRelay sends structured JSON (`type: "prompt"`, `type: "text"`). They are **incompatible** — a CR handler cannot be used with `<Stream>` and vice versa.

## Quickstart (5 Minutes)

Minimum viable ConversationRelay setup:

1. **TwiML function** — Returns `<Connect><ConversationRelay>` pointing to your WebSocket URL
2. **WebSocket server** — Handles `setup`, `prompt`, and `interrupt` events; sends `text` responses
3. **Phone number** — Configure voice webhook to your TwiML function
4. **Call it** — Dial the number, speak, hear AI response

```javascript
// Minimal TwiML
const twiml = new Twilio.twiml.VoiceResponse();
const connect = twiml.connect();
connect.conversationRelay({
  url: 'wss://your-server.ngrok.dev/ws',
  voice: 'Google.en-US-Neural2-F',
  transcriptionProvider: 'google',
  ttsProvider: 'google'
});
return callback(null, twiml);
```

```javascript
// Minimal WebSocket handler (3 events)
ws.on('message', (data) => {
  const msg = JSON.parse(data);
  if (msg.type === 'setup') { /* session started, msg.callSid available */ }
  if (msg.type === 'prompt') {
    ws.send(JSON.stringify({ type: 'text', token: 'Hello! How can I help?' }));
  }
  if (msg.type === 'interrupt') { /* user interrupted, stop current response */ }
});
```

## Basic TwiML Setup

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
const connect = twiml.connect();
connect.conversationRelay({
  url: 'wss://your-server.com/relay',
  voice: 'Google.en-US-Neural2-F',
  language: 'en-US'
});
return callback(null, twiml);
```

### Full Configuration

```javascript
connect.conversationRelay({
  url: 'wss://your-server.com/relay',        // WebSocket endpoint
  voice: 'Google.en-US-Neural2-F',                        // TTS voice
  language: 'en-US',                         // Language code
  transcriptionProvider: 'google',           // 'google' or 'deepgram'
  speechModel: 'telephony',                  // Speech recognition model
  profanityFilter: 'true',                   // Filter profanity
  dtmfDetection: 'true',                     // Detect DTMF tones
  interruptible: 'true',                     // Allow interruptions
  welcomeGreeting: 'Hello, how can I help?', // Initial greeting
  partialPrompts: 'true'                     // Enable partial transcripts
});
```

**Note**: `interruptByDtmf` is NOT a valid ConversationRelay attribute. DTMF detection is controlled by `dtmfDetection`, and interruption behavior is controlled by `interruptible`.

## WebSocket Protocol

### Incoming (from Twilio)

| Type | Key Fields | Description |
|------|-----------|-------------|
| `setup` | `callSid`, `streamSid`, `from`, `to` | Connection established |
| `prompt` | `voicePrompt`, `confidence`, `last` | User speech (process when `last: true`) |
| `dtmf` | `digit` | DTMF tone detected |
| `interrupt` | — | User interrupted AI response |

### Outgoing (to Twilio)

| Type | Key Fields | Description |
|------|-----------|-------------|
| `text` | `token` | TTS response (stream individual tokens for natural speech) |
| `end` | — | End the conversation |

### Message Examples

```json
// Setup
{ "type": "setup", "callSid": "CA...", "streamSid": "MZ...", "from": "+1234567890", "to": "+0987654321" }

// Prompt (user speech)
{ "type": "prompt", "voicePrompt": "Hello, I need help with my account", "confidence": 0.95, "last": true }

// DTMF
{ "type": "dtmf", "digit": "1" }

// Interrupt
{ "type": "interrupt" }

// Text response (TTS)
{ "type": "text", "token": "Hello! I'd be happy to help you with your account." }

// End session
{ "type": "end" }
```

## WebSocket Server Implementation Pattern

```javascript
// Example WebSocket handler (Node.js with ws library)
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws) => {
  let callContext = {};

  ws.on('message', async (data) => {
    const message = JSON.parse(data);

    switch (message.type) {
      case 'setup':
        callContext = {
          callSid: message.callSid,
          from: message.from,
          to: message.to
        };
        break;

      case 'prompt':
        if (message.last) {
          // Process with your LLM
          const response = await processWithLLM(message.voicePrompt);
          ws.send(JSON.stringify({
            type: 'text',
            token: response
          }));
        }
        break;

      case 'dtmf':
        // Handle DTMF digit
        break;

      case 'interrupt':
        // User interrupted, stop current response
        break;
    }
  });

  ws.on('close', () => {
    // Cleanup
  });
});
```

## Integration with Claude/LLMs

### Anthropic Claude Integration (Streaming — Recommended for Voice)

Streaming delivers tokens as they're generated, enabling natural real-time voice:

```javascript
const Anthropic = require('@anthropic-ai/sdk');
const anthropic = new Anthropic();

async function processWithLLM(systemPrompt, messages, ws) {
  const stream = await anthropic.messages.stream({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1024,
    system: systemPrompt,
    messages: messages,
  });

  stream.on('text', (text) => {
    ws.send(JSON.stringify({ type: 'text', token: text }));
  });

  const finalMessage = await stream.finalMessage();
  return finalMessage.content[0].text;
}
```

### Anthropic Claude Integration (Non-Streaming)

```javascript
async function processWithLLM(userMessage) {
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1024,
    messages: [
      { role: 'user', content: userMessage }
    ]
  });

  return response.content[0].text;
}
```

**Anthropic Message Format Gotcha**: When passing conversation history to Anthropic's API, only `role` and `content` are allowed. Extra fields like `timestamp` will cause "Extra inputs are not permitted" errors:

```javascript
// WRONG - will fail if messages have extra fields
messages: conversationHistory

// CORRECT - strip to only role and content
messages: conversationHistory.map(m => ({
  role: m.role,
  content: m.content
}))
```

### OpenAI Integration
```javascript
const OpenAI = require('openai');
const openai = new OpenAI();

async function processWithLLM(userMessage) {
  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      { role: 'user', content: userMessage }
    ]
  });

  return response.choices[0].message.content;
}
```

### Recommended Models

| Provider | Model | Best For |
|----------|-------|----------|
| Anthropic | `claude-sonnet-4-20250514` | Best balance of quality and latency |
| Anthropic | `claude-haiku-4-5-20251001` | Fastest, good for simple interactions |
| OpenAI | `gpt-4o` | Best quality |
| OpenAI | `gpt-4o-mini` | Faster, lower cost |

## Voice & Transcription Options

**Important**: Some voice/provider combos cause error 64101. Google Neural voices are recommended. Polly voices may be blocked.

### Google Voices (Recommended)

- `Google.en-US-Neural2-F` - US English, Female (default for Voice AI Builder)
- `Google.en-US-Neural2-J` - US English, Male
- `Google.en-US-Neural2-A` - US English Neural
- `Google.en-GB-Neural2-B` - British English Neural

### Amazon Polly Voices (May Be Blocked)

- `Polly.Amy` - British English, Female
- `Polly.Brian` - British English, Male
- `Polly.Joanna` - US English, Female
- `Polly.Matthew` - US English, Male

### Transcription Providers

| Provider | Best For |
|----------|----------|
| `google` | Default, good accuracy, wide language support |
| `deepgram` | Noisy environments, faster latency |

### Speech Models

| Model | Best For |
|-------|----------|
| `telephony` | Phone calls (recommended — optimized for 8kHz audio) |
| `default` | General purpose |

## Context Management Strategies

Voice calls can last many turns. Without context management, LLM context windows overflow on long calls.

### Sliding Window (Recommended for Voice)

Keep only the last N messages:

```javascript
function manageContext(messages) {
  const WINDOW_SIZE = 20;
  return messages.length > WINDOW_SIZE
    ? messages.slice(-WINDOW_SIZE)
    : messages;
}
```

### Summary

Periodically summarize older messages and replace history:

```javascript
async function manageContext(messages) {
  if (messages.length > 30) {
    const summary = await summarizeConversation(messages.slice(0, -10));
    return [
      { role: 'user', content: `Previous conversation summary: ${summary}` },
      ...messages.slice(-10),
    ];
  }
  return messages;
}
```

### Full History

Keep all messages. Risk of context overflow on long calls — only use for short interactions.

## Prerequisites

### Voice Intelligence Service

You must create a CI Service in the Twilio Console (no API for this). Go to Console > Voice > Voice Intelligence > Create new Service > copy the `GA...` SID > add to `.env` as `TWILIO_INTELLIGENCE_SERVICE_SID`.

Without this, transcript creation fails with 404.

### Dual Service Pattern

| Service | Env Var | Operators | Use Case |
|---------|---------|-----------|----------|
| Auto-analyze | `TWILIO_INTELLIGENCE_SERVICE_SID` | Summary + Sentiment (auto) | Validation, demo calls |
| Manual | `TWILIO_INTELLIGENCE_SERVICE_MANUAL_SID` | None | Manual transcript creation |

**Why two?** Operators are per-service and auto-run on all transcripts. No per-transcript bypass. PII redaction is also per-service — separate services for redacted vs unredacted access.

### Transcript Creation

Use `source_sid` (not `media_url`) for Twilio recordings — Intelligence API can't authenticate to api.twilio.com. Language Operators run automatically when configured on the service.

```javascript
// WRONG - Intelligence API can't authenticate to api.twilio.com
const channel = {
  media_properties: {
    media_url: `https://api.twilio.com/.../Recordings/${recordingSid}.mp3`,
  },
  participants: [...]
};

// CORRECT - Use source_sid for Twilio recordings
const channel = {
  media_properties: {
    source_sid: recordingSid,  // e.g., "RE1234567890abcdef"
  },
  participants: [
    { channel_participant: 1, user_id: 'caller' },
    { channel_participant: 2, user_id: 'agent' },
  ],
};

const transcript = await client.intelligence.v2.transcripts.create({
  serviceSid: intelligenceServiceSid,
  channel,
  customerKey: callSid,  // For correlation
});
```

## ConversationRelay in Conferences

Each agent's CR runs on their individual call leg (child), while conference membership is on the parent leg. Audio bridges through. Use the Participants API to add agents — `make_call(url=conference-TwiML)` won't work because the `url` parameter only controls the parent leg.

### Pattern: Participants API + ConversationRelay Webhooks

```javascript
// 1. Configure each agent's phone with ConversationRelay webhook
//    Agent A: agent-a-inbound -> ConversationRelay to wss://agent-a-server
//    Agent B: agent-b-inbound -> ConversationRelay to wss://agent-b-server

// 2. Create conference and add customer
const customerCall = await client.calls.create({
  to: customerPhone,        // Phone with ConversationRelay webhook
  from: servicePhone,
  url: customerLegUrl,       // TwiML: <Dial><Conference>name</Conference></Dial>
});

// 3. Add agent via Participants API
await client.conferences(conferenceSid)
  .participants.create({
    from: servicePhone,
    to: agentPhone,          // Phone with ConversationRelay webhook
  });
// Agent's phone webhook fires -> ConversationRelay on child leg
// Parent leg auto-joins conference -> audio bridges through
```

### Why `make_call(url=conference-TwiML)` Fails for ConversationRelay

When `make_call(to=TwilioNumber, url=conference-joining-TwiML)`:
- Parent leg: runs the `url` TwiML -> joins conference
- Child leg: runs the phone's webhook

If the phone's webhook is NOT ConversationRelay, the agent's WebSocket never connects. The `url` parameter only controls the parent leg — it cannot set up ConversationRelay.

### Not Compatible: Media Streams (`<Connect><Stream>`)

ConversationRelay and Media Streams use incompatible WebSocket protocols:
- **ConversationRelay**: JSON messages with transcribed text. Twilio handles STT/TTS.
- **Media Streams**: Raw base64 mulaw 8kHz audio frames. Handler must implement its own STT/TTS.

A ConversationRelay WebSocket handler cannot be used with `<Stream>` and vice versa.

## Local Development with ngrok

For local WebSocket development, use ngrok to expose your local server:

### Setup ngrok

1. **Install ngrok**

   ```bash
   # macOS
   brew install ngrok

   # Or download from https://ngrok.com/download
   ```

2. **Configure ngrok auth token**

   ```bash
   ngrok config add-authtoken YOUR_AUTH_TOKEN
   ```

3. **Start your WebSocket server locally**

   ```bash
   node websocket-server.js  # Runs on port 8080
   ```

4. **Expose with ngrok**

   ```bash
   ngrok http 8080
   ```

5. **Use the ngrok URL in your function**

   ```javascript
   connect.conversationRelay({
     url: 'wss://abc123.ngrok.io/relay',  // Use the ngrok URL
     voice: 'Polly.Amy'
   });
   ```

### ngrok Configuration for WebSockets

For a stable development URL, use a custom domain (requires paid ngrok):

```bash
ngrok http 8080 --domain=your-domain.ngrok.dev
```

This gives you a consistent URL: `wss://your-domain.ngrok.dev`

### Agent-to-Agent Testing (Dual Tunnel Setup)

Agent-to-agent testing requires **two separate ngrok tunnels** — one per agent. Each tunnel needs its own domain since ngrok only allows one endpoint per domain.

```bash
# Terminal A: Agent A (questioner) on port 8080
ngrok http 8080 --domain=zembla.ngrok.dev

# Terminal B: Agent B (answerer) on port 8081
ngrok http 8081 --domain=submariner.ngrok.io
```

Then set the relay URLs on the deployed Twilio service:
```bash
twilio serverless:env:set --key AGENT_A_RELAY_URL \
  --value "wss://zembla.ngrok.dev" \
  --environment dev-environment \
  --service-sid YOUR_SERVICE_SID

twilio serverless:env:set --key AGENT_B_RELAY_URL \
  --value "wss://submariner.ngrok.io" \
  --environment dev-environment \
  --service-sid YOUR_SERVICE_SID
```

### Development Workflow

1. Start WebSocket server locally (port 8080)
2. Start ngrok tunnel: `ngrok http 8080 --domain=your-domain.ngrok.dev`
3. Update `CONVERSATION_RELAY_URL` in `.env` with ngrok URL
4. Start Twilio serverless: `npm run start:ngrok`
5. Call your Twilio number to test

### Debugging WebSocket Traffic

ngrok provides a web interface at `http://localhost:4040` to inspect WebSocket traffic in real-time.

## Best Practices

1. **Handle Interruptions**: Users may interrupt the AI mid-sentence. Handle the `interrupt` message to stop current output.

2. **Use Streaming**: For long responses, stream text tokens individually for natural conversation flow.

3. **Manage Latency**: Keep LLM response times low for natural conversation. Consider using faster models for time-sensitive responses.

4. **Handle Silence**: Implement timeout handling for long silences.

5. **Graceful Endings**: Send the `end` message when the conversation should conclude.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| AI greets but doesn't respond to speech | Using `isFinal` instead of `last` in prompt handler | Check for `message.last` instead of `message.isFinal` |
| "Extra inputs are not permitted" from Anthropic | Passing extra fields (timestamp, etc.) in messages array | Strip messages to only `role` and `content` fields |
| WebSocket doesn't connect | URL not HTTPS/WSS | Use ngrok HTTPS URL, convert to `wss://` |
| No transcript created after call | Missing Sync Service SID | Ensure `TWILIO_SYNC_SERVICE_SID` is set in environment |
| Call connects but no audio | WebSocket server not responding | Check WebSocket server logs, verify connection |
| Interruption not working | `interruptible` not set to `'true'` | Add `interruptible: 'true'` to ConversationRelay config |
| DTMF not detected | `dtmfDetection` not enabled | Add `dtmfDetection: 'true'` to ConversationRelay config |
| Partial transcripts missing | `partialPrompts` not enabled | Add `partialPrompts: 'true'` for streaming transcripts |
| Transcript status "error" | Using media_url for Twilio recordings | Use `source_sid: RecordingSid` instead of `media_url` - Intelligence API can't authenticate to api.twilio.com |
| Call says "not configured" (8s) | CONVERSATION_RELAY_URL not set after deploy | Redeploy with correct env var or set in Twilio Console |
| Transcript callback skipping | Checking for `status === 'completed'` | Voice Intelligence sends `event_type: voice_intelligence_transcript_available`, not `status` |
| "Unique name already exists" on callback | Twilio sends duplicate callbacks | Handle error 54301 gracefully - document was created on first callback |
| Error 82005 in notifications | Function has a stray `console.error()` call | Replace with `console.log()` — never use `console.error()` in Twilio Functions |
| ngrok tunnel dies during long session | Tunnel expires or disconnects, WebSocket URL becomes unreachable | Verify tunnel is alive (`curl localhost:4040`) before each agent-to-agent call; kill and restart if dead |

## Logging and Response Rules

Use `console.log` for **all** logging in Twilio Functions, including error conditions and catch blocks. `console.error()` generates 82005 alerts and `console.warn()` generates 82004 alerts — never use either.

Always pass a string to `Twilio.Response.setBody()`:

```javascript
// WRONG — triggers Buffer TypeError
response.setBody({ success: true });

// RIGHT — explicit JSON serialization
response.setBody(JSON.stringify({ success: true }));
```

## Environment Variables

```text
CONVERSATION_RELAY_URL=wss://your-server.com/relay
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
```
