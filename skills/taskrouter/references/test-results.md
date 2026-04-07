---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Live test evidence for TaskRouter skill assertions. Every behavioral claim traces back to a SID. -->
<!-- ABOUTME: Use when verifying skill claims or reproducing test scenarios. -->

# TaskRouter Skill — Live Test Results

Evidence date: 2026-03-25. Account: ACxx...xx. Workspace: WS04a6cec181fb434ef1fe8394ec13380d (deleted after testing).

## Test Resources

| Resource | SID | Purpose |
|----------|-----|---------|
| Workspace | WS04a6cec181fb434ef1fe8394ec13380d | FIFO template test workspace |
| Activity (Offline) | WAa56b76ad5498913967b644c46c08d809 | Default + timeout activity |
| Activity (Available) | WA2284363cb1ede5d43e2d78e7d48250a7 | Available for tasks |
| Activity (Unavailable) | WA31a119fbee80b0ebacfd9df354016983 | System-created |
| Worker (Alice) | WKc1a5870652316f936b5b7a9e13d29b03 | Available, skills: support+sales, level 3 |
| Worker (Bob) | WK144eae9774012a3af25336783a1f11d9 | Offline, skills: support, level 1 |
| Worker (HyphenTest) | WKcd286d49341b1a24d351c4249b041c27 | Attribute `skill-level` with hyphen |
| Queue (Sample) | WQfe85a0a792c55e2f8f377d3c61e9cadb | FIFO template default (1==1) |
| Queue (Support) | WQ81a377254f6032b51141cff5a577dae2 | `skills HAS "support"` |
| Queue (Sales) | WQa281c13411c73dac282488237091a751 | `skills HAS "sales"` |
| Queue (Bad Expr) | WQeecb6580b49085310d8977f47ca19ce8 | `level HAS "support"` (HAS on number) |
| Workflow (FIFO) | WWa98902fa0a39f5b52040d72f3e505248 | Template default (120s timeout) |
| Workflow (Skill Router) | WWb6f659ff3c3baec5cae5ea96ea21fcb7 | Multi-filter: sales→Sales Queue, support→Support Queue |
| Task (Sales 1) | WT2c881f5059e999087ca49fb32d1ab51a | Auto-canceled on timeout |
| Task (Support) | WTa3944de0ace6e3bf3214a3a459dd4e31 | Pending (no available worker) |
| Task (Sales 2) | WT2b0a786583c9d27abd70cec7fda88d91 | Full lifecycle: pending→reserved→assigned→completed |
| Reservation (timeout) | WR95318340d4ea4da620da587bbf595519 | Timed out after 30s |
| Reservation (accepted) | WR277f05dc8a58a59d85df84119f8a0d3e | Accepted → task completed |

## Test 1: FIFO Template

| What was created | Details |
|-----------------|---------|
| Activities | 3: Offline (available=false), Available (available=true), Unavailable (available=false) |
| Task Queue | 1: "Sample Queue", targetWorkers="1==1", FIFO |
| Workflow | 1: "Default Fifo Workflow", 120s timeout, no callback URL |
| Default activity | Offline (WAa56b76ad) |
| Timeout activity | Offline (WAa56b76ad) — same as default |

## Test 2: Worker Creation

| Test | Result |
|------|--------|
| Create with Available activity | available=true, activityName="Available" (WKc1a5870) |
| Create with Offline activity | available=false, activityName="Offline" (WK144eae97) |
| Omit activitySid | Gets workspace defaultActivitySid (Offline) |
| Attributes JSON with arrays+numbers | Stored and returned correctly |
| Duplicate friendlyName "Alice" | Error 20001 "Worker with the same friendly name already exists" |
| Hyphen in attribute name | Accepted: `{"skill-level": 5}` stored OK (WKcd286d49) |

## Test 3: Expression Edge Cases

| Expression | Context | Result |
|-----------|---------|--------|
| `skills HAS "support"` | Queue create | OK — matches workers with support in skills array |
| `level HAS "support"` | Queue create | **Accepted** — no validation error. Queue created (WQeecb6580). Will never match. |
| `skill-level > 3` | Queue create | **Error 20001**: "extraneous input 'evel' expecting OPERATOR" — hyphen parsed as subtraction |

## Test 4: Task Routing & Priority

| Test | Result |
|------|--------|
| Sales task (type="sales") | Routed to Sales Queue, reserved for Alice (only available worker with sales skill) |
| Support task (type="support") | Routed to Support Queue, **0 reservations** (Alice already reserved, Bob offline) |
| Workflow target priority | Target `priority: 5` applied to task (WT2b0a7865 shows priority=5) |
| Task priority from target `priority: 3` | Support task shows priority=3 (from workflow target) |

## Test 5: Reservation Lifecycle

| Step | Observation |
|------|------------|
| Task created | assignmentStatus=pending |
| Worker matched | Reservation WR95318340 created, status=pending |
| 30s elapsed (no response) | Reservation status=timeout |
| Worker activity after timeout | **Moved from Available to Offline** (timeoutActivitySid) |
| Task status after timeout | **canceled**, reason="Task canceled on Workflow timeout" |
| Set worker back to Available | Immediately reserved for next pending task (WR277f05dc) |
| Accept reservation | reservationStatus=accepted, task=assigned |
| Complete task | assignmentStatus=completed, reason="resolved" |

## Test 6: Activity Immutability

| Test | Result |
|------|--------|
| Update Offline activity: Available=true | HTTP 200 returned — **no error** — but available stayed false. Silent no-op. |

## Test 7: Queue Statistics

| Field | Sales Queue | Support Queue |
|-------|------------|---------------|
| totalAvailableWorkers | 1 | 1 |
| totalEligibleWorkers | 1 | 2 |
| totalTasks | 1 | 1 |
| longestTaskWaitingAge | 0 | 11 |
| tasksByStatus.reserved | 1 | 0 |
| tasksByStatus.pending | 0 | 1 |
| activityStatistics | Per-activity worker count breakdown | Per-activity worker count breakdown |

## Test 8: validate_task Event Timeline

Task WT2b0a786583c9d27abd70cec7fda88d91 full event history:

| Event | Type | Timestamp |
|-------|------|-----------|
| 1 | workflow.entered | 04:00:56 |
| 2 | task-queue.entered | 04:00:56 |
| 3 | task.created | 04:00:56 |
| 4 | workflow.target-matched | 04:00:56 |
| 5 | reservation.created | 04:01:16 |
| 6 | reservation.accepted | 04:01:26 |
| 7 | task.completed | 04:06:18 |
| 8 | reservation.completed | 04:06:18 |
| 9 | task.updated | 04:06:18 |

## Test 9: Task Attributes in List

| Endpoint | Attributes Present? |
|----------|-------------------|
| REST `GET /Tasks?PageSize=2` | **Yes** — full attributes returned (contradicts docs) |
| MCP `list_tasks` | Yes — attributes included |

## Cleanup

Workspace WS04a6cec181fb434ef1fe8394ec13380d deleted — cascading removal of all child resources.
