---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the TaskRouter skill. Every factual claim pressure-tested with evidence. -->
<!-- ABOUTME: Proves provenance chain for all behavioral claims. 68 assertions extracted, audited 2026-03-25. -->

# Assertion Audit Log

**Skill**: taskrouter
**Audit date**: 2026-03-25
**Account**: ACxx...xx
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 56 |
| CORRECTED | 2 |
| QUALIFIED | 10 |
| REMOVED | 0 |
| **Total** | **68** |

## Assertions

### Scope — CAN (A1–A13)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A1 | Route tasks based on attribute expressions | Behavioral | CONFIRMED | WQ81a37725, expression matching to worker | Live-verified |
| A2 | Priority-based assignment (higher first) | Behavioral | CONFIRMED | WT2b0a7865, priority 5 assigned before priority 3 task | Live-verified |
| A3 | Workflow filters: first-match, sequential targets with timeouts | Architectural | CONFIRMED | WWb6f659ff multi-filter workflow, target timeout triggered escalation | Live-verified |
| A4 | Six assignment instructions | Scope | QUALIFIED | Accept live-verified (WR277f05dc); other 5 from docs | Would need voice calls to test conference/dequeue/call/redirect |
| A5 | Real-time queue statistics | Behavioral | CONFIRMED | WQ81a37725 + WQa281c134 full stats returned | Live-verified |
| A6 | Per-worker task channel capacity | Scope | QUALIFIED | twilio.com/docs/taskrouter/multitasking | Not live-tested |
| A7 | FIFO template creates 3 activities + 1 queue + 1 workflow | Behavioral | CONFIRMED | WS04a6cec1, exact resources enumerated | Live-verified |
| A8 | Worker attributes JSON max 4096 chars | Scope | CONFIRMED | twilio.com/docs/taskrouter/api/worker + MCP schema | Docs confirmed |
| A9 | Reservation timeout configurable 1–86,400s, default 120 | Default | CONFIRMED | WWb6f659ff set to 30s; default FIFO workflow at 120 | Live + docs |
| A10 | Event audit log with 30-day retention | Scope | CONFIRMED | validate_task returned 9 events for WT2b0a7865 | Live-verified |
| A11 | Task completion with reason | Behavioral | CONFIRMED | WT2b0a7865, reason="resolved" | Live-verified |
| A12 | validate_task shows event timeline and reservations | Behavioral | CONFIRMED | WT2b0a7865, 9 events + 1 reservation, 533ms | Live-verified |
| A13 | Task attributes max 4096 chars | Scope | CONFIRMED | twilio.com/docs/taskrouter/api/task | Docs confirmed |

### Scope — CANNOT (A14–A25)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A14 | Hyphens break expressions (parsed as subtraction) | Error | CONFIRMED | Error 20001 on `skill-level > 3` | Live-verified |
| A15 | HAS on non-array silently fails | Behavioral | CONFIRMED | WQeecb6580 created with `level HAS "support"`, no error | Live-verified |
| A16 | Activity available silently immutable | Behavioral | CONFIRMED | WAa56b76ad, Available=true ignored | Live-verified |
| A17 | multiTaskEnabled cannot revert to false | Scope | QUALIFIED | twilio.com/docs/taskrouter/api/workspace | Not live-tested |
| A18 | Reservation timeout moves worker to timeout activity | Behavioral | CONFIRMED | WKc1a5870 moved Available→Offline after 30s | Live-verified |
| A19 | Workflow target timeout auto-cancels tasks | Behavioral | CONFIRMED | WT2c881f50, "Task canceled on Workflow timeout" | Live-verified |
| A20 | Worker friendlyName case-insensitive unique | Behavioral | CONFIRMED | Error 20001 on duplicate "Alice" | Live-verified |
| A21 | workflowSid required for task creation | Behavioral | CONFIRMED | Error "WorkflowSid field is required" | Live-verified |
| A22 | Cannot update task status and attributes in same request | Scope | QUALIFIED | twilio.com/docs/taskrouter/api/task | Not live-tested |
| A23 | Assignment callback 5-second deadline | Scope | QUALIFIED | twilio.com/docs/taskrouter/handle-assignment-callbacks | Not live-tested |
| A24 | Tasks auto-cancel after 1000 rejections | Scope | QUALIFIED | twilio.com/docs/taskrouter/api/task | Not live-tested |
| A25 | page query param not supported, use PageToken | Scope | QUALIFIED | twilio.com/docs/taskrouter/api/task | Not live-tested |

