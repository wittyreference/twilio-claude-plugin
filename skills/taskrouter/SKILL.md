---
name: "taskrouter"
description: "Twilio development skill: taskrouter"
---

---
name: taskrouter
description: Twilio TaskRouter skills-based routing guide. Use when building contact centers, queue-based work distribution, skills-based agent routing, or managing workers/tasks/reservations.
---

<!-- verified: twilio.com/docs/taskrouter, twilio.com/docs/taskrouter/api/workspace, twilio.com/docs/taskrouter/api/activity, twilio.com/docs/taskrouter/api/worker, twilio.com/docs/taskrouter/api/task-queue, twilio.com/docs/taskrouter/api/workflow, twilio.com/docs/taskrouter/api/task, twilio.com/docs/taskrouter/api/reservations, twilio.com/docs/taskrouter/expression-syntax, twilio.com/docs/taskrouter/workflow-configuration + live testing 2026-03-25 -->

# Twilio TaskRouter

Skills-based routing engine distributing tasks to workers based on skills, availability, priority, and workflow rules. Covers the 6-resource architecture (Workspace → Activities → Workers → Task Queues → Workflows → Tasks/Reservations), expression syntax, assignment callbacks, and the 30 MCP tools.

Evidence date: 2026-03-25. Account prefix: AC... Workspace: WS04a6cec1 (deleted after testing).

## Scope

### CAN

- Route tasks to workers based on attribute expressions (`skills HAS "support" AND level >= 2`) <!-- verified: WQ81a37725, expression matching -->
- Priority-based assignment: higher priority tasks assigned first regardless of age <!-- verified: WT2b0a7865, priority 5 from workflow target -->
- Workflow filters with cascading targets: first-match filter, sequential target escalation with timeouts <!-- verified: WWb6f659ff, multi-filter multi-target workflow -->
- Six assignment instructions: accept, reject, conference, dequeue, call, redirect <!-- verified: WR277f05dc accepted; docs confirm all 6 -->
- Real-time queue statistics: available/eligible workers, pending tasks, wait times, per-activity breakdown <!-- verified: WQ81a37725 and WQa281c134 stats -->
- Per-worker task channel capacity for multitasking (e.g., 1 voice + 10 SMS) <!-- verified: twilio.com/docs/taskrouter/multitasking -->
- Workspace templates: `FIFO` pre-creates 3 activities + 1 queue + 1 workflow <!-- verified: WS04a6cec1 FIFO template -->
- Worker attributes as JSON with arrays, numbers, strings, booleans (max 4096 chars) <!-- verified: WKc1a5870, skills array + level number -->
- Task attributes as JSON (max 4096 chars) with priority and timeout <!-- verified: WT2b0a7865 -->
- Reservation timeout configurable per workflow (1–86,400 seconds, default 120) <!-- verified: WWb6f659ff, 30s timeout -->
- Event audit log with 30-day retention (EV-prefixed SIDs) <!-- verified: validate_task showed 9 events -->
- Task completion with reason tracking <!-- verified: WT2b0a7865, reason="resolved" -->
- Deep validation via `mcp__twilio__validate_task` with event timeline and reservation history <!-- verified: WT2b0a7865, 9 events, 533ms -->

### CANNOT

<!-- verified: all CANNOT items live-tested 2026-03-25 unless noted -->

