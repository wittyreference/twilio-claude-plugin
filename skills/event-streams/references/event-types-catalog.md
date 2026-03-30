---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Catalog of all Twilio Event Streams event types organized by product. -->
<!-- ABOUTME: Includes status (available/deprecated/discontinued) and schema IDs. -->

# Event Streams — Event Types Catalog

120+ event types across 17 product categories. Status values: `available`, `deprecated`, `discontinued`.

Deprecated types are subscribable but may not fire. Discontinued types are rejected.

## Messaging

### Outbound Message Status (`Messaging.MessageStatus`)
| Event Type | Status |
|------------|--------|
| `com.twilio.messaging.message.queued` | available |
| `com.twilio.messaging.message.sent` | available |
| `com.twilio.messaging.message.delivered` | available |
| `com.twilio.messaging.message.failed` | available |
| `com.twilio.messaging.message.undelivered` | available |
| `com.twilio.messaging.message.read` | available |

### Inbound Message (`Messaging.InboundMessageV1`)
| Event Type | Status |
|------------|--------|
| `com.twilio.messaging.inbound-message.received` | available |

## Voice

### Call Progress (`Voice.WebhookEvent`)
| Event Type | Status | Notes |
|------------|--------|-------|
| `com.twilio.voice.status-callback.call.initiated` | available | Current |
| `com.twilio.voice.status-callback.call.ringing` | available | Current |
| `com.twilio.voice.status-callback.call.answered` | available | Current |
| `com.twilio.voice.status-callback.call.completed` | available | Current |
| `com.twilio.voice.webhook.status-callback.call.initiated` | **deprecated** | Legacy prefix |
| `com.twilio.voice.webhook.status-callback.call.ringing` | **deprecated** | Legacy prefix |
| `com.twilio.voice.webhook.status-callback.call.answered` | **deprecated** | Legacy prefix |
| `com.twilio.voice.webhook.status-callback.call.completed` | **deprecated** | Legacy prefix |

### API Requests
| Event Type | Status |
|------------|--------|
| `com.twilio.voice.api-request.call.created` | available |
| `com.twilio.voice.api-request.call.modified` | available |
| `com.twilio.voice.api-request.conference.modified` | available |
| `com.twilio.voice.api-request.conference-participant.created` | available |
| `com.twilio.voice.api-request.conference-participant.deleted` | available |
| `com.twilio.voice.api-request.conference-participant.modified` | available |

### TwiML Events
| Event Type | Status |
|------------|--------|
| `com.twilio.voice.twiml.call.redirected` | available |
| `com.twilio.voice.twiml.call.transferred` | available |
| `com.twilio.voice.twiml.dial.finished` | available |
| `com.twilio.voice.twiml.enqueue.finished` | available |
| `com.twilio.voice.twiml.gather.finished` | available |
| `com.twilio.voice.twiml.record.finished` | available |
| `com.twilio.voice.twiml.request.failed` | available |
| `com.twilio.voice.twiml.requested` | available (docs) |

> **Warning**: `com.twilio.voice.twiml.requested` is listed in docs as available but the API rejects it: "Type not found in the system" (tested 2026-03-29).

### Status Callbacks (Voice)
| Event Type | Status |
|------------|--------|
| `com.twilio.voice.status-callback.amd.detected` | available |
| `com.twilio.voice.status-callback.announcement.processed` | available |
| `com.twilio.voice.status-callback.conference.participant.updated` | available |
| `com.twilio.voice.status-callback.conference.updated` | available |
| `com.twilio.voice.status-callback.gather.partial.captured` | available |
| `com.twilio.voice.status-callback.recording.processed` | available |
| `com.twilio.voice.status-callback.stream.updated` | available |
| `com.twilio.voice.status-callback.transcription.processed` | available |

### Media
| Event Type | Status |
|------------|--------|
| `com.twilio.voice.media.fetched` | available |

## Voice Insights (`VoiceInsights.CallSummary`)

