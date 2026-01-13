---
name: twilio-cli
description: Comprehensive Twilio CLI and Serverless Toolkit reference. Use when deploying, managing phone numbers, or using CLI commands.
---

# Twilio CLI Skill

Comprehensive reference for Twilio CLI operations. This document covers command patterns, gotchas, and the full command hierarchy to prevent trial-and-error token consumption.

## Command Structure Patterns

Understanding CLI patterns prevents guessing at command syntax.

### Universal Pattern
```
twilio <topic>:<subtopic>:<resource>:<action> [--flags]
```

### Action Verbs (CRUD)
| Action | Purpose | Example |
|--------|---------|---------|
| `create` | Create resource | `api:core:messages:create` |
| `fetch` | Get single resource | `api:core:calls:fetch --sid CAxx` |
| `list` | List resources | `api:core:recordings:list` |
| `update` | Modify resource | `api:core:calls:update --sid CAxx` |
| `remove` | Delete resource | `api:core:recordings:remove --sid RExx` |

### SID Prefix Reference
| Prefix | Resource Type | Example |
|--------|---------------|---------|
| `AC` | Account | `ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `CA` | Call | `CAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `SM` | Message | `SMxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `PN` | Phone Number | `PNxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `VA` | Verify Service | `VAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `IS` | Sync Service | `ISxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `WS` | TaskRouter Workspace | `WSxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `WW` | TaskRouter Workflow | `WWxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `WK` | TaskRouter Worker | `WKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `ZS` | Serverless Service | `ZSxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `ZE` | Serverless Environment | `ZExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `ZN` | Serverless Function | `ZNxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `ZB` | Serverless Build | `ZBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `MS` | Messaging Service | `MSxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `RE` | Recording | `RExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `CF` | Conference | `CFxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `SK` | API Key | `SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |

### Global Flags (All Commands)
| Flag | Short | Description |
|------|-------|-------------|
| `--help` | `-h` | Show help |
| `--log-level` | `-l` | `debug`, `info`, `warn`, `error`, `none` |
| `--output` | `-o` | `columns`, `json`, `tsv`, `none` |
| `--silent` | | Suppress output (`-l none -o none`) |
| `--profile` | `-p` | Use specific profile |
| `--properties` | | Columns to display |
| `--no-header` | | Skip header row |
| `--limit` | | Max resources (default 50) |

---

## Serverless Toolkit (`twilio serverless:*`)

The Twilio Serverless Toolkit provides a complete development environment for building, testing, and deploying Twilio Functions and Assets.

### Command Reference

| Command | Description |
|---------|-------------|
| `serverless:init <name>` | Create new project |
| `serverless:start` | Local development server (aliases: `dev`, `run`) |
| `serverless:deploy` | Deploy to Twilio |
| `serverless:list` | List deployed services/environments/functions/assets |
| `serverless:logs` | View function logs |
| `serverless:promote` | Promote between environments |
| `serverless:activate` | Rollback to previous build |
| `serverless:new` | Create function from template |
| `serverless:list-templates` | Show available templates |
| `serverless:env:*` | Manage remote environment variables |

### `serverless:start` - Local Development

```bash
# Basic (port 3000)
twilio serverless:start

# With ngrok tunnel (for webhooks)
twilio serverless:start --ngrok

# Combined (recommended for development)
twilio serverless:start --ngrok --detailed-logs --live
```

### `serverless:deploy` - Deployment

```bash
# Deploy to default environment (dev)
twilio serverless:deploy

# Deploy to specific environment
twilio serverless:deploy --environment production

# Specify Node.js runtime version
twilio serverless:deploy --runtime node22
```

### Gotchas - Serverless Deploy

- **Runtime version**: Default runtime may be outdated. Explicitly set `--runtime node22` for latest features
- **Environment names**: Names become URL suffixes (e.g., `foo-1234-dev.twil.io`). Use `--production` for clean URLs
- **Protected functions**: `.protected.js` suffix requires valid Twilio signature
- **Private functions**: `.private.js` suffix = not exposed as endpoint, only callable internally

---

## Phone Numbers (`twilio phone-numbers:*`)

```bash
# List all numbers on account
twilio phone-numbers:list

