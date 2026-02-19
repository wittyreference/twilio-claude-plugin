---
name: conversation-relay
description: Real-time voice AI with ConversationRelay WebSocket protocol. Use when building voice assistants, AI agents, or real-time transcription.
---

# ConversationRelay Skill

Knowledge for building Twilio ConversationRelay functions for real-time voice AI applications.

## What is ConversationRelay?

ConversationRelay enables real-time, bidirectional communication between phone calls and AI/LLM backends via WebSockets. It handles:
- Real-time speech transcription
- Text-to-speech synthesis
- Audio streaming
- DTMF detection
- Interruption handling

## TwiML Setup

### Basic Connection
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
  voice: 'Google.en-US-Neural2-F',           // TTS voice (use Google Neural, not Polly)
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

## WebSocket Message Protocol

### Incoming Messages (from Twilio)

#### Setup Message
```json
{
  "type": "setup",
  "callSid": "CA...",
  "streamSid": "MZ...",
  "from": "+1234567890",
  "to": "+0987654321"
}
```

#### Prompt Message (User Speech)
```json
{
  "type": "prompt",
  "voicePrompt": "Hello, I need help with my account",
  "confidence": 0.95,
  "last": true
}
```

> **Critical**: The field is `last`, NOT `isFinal`. Checking `isFinal` silently drops all follow-up utterances.

#### DTMF Message
```json
{
  "type": "dtmf",
  "digit": "1"
}
```

#### Interrupt Message
```json
{
  "type": "interrupt"
}
```

### Outgoing Messages (to Twilio)

#### Text Response (TTS)
```json
{
  "type": "text",
  "token": "Hello! I'd be happy to help you with your account."
}
```

#### End Session
```json
{
  "type": "end"
}
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

### Anthropic Claude Integration
```javascript
const Anthropic = require('@anthropic-ai/sdk');
const anthropic = new Anthropic();

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

### OpenAI Integration
```javascript
const OpenAI = require('openai');
const openai = new OpenAI();

async function processWithLLM(userMessage) {
  const response = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [
      { role: 'user', content: userMessage }
    ]
  });

  return response.choices[0].message.content;
}
```

## Voice Options

> **Important**: Use Google Neural voices for ConversationRelay. Polly voices may be blocked (error 64101).

### Google Neural Voices (Recommended)
- `Google.en-US-Neural2-F` - US English, Female (recommended default)
- `Google.en-US-Neural2-A` - US English, Male
- `Google.en-GB-Neural2-B` - British English, Male
- `Google.en-GB-Neural2-F` - British English, Female

### Amazon Polly Voices (May Not Work)
- `Polly.Amy` - British English, Female
- `Polly.Joanna` - US English, Female
- Polly voices may be blocked by ConversationRelay with error 64101. Use Google Neural voices instead.

## Best Practices

1. **Handle Interruptions**: Users may interrupt the AI mid-sentence. Handle the `interrupt` message to stop current output.

2. **Use Streaming**: For long responses, stream text tokens individually for natural conversation flow.

3. **Manage Latency**: Keep LLM response times low for natural conversation. Consider using faster models for time-sensitive responses.

4. **Handle Silence**: Implement timeout handling for long silences.

5. **Graceful Endings**: Send the `end` message when the conversation should conclude.

## Local Development with ngrok

For local WebSocket development, use ngrok to expose your local server:

### Setup ngrok

1. **Install ngrok**
   ```bash
   # macOS
   brew install ngrok
   ```

2. **Start your WebSocket server locally**
   ```bash
   node websocket-server.js  # Runs on port 8080
   ```

3. **Expose with ngrok**
   ```bash
   ngrok http 8080
   ```

4. **Use the ngrok URL in your function**
   ```javascript
   connect.conversationRelay({
     url: 'wss://abc123.ngrok.io/relay',  // Use the ngrok URL
     voice: 'Google.en-US-Neural2-F'
   });
   ```

## Environment Variables

```text
CONVERSATION_RELAY_URL=wss://your-server.com/relay
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
```