| Event Type | Status | Latency |
|------------|--------|---------|
| `com.twilio.voice.insights.call-summary.partial` | available | ~10 min |
| `com.twilio.voice.insights.call-summary.predicted-complete` | available | ~10 min |
| `com.twilio.voice.insights.call-summary.complete` | available | ~30 min |
| `com.twilio.voice.insights.call-event.gateway` | available | ~90s |
| `com.twilio.voice.insights.call-event.sdk` | available | ~90s |
| `com.twilio.voice.insights.call-metrics.gateway` | available | ~90s |
| `com.twilio.voice.insights.call-metrics.sdk` | available | ~90s |

## Conference Insights

| Event Type | Status |
|------------|--------|
| `com.twilio.voice.insights.conference-summary.complete` | available |
| `com.twilio.voice.insights.conference-summary.partial` | available |
| `com.twilio.voice.insights.conference-participant-summary.complete` | available |

## TaskRouter (`TaskRouter.WDSEvent`)

### Task
| Event Type | Status |
|------------|--------|
| `com.twilio.taskrouter.task.created` | available |
| `com.twilio.taskrouter.task.updated` | available |
| `com.twilio.taskrouter.task.canceled` | available |
| `com.twilio.taskrouter.task.completed` | available |
| `com.twilio.taskrouter.task.deleted` | available |
| `com.twilio.taskrouter.task.system-deleted` | available |
| `com.twilio.taskrouter.task.wrapup` | available |
| `com.twilio.taskrouter.task.transfer-initiated` | available |
| `com.twilio.taskrouter.task.transfer-completed` | available |
| `com.twilio.taskrouter.task.transfer-failed` | available |
| `com.twilio.taskrouter.task.transfer-canceled` | available |
| `com.twilio.taskrouter.task.transfer-attempt-failed` | available |

### Reservation
| Event Type | Status |
|------------|--------|
| `com.twilio.taskrouter.reservation.created` | available |
| `com.twilio.taskrouter.reservation.accepted` | available |
| `com.twilio.taskrouter.reservation.rejected` | available |
| `com.twilio.taskrouter.reservation.timeout` | available |
| `com.twilio.taskrouter.reservation.canceled` | available |
| `com.twilio.taskrouter.reservation.rescinded` | available |
| `com.twilio.taskrouter.reservation.completed` | available |
| `com.twilio.taskrouter.reservation.failed` | available |
| `com.twilio.taskrouter.reservation.wrapup` | available |

### Worker
| Event Type | Status |
|------------|--------|
| `com.twilio.taskrouter.worker.created` | available |
| `com.twilio.taskrouter.worker.deleted` | available |
| `com.twilio.taskrouter.worker.activity.update` | available |
| `com.twilio.taskrouter.worker.attributes.update` | available |
| `com.twilio.taskrouter.worker.capacity.update` | available |
| `com.twilio.taskrouter.worker.channel.availability.update` | available |

### Task Queue
| Event Type | Status |
|------------|--------|
| `com.twilio.taskrouter.task-queue.created` | available |
| `com.twilio.taskrouter.task-queue.deleted` | available |
| `com.twilio.taskrouter.task-queue.entered` | available |
| `com.twilio.taskrouter.task-queue.moved` | available |
| `com.twilio.taskrouter.task-queue.timeout` | available |
| `com.twilio.taskrouter.task-queue.expression-updated` | available |

### Workflow
| Event Type | Status |
|------------|--------|
| `com.twilio.taskrouter.workflow.entered` | available |
| `com.twilio.taskrouter.workflow.rejected` | available |
| `com.twilio.taskrouter.workflow.skipped` | available |
| `com.twilio.taskrouter.workflow.target-matched` | available |
| `com.twilio.taskrouter.workflow.timeout` | available |

### Rate Limit
| Event Type | Status |
|------------|--------|
| `com.twilio.apiusage.taskrouter.ratelimits` | available |

## Conversations

