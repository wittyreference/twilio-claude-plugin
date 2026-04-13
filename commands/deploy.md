---
description: Deploy Twilio serverless functions. Use when user says deploy, ship, push to production, or go live with changes.
argument-hint: [environment]
---

# Deployment Helper

Deploy Twilio serverless functions across 3 services (core, ai, labs) via `scripts/deploy-services.sh`.

## Pre-Deployment Checklist

Before deploying, verify:

1. **All Tests Pass**
   ```bash
   npm test
   npm run test:e2e
   ```

2. **Linting Passes**
   ```bash
   npm run lint
   ```

3. **CLI Profile** — Verify active profile matches target account:
   ```bash
   twilio profiles:list
   ```

4. **No Uncommitted Changes**
   ```bash
   git status
   ```

## Deployment Commands

### Deploy All Services (Recommended)
```bash
./scripts/deploy-services.sh dev    # Deploy core + ai + labs to dev
./scripts/deploy-services.sh prod   # Deploy to production
```

### Deploy Single Service
```bash
./scripts/deploy-services.sh --only core dev
./scripts/deploy-services.sh --only ai dev
./scripts/deploy-services.sh --only labs dev
```

### Deploy Ephemeral Validation Service
```bash
./scripts/deploy-services.sh --only validation dev   # Deploy fresh
./scripts/deploy-services.sh --teardown validation    # Remove after testing
```

## Service Architecture

| Service | Directories | Env Var |
|---------|-------------|---------|
| `prototype-core` | voice, callbacks, helpers, messaging, messaging-services, taskrouter, verify, phone-numbers, proxy, sync, video | `CORE_BASE_URL` |
| `prototype-ai` | conversation-relay, webinar, helpers | `AI_BASE_URL` |
| `prototype-labs` | pay, sip, helpers | `LABS_BASE_URL` |
| `prototype-validation` | conversation-relay, callbacks, helpers, messaging (ephemeral) | `VALIDATION_BASE_URL` |

Manifest: `services.json`

## Post-Deployment

1. **Update `.env`** with domains from deploy output (CORE_BASE_URL, AI_BASE_URL, LABS_BASE_URL)
2. **Wire phone numbers**: Configure voice/messaging webhooks on your Twilio phone numbers via Console or CLI (see DESIGN_DECISIONS.md D45)
3. **Verify endpoints** — make test calls using MCP `make_call` / `send_sms`, validate with `validate_call(callSid)`
4. **Check debugger**: `validate_debugger(lookbackSeconds: 300)`

## Rollback

Each service can be rolled back independently:
```bash
twilio serverless:list builds --service-name prototype-core
twilio serverless:activate --build-sid BU_PREVIOUS_BUILD_SID --service-name prototype-core
```

## Environment Target

<user_request>
$ARGUMENTS
</user_request>
