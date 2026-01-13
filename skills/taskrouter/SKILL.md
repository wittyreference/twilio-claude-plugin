---
name: taskrouter
description: Skills-based routing with Twilio TaskRouter for contact centers. Use when routing tasks to workers based on skills, availability, or queues.
---

# TaskRouter Skill

Knowledge for building Twilio TaskRouter API functions for intelligent task routing to workers and agents.

## What is TaskRouter?

TaskRouter is a skill-based routing engine that distributes tasks to the most appropriate workers based on:
- Worker skills and attributes
- Worker availability
- Task priority and requirements
- Custom routing rules (workflows)

Common use cases: contact center routing, support ticket assignment, delivery dispatch.

## Core Concepts

| Concept | Description | SID Prefix |
|---------|-------------|------------|
| **Workspace** | Container for all TaskRouter configuration | `WS` |
| **Worker** | Agent who handles tasks (human or automated) | `WK` |
| **Task Queue** | Queue holding tasks waiting for workers | `WQ` |
| **Task** | Work item to be routed and handled | `WT` |
| **Workflow** | Routing rules that assign tasks to queues | `WW` |
| **Activity** | Worker state (Available, Offline, Break, etc.) | `WA` |

## API Overview

### Getting the TaskRouter Client

```javascript
const client = context.getTwilioClient();
const workspace = client.taskrouter.v1.workspaces(context.TWILIO_TASKROUTER_WORKSPACE_SID);
```

### Workers

```javascript
// List workers
const workers = await workspace.workers.list({ limit: 20 });

// Get specific worker
const worker = await workspace.workers(workerSid).fetch();

// Create worker
const worker = await workspace.workers.create({
  friendlyName: 'Alice',
  attributes: JSON.stringify({
    skills: ['english', 'billing'],
    department: 'support',
    level: 2
  })
});

// Update worker attributes
await workspace.workers(workerSid).update({
  attributes: JSON.stringify({
    skills: ['english', 'billing', 'technical'],
    department: 'support',
    level: 3
  })
});

// Update worker activity (Available, Offline, etc.)
await workspace.workers(workerSid).update({
  activitySid: availableActivitySid
});
```

### Tasks

```javascript
// Create task
const task = await workspace.tasks.create({
  workflowSid: context.TWILIO_TASKROUTER_WORKFLOW_SID,
  attributes: JSON.stringify({
    type: 'support',
    language: 'english',
    priority: 1,
    customerId: 'cust-123',
    callSid: event.CallSid
  }),
  timeout: 3600  // Task timeout in seconds
});

// Get task
const task = await workspace.tasks(taskSid).fetch();

// Update task (change priority, attributes)
await workspace.tasks(taskSid).update({
  attributes: JSON.stringify({
    ...JSON.parse(task.attributes),
    priority: 2
  })
});

// Complete task
await workspace.tasks(taskSid).update({
  assignmentStatus: 'completed',
  reason: 'resolved'
});

// Cancel task
await workspace.tasks(taskSid).update({
  assignmentStatus: 'canceled',
  reason: 'customer_hangup'
});
```

### Task Queues

```javascript
// List queues
const queues = await workspace.taskQueues.list();

// Create queue
const queue = await workspace.taskQueues.create({
  friendlyName: 'English Support',
  targetWorkers: '"skills" HAS "english" AND "skills" HAS "support"'
});

// Get queue statistics
const stats = await workspace.taskQueues(queueSid)
  .realTimeStatistics().fetch();
console.log(stats.tasksByStatus);
```

## Worker Attributes

Workers have JSON attributes defining their skills and capabilities:

```javascript
{
  "skills": ["english", "spanish", "billing", "technical"],
  "department": "support",
  "level": 2,
  "location": "US-West",
  "maxConcurrentTasks": 3
}
```

### Attribute Expressions

TaskRouter uses expressions to match workers to tasks:

| Expression | Description |
|------------|-------------|
| `"skills" HAS "english"` | Worker has skill |
| `level >= 2` | Numeric comparison |
| `department == "support"` | Exact match |
| `"skills" HAS "english" AND level >= 2` | Combined conditions |
| `"skills" IN task.required_skills` | Match against task attributes |

## Assignment Callback

When a task is assigned to a worker, TaskRouter calls your assignment webhook.

### Webhook Parameters