| Event Type | Status |
|------------|--------|
| `com.twilio.conversations.conversation.added` | available |
| `com.twilio.conversations.conversation.removed` | available |
| `com.twilio.conversations.conversation.updated` | available |
| `com.twilio.conversations.conversation-state.updated` | available |
| `com.twilio.conversations.message.added` | available |
| `com.twilio.conversations.message.removed` | available |
| `com.twilio.conversations.message.updated` | available |
| `com.twilio.conversations.participant.added` | available |
| `com.twilio.conversations.participant.removed` | available |
| `com.twilio.conversations.participant.updated` | available |
| `com.twilio.conversations.user.added` | available |
| `com.twilio.conversations.user.updated` | available |
| `com.twilio.conversations.delivery.updated` | **discontinued** |

## Verify

### Verification Status
| Event Type | Status |
|------------|--------|
| `com.twilio.accountsecurity.verify.verification.approved` | available |
| `com.twilio.accountsecurity.verify.verification.canceled` | available |
| `com.twilio.accountsecurity.verify.verification.expired` | available |
| `com.twilio.accountsecurity.verify.verification.max_attempts_reached` | available |
| `com.twilio.accountsecurity.verify.verification.pending` | available |

### Message Status
| Event Type | Status |
|------------|--------|
| `com.twilio.accountsecurity.verify.message.delivered` | available |
| `com.twilio.accountsecurity.verify.message.failed` | available |
| `com.twilio.accountsecurity.verify.message.read` | available |
| `com.twilio.accountsecurity.verify.message.sent` | available |
| `com.twilio.accountsecurity.verify.message.undelivered` | available |

### Attempt DLR
| Event Type | Status |
|------------|--------|
| `com.twilio.accountsecurity.verify.attempt-dlr.delivered` | available |
| `com.twilio.accountsecurity.verify.attempt-dlr.failed` | available |
| `com.twilio.accountsecurity.verify.attempt-dlr.read` | available |
| `com.twilio.accountsecurity.verify.attempt-dlr.sent` | available |
| `com.twilio.accountsecurity.verify.attempt-dlr.undelivered` | available |

## Error Logs (`ErrorLogs.Error`)

| Event Type | Status |
|------------|--------|
| `com.twilio.error-logs.error.logged` | available |

> **Warning**: Fires for ALL log levels (INFO, WARNING, ERROR), not just errors. Creates feedback loops with Functions webhooks — see SKILL.md Gotcha #9.

## Studio (`Studio.FlowExecution` / `Studio.FlowStep`)

| Event Type | Status |
|------------|--------|
| `com.twilio.studio.flow.execution.started` | available |
| `com.twilio.studio.flow.execution.ended` | available |
| `com.twilio.studio.flow.step.ended` | available |

## IAM

| Event Type | Status |
|------------|--------|
| `com.twilio.iam.ip.blocked` | available |
| `com.twilio.iam.ip.blocked.dryrun` | available |

## A2P Compliance

### Brand Registration
| Event Type | Status |
|------------|--------|
| `com.twilio.messaging.compliance.brand-registration.brand-failure` | available |
| `com.twilio.messaging.compliance.brand-registration.brand-registered` | available |
| `com.twilio.messaging.compliance.brand-registration.brand-unverified` | available |
| `com.twilio.messaging.compliance.brand-registration.brand-verified` | available |
| `com.twilio.messaging.compliance.brand-registration.brand-vetted-verified` | available |
| `com.twilio.messaging.compliance.brand-registration.brand-secondary-vetting-failure` | available |
| `com.twilio.messaging.compliance.brand-registration.sharing-created` | available |
| `com.twilio.messaging.compliance.brand-registration.sharing-deleted` | available |
| `com.twilio.messaging.compliance.brand-registration.invalid-contact-email` | available |

### Brand Registration 2FA Email
| Event Type | Status |
|------------|--------|
| `com.twilio.messaging.compliance.brand-registration.email-2fa-clicked` | available |
| `com.twilio.messaging.compliance.brand-registration.email-2fa-completed` | available |
| `com.twilio.messaging.compliance.brand-registration.email-2fa-opened` | available |
| `com.twilio.messaging.compliance.brand-registration.email-2fa-sent` | available |
| `com.twilio.messaging.compliance.brand-registration.email-2fa-timeout` | available |

