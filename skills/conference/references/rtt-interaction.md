---
name: "conference"
description: "Twilio development skill: conference"
---

<!-- ABOUTME: Behavior when combining Conference with Real-Time Transcription (RTT). -->
<!-- ABOUTME: Track semantics, speaker labeling, hold interaction, and capture method conflicts. -->

# Conference + Real-Time Transcription Interaction

This reference documents the interaction between Twilio Conference and `<Start><Transcription>` (RTT). Both are mature products with extensive individual documentation, but their combined behavior has gaps.

## Track Semantics in Conference Context

On a simple two-party call, RTT track labels map clearly:
- `inbound_track` = the caller's audio
- `outbound_track` = the called party's audio

**In a conference, this changes:**
- `inbound_track` = the participant's microphone (their individual audio)
- `outbound_track` = the conference mix (all other participants combined)

This means a conference participant's outbound track contains the mixed audio of everyone else in the room, making per-speaker attribution impossible from track labels alone.

## Behavior Matrix

| Scenario | Expected Behavior | Status |
|----------|-------------------|--------|
| RTT started before `<Dial><Conference>` | [UNTESTED] May continue running after participant joins conference |
| RTT started via REST API mid-conference | [UNTESTED] Should work on already-conferenced calls |
| `track: inbound_track` in conference | Transcribes only that participant's speech | Deduced from track semantics |
| `track: outbound_track` in conference | Transcribes the conference mix (all other participants) | Deduced from track semantics |
| `track: both_tracks` in conference | Two callback streams: participant mic + conference mix | Deduced from track semantics |
| Speaker diarization with 4+ participants | Not possible — outbound_track is a mix, no per-speaker labels | Confirmed (RTT SKILL.md scope) |
| RTT on a held participant | Hold music is transcribed on the inbound track | Deduced from conference gotcha #14 |
| RTT callbacks during hold music | Expect garbage transcription of hold music | Deduced |
| Stopping RTT on one participant | [UNTESTED] Should not affect other participants' RTT |
| RTT + conference-level recording | Both run independently without conflict | Deduced from RTT gotcha #14 |

## Hold Interaction

Conference gotcha #14 states: "Recording captures hold music." By the same audio routing logic, RTT will also transcribe hold music when a participant is on hold. The STT engine will attempt to transcribe the music, producing nonsensical text.

**Mitigation:** Stop or pause RTT when placing a participant on hold, or filter hold-period transcriptions in post-processing.

## Capture Method Matrix

Three simultaneous capture methods are possible on a conference call:

| Method | What It Captures | Channel Layout |
|--------|-----------------|----------------|
| Conference recording (`record=true`) | Mixed audio of all participants | Single channel (mono mix) |
| `<Start><Recording>` on a participant | That participant's call leg | Dual-channel (participant + conference) |
| `<Start><Transcription>` (RTT) | Real-time text from STT engine | Per-track callbacks |

### Combination Safety

| Combination | Safe? | Notes |
|-------------|-------|-------|
| Conference recording + RTT | Yes | Independent systems, no conflict |
| Conference recording + `<Start><Recording>` | No — duplicates | Conference gotcha #15: produces duplicate recordings |
| RTT + `<Start><Recording>` | Yes | Confirmed on simple calls (RTT gotcha #14) [UNTESTED on conference legs] |
| All three simultaneously | Risky | The recording combination causes duplicates; RTT is likely fine |

## Coaching Audio

Conference gotcha #22: "Conference recording does NOT capture coaching audio." Coaching uses a separate audio path. Whether RTT captures coaching audio is **[UNTESTED]**. If RTT is attached to the coached participant's call leg, the coaching whisper may or may not appear in the transcription callbacks.

## Recommended Patterns

### Single-speaker transcription in conference
Use `track: inbound_track` on each participant you want to transcribe. This gives you clean, per-speaker text without conference mix noise.

### Full conference transcription
Start RTT with `track: inbound_track` on each participant separately. Correlate callbacks by `CallSid` to identify speakers. Do NOT use `outbound_track` for this — it's a mix and produces poor STT results.

### Conference with recording + transcription
Use conference-level recording for the audio record. Use RTT for real-time text. Do NOT also add `<Start><Recording>` — it creates duplicate recordings.

## Gotchas

1. **RTT outbound_track in conference = conference mix, not a single far-end**: Track semantics differ from simple calls. See Track Semantics section above.
2. **Hold music is transcribed**: RTT doesn't know about hold state. Expect garbage text during hold periods.
3. **No per-speaker diarization in multi-party conference**: RTT labels by track (participant vs mix), not by speaker identity.
4. **Conference recording + `<Start><Recording>` = duplicates**: Do not combine these two recording methods on the same conference.

## Related Resources

- [Conference SKILL.md](/.claude/skills/conference/SKILL.md) — Full conference guide (22 gotchas)
- [Real-Time Transcription SKILL.md](/.claude/skills/real-time-transcription/SKILL.md) — RTT guide (20 gotchas)
- [Recordings SKILL.md](/.claude/skills/recordings/SKILL.md) — Recording methods and lifecycle
