---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Troubleshooting guide for missing, empty, short, or broken recordings. -->
<!-- ABOUTME: MCP validation workflow and common failure modes from live testing. -->

# Debugging Recordings

## Recording Missing Entirely

| Check | How | What it means |
|-------|-----|---------------|
| Was recording started? | `list_call_recordings(callSid)` | 0 results = recording never started |
| Wrong verb? | `.record()` vs `.recording()` | `.record()` = `<Record>` verb, `.recording()` = `<Start><Recording>` |
| Two methods combined? | `list_recordings(callSid)` | Two RE SIDs = duplicate recording, one may look "missing" |
| Call failed? | `validate_call(callSid)` | Failed calls may not produce recordings |
| CR call with API recording? | Check for error 20005 | `start_call_recording` rejected on ConversationRelay calls |
| Trunk recording on wrong SID? | `list_recordings` account-wide | Trunk recordings are on the trunk leg call SID, not parent |
| Callback URL relative? | Check for error 11200 | `<Start><Recording>` requires absolute URLs |

## Recording Empty (0 seconds)

- `record-from-answer` on a call that was never answered
- `trim-silence` removed all content (the recording was only silence)
- One-way audio issue (no audio flowing in one direction)
- Check Voice Insights for media quality issues

## Recording Shorter Than Expected

- `<Record>` verb has `maxLength` limit (default 3600s)
- `trim-silence` removed leading/trailing silence (confirmed: reduced 10s → 5s in testing)
- `record-from-answer` excludes ring time (use `record-from-ringing` to include)
- `pauseBehavior: 'skip'` removes paused time from duration (confirmed: 15s call → 7s recording)
- Call dropped before recording was flushed

## Recording Has Wrong Channel Count

- `<Start><Recording>` **always produces 2 channels** regardless of `recordingTrack` parameter
- `Record=true` on Calls API **defaults to mono** (must specify `recordingChannels: 'dual'` explicitly)
- Conference recording is **always mono** (all participants mixed)
- `<Dial record="record-from-answer-dual">` = 2 channels, `record-from-answer` = 1 channel

## Callback Not Firing

1. `recordingStatusCallback` is absolute URL? (`<Start><Recording>` requires it)
2. `recordingStatusCallbackEvent` includes the event you expect? (default: only `completed`)
3. Function deployed and accessible? (`validate_debugger()` for webhook errors)
4. Returning 200 from callback? (non-200 = retry, but initial callback still fires)

## Speaker Labels Swapped in Transcript

Channel assignment differs by recording source:
- **API/TwiML recordings**: ch1=child leg (TO number), ch2=parent leg (API side)
- **SIP trunk recordings**: ch1=Twilio side, ch2=PBX side

If Voice Intelligence shows the wrong speaker, your `channel_participant` mapping is inverted. Swap the participant user IDs.

## Pause/Resume Not Working

- **ConversationRelay calls**: Cannot use `start_call_recording` or pause/resume. Use `<Start><Recording>` before `<Connect>`.
- **`Twilio.CURRENT`**: Use as recording SID when you don't know the RE SID.
- **`pauseBehavior`**: `skip` removes time, `silence` inserts dead air.

## Validation Workflow (MCP Tools)

Step-by-step diagnostic:

```
1. validate_call(callSid)
   → Was the call successful? Check notifications for errors.

2. list_call_recordings(callSid)
   → Do recordings exist? How many? What are their statuses?

3. validate_recording(recordingSid)
   → Is the recording complete? Does duration match expectations?

4. validate_debugger(resourceSid: callSid)
   → Any 11200, 13xxx, or other errors during the call?

5. get_recording(recordingSid)
   → Check channels, source, duration, mediaUrl
```

For trunk recordings, also check with `list_recordings` account-wide since the recording may be on a different call SID.
