---
name: getting-started
description: Set up a new Twilio serverless project from scratch. Use when starting a new project, scaffolding directory structure, or configuring deployment.
---

# Getting Started with Twilio Serverless

Guide for scaffolding a new Twilio serverless project from an empty directory to first deploy.

## Prerequisites

- Node.js 18+
- Twilio account with Account SID and Auth Token
- Twilio CLI: `npm install -g twilio-cli`
- Serverless plugin: `twilio plugins:install @twilio-labs/plugin-serverless`

## Project Setup

### 1. Initialize

```bash
mkdir my-twilio-project && cd my-twilio-project
npm init -y
npm install twilio @twilio-labs/serverless-runtime-types
```

### 2. Create Directory Structure

```
my-twilio-project/
├── functions/          # Serverless functions (auto-routed as endpoints)
│   └── hello.js        # → /hello endpoint
├── assets/             # Static files (HTML, audio, images)
├── .env                # Environment variables (never commit)
├── .twiliodeployinfo   # Deploy state (auto-generated, gitignore)
└── package.json
```

### 3. Create `.env`

```bash
# Required for deployment (twilio-run reads these WITHOUT the TWILIO_ prefix)
ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AUTH_TOKEN=your-auth-token

# Also set prefixed versions for your function code
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your-auth-token
TWILIO_PHONE_NUMBER=+1xxxxxxxxxx
```

**Important**: `twilio-run` (the serverless runtime) reads `ACCOUNT_SID` and `AUTH_TOKEN` without the `TWILIO_` prefix. If you only have `TWILIO_ACCOUNT_SID`, deployment fails with "Missing Credentials". Add both versions.

### 4. Create First Function

```javascript
// functions/hello.js
// ABOUTME: Simple hello world endpoint for testing deployment
// ABOUTME: Returns JSON greeting — verifies serverless runtime is working

exports.handler = function (context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  twiml.say({ voice: 'Google.en-US-Neural2-F' }, 'Hello from Twilio!');
  callback(null, twiml);
};
```

### 5. Add Scripts to package.json

```json
{
  "scripts": {
    "start": "twilio serverless:start --live",
    "start:ngrok": "twilio serverless:start --ngrok --live --detailed-logs",
    "deploy:dev": "twilio serverless:deploy --runtime node22",
    "deploy:prod": "twilio serverless:deploy --production --runtime node22"
  }
}
```

### 6. Create `.gitignore`

```
node_modules/
.env
.twiliodeployinfo
```

## Local Development

```bash
# Start local server (port 3000)
npm start

# Start with ngrok tunnel (required for webhooks)
npm run start:ngrok
```

The local server auto-reloads on file changes with `--live`.

## First Deploy

```bash
npm run deploy:dev
```

This creates a service on `your-project-XXXX-dev.twil.io`. The output shows your function URLs.

### Verify CLI Profile

Before deploying, check you're targeting the right account:

```bash
twilio profiles:list
```

The active profile (marked with `*`) determines which account gets the deployment.

## Function Access Levels

| Suffix | Access | Use Case |
|--------|--------|----------|
| `*.js` | Public | Webhooks, TwiML endpoints |
| `*.protected.js` | Protected | Callbacks (requires valid Twilio signature) |
| `*.private.js` | Private | Helpers (only callable from other functions) |

## Environment Variables in Functions

Access `.env` values via `context`:

```javascript
exports.handler = function (context, event, callback) {
  const phoneNumber = context.TWILIO_PHONE_NUMBER;
  const client = context.getTwilioClient();
  // ...
};
```

`context.getTwilioClient()` returns an authenticated Twilio REST client using the account credentials.

## Common Next Steps

After first deploy:

1. **Configure webhooks**: Point your Twilio phone number's voice/SMS URL to your deployed function
2. **Add recordings**: Use `<Start><Recording>` in TwiML (see `voice` skill)
3. **Add IVR**: Use `<Gather>` for speech/DTMF input (see `voice` skill)
4. **Add AI agent**: Use `<Connect><ConversationRelay>` (see `conversation-relay` skill)
5. **Add routing**: Use TaskRouter for skills-based routing (see `taskrouter` skill)

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "Missing Credentials" on deploy | `.env` has `TWILIO_ACCOUNT_SID` but not `ACCOUNT_SID` | Add unprefixed `ACCOUNT_SID` and `AUTH_TOKEN` |
| Deploy goes to wrong account | CLI profile mismatch | Run `twilio profiles:list`, switch with `twilio profiles:use <name>` |
| Function returns 403 | `.protected.js` requires Twilio signature | Use `.js` for public endpoints or call from Twilio |
| `.twiliodeployinfo` conflicts | Deploying to different service | Delete `.twiliodeployinfo` and redeploy |
| Env vars reset after deploy | `serverless:deploy` doesn't preserve runtime env vars | Re-set with `twilio serverless:env:set` after deploy |