| Parameter | Description |
|-----------|-------------|
| `AccountSid` | Twilio Account SID |
| `WorkspaceSid` | TaskRouter Workspace SID |
| `TaskSid` | Assigned task SID |
| `TaskAttributes` | Task attributes JSON |
| `TaskAge` | Seconds since task creation |
| `TaskPriority` | Task priority value |
| `WorkerSid` | Assigned worker SID |
| `WorkerName` | Worker friendly name |
| `WorkerAttributes` | Worker attributes JSON |
| `ReservationSid` | Reservation SID |

### Assignment Instructions

Respond with instructions for what action to take:

```javascript
exports.handler = async (context, event, callback) => {
  const taskAttributes = JSON.parse(event.TaskAttributes);

  // For voice calls - dequeue to worker
  if (taskAttributes.type === 'call') {
    return callback(null, {
      instruction: 'dequeue',
      post_work_activity_sid: context.AFTER_CALL_ACTIVITY_SID
    });
  }

  // For other tasks - accept the reservation
  return callback(null, {
    instruction: 'accept'
  });
};
```

### Available Instructions

| Instruction | Description | Parameters |
|-------------|-------------|------------|
| `accept` | Accept the reservation | - |
| `reject` | Reject the reservation | `activity_sid` (optional) |
| `dequeue` | Connect voice call to worker | `from`, `post_work_activity_sid` |
| `call` | Initiate outbound call to worker | `url`, `from`, `to` |
| `redirect` | Redirect call to TwiML | `url` |

## Common Patterns

### Voice Call Routing

Route inbound calls to available agents:

```javascript
exports.handler = async (context, event, callback) => {
  const twiml = new Twilio.twiml.VoiceResponse();

  // Create task and enqueue caller
  twiml.enqueue({
    workflowSid: context.TWILIO_TASKROUTER_WORKFLOW_SID
  }).task({}, JSON.stringify({
    type: 'call',
    language: detectLanguage(event),
    callSid: event.CallSid,
    from: event.From,
    priority: 1
  }));

  // Optional: Play hold music while waiting
  twiml.say('Please wait while we connect you.');

  return callback(null, twiml);
};
```

### Worker Activity Management

```javascript
exports.handler = async (context, event, callback) => {
  const client = context.getTwilioClient();
  const workspace = client.taskrouter.v1
    .workspaces(context.TWILIO_TASKROUTER_WORKSPACE_SID);

  const { workerSid, activity } = event;

  // Map activity names to SIDs
  const activityMap = {
    available: context.ACTIVITY_AVAILABLE_SID,
    offline: context.ACTIVITY_OFFLINE_SID,
    break: context.ACTIVITY_BREAK_SID,
    busy: context.ACTIVITY_BUSY_SID
  };

  await workspace.workers(workerSid).update({
    activitySid: activityMap[activity]
  });

  return callback(null, { success: true });
};
```

## Error Handling

### Common Error Codes

| Code | Description |
|------|-------------|
| `20001` | Invalid parameter |
| `20404` | Resource not found |
| `22207` | Task Queue not found |
| `22208` | Workflow not found |
| `22209` | Worker not found |
| `22210` | Activity not found |
| `22211` | Task not found |
| `22212` | Reservation not found |
| `22213` | Task already assigned |
| `22214` | Invalid worker activity |

## Environment Variables

```
TWILIO_TASKROUTER_WORKSPACE_SID=WSxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_TASKROUTER_WORKFLOW_SID=WWxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ACTIVITY_AVAILABLE_SID=WAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ACTIVITY_OFFLINE_SID=WAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ACTIVITY_BREAK_SID=WAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ACTIVITY_BUSY_SID=WAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AFTER_CALL_ACTIVITY_SID=WAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Best Practices

1. **Use Meaningful Attributes**: Design worker and task attributes for flexible routing
2. **Set Appropriate Timeouts**: Configure reservation timeouts based on expected response times
3. **Handle Escalation**: Use workflow filters to escalate tasks to different queues
4. **Monitor Queue Health**: Track queue statistics for capacity planning
5. **Implement Fallbacks**: Always have a default queue for unmatched tasks
6. **Clean Up Tasks**: Complete or cancel tasks when done to avoid orphaned tasks
7. **Use Activities Properly**: Ensure workers set correct activity for accurate routing