### Campaign Registration
| Event Type | Status |
|------------|--------|
| `com.twilio.messaging.compliance.campaign-registration.campaign-approved` | available |
| `com.twilio.messaging.compliance.campaign-registration.campaign-deleted` | available |
| `com.twilio.messaging.compliance.campaign-registration.campaign-failure` | available |
| `com.twilio.messaging.compliance.campaign-registration.campaign-submitted` | available |
| `com.twilio.messaging.compliance.campaign-registration.suspended-campaign-delete-submitted` | available |

### Number Registration/Deregistration
| Event Type | Status |
|------------|--------|
| `com.twilio.messaging.compliance.number-registration.failed` | available |
| `com.twilio.messaging.compliance.number-registration.pending` | available |
| `com.twilio.messaging.compliance.number-registration.successful` | available |
| `com.twilio.messaging.compliance.number-deregistration.failed` | available |
| `com.twilio.messaging.compliance.number-deregistration.pending` | available |
| `com.twilio.messaging.compliance.number-deregistration.successful` | available |

### Toll Free Verification
| Event Type | Status |
|------------|--------|
| `com.twilio.messaging.compliance.toll-free-verification.edit` | available |
| `com.twilio.messaging.compliance.toll-free-verification.expired` | available |
| `com.twilio.messaging.compliance.toll-free-verification.failure` | available |
| `com.twilio.messaging.compliance.toll-free-verification.requested` | available |
| `com.twilio.messaging.compliance.toll-free-verification.pending-review` | available |
| `com.twilio.messaging.compliance.toll-free-verification.request-approved` | available |
| `com.twilio.messaging.compliance.toll-free-verification.deleted` | available |
| `com.twilio.messaging.compliance.toll-free-verification.rejected` | available |

### Resource Cleanup
| Event Type | Status |
|------------|--------|
| `com.twilio.messaging.compliance.a2p-resource-cleanup-finished` | available |
| `com.twilio.messaging.compliance.a2p-resource-cleanup-started` | available |

## Notify (`Notify.PushNotificationDelivery`)

| Event Type | Status |
|------------|--------|
| `com.twilio.notify.notification.delivered` | available |

## Video Insights

| Event Type | Status |
|------------|--------|
| `com.twilio.video.insights.log-analyzer.participant-summary` | available |
| `com.twilio.video.insights.log-analyzer.room-summary` | available |
| `com.twilio.video.insights.participant-summary.complete` | available |
| `com.twilio.video.insights.room-summary.complete` | available |
| `com.twilio.video.insights.track-summary.complete` | available |

## Link Shortening

| Event Type | Status |
|------------|--------|
| `com.twilio.daptbt.link-shortening.link-clicked` | available |
| `com.twilio.daptbt.link-shortening.link-shortened` | available |

## Lookup

| Event Type | Status |
|------------|--------|
| `com.twilio.lookup.bulk.job-status-changed` | available |

## Engagement Intelligence

| Event Type | Status |
|------------|--------|
| `com.twilio.engagement-intelligence.transcript.operators.results-available` | **restricted** |
| `com.twilio.engagement-intelligence.transcript.finished` | **restricted** |

## IoT — Super SIM (Discontinued)

| Event Type | Status |
|------------|--------|
| `com.twilio.iot.supersim.connection.attachment.accepted` | **discontinued** |
| `com.twilio.iot.supersim.connection.attachment.failed` | **discontinued** |
| `com.twilio.iot.supersim.connection.attachment.rejected` | **discontinued** |
| `com.twilio.iot.supersim.connection.data-session.ended` | **discontinued** |
| `com.twilio.iot.supersim.connection.data-session.failed` | **discontinued** |
| `com.twilio.iot.supersim.connection.data-session.started` | **discontinued** |
| `com.twilio.iot.supersim.connection.data-session.updated` | **discontinued** |
