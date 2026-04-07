---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Recording status callbacks, lifecycle states, and retrieval patterns. -->
<!-- ABOUTME: Complete callback field reference and idempotent handling pattern. -->

# Callbacks, Lifecycle & Retrieval

## Recording Status Lifecycle

```
in-progress → paused (optional) → stopped → processing → completed
                                                       → failed
                                                       → absent
```

| Status | Description |
|--------|-------------|
| `in-progress` | Recording is actively capturing audio |
| `paused` | Recording paused (via API `update_call_recording`) |
| `stopped` | Recording stopped (call ended or API stop) |
| `processing` | Audio file being prepared |
| `completed` | Recording available for download |
| `failed` | Recording failed (check `ErrorCode`) |
| `absent` | No audio detected in recording |

## Callback Fields

All recording status callbacks include these fields (confirmed via live testing):

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| `AccountSid` | string | `ACxx...xx` | Account that owns the recording |
| `CallSid` | string | `CA...` | Call the recording is associated with |
| `RecordingSid` | string | `RE...` | Unique recording identifier |
| `RecordingUrl` | string | `https://api.twilio.com/.../RE...` | **Without file extension** |
| `RecordingStatus` | string | `completed` | Current lifecycle status |
| `RecordingDuration` | string | `13` | Duration in seconds (as string) |
| `RecordingChannels` | string | `1` or `2` | Channel count (as string) |
| `RecordingSource` | string | `DialVerb` | See source values below |
| `RecordingStartTime` | string | `Tue, 24 Mar 2026 18:15:40 +0000` | RFC 2822 format |
| `RecordingTrack` | string | `both` | Defaults to `both` even when method doesn't support tracks |
| `ErrorCode` | string | `0` | `0` for success |

### Source Values

| Source | Created By |
|--------|-----------|
| `RecordVerb` | `<Record>` TwiML verb |
| `DialVerb` | `<Dial record="...">` attribute |
| `StartCallRecordingTwiML` | `<Start><Recording>` verb |
| `OutboundAPI` | Calls API with `Record=true` |
| `StartCallRecordingAPI` | `start_call_recording` tool / POST /Calls/{sid}/Recordings |
| `Conference` | Conference `record` attribute |
| `Trunking` | Elastic SIP Trunk configuration |

## Callback Events

Subscribe to specific events via `recordingStatusCallbackEvent`:

| Event | When |
|-------|------|
| `in-progress` | Recording started |
| `completed` | Recording finished and available |
| `absent` | No audio detected |

Default: only `completed` events fire.

## Idempotent Callback Handling

Twilio retries callbacks on non-200 responses. Always handle duplicates:

```javascript
// Pattern from recording-complete.protected.js
try {
  await client.sync.v1.services(syncSid).documents.create({
    uniqueName: `recording-${CallSid}`,
    data: { recordingSid, recordingUrl, ... },
    ttl: 86400,
  });
} catch (err) {
  if (err.code === 54301) {
    // Duplicate callback — document already exists
    console.log('Duplicate callback, skipping');
  } else {
    throw err;
  }
}

// Always return 200 to prevent retries
response.setStatusCode(200);
```

## Retrieving Recordings

### Download URL

Append `.mp3` or `.wav` to the `RecordingUrl`:

```javascript
const mp3Url = `${RecordingUrl}.mp3`;
const wavUrl = `${RecordingUrl}.wav`;
```

Default (no extension) returns JSON metadata.

### Authentication

Recording URLs require HTTP Basic Auth with Account SID and Auth Token:

```bash
curl -u "$ACCOUNT_SID:$AUTH_TOKEN" \
  "https://api.twilio.com/2010-04-01/Accounts/$ACCOUNT_SID/Recordings/RE...mp3" \
  -o recording.mp3
```

### Format Details

| Format | Codec | Size Estimate |
|--------|-------|--------------|
| WAV | PCM 16-bit, 8000 Hz | ~1 MB/min (mono), ~2 MB/min (dual) |
| MP3 | — | ~120 KB/min (mono) |

Recordings are WAV (PCM 16-bit, 8000 Hz) natively. MP3 is transcoded on download.

## Deletion

`DELETE /Recordings/{sid}` is a soft delete:
- Recording becomes inaccessible immediately
- Metadata retained for 40 days
- Use `includeSoftDeleted: true` on list queries to see deleted recordings
- After 40 days: permanently deleted

MCP tool: `delete_recording` or `delete_call_recording`.
