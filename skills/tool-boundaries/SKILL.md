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
5. **SID-First Principle**: When you have a specific resource SID (call, message, recording, transcript, task, room, trunk, Sync resource), always use the SID-targeted `validate_*` or `get_*` tool instead of listing and filtering. SID-targeted tools provide deep validation (status, notifications, insights, sub-resources) in a single call. Reserve `list_*` tools for discovery when you don't have a SID.

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
| List Sync documents | `list_documents` | State enumeration |
| List TaskRouter workers | `list_workers` | Availability check |
| List TaskRouter workflows | `list_workflows` | Routing config review |
| List TaskRouter task queues | `list_task_queues` | Queue topology discovery |
| Get TaskRouter queue stats | `get_queue_statistics` | Real-time operational metrics |
| List TaskRouter activities | `list_activities` | Worker state discovery |
| Get verification status | `get_verification_status` | Status check |
| Get payment status | `get_payment` | Payment status check |
| Validate call (deep) | `validate_call` | Status + notifications + Voice Insights |
| Validate message (deep) | `validate_message` | Delivery + debugger alerts |
| Validate recording | `validate_recording` | Completion polling + duration |
| Validate transcript | `validate_transcript` | Completion + sentences |
| Validate debugger | `validate_debugger` | Alerts, optionally filtered by resourceSid |
| Validate voice AI flow | `validate_voice_ai_flow` | Full flow: call → recording → transcript |
| Validate Sync document | `validate_sync_document` | Data structure + content |
| Validate Sync list | `validate_sync_list` | Item count + structure |
| Validate Sync map | `validate_sync_map` | Key/value validation |
| Validate TaskRouter task | `validate_task` | Task deep validation |
| Validate SIP | `validate_sip` | Infrastructure validation |
| Validate video room | `validate_video_room` | Room + participants + tracks |
| List serverless services | `list_services` | Deployment state |
| List serverless functions | `list_functions` | Function inventory |
| List Studio flows | `list_studio_flows` | Flow inventory |
| Get account | `get_account` | Account info + status |
| Get account balance | `get_account_balance` | Balance check |
| Lookup phone number | `lookup_phone_number` | Carrier info, validation |
| Check fraud risk | `check_fraud_risk` | Fraud assessment |
| List video rooms | `list_video_rooms` | Room inventory |
| List messaging services | `list_messaging_services` | Service inventory |

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
| Update TaskRouter task | `update_task` | Changes task state |
| Update TaskRouter worker | `update_worker` | Changes worker availability |
| Create payment | `create_payment` | PCI Mode required (irreversible) |
| Update payment | `update_payment` | Completes/cancels payment |
| Create video room | `create_video_room` | Room creation |
| Trigger Studio flow | `trigger_flow` | Flow execution |
| Create messaging service | `create_messaging_service` | Service setup |
| Send notification | `send_notification` | Push notification |

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

### Debugger Logs

| Tool | Use When |
|------|----------|
| MCP `validate_debugger(resourceSid)` | SID-targeted: alerts for a specific call/message/resource |
| MCP `validate_call(callSid)` / `validate_message(messageSid)` | Deep validation including debugger alerts for that resource |
| MCP `get_debugger_logs` | Time-window browsing when no specific SID available |
| MCP `analyze_errors` | Pattern detection and error grouping |
| CLI `debugger:logs:list` | Interactive human debugging session |

**Rule**: SID-first — use `validate_*` tools when you have a resource SID. Use `get_debugger_logs` for discovery. CLI for human debugging only.

### Sync State

| Tool | Use When |
|------|----------|
| MCP `validate_sync_document(serviceSid, name)` | SID-targeted: deep validation of a specific document |
| MCP `validate_sync_list(serviceSid, name)` / `validate_sync_map(serviceSid, name)` | SID-targeted: validate list/map structure and contents |
| MCP `create_document`, `update_document`, List/Map CRUD tools | Agent state management workflows |
| Function (via `context.getTwilioClient()`) | Event-triggered state updates from webhooks |

**Rule**: SID-first for validation. MCP for agent workflows. Functions for event-triggered updates.

### TaskRouter

| Tool | Use When |
|------|----------|
| MCP `validate_task(taskSid)` | SID-targeted: deep validation of a specific task |
| MCP `list_workers`, `get_queue_statistics`, `list_task_queues` | Agent monitoring and management |
| MCP `create_task`, `update_task`, `update_worker` | Agent-driven task orchestration |
| Function (via `context.getTwilioClient()`) | Worker updates from call events, assignment callbacks |

**Rule**: SID-first for task validation. MCP for monitoring. Functions for event-triggered routing.

### Recordings & Transcripts

| Tool | Use When |
|------|----------|
| MCP `validate_recording(recordingSid)` | SID-targeted: completion polling + status |
| MCP `validate_transcript(transcriptSid)` | SID-targeted: completion + sentence extraction |
| MCP `list_recordings`, `list_transcripts` | Discovery when no specific SID |

**Rule**: SID-first for validation. List tools for discovery only.

### Studio Flows

| Tool | Use When |
|------|----------|
| MCP `trigger_flow`, `get_execution_status` | Always MCP for agent interaction |
| MCP `list_studio_flows`, `get_flow` | Flow discovery and inspection |

**Rule**: Always MCP. No dedicated CLI equivalent.

### Video

| Tool | Use When |
|------|----------|
| MCP `validate_video_room(roomSid)` | SID-targeted: room + participants + tracks + recordings |
| MCP `create_video_room`, `list_video_rooms` | Room management |

**Rule**: SID-first for room validation. Always MCP — no dedicated CLI equivalent.

### Lookups

| Tool | Use When |
|------|----------|
| MCP `lookup_phone_number` | Phone number validation and carrier info |
| MCP `check_fraud_risk` | Fraud risk assessment |

**Rule**: Always MCP. No dedicated CLI equivalent.

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