- **Hyphens break expressions** — Attribute names with hyphens (e.g., `skill-level`) are valid in JSON but the expression parser treats `-` as subtraction. `skill-level > 3` parses as `skill` minus `level` and returns error 20001: "extraneous input 'evel' expecting OPERATOR." Use underscores (`skill_level`) instead. <!-- verified: error 20001 on queue create with `skill-level > 3` -->
- **`HAS` on non-array silently fails** — `level HAS "support"` is accepted when creating a queue but will never match any worker because `level` is a number, not an array. No error at creation time, no error at match time — tasks just sit in the queue forever. Check `totalEligibleWorkers` in queue stats to catch this. <!-- verified: WQeecb6580 created with `level HAS "support"`, no error -->
- **Expression validation is syntactic only, not semantic.** Queue creation validates that the expression parses correctly (hyphens cause parse errors), but does NOT validate that the expression matches any workers. `level HAS "support"` is syntactically valid but semantically wrong (HAS requires an array). The queue creates successfully, tasks route into it, but zero workers ever match — and there is NO error at routing time. Always check `totalEligibleWorkers` via `get_queue_statistics` after creating a queue.
- **Activity `available` flag is silently immutable** — Updating an activity's `available` property via API returns 200 OK but does not change the value. No error, no warning. You must delete the activity and recreate it with the correct flag. <!-- verified: WAa56b76ad, set Available=true, stayed false -->
- **`multiTaskEnabled` cannot be reverted to false** — Once enabled on a workspace, it cannot be disabled. <!-- verified: twilio.com/docs/taskrouter/api/workspace -->
- **Reservation timeout moves worker to timeout activity** — When a reservation times out, the worker is automatically moved to the workspace's `timeoutActivitySid` (Offline by default). The worker becomes unavailable for all tasks until manually set back to an available activity. This is the #1 surprise in TaskRouter. <!-- verified: WKc1a5870 moved from Available to Offline after 30s timeout -->
- **Workflow target timeout auto-cancels tasks** — When all targets in a filter exhaust their timeouts with no worker accepting, the task is canceled with reason "Task canceled on Workflow timeout." Use a `default_filter` as a catch-all to prevent this. <!-- verified: WT2c881f50, auto-canceled after 30s target timeout -->
- **Worker `friendlyName` is case-insensitive unique** — Creating a worker named "alice" when "Alice" exists returns error 20001. <!-- verified: duplicate "Alice" rejected -->
- **`workflowSid` is required for task creation** — At minimum when multiple workflows exist. The API does not auto-select a default workflow. <!-- verified: error "WorkflowSid field is required" -->
- **Cannot update task status and attributes in same request** — Must be two separate API calls. <!-- verified: twilio.com/docs/taskrouter/api/task -->
- **Assignment callback must respond in 5 seconds** — If your callback URL doesn't respond in time, the fallback URL is tried. If both fail, the reservation is canceled. <!-- verified: twilio.com/docs/taskrouter/handle-assignment-callbacks -->
- **Tasks auto-cancel after 1,000 rejections** — If a task cycles through 1,000 reservation rejections, it is automatically canceled. <!-- verified: twilio.com/docs/taskrouter/api/task -->
- **`page` query param not supported** — Use `PageToken` for pagination. `page` returns error 40153. <!-- verified: twilio.com/docs/taskrouter/api/task -->

### Beyond Platform (Your Responsibility)

These are commonly requested in contact center projects but are **not Twilio features** — they require custom application code:

- **Estimated Wait Time (EWT) announcements** — Twilio provides queue statistics (pending tasks, average service time) via the TaskQueue Statistics API, but does NOT compute or announce EWT. You must: (1) poll `get_queue_statistics` periodically, (2) calculate estimates from historical data, (3) serve announcements via a custom `waitUrl` handler on `<Enqueue>` that fetches the estimate and `<Say>`s it.
- **CRM screen pops** — Twilio has no CRM integration feature. The pattern is: Voice SDK fires a call event to the agent's browser, your application JavaScript extracts caller info (ANI, task attributes), and opens a CRM URL with pre-filled data. Twilio provides the event; the screen pop is 100% your code. Flex has built-in CRM panels, but custom contact centers must build this.
- **Workforce dashboards** — Twilio Sync provides real-time data transport (Documents for agent state, Maps for queue metrics), but the dashboard UI, visualization, and aggregation are entirely custom. Use Event Streams for analytics pipeline feeding and Sync for live operational displays.
- **Genesys Architect equivalent** — TaskRouter Workflows (JSON routing rules) + Twilio Functions (webhook logic). There is no visual flow builder equivalent; Studio exists but Functions are preferred.

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Route calls to agents by skill | Workflow filter + queue with `skills HAS "x"` expression | Core use case |
| Simple FIFO queue | Workspace with `FIFO` template, single queue `1==1` | Pre-built, no configuration needed |
| Priority escalation | Workflow target with `priority` + `timeout` for escalation | Higher priority assigned first |
| Contact center with hold music | `<Enqueue>` TwiML + conference assignment instruction | Caller holds, agent bridges via conference |
| Non-voice work (chat, email) | `tasks.create()` API + accept instruction | No TwiML needed |
| Agent availability dashboard | `get_queue_statistics` per queue | Real-time worker/task counts |
| Post-call wrap-up | Task status `wrapping` → `completed` | Flex-compatible wrap-up state |
| Fallback for unmatched tasks | `default_filter` in workflow config | Catch-all queue prevents task loss |

