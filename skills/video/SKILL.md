---
name: "video"
description: "Twilio development skill: video"
---

---
name: video
description: Twilio Video development guide. Use when building video applications, telehealth platforms, remote collaboration tools, or working with rooms, participants, recordings, and compositions.
---

# Video Development Skill

Comprehensive decision-making guide for Twilio Video development. Load this skill when building video applications, telehealth platforms, or remote collaboration tools.

**Validated**: 2026-03-28 against account ACb4de2... with live API tests. All assertions backed by SID evidence in `references/assertion-audit.md`.

## Scope

### CAN
- Group rooms with up to 50 participants (server-mediated via SFU)
- Per-track recording (audio + video separately) in Matroska containers
- Compositions: combine tracks into single MP4/WebM after room ends
- Composition Hooks: automatic composition on every room end
- Recording Rules: fine-grained include/exclude by participant, track kind, or track name
- Real-time transcription with speaker attribution
- PSTN dial-in/dial-out (audio-only participants, max 35)
- Track Subscriptions API for observer/supervisor patterns
- DataTrack for in-call messaging (reliable, ordered, max 64KB)
- VP8 simulcast for bandwidth-adaptive multi-party
- Network Quality API (levels 1-5 per participant)
- Media region selection (us1, us2, ie1, de1, au1, br1, jp1, sg1, in1, gll)

### CANNOT
- Create P2P, group-small, go, or audio-only rooms on accounts created after Oct 21, 2024 (error 53126; legacy accounts retain access)
- Set `maxConcurrentPublishedTracks` per room — value is account-level (170 on standard accounts), ignores per-room input
- Use `audioOnly: true` — removed, error 53127
- Use `largeRoom: true` — requires special account enablement (error 53103 on standard accounts)
- Set `maxParticipants` to 0 for "unlimited" — 0 is rejected (error 53107), range is 1-50
- Use H.264 with simulcast — H.264 does not support simulcast encoding
- Compose during an in-progress room and get a successful result — API accepts the request but composition status ends as `failed` without completed recordings
- Record in P2P/Go rooms — server-side recording requires Group rooms
- Record DataTracks — only audio and video tracks are captured
- Distinguish API-initiated participant removal from voluntary leave via disconnect error codes

## Room Type Decision

**Use `group` rooms.** This is the only room type available to accounts created after October 21, 2024. Legacy types (peer-to-peer, group-small, go) return error 53126 on newer accounts.

| Room Type | Status | Notes |
|-----------|--------|-------|
| `group` | Active | Full features, HIPAA-eligible, up to 50 participants |
| `group-small` | Legacy (Oct 2024) | Error 53126 on newer accounts |
| `peer-to-peer` | Legacy (Oct 2024) | Error 53126 on newer accounts |
| `go` | Legacy (Oct 2024) | Error 53126 on newer accounts |

## Quick Decision Reference

| Need | Use | Why |
|------|-----|-----|
| Any video session | `group` room | Only HIPAA-eligible type |
| Recording for compliance | `recordParticipantsOnConnect: true` | Automatic, per-track |
| Recording selective participants | Recording Rules | Fine-grained include/exclude |
| Combined video file | Compositions | Post-room MP4/WebM generation |
| Auto-compose every room | Composition Hooks | Automatic composition on room end |
| Real-time captions/notes | Transcriptions | Live speech-to-text with speaker attribution |
| Phone participants | PSTN dial-in/out | Bridges voice to video room |
| Long-term storage | External Storage (S3) | Twilio default is 24-hour retention |

## Decision Frameworks

### Recording: ON vs OFF

**Turn Recording ON when:** Compliance requirements, training/playback, QA review, proctoring/monitoring.
**Keep Recording OFF when:** Privacy-sensitive (therapy, legal where recording prohibited), no retention requirements.

### Composition vs Raw Track Recordings

**Use Compositions when:** Need single MP4/WebM for playback, sharing with end users, archival, grid/speaker layout.
**Use Raw Tracks when:** Per-participant separation, post-processing/editing, ML training data, proctoring (individual student video).

### Transcription: Real-time vs None

**Use Transcription when:** Accessibility (deaf/HoH), note-taking, AI integration, healthcare documentation.
**Skip Transcription when:** Privacy concerns, cost optimization, non-verbal content (screen share only).

### PSTN Integration: Yes vs No

**Add PSTN when:** Participants may lack video devices, backup access needed, dial-out to experts.
**Skip PSTN when:** All participants have app/browser, video is required, simplicity preferred.

## Deep Validation (MANDATORY)

