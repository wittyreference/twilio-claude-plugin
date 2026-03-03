---
name: tool-boundaries
description: Architectural boundaries between MCP Server, Twilio CLI, Serverless Toolkit, and Functions. Golden Rules, Risk Tiers, and decision flowchart for when to use each tool.
---

# Tool Boundaries Reference

This document defines the architectural boundaries between MCP Server, Twilio CLI, Serverless Toolkit, and Twilio Functions. Use this as a decision guide when implementing new capabilities.

---

## Component Overview

| Component | Purpose | Runtime | Output Type |
|-----------|---------|---------|-------------|
| **MCP Server** | Agent-accessible Twilio API wrapper | In-process with Claude Agent SDK | JSON data |
| **Twilio CLI** | DevOps/admin interface for humans | Terminal / CI pipelines | Commands + logs |
| **Serverless Toolkit** | Deployment mechanism (CLI plugin) | CLI plugin | Deployed code |
| **Twilio Functions** | Webhook handlers on Twilio infra | Twilio's Node.js runtime | TwiML / JSON |

---

## The Golden Rules

1. **MCP = Data Operations**: Query, send, create records. Never deploy or delete infrastructure.
2. **CLI = Infrastructure Operations**: Deploy, configure environments, purchase numbers.
3. **Functions = Real-Time Webhooks**: Handle calls/messages, return TwiML.
4. **Never Cross Layers**: MCP does not invoke CLI. Functions do not use MCP.

---

## Operation Risk Tiers

### Tier 1: Safe (Agent Autonomous)

Read-only operations agents can perform freely via MCP tools.

| Operation | MCP Tool | Notes |
|-----------|----------|-------|
| Query message history | `get_message_logs` | Filtered by date, phone, status |
| Query call history | `get_call_logs` | Filtered by date, phone, status |
| Get debugger alerts | `get_debugger_logs` | Error analysis, monitoring |
| Get usage records | `get_usage_records` | Billing, cost analysis |
| List phone numbers | `list_phone_numbers` | Inventory check |
| Search available numbers | `search_available_numbers` | Research only, no purchase |
| Get Sync document | `get_document` | State retrieval |
| List TaskRouter workers | `list_workers` | Availability check |
| Get TaskRouter queue stats | `get_queue_statistics` | Real-time operational metrics |

### Tier 2: Controlled (Agent with Guardrails)

Write operations agents can perform with rate limits or validation.

| Operation | MCP Tool | Guardrail |
|-----------|----------|-----------|
| Send SMS | `send_sms` | Rate limit: 10/minute, validated E.164 |
| Send MMS | `send_mms` | Rate limit: 10/minute, media URL validation |
| Make outbound call | `make_call` | Rate limit: 5/minute, validated E.164 |
| Start verification | `start_verification` | Rate limit: 5/minute per recipient |
| Create Sync document | `create_document` | Namespace isolation for agent state |
| Update Sync document | `update_document` | Agent-owned documents only |
| Create TaskRouter task | `create_task` | Priority caps, timeout limits |

### Tier 3: Supervised (Human Confirmation Required)

| Operation | Tool | Why Supervised |
|-----------|------|----------------|
| Configure webhook URLs | MCP: `configure_webhook` | Changes production routing |
| Deploy to production | CLI: `serverless:deploy --environment production` | Production infrastructure change |
| Purchase phone number | CLI: `phone-numbers:buy:*` | Financial commitment |

### Tier 4: Prohibited (Never Autonomous)

| Operation | Why Prohibited |
|-----------|----------------|
| Delete phone numbers | Irreversible, financial impact |
| Close/suspend account | Catastrophic |
| Force push to git | Data loss potential |
| Deploy without tests passing | Quality gate bypass |
| Commit with `--no-verify` | Hook bypass |

---

## When to Use Each Component

### Use MCP Server When

- Agent needs to **query** Twilio data (logs, status, lookups)
- Agent is **sending test messages** or making test calls
- Agent is **managing Sync state** for its own memory
- Agent is **creating TaskRouter tasks** for orchestration
- Agent needs **structured JSON responses** for reasoning

### Use Twilio CLI When

- **Deploying** serverless functions (`serverless:deploy`)
- **Local development** server (`serverless:start --ngrok`)
- **Purchasing** phone numbers (requires human approval)
- **Managing** CLI profiles and credentials
- **Rollback** operations (`serverless:activate`)

### Use Twilio Functions When

- Handling **inbound webhooks** (calls, messages)
- Response must be **TwiML**
- Operation is **triggered by real Twilio events**
- **Low-latency** is required (deployed on Twilio infra)
- Need **Twilio request signature validation** (`.protected.js`)

---

## Overlapping Functionality Resolution

### SMS Sending

| Tool | Use When |
|------|----------|
| MCP `send_sms` | Agent-initiated: testing, debugging, proactive notifications |
| Function handler | Event-triggered: after call, verification success, workflow step |
| CLI `api:core:messages:create` | Human debugging, one-off manual sends |

**Rule**: Use MCP when agent decides to send. Use Function when event triggers sending.

### Phone Number Configuration

| Tool | Use When |
|------|----------|
| MCP `configure_webhook` | Automated configuration during deployment pipelines |
| CLI `phone-numbers:update` | Interactive setup, one-time manual configuration |

**Rule**: Both require Tier 3 approval for production. MCP for automation, CLI for manual.

---

## Decision Flowchart

```
Is this a webhook response to an inbound call/message?
├─ Yes → Use Functions (.js or .protected.js)
└─ No → Continue

Does the operation deploy or modify infrastructure?
├─ Yes → Use CLI (human approval required)
└─ No → Continue

Is this triggered by a real-time Twilio event?
├─ Yes → Use Functions
└─ No → Continue

Does the agent need to perform this operation?
├─ Yes → Use MCP Server tool
└─ No → Use CLI for manual operation

Is the operation read-only?
├─ Yes → MCP Tier 1 (autonomous)
└─ No → Does it cost money or affect production?
    ├─ Yes → MCP Tier 2/3 (guardrails/approval)
    └─ No → MCP Tier 2 (with rate limits)
```

---

## Anti-Patterns to Avoid

### 1. MCP Invoking CLI Commands

```typescript
// DON'T DO THIS
const deployTool = {
  name: 'deploy_functions',
  handler: async () => {
    exec('twilio serverless:deploy');  // WRONG
  }
};
```

**Why**: Violates pure API principle. Deployment requires human oversight.

### 2. Functions Calling MCP

```javascript
// DON'T DO THIS in a Function
const mcpServer = require('../mcp-servers/twilio');
await mcpServer.tools.send_sms({ to, body });  // WRONG
```

**Why**: Functions have direct SDK access via `context.getTwilioClient()`. MCP is for agent orchestration.

### 3. Agent Deploying Autonomously

```
Agent: "I'll deploy these changes now."
*runs twilio serverless:deploy*  // WRONG
```

**Why**: Deployment is Tier 3 (requires human approval). Pre-bash hooks block this anyway.