## Architecture

```
Workspace (WS)
├── Activities (WA) — Worker states: Available, Offline, Break, ...
├── Workers (WK) — Agents with JSON attributes (skills, languages, level)
├── Task Queues (WQ) — Pools with worker-matching expressions
├── Workflows (WW) — Routing rules: filters → targets → queues
├── Tasks (WT) — Work items with attributes, priority, timeout
│   └── Reservations (WR) — Worker↔Task bindings (auto-created)
└── Task Channels (TC) — Work types for multitasking capacity
```

### Task Lifecycle

```
pending → reserved → assigned → wrapping → completed
    │         │                              ↗
    │         └── timeout ──→ re-route or cancel
    └── no match ──→ sits until timeout or cancel
```

| Status | Trigger | Notes |
|--------|---------|-------|
| `pending` | Task created | Waiting for workflow evaluation + worker match |
| `reserved` | Worker matched | Reservation created; worker has `taskReservationTimeout` to respond |
| `assigned` | Reservation accepted | Worker actively handling task |
| `wrapping` | Post-call work | Flex accounts; transition via API |
| `completed` | Task finished | Terminal; requires `reason` |
| `canceled` | Timeout or API | Terminal; auto-reason from workflow or manual |

### Workflow Configuration

```json
{
  "task_routing": {
    "filters": [
      {
        "filter_friendly_name": "VIP Support",
        "expression": "type == 'support' AND priority_level == 'high'",
        "targets": [
          {
            "queue": "WQ_senior_support",
            "priority": 10,
            "timeout": 60
          },
          {
            "queue": "WQ_all_support",
            "priority": 5,
            "timeout": 120
          }
        ]
      }
    ],
    "default_filter": {
      "queue": "WQ_general"
    }
  }
}
```

**Evaluation**: Filters evaluated top-to-bottom (first match wins). Targets within a filter evaluated sequentially — each target's `timeout` triggers escalation to the next target.

**Target fields**: `queue` (required), `priority` (optional), `timeout` (optional), `expression` (optional worker filter using `task.*` and `worker.*`), `skip_if` (optional condition to bypass).

## Expression Syntax

### Operators

| Operator | Type | Example | Notes |
|----------|------|---------|-------|
| `==`, `!=` | Comparison | `language == "en"` | Strings, numbers, booleans |
| `>`, `>=`, `<`, `<=` | Comparison | `level >= 3` | Numbers only |
| `HAS` | Array contains | `skills HAS "support"` | Left side MUST be array or silently fails |
| `IN` | Value in array | `language IN ["en","es"]` | Right side must be array |
| `NOT IN` | Value not in array | `status NOT IN ["vip"]` | |
| `CONTAINS` | String contains | `name CONTAINS "smith"` | Substring match |
| `AND`, `OR` | Logical | `skills HAS "sales" AND level > 2` | Parentheses for grouping |

### Rules
- **No hyphens** in attribute names used in expressions (use underscores)
- `1==1` matches all workers (universal queue)
- Non-existent keys return `NULL`
- Workflow target expressions use `task.*` and `worker.*` prefixes: `task.language IN worker.languages`

## MCP Tool Reference

