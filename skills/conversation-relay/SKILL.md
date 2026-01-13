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
  voice: 'Polly.Amy',
  language: 'en-US'
});

return callback(null, twiml);
```

### Full Configuration
```javascript
connect.conversationRelay({
  url: 'wss://your-server.com/relay',        // WebSocket endpoint
  voice: 'Polly.Amy',                        // TTS voice
  language: 'en-US',                         // Language code
  transcriptionProvider: 'google',           // 'google' or 'deepgram'
  speechModel: 'telephony',                  // Speech recognition model
  profanityFilter: 'true',                   // Filter profanity
  dtmfDetection: 'true',                     // Detect DTMF tones
  interruptible: 'true',                     // Allow interruptions
  interruptByDtmf: 'true',                   // DTMF can interrupt
  welcomeGreeting: 'Hello, how can I help?', // Initial greeting
  partialPrompts: 'true'                     // Enable partial transcripts
});
```

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
  "isFinal": true
}
```

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
        if (message.isFinal) {
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

### Amazon Polly Voices
- `Polly.Amy` - British English, Female
- `Polly.Brian` - British English, Male
- `Polly.Joanna` - US English, Female
- `Polly.Matthew` - US English, Male
- `Polly.Ivy` - US English, Child Female

### Google Voices
- `Google.en-US-Neural2-A` - US English Neural
- `Google.en-GB-Neural2-B` - British English Neural

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
     voice: 'Polly.Amy'
   });
   ```

## Environment Variables

```text
CONVERSATION_RELAY_URL=wss://your-server.com/relay
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
```