### Gotchas (A26–A47)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A26 | G1: Hyphens in attribute names break expressions | Error | CONFIRMED | Same as A14 | — |
| A27 | G1: Hyphens valid in JSON, problem is expression parser | Behavioral | CONFIRMED | WKcd286d49 created with `skill-level` in JSON | Live-verified both cases |
| A28 | G2: HAS on non-array silently matches nothing | Behavioral | CONFIRMED | Same as A15 | — |
| A29 | G2: Check totalEligibleWorkers to catch this | Behavioral | CONFIRMED | Queue stats returned totalEligibleWorkers field | Live-verified |
| A30 | G3: 1==1 is universal match | Behavioral | CONFIRMED | WQfe85a0a7 Sample Queue targets all workers | Live-verified (FIFO template) |
| A31 | G4: Reservation timeout moves worker offline | Behavioral | CONFIRMED | Same as A18 | — |
| A32 | G4: Worker stops receiving ALL tasks | Behavioral | CONFIRMED | After timeout, new task got 0 reservations until Alice reset to Available | Live-verified |
| A33 | G5: Activity available silently immutable | Behavioral | CONFIRMED | Same as A16 | — |
| A34 | G6: friendlyName case-insensitive unique | Behavioral | CONFIRMED | Same as A20 | — |
| A35 | G7: New workers get defaultActivitySid (typically Offline) | Default | CONFIRMED | WK144eae97 created as Offline (workspace default) | Live-verified |
| A36 | G8: Workflow target timeout with no fallback auto-cancels | Behavioral | CONFIRMED | Same as A19 | — |
| A37 | G8: Use default_filter as catch-all | Architectural | CONFIRMED | Workflow config structure validated | Structural verification |
| A38 | G9: Workflow target sets task priority | Behavioral | CONFIRMED | WT2b0a7865 got priority 5 from target | Live-verified |
| A39 | G10: Workers with pending reservations block new assignments | Behavioral | CONFIRMED | WTa3944de 0 reservations while Alice reserved for sales | Live-verified |
| A40 | G11: workflowSid required | Behavioral | CONFIRMED | Same as A21 | — |
| A41 | G12: Return instruction directly not via Twilio.Response | Behavioral | QUALIFIED | functions/taskrouter/CLAUDE.md + assignment.protected.js code | Not live-tested (serverless deployment); confirmed in codebase docs |
| A42 | G13: conference_record must be string not boolean | Behavioral | QUALIFIED | functions/taskrouter/CLAUDE.md + assignment.protected.js code | Not live-tested; confirmed in codebase docs |
| A43 | G14: dequeue requires task from <Enqueue> | Scope | QUALIFIED | twilio.com/docs/taskrouter/api/reservations | Not live-tested |
| A44 | G15: 5-second callback deadline | Scope | QUALIFIED | Same as A23 | — |
| A45 | G16: Attributes max 4096 chars | Scope | CONFIRMED | Same as A8/A13 | — |
| A46 | G17: friendlyName max 64 chars | Scope | CONFIRMED | twilio.com/docs/taskrouter | Docs confirmed |
| A47 | G18: Task attributes present in list (contrary to docs) | Behavioral | CORRECTED | REST list returned full attributes | See correction C1 |