### Workspace (5 tools)

| Tool | Operation |
|------|-----------|
| `mcp__twilio__create_workspace` | Create (friendlyName required, template optional) |
| `mcp__twilio__list_workspaces` | List (filter by friendlyName) |
| `mcp__twilio__get_workspace` | Fetch |
| `mcp__twilio__update_workspace` | Update (name, callbacks, default/timeout activities) |
| `mcp__twilio__delete_workspace` | Delete (cascading — destroys all children) |

### Workers (5 tools)

| Tool | Operation | Key params |
|------|-----------|-----------|
| `mcp__twilio__create_worker` | Create | `friendlyName` (required, unique), `attributes` (JSON object), `activitySid` |
| `mcp__twilio__list_workers` | List | `available` (bool filter), `activityName` (filter) |
| `mcp__twilio__get_worker` | Fetch | `workerSid` |
| `mcp__twilio__update_worker` | Update | `activitySid`, `attributes` |
| `mcp__twilio__delete_worker` | Delete | `workerSid` |

### Task Queues (5 tools + stats)

| Tool | Operation | Key params |
|------|-----------|-----------|
| `mcp__twilio__create_task_queue` | Create | `friendlyName`, `targetWorkers` (expression), `maxReservedWorkers`, `taskOrder` |
| `mcp__twilio__list_task_queues` | List | |
| `mcp__twilio__get_task_queue` | Fetch | `taskQueueSid` |
| `mcp__twilio__update_task_queue` | Update | `targetWorkers`, `taskOrder`, `maxReservedWorkers` |
| `mcp__twilio__delete_task_queue` | Delete | `taskQueueSid` |
| `mcp__twilio__get_queue_statistics` | Real-time stats | `taskQueueSid` — returns available/eligible workers, task counts, wait times |

### Workflows (5 tools)

| Tool | Operation | Key params |
|------|-----------|-----------|
| `mcp__twilio__create_workflow` | Create | `friendlyName`, `configuration` (JSON string), `taskReservationTimeout`, `assignmentCallbackUrl` |
| `mcp__twilio__list_workflows` | List | |
| `mcp__twilio__get_workflow` | Fetch | Returns configuration |
| `mcp__twilio__update_workflow` | Update | `configuration`, `taskReservationTimeout` |
| `mcp__twilio__delete_workflow` | Delete | |

### Tasks (4 tools + validation)

| Tool | Operation | Key params |
|------|-----------|-----------|
| `mcp__twilio__create_task` | Create | `attributes` (required), `workflowSid`, `priority`, `timeout` |
| `mcp__twilio__list_tasks` | List | `assignmentStatus` filter |
| `mcp__twilio__get_task_status` | Fetch | Returns attributes, status, queue, workflow |
| `mcp__twilio__delete_task` | Delete | |
| `mcp__twilio__validate_task` | Deep validate | `expectedStatus`, `expectedAttributeKeys`, `includeEvents`, `includeReservations` |

### Activities & Reservations (4 tools)

| Tool | Operation | Key params |
|------|-----------|-----------|
| `mcp__twilio__create_activity` | Create | `friendlyName`, `available` (required, immutable after creation) |
| `mcp__twilio__list_activities` | List | |
| `mcp__twilio__list_reservations` | List for task | `taskSid`, `reservationStatus` filter |
| `mcp__twilio__update_reservation` | Accept/reject/instruct | `reservationStatus` or `instruction` (conference/dequeue/redirect/call) |

### MCP Gaps

| Operation | REST Required |
|-----------|--------------|
| Update task (complete/cancel/wrapping) | `POST /Tasks/{TaskSid}` with `AssignmentStatus` |
| Task channels CRUD | Full REST API |
| Events list/fetch | `GET /Events` with filters |
| Worker channel capacity | Sub-resource on Worker |
| Workspace statistics | Statistics endpoints |

## Gotchas

### Expressions

