---
name: multi-agent-patterns
description: Agent orchestration and coordination patterns. Use when designing multi-agent workflows, choosing between parallel/sequential/hierarchical patterns, or coordinating subagents.
---

# Multi-Agent Patterns for Twilio

This skill describes orchestration and coordination patterns for Twilio development workflows.

## Attribution

This skill is adapted from [Agent Skills for Context Engineering](https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering) by Murat Can Koylan. The orchestration patterns have been customized for Twilio TDD workflows and webhook chain coordination.

## Pattern Overview

| Pattern | Best For | Twilio Use Case |
|---------|----------|-----------------|
| Orchestrator | Sequential flows | Feature development pipeline |
| Agent Teams | Parallel + adversarial | Bug debugging, code review, parallel QA |
| Peer-to-Peer | Parallel work | Debugging + fixing simultaneously |
| Hierarchical | Complex features | Multi-channel solutions |
| Evaluator | Quality gates | Code review with standards |
| TDD Pipeline | Code quality | Red → Green → Refactor |

## Orchestrator Pattern (Default)

A central coordinator manages the workflow, invoking specialists in sequence.

### Structure

```
                    ┌─────────────┐
                    │ Orchestrator│
                    └──────┬──────┘
                           │
     ┌─────────┬───────────┼───────────┬─────────┐
     ▼         ▼           ▼           ▼         ▼
┌─────────┐ ┌─────┐ ┌──────────┐ ┌─────┐ ┌────────┐
│architect│ │spec │ │ test-gen │ │ dev │ │ review │
└─────────┘ └─────┘ └──────────┘ └─────┘ └────────┘
```

### When to Use

- New feature development (sequential phases)
- Bug fixes (diagnose → test → fix → verify)
- Refactoring (test → change → test)

### Twilio Example: New Voice Feature

```
Phase 1: architect
  → Design: functions/voice/voicemail.protected.js
  → Pattern: Record verb with callback

Phase 2: spec
  → Input: CallSid, RecordingUrl
  → Output: TwiML with Record, callback handling

Phase 3: test-gen
  → Unit tests for TwiML generation
  → Integration test for recording callback

Phase 4: dev
  → Implement voicemail.protected.js
  → Make tests pass

Phase 5: review
  → Security: Protected endpoint ✓
  → Patterns: Matches voice skill ✓

Phase 6: test
  → All tests passing ✓
```

### Handoff Protocol

Each agent passes structured context to the next:

```markdown
## Handoff: architect → spec

Files identified:
- functions/voice/voicemail.protected.js (create)
- __tests__/unit/voice/voicemail.test.js (create)

Architecture decisions:
- Use Record verb with transcribe=true
- Store recordings via callback to /voice/recording-complete
- Protected endpoint (requires Twilio signature)

Ready for: Detailed specification
```

## Peer-to-Peer Pattern

Agents work in parallel on related but independent tasks.

### Structure

```
        ┌─────────────┐
        │    User     │
        └──────┬──────┘
               │
       ┌───────┴───────┐
       ▼               ▼
  ┌─────────┐    ┌─────────┐
  │ Agent A │◄──►│ Agent B │
  └─────────┘    └─────────┘
```

### When to Use

- Debugging (analyze logs while reviewing code)
- Multi-file changes (update function + tests simultaneously)
- Documentation (code + docs in parallel)

### Twilio Example: Debugging SMS Failure

```
Parallel agents:

Agent A: twilio-logs
  → Analyzing debugger for error 30003
  → Found: Unreachable destination +1555...

Agent B: dev (investigating)
  → Reading send-sms.protected.js
  → Found: No validation on 'to' parameter

Sync point:
  → Root cause: Invalid phone number passed through
  → Fix: Add E.164 validation before API call
```

### Coordination Mechanism

Agents share findings through explicit sync points:

```markdown
## Sync: Debug Analysis Complete

Agent A findings:
- Error 30003: Unreachable destination
- 5 failures in last hour
- All to same number pattern

Agent B findings:
- No input validation in send-sms
- Phone number from user input without sanitization

Combined insight:
- Need E.164 validation before Twilio API call
- Add test for invalid phone number handling
```

## Hierarchical Pattern

A lead agent delegates to sub-agents, which may further delegate.

### Structure

```
              ┌──────────────┐
              │  Lead Agent  │
              │   architect  │
              └───────┬──────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
   ┌─────────┐   ┌─────────┐   ┌─────────┐
   │  Voice  │   │   SMS   │   │ Verify  │
   │  Team   │   │  Team   │   │  Team   │
   └────┬────┘   └────┬────┘   └────┬────┘
        │             │             │
     ┌──┴──┐       ┌──┴──┐       ┌──┴──┐
     ▼     ▼       ▼     ▼       ▼     ▼
   spec   dev    spec   dev    spec   dev
```

### When to Use

- Multi-channel features (voice + SMS + web)
- Large refactoring (multiple subsystems)
- Complex IVR with nested menus

### Twilio Example: Multi-Channel Notification System

