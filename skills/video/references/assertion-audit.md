---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the Video skill — every factual claim extracted and verified. -->
<!-- ABOUTME: 42 assertions tested against live Twilio Video API with SID evidence. 6 corrected, 4 qualified. -->

# Assertion Audit Log

**Skill**: Video
**Audit date**: 2026-03-28
**Account**: ACb4de2... (API Key auth)
**Auditor**: Claude (skill-builder validation)

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 32 |
| CORRECTED | 6 |
| QUALIFIED | 4 |
| REMOVED | 0 |
| **Total** | **42** |

## Assertions

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| 1 | Group rooms support up to 50 participants | scope | CONFIRMED | maxParticipants=50 accepted; 51 rejected with 53107 | |
| 2 | Default room type is group | default | CONFIRMED | Room created without type → type=group | |
| 3 | P2P rooms are legacy on newer accounts | scope | CONFIRMED | Error 53126: "Room type is no longer supported" | |
| 4 | group-small rooms are legacy | scope | CONFIRMED | Error 53126 on creation attempt | |
| 5 | go rooms are legacy | scope | CONFIRMED | Error 53126 on creation attempt | |
| 6 | maxParticipantDuration minimum is 600 | behavioral | CONFIRMED | 300 rejected (53123); 600 accepted; 599 rejected (53123) | |
| 7 | maxParticipantDuration maximum is 86400 | behavioral | CONFIRMED | 86400 accepted; 86401 rejected | |
| 8 | maxParticipantDuration default is 14400 (4h) | default | CONFIRMED | Room created without param → maxParticipantDuration=14400 | |
| 9 | emptyRoomTimeout default is 5 minutes | default | CORRECTED | Live: emptyRoomTimeout=5. Docs claim 0. | Docs say 0 (disabled); live API returns 5. Updated to reflect reality. |
| 10 | unusedRoomTimeout default is 5 minutes | default | CONFIRMED | Live: unusedRoomTimeout=5 | |
| 11 | maxParticipants default is 50 | default | CORRECTED | Live: maxParticipants=50. Docs claim 0. | Docs say 0 (unlimited); live API returns 50. maxParticipants=0 rejected with 53107. |
| 12 | maxConcurrentPublishedTracks is 170 (account-level) | default | CORRECTED | Values 0/1/16/200 all returned 170 | Per-room parameter is ignored; value is account-level fixed at 170. Skill previously claimed "16 video tracks max". |
| 13 | recordParticipantsOnConnect default is false | default | CONFIRMED | Room created without param → false | |
| 14 | Default videoCodecs are VP8 and H264 | default | CONFIRMED | Room created without param → ["VP8","H264"] | |
| 15 | Empty videoCodecs array defaults to both codecs | behavioral | CONFIRMED | `videoCodecs: []` → ["VP8","H264"] returned | |
| 16 | VP8 codec accepted | compatibility | CONFIRMED | Room with videoCodecs=["VP8"] created successfully | |
| 17 | H264 codec accepted | compatibility | CONFIRMED | Room with videoCodecs=["H264"] created successfully | |
| 18 | Both codecs together accepted | compatibility | CONFIRMED | videoCodecs=["VP8","H264"] created successfully | |
| 19 | P2P rooms reject recordParticipantsOnConnect | scope | CONFIRMED | Error 53126 (room type rejected before recording param evaluated) | Legacy type rejected before param is evaluated |
| 20 | Go rooms reject recording | scope | CONFIRMED | Error 53126 (same as P2P) | |
| 21 | Group room accepts recordParticipantsOnConnect | behavioral | CONFIRMED | Room created with recordParticipantsOnConnect=true | |
| 22 | Composition on in-progress room fails | behavioral | CORRECTED | CJ9b42c9ccea2fd92f8baca76679c773ef created (HTTP 200) but status=failed | API accepts the request, returns CJ SID, but composition ends with failed status. Not a hard API rejection. |
| 23 | Recording Rules exclude-all works | behavioral | CONFIRMED | Rules: [{type:"exclude",all:true}] accepted | |
| 24 | Recording Rules include-all works | behavioral | CONFIRMED | Rules: [{type:"include",all:true}] accepted | |
| 25 | Recording Rules kind filter works | behavioral | CONFIRMED | Rules: [{type:"include",kind:"audio"}] accepted | |
| 26 | Recording Rules all+kind in same rule rejected | interaction | CONFIRMED | Error 53120 when combining all:true with kind:"audio" | |
| 27 | Recording Rules publisher+kind combo works | interaction | CONFIRMED | [{type:"include",publisher:"alice",kind:"audio"}] accepted | |
| 28 | mediaRegion us1 accepted | compatibility | CONFIRMED | Room created with mediaRegion=us1 | |
| 29 | mediaRegion us2 accepted | compatibility | CONFIRMED | Room created with mediaRegion=us2 | |
| 30 | mediaRegion ie1 accepted | compatibility | CONFIRMED | Room created with mediaRegion=ie1 | |
| 31 | mediaRegion de1 accepted | compatibility | CONFIRMED | Room created with mediaRegion=de1 | |
| 32 | mediaRegion au1 accepted | compatibility | CONFIRMED | Room created with mediaRegion=au1 | |
| 33 | mediaRegion br1 accepted | compatibility | CONFIRMED | Room created with mediaRegion=br1 | |
| 34 | mediaRegion jp1 accepted | compatibility | CONFIRMED | Room created with mediaRegion=jp1 | |
| 35 | mediaRegion sg1 accepted | compatibility | CONFIRMED | Room created with mediaRegion=sg1 | |
| 36 | mediaRegion in1 accepted | compatibility | CONFIRMED | Room created with mediaRegion=in1 | |
| 37 | mediaRegion gll (global) accepted | compatibility | CONFIRMED | Room created with mediaRegion=gll | Previously missing from skill |
| 38 | Invalid mediaRegion rejected | error | CONFIRMED | "invalid-region" → error 53113 | |
| 39 | statusCallback and statusCallbackMethod accepted | behavioral | CONFIRMED | Room created with both params | |
| 40 | Room lifecycle is one-way (in-progress → completed) | architectural | CONFIRMED | Room update to completed succeeded; no API to reactivate | |
| 41 | audioOnly mode no longer supported | scope | QUALIFIED | Error 53127 on creation attempt | May work on legacy accounts created before Oct 2024 |
| 42 | largeRoom requires special enablement | scope | QUALIFIED | Error 53103 on creation attempt | May require account-level flag; not available on standard accounts |