1. **Hyphens in attribute names break expressions**: `skill-level > 3` parses as `skill` minus `level`. Use underscores: `skill_level > 3`. Hyphens are valid in the JSON attribute itself — the problem is only in expression evaluation. [Evidence: error 20001 "extraneous input 'evel'"]

2. **`HAS` on non-array silently matches nothing**: Creating a queue with `level HAS "support"` succeeds without error, but `level` is a number so `HAS` always returns false. Tasks route to the queue but no worker ever matches. Check `totalEligibleWorkers` in queue stats — if it's 0, your expression is wrong. [Evidence: WQeecb6580]

3. **`1==1` is the universal match**: For catch-all queues that should match all workers, use `1==1`. Any truthy constant expression works.

### Worker & Activity

4. **Reservation timeout moves worker offline**: When a reservation times out, the worker is automatically moved to the workspace's `timeoutActivitySid` (Offline by default). The worker stops receiving ALL tasks. You must explicitly set them back to Available. This is the #1 TaskRouter surprise. [Evidence: WKc1a5870, Available→Offline after 30s timeout]

5. **Activity `available` is silently immutable**: Updating `available` via API returns 200 OK but the value doesn't change. No error, no warning. Delete and recreate the activity with the correct flag. [Evidence: WAa56b76ad]

6. **Worker `friendlyName` is case-insensitive unique**: "alice" and "Alice" conflict. Error 20001. [Evidence: duplicate Alice rejected]

7. **New workers get the workspace's `defaultActivitySid`**: This is typically Offline. If you want workers to immediately receive tasks, explicitly pass `activitySid` for an Available activity on creation. [Evidence: WK144eae97 created as Offline]

### Task Routing

8. **Workflow target timeout auto-cancels if no fallback**: When all targets exhaust their timeouts, the task is canceled with "Task canceled on Workflow timeout." Always include a `default_filter` as catch-all. [Evidence: WT2c881f50, auto-canceled]

9. **Workflow target sets task priority**: The `priority` field in a workflow target is applied to the task at routing time. Explicit priority on task creation is overridden by the target. [Evidence: WT2b0a7865 got priority 5 from target]

10. **Workers with pending reservations block new assignments**: A worker with an unresolved reservation (pending) won't receive new tasks on the same channel, even if their capacity allows it. The support task sat pending with 0 reservations because Alice already had a sales reservation. [Evidence: WTa3944de, 0 reservations while Alice reserved for WT2c881f50]

11. **`workflowSid` is required for task creation**: The API does not auto-select a default workflow. Always specify it. [Evidence: error "WorkflowSid field is required"]

### Assignment Callback

12. **Return instruction directly, NOT via `Twilio.Response`**: In serverless functions, `callback(null, instructionObj)` — do NOT wrap in `Twilio.Response` with `setBody(JSON.stringify())`. This double-encodes JSON and produces error 40001. [Evidence: CLAUDE.md]

13. **`conference_record` must be string `'record-from-start'`**: Boolean `true` is silently ignored. No error, no recording. [Evidence: CLAUDE.md]

14. **`dequeue` requires task created via `<Enqueue>`**: The dequeue instruction only works for voice tasks that were enqueued via TwiML. API-created tasks cannot use dequeue — use conference or call instead. [Evidence: twilio.com/docs/taskrouter/api/reservations]

15. **5-second callback response deadline**: If your assignment callback doesn't respond in 5 seconds, the fallback URL is tried. If both fail, the reservation is canceled. Keep callback handlers fast. [Evidence: twilio.com/docs/taskrouter/handle-assignment-callbacks]

### Data Constraints

16. **Worker and task attributes max 4096 characters**: The JSON string representation, not the parsed object. Large attribute sets can hit this silently. [Evidence: twilio.com/docs/taskrouter/api/worker]

17. **`friendlyName` max 64 characters**: Applies to workspaces, workers, activities, queues, workflows. [Evidence: twilio.com/docs/taskrouter]

18. **Task attributes present in list responses**: Contrary to documentation stating attributes are null in list endpoints, the REST API returns full attributes. MCP `list_tasks` also returns attributes. [Evidence: REST list test on WS04a6cec1]