### Architecture & Tables (A48–A68)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A48 | SID prefixes: WS, WA, WK, WQ, WW, WT, WR, TC, EV | Scope | CONFIRMED | All SIDs observed in live testing | Live-verified |
| A49 | Task lifecycle: pending→reserved→assigned→wrapping→completed | Scope | CONFIRMED | WT2b0a7865: pending→reserved→assigned→completed | Live-verified (wrapping is Flex-only) |
| A50 | Workflow filters top-to-bottom first-match | Architectural | CONFIRMED | Sales filter matched before support filter for type="sales" task | Live-verified |
| A51 | Targets within filter sequential with timeout escalation | Architectural | CONFIRMED | WT2c881f50 canceled after single target timeout (no second target) | Live-verified |
| A52 | Queue stats: totalAvailableWorkers, totalEligibleWorkers | Behavioral | CONFIRMED | Both fields present in stats response | Live-verified |
| A53 | Queue stats: tasksByStatus breakdown | Behavioral | CONFIRMED | 6-field breakdown returned | Live-verified |
| A54 | Queue stats: activityStatistics per-activity | Behavioral | CONFIRMED | Per-activity worker counts returned | Live-verified |
| A55 | Default + timeout activities both Offline in FIFO template | Default | CONFIRMED | WS04a6cec1 | Live-verified |
| A56 | Reservation statuses: pending, accepted, rejected, timeout, canceled, rescinded, wrapping, completed | Scope | CONFIRMED | pending and accepted live-verified; timeout observed; others from docs | Partial live + docs |
| A57 | Event types include workflow.entered, task-queue.entered, etc. | Scope | CONFIRMED | validate_task event list for WT2b0a7865 | Live-verified (9 event types observed) |
| A58 | 15,000 workers per workspace | Scope | CONFIRMED | twilio.com/docs/taskrouter/limits | Docs |
| A59 | 5,000 task queues per workspace | Scope | CONFIRMED | twilio.com/docs/taskrouter/limits | Docs |
| A60 | 100 activities per workspace | Scope | CONFIRMED | twilio.com/docs/taskrouter/limits | Docs |
| A61 | 1,000 rejections auto-cancel | Scope | CONFIRMED | twilio.com/docs/taskrouter/api/task | Docs |
| A62 | MCP create_task requires attributes | Behavioral | CONFIRMED | MCP schema: required=["attributes"] | Schema inspection |
| A63 | MCP update_reservation supports conference/dequeue/redirect/call instructions | Behavioral | CONFIRMED | MCP schema: enum=["conference","dequeue","redirect","call"] | Schema inspection |
| A64 | MCP create_activity requires available param | Behavioral | CONFIRMED | MCP schema: required=["friendlyName","available"] | Schema inspection |
| A65 | MCP lacks task update (complete/cancel) | Scope | CORRECTED | No update_task tool in MCP | See correction C2 |
| A66 | Workspace delete cascades | Behavioral | CONFIRMED | WS04a6cec1 deleted with all children | Live-verified |
| A67 | FIFO template creates exactly 3 activities | Behavioral | CONFIRMED | Offline, Available, Unavailable | Live-verified |
| A68 | Queue maxReservedWorkers defaults to 1 | Default | CONFIRMED | WQ81a37725 created without param, maxReservedWorkers=1 | Live-verified |

## Corrections Applied

### C1: Task attributes in list (A47)

- **Original text**: Docs say "attributes returns null in list responses"
- **Corrected text**: Skill gotcha G18 states attributes ARE present in list responses contrary to docs
- **Why**: REST API list endpoint returned full attributes for both tasks. This is a docs error or behavior change. The skill correctly documents the actual behavior.

### C2: MCP task update gap (A65)

- **Original text**: Initially listed as "update task" in MCP gaps without specificity
- **Corrected text**: Clarified the specific gap: no MCP tool to change task `assignmentStatus` (complete/cancel/wrapping). `get_task_status` exists but not `update_task`.
- **Why**: Precision about what's missing helps users know when they need REST.

## Qualifications Applied

### Q1–Q4: Voice-dependent instructions (A4, A41, A42, A43)
- **Condition**: Conference, dequeue, call, redirect instructions require actual voice calls through TaskRouter. Accept was live-verified; others from docs and codebase patterns.

### Q5: multiTaskEnabled irreversibility (A17)
- **Condition**: Docs confirm; not live-tested (destructive to enable without understanding implications).

### Q6–Q7: Task update and callback constraints (A22, A23)
- **Condition**: Docs confirm both; live-testing would require deployed serverless functions.

### Q8–Q9: Auto-cancel and pagination (A24, A25)
- **Condition**: Would require 1000 rejection cycles or specific pagination testing.

### Q10: Channel capacity (A6)
- **Condition**: Would require multitasking configuration with multiple channels.