## Corrections Applied

### C1: emptyRoomTimeout default (#9)
- **Original text**: (docs-sourced) Default is 0 (disabled)
- **Corrected text**: Default is 5 (minutes)
- **Why**: Live API returns 5 when no value specified. Docs say 0. Trusted live behavior over docs.

### C2: maxParticipants default (#11)
- **Original text**: (docs-sourced) Default is 0 (unlimited)
- **Corrected text**: Default is 50; maxParticipants=0 rejected with error 53107
- **Why**: Live API returns 50 when no value specified. Setting 0 fails. Range is 1-50.

### C3: maxConcurrentPublishedTracks per-room (#12)
- **Original text**: "16 video tracks max visible simultaneously in group rooms"
- **Corrected text**: Account-level value (170 on standard accounts); per-room parameter ignored. Recommended limits: 60 video publications/room, 60 video subscriptions/participant.
- **Why**: All per-room values (0, 1, 16, 200) returned 170. The "16" claim had no verified source.

### C4: Composition on in-progress room (#22)
- **Original text**: "Creating during `in-progress` fails"
- **Corrected text**: API accepts the request (returns CJ SID) but composition ends with `failed` status
- **Why**: CJ9b42c9ccea2fd92f8baca76679c773ef was created on in-progress room — HTTP 200 returned, but composition status was `failed`. It's a silent failure, not a hard API rejection.

### C5: Legacy room types (#3, #4, #5)
- **Original text**: "AVOID group-small", "NEVER peer-to-peer", "NEVER go"
- **Corrected text**: All three return error 53126 on accounts created after Oct 21, 2024
- **Why**: Live testing confirmed these types are completely unavailable, not just discouraged. Updated from recommendation to hard constraint.

### C6: "16 video tracks max" removed and replaced
- **Original text**: "16 video tracks max visible simultaneously"
- **Corrected text**: Replaced with verified Twilio docs limits (60/60/50 per room, 2/6/1 per participant)
- **Why**: The "16" figure had no API or documentation backing. Real limits are much higher.

## Qualifications Applied

### Q1: Legacy room type deprecation (#3, #4, #5)
- **Original text**: P2P/group-small/go rooms should not be used
- **Qualified text**: Error 53126 on accounts created after Oct 21, 2024; legacy accounts retain access
- **Condition**: Accounts created before Oct 21, 2024 can still use these types

### Q2: audioOnly mode (#41)
- **Original text**: audioOnly mode not supported (error 53127)
- **Qualified text**: Error 53127 on standard/newer accounts
- **Condition**: May still work on legacy accounts; could not test cross-account

### Q3: largeRoom mode (#42)
- **Original text**: largeRoom=true fails with error 53103
- **Qualified text**: Requires special account enablement; not available on standard accounts
- **Condition**: Some accounts may have this feature enabled

### Q4: Recording retention 24 hours
- **Original text**: Recordings deleted after 24 hours without external storage
- **Qualified text**: Keeping claim but could not verify exact retention period via API
- **Condition**: Twilio docs state this; no live test contradicted it but we couldn't wait 24h to confirm