### Limits

19. **15,000 workers per workspace**: Default limit, adjustable via Twilio support. [Evidence: twilio.com/docs/taskrouter/limits]

20. **5,000 task queues per workspace**: Hard limit. [Evidence: twilio.com/docs/taskrouter/limits]

21. **100 activities per workspace**: Hard limit. Plan activity states carefully. [Evidence: twilio.com/docs/taskrouter/limits]

22. **Tasks auto-cancel after 1,000 rejections**: If a task cycles through 1,000 reservation reject cycles, it auto-cancels. [Evidence: twilio.com/docs/taskrouter/api/task]

## Cascade Chains

Individual gotchas above interact under load. These are the documented failure cascades:

### High-Concurrency Cascade (Inbound Spike)

```
Call spike (500+ concurrent)
  → Reservation creation backlog (rate limited)
    → Assignment callbacks timeout (5s deadline, gotcha #3)
      → Reservations auto-timeout
        → Workers pushed to offline activity (gotcha #4)
          → Fewer available workers
            → Deeper reservation backlog (positive feedback loop)
              → Tasks reach 1000 rejections → auto-cancel (gotcha #22)
```

**Detection**: Monitor `workspace.realtime` statistics — if `tasks_by_status.pending` grows while `workers_by_activity.available` shrinks, you're in this cascade.

**Mitigation**:
1. **Overflow queue**: Configure a secondary workflow with a lower-priority catch-all queue. Tasks that exceed N seconds in pending state get reassigned to the overflow queue which plays "estimated wait time" and offers a callback option.
2. **Worker auto-recovery**: Periodically poll workers in offline state and reset to available if their last reservation was a timeout (not a manual state change). Use `worker.activity.name` and `worker.dateUpdated` to distinguish.
3. **Capacity planning**: Rough formula — peak concurrent calls ÷ average handle time = minimum agents needed. Add 20% buffer for reservation overhead and timeout recovery.

### Reservation Timeout → Worker Offline Cascade

```
Reservation assigned to worker
  → Worker doesn't respond within reservationTimeout
    → Reservation times out
      → Worker moved to offline activity (gotcha #4)
        → Worker receives no further reservations until manually/programmatically restored
```

**Recovery**: Your application must detect workers stuck in offline state due to timeouts (not intentional logout) and restore them. TaskRouter does not auto-recover — a worker moved offline by timeout stays offline permanently.

## SID Reference

| Prefix | Resource |
|--------|----------|
| `WS` | Workspace |
| `WA` | Activity |
| `WK` | Worker |
| `WQ` | Task Queue |
| `WW` | Workflow |
| `WT` | Task |
| `WR` | Reservation |
| `TC` | Task Channel |
| `EV` | Event |

## Related Resources

- **TaskRouter CLAUDE.md** (`CLAUDE.md`) — File inventory, assignment gotchas, error codes, environment variables
- **TaskRouter REFERENCE.md** (`REFERENCE.md`) — Full API code samples, workflow configuration examples, testing patterns
- **Conference skill** (`skills/conference/SKILL.md`) — Conference instruction bridges agent to caller; "Use TaskRouter Instead When" decision
- **Voice skill** (`skills/voice/SKILL.md`) — Product selection: "Use TaskRouter when skill-based routing needed"
- **Voice Use Case Map** (`skills/voice-use-case-map/SKILL.md`) — UC 3 (Contact Center): TaskRouter + Conference + Recording + Sync
- **Codebase functions**: `contact-center-welcome.js` (enqueue), `assignment.protected.js` (conference instruction)
- **Callback handler**: `task-status.protected.js` — Event logging to Sync
- **Unit tests**: `__tests__/unit/taskrouter/` — 17 tests (6 welcome + 11 assignment)

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Test results | `references/test-results.md` | Live test evidence with SID references |
| Assertion audit | `references/assertion-audit.md` | Adversarial audit of every factual claim |
