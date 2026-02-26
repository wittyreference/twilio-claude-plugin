---
name: agent-testing
description: Automated voice testing with agent-to-agent calls. Use when building test infrastructure for voice apps, IVRs, or AI agents.
---

# Agent-to-Agent Voice Testing

Infrastructure for automated testing of Twilio voice applications using two AI agents that call each other.

## Concept

Instead of manually testing voice apps by phone, use two WebSocket-based agents:
- **Agent A** (questioner/caller): Initiates conversation, navigates IVRs, asks questions
- **Agent B** (answerer/recipient): Responds to prompts, simulates customers or agents

Both connect via ConversationRelay WebSocket protocol and use an LLM (Claude, GPT, etc.) to generate natural responses based on configurable system prompts.

## Architecture

```
┌─────────────┐    make_call     ┌──────────────┐
│ Test Script  │ ──────────────→ │ Twilio Voice  │
└─────────────┘                  │   Platform    │
                                 └──────┬───────┘
                          ┌─────────────┴──────────────┐
                     Parent Leg                    Child Leg
                   (outbound-api)                 (inbound)
                          │                            │
                    ┌─────┴─────┐              ┌──────┴──────┐
                    │ TwiML A   │              │  TwiML B    │
                    │ <Connect> │              │  <Connect>  │
                    │ <CR>      │              │  <CR>       │
                    └─────┬─────┘              └──────┬──────┘
                          │ wss://                     │ wss://
                    ┌─────┴─────┐              ┌──────┴──────┐
                    │  Agent A  │              │  Agent B    │
                    │ (port 8080)│              │ (port 8081) │
                    │ ngrok A   │              │  ngrok B    │
                    └───────────┘              └─────────────┘
```

## Setup

### 1. Two WebSocket Servers

Each agent runs its own WebSocket server with a configurable system prompt:

```javascript
const WebSocket = require('ws');
const Anthropic = require('@anthropic-ai/sdk');

const PORT = process.env.PORT || 8080;
const SYSTEM_PROMPT = process.env.SYSTEM_PROMPT || 'You are a helpful assistant.';

const anthropic = new Anthropic();
const wss = new WebSocket.Server({ port: PORT });

wss.on('connection', (ws) => {
  const messages = [];

  ws.on('message', async (data) => {
    const msg = JSON.parse(data);

    if (msg.type === 'prompt' && msg.last) {
      messages.push({ role: 'user', content: msg.voicePrompt });

      const stream = await anthropic.messages.stream({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 256,
        system: SYSTEM_PROMPT,
        messages: messages,
      });

      let fullResponse = '';
      stream.on('text', (text) => {
        ws.send(JSON.stringify({ type: 'text', token: text }));
        fullResponse += text;
      });

      await stream.finalMessage();
      messages.push({ role: 'assistant', content: fullResponse });
    }
  });
});

console.log(`Agent listening on port ${PORT}`);
```

### 2. Two ngrok Tunnels

Each agent needs its own ngrok tunnel (one endpoint per domain):

```bash
# Terminal 1: Agent A (questioner) on port 8080
ngrok http 8080 --domain=your-domain-a.ngrok.dev

# Terminal 2: Agent B (answerer) on port 8081
ngrok http 8081 --domain=your-domain-b.ngrok.dev
```

### 3. Two TwiML Functions

Each leg of the call needs a ConversationRelay function pointing to its agent:

```javascript
// functions/voice/agent-a-handler.js
exports.handler = function (context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  twiml.start().recording({
    recordingStatusCallback: `https://${context.DOMAIN_NAME}/callbacks/recording-status`,
  });
  const connect = twiml.connect();
  connect.conversationRelay({
    url: context.AGENT_A_RELAY_URL || 'wss://your-domain-a.ngrok.dev',
    voice: 'Google.en-US-Neural2-F',
    language: 'en-US',
    dtmfDetection: 'true',
    interruptible: 'true',
    welcomeGreeting: 'Hello, I am ready to begin the test.'
  });
  callback(null, twiml);
};