A 200 OK is NOT sufficient. Use `validate_video_room` MCP tool for automated validation.

```
ALWAYS CHECK (every room):
[ ] Room Resource - status = 'in-progress', type = 'group'
[ ] Participant count - expected participants connected
[ ] Published tracks - participants publishing audio/video
[ ] Subscribed tracks - participants receiving each other

WHEN USING RECORDING:    + recording resources exist, status progresses to 'completed'
WHEN USING TRANSCRIPTION: + transcription exists, status = 'started', sentences appearing
WHEN USING COMPOSITION:  + composition created after room ends, status = 'completed', media URL accessible
```

## Room Defaults (Verified Live)

| Parameter | Default | Range | Notes |
|-----------|---------|-------|-------|
| `type` | `group` | `group` only (new accounts) | Legacy types error 53126 |
| `maxParticipants` | 50 | 1-50 | 0 rejected (53107); docs incorrectly say 0 = unlimited |
| `maxParticipantDuration` | 14400 (4h) | 600-86400 | 599 rejected (53123) |
| `maxConcurrentPublishedTracks` | 170 | Account-level | Per-room input ignored |
| `recordParticipantsOnConnect` | false | boolean | Requires group room |
| `videoCodecs` | `["VP8","H264"]` | VP8, H264 | Empty array defaults to both |
| `emptyRoomTimeout` | 5 (min) | 1+ | Docs say 0; live API returns 5 |
| `unusedRoomTimeout` | 5 (min) | 1+ | Docs say 0; live API returns 5 |

## Gotchas

### Room Lifecycle
1. **Room status is one-way**: `in-progress` → `completed` → never back. Cannot reactivate a completed room.
2. **Empty room auto-close**: Rooms close after `emptyRoomTimeout` (default 5 min). Set higher for waiting-room patterns.

### Recording
3. **Recording retention is 24 hours** without external storage (S3). Configure S3 for production.
4. **P2P/Go rooms cannot record**: Server-side recording requires Group rooms.
5. **Recording Rules `all` filter**: Cannot combine `all` with `kind` or `publisher` in the same rule — error 53120. Use separate rules. [Evidence: live test, error 53120]

### Composition
6. **Composition on in-progress room**: API accepts the request (returns CJ SID) but composition ends with `failed` status because no completed recordings exist yet. Wait for room to complete. [Evidence: CJ9b42c9ccea2fd92f8baca76679c773ef status=failed]
7. **Composition processing time**: Batch-based, typically 3-5 minutes, up to 10+ during high load.

### Participants & Tracks
8. **PSTN participants are audio-only**: No video track. Handle in UI with avatar/audio indicator. Max 35 PSTN participants per room.
9. **Track publication limits (recommended)**: 60 audio, 60 video, 50 data publications per room. Per participant: 2 audio, 6 video, 1 data. Use `clientTrackSwitchOffControl: 'auto'` to manage bandwidth.
10. **Kick detection impossible**: Participant removal via API produces NO error code; indistinguishable from voluntary leave. Implement custom signaling (DataTrack) if needed.

### Codecs & Network
11. **H.264 does NOT support simulcast**: Use VP8 for multi-party rooms with 3+ participants.
12. **Transcription partials are ephemeral**: Partial results WILL change. Only persist `final` results.

### Legacy Types
13. **Legacy room types (Oct 2024)**: `peer-to-peer`, `group-small`, `go`, `audioOnly` all return errors on accounts created after Oct 21, 2024. Only `group` is available.

Read `references/gotchas-and-edge-cases.md` for full details, error codes, and code patterns.

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Use cases & customer themes | `references/use-cases.md` | Building for healthcare, proctoring, professional consultation |
| Supervised communication | `references/supervised-communication.md` | Observer patterns, invisible participants, Track Subscriptions API |
| SDK integration | `references/sdk-integration.md` | Client-side code (JS/iOS/Android), access tokens, DataTrack, screen share |
| Network & bandwidth | `references/network-and-bandwidth.md` | Simulcast, bandwidth profiles, network quality, preflight, capture constraints |
| Recordings & compositions | `references/recordings-and-compositions.md` | Recording rules, compositions, composition hooks, external storage |
| Transcription & PSTN | `references/transcription-and-pstn.md` | Real-time transcription, PSTN dial-in/out, recording math |
| Gotchas & edge cases | `references/gotchas-and-edge-cases.md` | Room lifecycle, reconnection, disconnect error codes, edge cases |
| Assertion audit | `references/assertion-audit.md` | Provenance chain — every claim verified with SID evidence (42 assertions) |