# Update webhook URLs
twilio phone-numbers:update +1234567890 \
  --sms-url https://example.com/sms \
  --voice-url https://example.com/voice
```

### Search & Purchase Numbers

```bash
# Search for available US numbers
twilio api:core:available-phone-numbers:local:list \
  --country-code US \
  --area-code 415

# Purchase a number
twilio api:core:incoming-phone-numbers:create \
  --phone-number +14155551234
```

---

## Debugger & Logs (`twilio debugger:*`)

```bash
# Recent errors (default limit 50)
twilio debugger:logs:list

# Filter by log level
twilio debugger:logs:list --log-level error

# Output as JSON (for parsing/scripting)
twilio debugger:logs:list -o json
```

---

## API Commands (`twilio api:*`)

### Messages

```bash
# Send SMS
twilio api:core:messages:create \
  --to +1234567890 \
  --from +0987654321 \
  --body "Hello from CLI"

# List recent messages
twilio api:core:messages:list --limit 10
```

### Calls

```bash
# Make outbound call with TwiML URL
twilio api:core:calls:create \
  --to +1234567890 \
  --from +0987654321 \
  --url https://example.com/twiml

# Hangup active call
twilio api:core:calls:update --sid CAxxxxxxxx --status completed
```

### Verify

```bash
# Start verification (SMS)
twilio api:verify:v2:services:verifications:create \
  --service-sid VAxxxxxxxx \
  --to +1234567890 \
  --channel sms

# Check verification code
twilio api:verify:v2:services:verification-checks:create \
  --service-sid VAxxxxxxxx \
  --to +1234567890 \
  --code 123456
```

---

## Common Workflows

### Development Cycle

```bash
# 1. Start local server with ngrok
twilio serverless:start --ngrok --live

# 2. Update phone number webhooks to ngrok URL
twilio phone-numbers:update +1234567890 \
  --sms-url https://abc123.ngrok.io/sms \
  --voice-url https://abc123.ngrok.io/voice

# 3. Deploy to dev
twilio serverless:deploy --environment dev --runtime node22
```

### Deploy to Production

```bash
# 1. Deploy to staging first
twilio serverless:deploy --environment staging --runtime node22

# 2. Promote to production
twilio serverless:promote \
  --service-sid ZSxxxx \
  --source-environment staging \
  --environment production
```

---

## Quick Reference Card

| Task | Command |
|------|---------|
| **Local Development** | |
| Start local dev | `twilio serverless:start` |
| Start with tunnel | `twilio serverless:start --ngrok --live` |
| **Deployment** | |
| Deploy to dev | `twilio serverless:deploy --environment dev --runtime node22` |
| Deploy to prod | `twilio serverless:deploy --production --runtime node22` |
| **Logs & Debugging** | |
| Check errors | `twilio debugger:logs:list --limit 10` |
| View live logs | `twilio serverless:logs --service-sid X --environment Y --tail` |
| **Resources** | |
| List services | `twilio serverless:list services` |
| List numbers | `twilio phone-numbers:list` |
| **Testing** | |
| Send test SMS | `twilio api:core:messages:create --to X --from Y --body Z` |
| Make test call | `twilio api:core:calls:create --to X --from Y --url Z` |

---

## Critical Gotchas

| Issue | Problem | Solution |
|-------|---------|----------|
| `--limit` default | Only returns 50 records | Add `--limit 500` or `--no-limit` |
| `--runtime` not set | Deploys to old Node version | Always add `--runtime node22` |
| Profile forgotten | Wrong account deployed to | Always verify with `twilio profiles:list` |
| E.164 format required | `1234567890` fails | Always use `+1234567890` |