// functions/voice/agent-b-handler.js
exports.handler = function (context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  twiml.start().recording({
    recordingStatusCallback: `https://${context.DOMAIN_NAME}/callbacks/recording-status`,
  });
  const connect = twiml.connect();
  connect.conversationRelay({
    url: context.AGENT_B_RELAY_URL || 'wss://your-domain-b.ngrok.dev',
    voice: 'Google.en-US-Neural2-A',
    language: 'en-US',
    dtmfDetection: 'true',
    interruptible: 'true'
  });
  callback(null, twiml);
};
```

### 4. Initiate Test Call

Use `make_call` targeting a Twilio number. The `Url` parameter runs Agent A's TwiML on the parent leg, and the destination number's voice webhook runs Agent B's TwiML on the child leg.

```javascript
const call = await client.calls.create({
  to: '+1TWILIO_NUMBER_B',      // Number configured with agent-b-handler webhook
  from: context.TWILIO_PHONE_NUMBER,
  url: `https://${context.DOMAIN_NAME}/voice/agent-a-handler`,
  record: true,
  statusCallback: `https://${context.DOMAIN_NAME}/callbacks/call-status`,
});
```

## System Prompt Examples

### IVR Navigator (Agent A)
```
You are testing a phone IVR system. Navigate through the menus by speaking
your choices clearly. When prompted for a selection, say the option name
(e.g., "appointments" or "billing"). When asked for information, provide
test data. Report what you hear at each step.
```

### Customer Support Agent (Agent B)
```
You are a customer support agent for Acme Corp. Answer questions about
billing, shipping, and returns. Be helpful and professional. If asked
about an order, use order number ORD-12345 with status "shipped".
```

### Pizza Customer (Agent A)
```
You are a customer ordering a pizza. Order a large pepperoni pizza with
extra cheese for delivery to 123 Main Street. Confirm the order details
when asked. Provide phone number 555-0123 if requested.
```

## Alternative: Scripted Caller (No WebSocket)

For simpler tests, use `<Say>` TwiML instead of a full WebSocket agent:

```javascript
// functions/voice/test-caller.js — scripted prompts via TTS
exports.handler = function (context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  twiml.pause({ length: 3 });
  twiml.say({ voice: 'Google.en-US-Neural2-F' }, 'I would like to schedule an appointment.');
  twiml.pause({ length: 8 });
  twiml.say({ voice: 'Google.en-US-Neural2-F' }, 'My name is Jane Smith.');
  twiml.pause({ length: 8 });
  twiml.say({ voice: 'Google.en-US-Neural2-F' }, 'Yes, that sounds good. Thank you.');
  twiml.pause({ length: 5 });
  twiml.hangup();
  callback(null, twiml);
};
```

This is simpler to set up (no WebSocket server needed) and works well for IVR navigation testing where responses are predictable.

## Validation After Test

Use MCP validation tools to verify test results:

```
validate_call — Check call completed without errors
validate_recording — Verify recordings captured both parties
validate_transcript — Check Voice Intelligence transcription quality
validate_two_way — Validate bidirectional conversation (both parties spoke)
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Busy signal / no audio | ngrok tunnel died | Verify tunnels: `curl localhost:4040/api/tunnels` |
| One-sided conversation | Agent B's TwiML not configured | Check destination number's voice webhook URL |
| Agent loops / repeats | Missing `last` check | Only process `prompt` messages where `msg.last === true` |
| Call drops after 15s | WebSocket server not responding | Check agent logs, verify ANTHROPIC_API_KEY is set |
| Both agents talk simultaneously | No turn-taking | Add system prompt instruction: "Wait for the other person to finish" |

## Environment Variables

```
AGENT_A_RELAY_URL=wss://your-domain-a.ngrok.dev
AGENT_B_RELAY_URL=wss://your-domain-b.ngrok.dev
NGROK_DOMAIN_A=your-domain-a.ngrok.dev
NGROK_DOMAIN_B=your-domain-b.ngrok.dev
ANTHROPIC_API_KEY=sk-ant-...
```
