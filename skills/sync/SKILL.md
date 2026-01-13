---
name: sync
description: Real-time state synchronization with Twilio Sync Documents, Lists, Maps, and Streams. Use when needing shared state across clients or webhook invocations.
---

# Sync Skill

Knowledge for building Twilio Sync API functions for real-time state synchronization across devices and services.

## What is Twilio Sync?

Twilio Sync provides real-time state synchronization primitives for building collaborative and stateful applications:
- **Documents**: Single JSON objects for simple state (like a settings object)
- **Lists**: Ordered collections with automatic indexing (like a chat history)
- **Maps**: Key-value stores for flexible lookups (like user sessions)
- **Streams**: Pub/sub messaging for ephemeral events (like typing indicators)

## API Overview

### Sync Service

All Sync operations require a Sync Service SID.

```javascript
const client = context.getTwilioClient();
const syncService = client.sync.v1.services(context.TWILIO_SYNC_SERVICE_SID);
```

### Documents

Single JSON objects (up to 16KB). Ideal for configuration, settings, or simple state.

```javascript
// Create document
const doc = await syncService.documents.create({
  uniqueName: 'app-config',
  data: { theme: 'dark', version: '1.0' },
  ttl: 86400  // Optional: auto-delete after 24 hours
});

// Fetch document
const doc = await syncService.documents('app-config').fetch();
console.log(doc.data);  // { theme: 'dark', version: '1.0' }

// Update document (full replace)
await syncService.documents('app-config').update({
  data: { theme: 'light', version: '1.1' }
});

// Delete document
await syncService.documents('app-config').remove();
```

### Lists

Ordered collections with automatic indexing. Ideal for message history, activity feeds.

```javascript
// Create list
const list = await syncService.syncLists.create({
  uniqueName: 'chat-messages'
});

// Add item to list
const item = await syncService.syncLists('chat-messages')
  .syncListItems.create({
    data: { sender: 'user123', text: 'Hello!' }
  });
console.log(item.index);  // Auto-assigned index

// Fetch items (paginated)
const items = await syncService.syncLists('chat-messages')
  .syncListItems.list({ limit: 20, order: 'desc' });

// Update item by index
await syncService.syncLists('chat-messages')
  .syncListItems(0).update({
    data: { sender: 'user123', text: 'Hello! (edited)' }
  });

// Delete item
await syncService.syncLists('chat-messages')
  .syncListItems(0).remove();
```

### Maps

Key-value stores for flexible lookups. Ideal for user sessions, device states.

```javascript
// Create map
const map = await syncService.syncMaps.create({
  uniqueName: 'user-sessions'
});

// Set item by key
await syncService.syncMaps('user-sessions')
  .syncMapItems.create({
    key: 'user-123',
    data: { lastSeen: new Date().toISOString(), status: 'online' }
  });

// Get item by key
const item = await syncService.syncMaps('user-sessions')
  .syncMapItems('user-123').fetch();

// Update item
await syncService.syncMaps('user-sessions')
  .syncMapItems('user-123').update({
    data: { lastSeen: new Date().toISOString(), status: 'away' }
  });

// Delete item
await syncService.syncMaps('user-sessions')
  .syncMapItems('user-123').remove();

// List all items
const items = await syncService.syncMaps('user-sessions')
  .syncMapItems.list({ limit: 100 });
```

### Streams

Pub/sub messaging for ephemeral events. Messages are not persisted.

```javascript
// Create stream
const stream = await syncService.syncStreams.create({
  uniqueName: 'typing-indicators'
});

// Publish message to stream
await syncService.syncStreams('typing-indicators')
  .streamMessages.create({
    data: { userId: 'user-123', typing: true }
  });
```

## TTL (Time-To-Live)

All Sync objects support automatic expiration:

```javascript
// Document with 1-hour TTL
await syncService.documents.create({
  uniqueName: 'temp-session',
  data: { token: 'abc123' },
  ttl: 3600  // Seconds until auto-delete
});

// List item with TTL
await syncService.syncLists('my-list')
  .syncListItems.create({
    data: { message: 'Temporary' },
    ttl: 300  // Item expires in 5 minutes
  });
```

## Common Patterns

### Call State Management

Track multi-step call state across webhooks:

```javascript
// Store call state
exports.storeCallState = async (context, event, callback) => {
  const client = context.getTwilioClient();
  const syncService = client.sync.v1.services(context.TWILIO_SYNC_SERVICE_SID);

  await syncService.documents.create({
    uniqueName: `call-${event.CallSid}`,
    data: {
      stage: 'greeting',
      selections: [],
      startTime: new Date().toISOString()
    },
    ttl: 3600  // Clean up after 1 hour
  });

  return callback(null, { success: true });
};

// Retrieve and update call state
exports.getCallState = async (context, event, callback) => {
  const client = context.getTwilioClient();
  const syncService = client.sync.v1.services(context.TWILIO_SYNC_SERVICE_SID);

  const doc = await syncService.documents(`call-${event.CallSid}`).fetch();
  const callState = doc.data;

  // Update state
  await syncService.documents(`call-${event.CallSid}`).update({
    data: {
      ...callState,
      stage: 'menu',
      selections: [...callState.selections, event.Digits]
    }
  });

  return callback(null, callState);
};
```

### User Presence

Track online/offline status across devices:

```javascript
exports.handler = async (context, event, callback) => {
  const client = context.getTwilioClient();
  const syncService = client.sync.v1.services(context.TWILIO_SYNC_SERVICE_SID);

  const { userId, status } = event;

  await syncService.syncMaps('user-presence')
    .syncMapItems.create({
      key: userId,
      data: {
        status: status,  // 'online', 'away', 'offline'
        lastSeen: new Date().toISOString(),
        device: event.device || 'unknown'
      },
      ttl: 300  // Auto-offline after 5 minutes if no heartbeat
    });

  return callback(null, { success: true });
};
```

## Error Handling

### Common Error Codes

| Code | Description |
|------|-------------|
| `54001` | Sync Service not found |
| `54007` | Document not found |
| `54008` | List not found |
| `54009` | Map not found |
| `54011` | List item not found |
| `54012` | Map item not found |
| `54301` | Document data too large (>16KB) |
| `54302` | Unique name already exists |

### Error Handling Pattern

```javascript
exports.handler = async (context, event, callback) => {
  const client = context.getTwilioClient();
  const syncService = client.sync.v1.services(context.TWILIO_SYNC_SERVICE_SID);

  try {
    const doc = await syncService.documents(event.docName).fetch();
    return callback(null, { success: true, data: doc.data });
  } catch (error) {
    if (error.code === 54007) {
      // Document not found - create it
      const newDoc = await syncService.documents.create({
        uniqueName: event.docName,
        data: { initialized: true }
      });
      return callback(null, { success: true, data: newDoc.data, created: true });
    }
    if (error.code === 54302) {
      // Already exists (race condition) - fetch it
      const doc = await syncService.documents(event.docName).fetch();
      return callback(null, { success: true, data: doc.data });
    }
    throw error;
  }
};
```

## Environment Variables

```
TWILIO_SYNC_SERVICE_SID=ISxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Create a Sync Service in the Twilio Console or via CLI:

```bash
twilio api:sync:v1:services:create --friendly-name "My Sync Service"
```

## Best Practices

1. **Use Unique Names**: Always set `uniqueName` for predictable access patterns
2. **Set TTLs**: Use TTL for temporary data to avoid storage buildup
3. **Handle Conflicts**: Document updates are last-write-wins; use Maps for key-based updates
4. **Limit Data Size**: Documents max 16KB; use Lists for larger datasets
5. **Use Streams for Ephemeral Data**: Don't persist data that doesn't need history
6. **Clean Up**: Delete Sync objects when no longer needed
7. **Secure Endpoints**: Use `.protected.js` for write operations