```
Lead: architect "Build notification system with voice, SMS, and email fallback"

Delegation:
├── Voice Team
│   ├── spec voice notification (call + TTS)
│   └── dev functions/voice/notify.protected.js
│
├── SMS Team
│   ├── spec SMS notification
│   └── dev functions/messaging/notify.protected.js
│
└── Orchestration Team
    ├── spec fallback logic (voice → SMS → email)
    └── dev functions/helpers/notify-orchestrator.private.js

Rollup:
- Each team reports completion + test status
- Lead verifies integration
- Final review of complete system
```

## Evaluator Pattern

An evaluator agent assesses work quality against standards.

### Structure

```
┌─────────┐     ┌───────────┐     ┌──────────┐
│Producer │────►│ Evaluator │────►│ Decision │
│   dev   │     │  review   │     │PASS/FAIL │
└─────────┘     └───────────┘     └──────────┘
                      │
                      ▼
               ┌────────────┐
               │ Feedback   │
               │ Loop       │
               └────────────┘
```

### When to Use

- Code review gates
- Security audits
- TDD verification (tests must fail first)

### Twilio Example: Code Review Gate

```
review functions/voice/transfer-call.protected.js

Evaluation criteria:

□ ABOUTME comments present
  ✓ Line 1-2: Descriptive ABOUTME

□ No hardcoded credentials
  ✓ Uses context.TWILIO_ACCOUNT_SID

□ Error handling present
  ✓ Validates 'to' parameter
  ✗ Missing try/catch around client call

□ Protected endpoint for sensitive operations
  ✓ .protected.js suffix

□ Tests exist and pass
  ✓ 4 unit tests passing

Verdict: NEEDS_CHANGES
Reason: Add try/catch for Twilio API call
```

## Agent Teams Pattern

Real parallel coordination with inter-agent messaging. Unlike subagents (which share the parent's context and can only report back), teammates have their own context windows and communicate directly with each other.

### Structure

```
              ┌──────────────┐
              │   Lead Agent │
              │  (delegate   │
              │    mode)     │
              └───────┬──────┘
                      │ shared task list
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
   ┌─────────┐  ┌─────────┐  ┌─────────┐
   │Teammate │◄►│Teammate │◄►│Teammate │
   │    A    │  │    B    │  │    C    │
   └─────────┘  └─────────┘  └─────────┘
        ◄── direct messaging ──►
```

### When to Use

- Bug debugging with competing hypotheses (3 investigators challenge each other)
- Multi-lens code review (security + performance + tests in parallel)
- Parallel QA + review after implementation
- Cross-layer changes (functions + agents + config)

### Comparison: Subagents vs Agent Teams

| Aspect | Subagents | Agent Teams |
|--------|-----------|-------------|
| **Context** | Shared with parent | Own window per teammate |
| **Communication** | Return results to caller | Message each other + shared tasks |
| **Parallelism** | Sequential | Parallel |
| **Token cost** | Lowest | ~2-3x |
| **Resumable** | Yes | No |
| **Best for** | Sequential workflows | Adversarial/parallel work |

### Twilio Example: Bug Fix with Competing Hypotheses

```
Parallel investigators:

Teammate "code-tracer":
  → Reading send-sms.protected.js
  → Found: No body validation, crashes on undefined
  → Confidence: HIGH

Teammate "log-analyst":
  → Checking debugger for error 11200
  → Found: 500 errors from /messaging/send-sms endpoint
  → Confirms code-tracer's finding

Teammate "config-checker":
  → Checking webhook config, env vars
  → All correct — rules out configuration issue
  → Supports code-level root cause

Lead synthesis:
  → Root cause: Missing body validation
  → Fix: Add null check before Twilio API call
  → Regression test: Empty body should return 400, not 500
```

## Pattern Selection Guide

```
Is work sequential with clear phases?
├── Yes → Orchestrator Pattern
│         Use orchestrate subagent
│
└── No → Do agents need to discuss findings?
         ├── Yes → Agent Teams Pattern
         │         Use team coordination
         │
         └── No → Can tasks run independently?
                  ├── Yes → Peer-to-Peer Pattern
                  │         Run multiple tasks in parallel
                  │
                  └── No → Is there natural hierarchy?
                           ├── Yes → Hierarchical Pattern
                           │         Lead agent delegates to teams
                           │
                           └── No → Evaluator Pattern
                                     Quality gate with feedback loop
```

## Twilio-Specific Considerations

### Webhook Chains = Orchestrator

Twilio webhooks naturally follow orchestrator pattern:

```
Incoming Call → IVR Menu → Gather Input → Route Call → Record → Hangup
     │              │            │            │           │
     ▼              ▼            ▼            ▼           ▼
  Handler 1    Handler 2    Handler 3    Handler 4   Handler 5
```

Each handler is a function that passes control to the next via TwiML action URLs.

### Real-Time Features = Peer Pattern

ConversationRelay and real-time features benefit from peer coordination:

```
┌─────────────────┐     ┌─────────────────┐
│  Voice Handler  │◄───►│  WebSocket AI   │
│  (TwiML setup)  │     │  (LLM backend)  │
└─────────────────┘     └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
              ┌─────────────┐
              │ Shared State│
              │  (context)  │
              └─────────────┘
```

### Multi-Channel = Hierarchical

Voice + SMS + Verify solutions need hierarchical coordination:

```
User Verification Flow
├── Channel Selection (Lead)
│   ├── Voice: Call with OTP
│   ├── SMS: Text with code
│   └── Email: Link with token
└── Verification Check (Shared)
```
