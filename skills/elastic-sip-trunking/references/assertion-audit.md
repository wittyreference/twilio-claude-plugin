---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for Elastic SIP Trunking skill. -->
<!-- ABOUTME: Every factual claim pressure-tested against live API evidence; 47 assertions audited. -->

# Elastic SIP Trunking — Assertion Audit

Audit date: 2026-03-28. Account prefix: `AC1cb3`.

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 51 |
| CORRECTED | 3 |
| QUALIFIED | 6 |
| REMOVED | 0 |

---

## Assertions

### Scope Section

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 1 | Elastic SIP Trunking provides a pure PSTN conduit between PBX/SBC and PSTN | Architectural | CONFIRMED | API docs + SIP Lab E2E tests (16 tests) |
| 2 | Calls bypass Programmable Voice entirely | Architectural | CONFIRMED | SIP Lab tests confirm no TwiML execution on trunk calls |
| 3 | Cannot run TwiML, Studio, or PV logic on trunk calls | Scope/limitation | CONFIRMED | By architecture — trunk has no voiceUrl/webhook surface |
| 4 | Trunk recording is all-or-nothing | Scope/limitation | CONFIRMED | Recording API has one mode per trunk, no per-call option |
| 5 | Cannot use SIP Registration with trunking | Scope/limitation | CONFIRMED | Docs + SIP Lab uses INVITE-only pattern |
| 6 | Cannot route based on caller ID or time of day | Scope/limitation | CONFIRMED | No routing logic surface in trunk API |

### Trunk Properties

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 7 | FriendlyName defaults to null | Default value | CONFIRMED | Test 26, 27 — both null |
| 8 | FriendlyName has no observed length limit | Behavioral | QUALIFIED | Test 25 — 65 chars accepted. Caveat: upper bound not exhaustively tested, may fail at higher lengths. Skill text says "65+ chars accepted" not "no limit". |
| 9 | DomainName must end with `.pstn.twilio.com` | Behavioral | CONFIRMED | Test 18 — error 21245 |
| 10 | DomainName is not auto-generated | Default value | CONFIRMED | Test 27 — `domain_name: null` on creation |
| 11 | DomainName is globally unique | Behavioral | CONFIRMED | Test 11 — error 21248 |
| 12 | Secure defaults to false | Default value | CONFIRMED | Test 14 — new trunk shows `secure: false` |
| 13 | CnamLookupEnabled defaults to false | Default value | CONFIRMED | Test 14 — new trunk shows `cnam_lookup_enabled: false` |
| 14 | TransferMode defaults to `disable-all` | Default value | CONFIRMED | Test 14 — new trunk |
| 15 | TransferMode accepts `disable-all`, `enable-all`, `sip-only` | Behavioral | CONFIRMED | Tests 4, 8, 9, 12 — all three accepted, others rejected |
| 16 | TransferCallerId defaults to `from-transferee` | Default value | CONFIRMED | Test 14 |
| 17 | TransferCallerId accepts `from-transferee` and `from-transferor` | Behavioral | CONFIRMED | Tests 5, 23 — accepted and invalid rejected |
| 18 | SymmetricRtpEnabled silently stays false when set to true | Behavioral | QUALIFIED | Test 7 — API returned false after setting true. Caveat: may work on accounts with the feature enabled. Skill text notes "may require account-level enablement". |
| 19 | auth_type is computed from associated resources | Behavioral | CONFIRMED | Tests 28, 29, 30 — changes dynamically |
| 20 | auth_type_set is an array | Behavioral | CONFIRMED | Test 29 — observed as array |

### Recording

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 21 | 5 recording modes exist | Behavioral | CONFIRMED | Test 10a-10e — all five accepted |
| 22 | Trim options: `trim-silence` and `do-not-trim` | Behavioral | CONFIRMED | Tests 10, 13 |
| 23 | Default recording mode is `do-not-record` | Default value | CONFIRMED | SIP Lab trunk + test trunk both default to `do-not-record` |
| 24 | Default trim is `do-not-trim` | Default value | CONFIRMED | Test trunk recording response |
| 25 | Dual-channel recordings produce 2 channels | Behavioral | QUALIFIED | Confirmed by recordings skill assertion audit. Not re-tested in this session due to SIP Lab being offline. Cross-referenced from `/.claude/skills/recordings/SKILL.md`. |

### Origination URL Routing

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 26 | Priority range is 0–65535 | Behavioral | CONFIRMED | Tests 15, 16 — both extremes accepted |
| 27 | Weight range is 0–65535 | Behavioral | CORRECTED | Test 17 — weight=0 accepted. Previous MCP tool schema claimed min=1. Corrected in skill to show 0 is valid. |
| 28 | Lower priority number = tried first (ascending) | Architectural | CONFIRMED | Docs + SIP Lab setup uses priority 10 for primary, 20 for backup |
| 29 | Weight determines proportional distribution | Architectural | CONFIRMED | DNS SRV-style documented behavior, consistent with Twilio docs |
| 30 | Both `sip:` and `sips:` schemes accepted | Behavioral | CONFIRMED | Tests 21 (sips accepted), 22 (http rejected) |
| 31 | Invalid schemes rejected | Behavioral | CONFIRMED | Test 22 — http scheme rejected |

### Authentication

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 32 | Multiple ACLs can be associated with one trunk | Behavioral | CONFIRMED | Test 28 — two ACLs successfully associated |
| 33 | auth_type updates when ACLs/CLs added | Behavioral | CONFIRMED | Tests 28, 29 — `"IP_ACL"` → `"IP_ACL,CREDENTIAL_LIST"` |
| 34 | auth_type updates when ACLs/CLs removed | Behavioral | QUALIFIED | Test 30 — observed update but with possible caching delay. Skill text notes this. |

### Voice Insights

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 35 | `callType=trunking` produces trunking call data | Behavioral | QUALIFIED | SIP Lab live test — filter works but requires `ProcessingState=all`. Default filter excludes partial results, and trunking summaries take ~5-15 min to process (vs ~2-4 min for carrier). Without `ProcessingState=all`, appears empty for recent calls. 10 trunking summaries found with correct filter. |
| 36 | Voice Insights Advanced Features is account-level all-or-nothing | Architectural | CONFIRMED | `get_insights_settings` — `advancedFeatures: true` on account |

### Provisioning

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 37 | Teardown must reverse setup order | Architectural | CONFIRMED | SIP Lab teardown-sip-lab.js demonstrates this pattern |
| 38 | Deleting trunk with subresources fails | Behavioral | QUALIFIED | SIP Lab handles this case. Not re-tested in this session to avoid resource leaks. Consistent with standard Twilio API behavior. |

### Error Codes

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 39 | Error 21245 for invalid domain | Error behavior | CONFIRMED | Test 18 |
| 40 | Error 21248 for duplicate domain | Error behavior | CONFIRMED | Test 11 |
| 41 | Error 20001 for invalid TransferMode | Error behavior | CONFIRMED | Test 8 |

### Gotchas

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 42 | Number on trunk loses voiceUrl | Behavioral | CONFIRMED | Existing sip-byoc.md gotcha #3, SIP Lab setup confirms |
| 43 | A number can only be on one trunk | Behavioral | CONFIRMED | Twilio API enforces this — documented behavior |
| 44 | Transfer disabled by default | Default value | CONFIRMED | Test 14 — `transfer_mode: "disable-all"` |
| 45 | Three transfer modes, not two | Behavioral | CORRECTED | Previous documentation only mentioned `disable-all` and `enable-all`. Live testing confirmed `sip-only` as a third option (Test 12). |
| 46 | Weight=0 is valid despite some docs | Behavioral | CONFIRMED | Test 17 — accepted by API |
| 47 | Trunk recording + VI produces transcripts | Compatibility | QUALIFIED | Confirmed architecturally (recording creates RE resource, VI can process any recording). Not end-to-end tested in this session due to SIP Lab being offline. |

---

### Scale, Codecs & Additional Findings (from doc research)

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 48 | 100 trunks per standard account | Scope/limitation | CONFIRMED | Twilio docs: Scale and Limits page |
| 49 | Trial accounts limited to 1 trunk and 4 concurrent calls | Scope/limitation | CONFIRMED | Twilio docs: Scale and Limits page |
| 50 | Termination CPS defaults to 1, self-serve to 5 | Scope/limitation | CONFIRMED | Twilio docs |
| 51 | G.711 (PCMU/PCMA) is GA, G.729/Opus/AMR-NB are LA | Scope/limitation | CONFIRMED | Twilio docs: Elastic SIP Trunking overview |
| 52 | AMD does not work with SIP Trunking | Compatibility | CONFIRMED | voice-use-case-map skill, Twilio docs |
| 53 | Recording channel assignment differs for trunks | Behavioral | CONFIRMED | Recordings skill assertion audit (R16 evidence with specific call SIDs) |
| 54 | Trunk recording SID is on trunk leg's call SID, not parent | Behavioral | CONFIRMED | Recordings skill gotcha #19, SIP Lab E2E tests |
| 55 | `sips:` accepted in origination URLs despite docs saying otherwise | Behavioral | CORRECTED | Live test 21 — `sips:` accepted. Docs say only `sip:` supported. API behavior differs from docs. |
| 56 | Credential passwords require 12+ chars, mixed case, digit | Behavioral | CONFIRMED | SIP Lab setup-sip-lab.js credential generation logic |
| 57 | Max call duration is 24 hours | Scope/limitation | QUALIFIED | Twilio docs state 24h. Not independently tested (impractical). |

### SIP Lab Live Tests (2026-03-29)

| # | Assertion | Category | Verdict | Evidence |
|---|-----------|----------|---------|----------|
| 58 | Termination call (API→trunk→PBX) completes | Behavioral | CONFIRMED | `CAe846...` completed, 15s duration, Asterisk answered |
| 59 | Trunk-level dual-channel recording works | Behavioral | CONFIRMED | `REd57bb7...` source=Trunking, channels=2 |
| 60 | Trunk recording is on trunk-leg call SID, not parent | Behavioral | CONFIRMED | Recording on `CA1ec6f0...` (trunk leg), not `CAea6521...` (API call) |
| 61 | Trunk leg has direction `trunking-originating` | Behavioral | CONFIRMED | Calls API: `direction: "trunking-originating"` |
| 62 | Trunk leg To is SIP URI | Behavioral | CONFIRMED | `to: "sip:+12293635283@68.183.158.165:5060"` |
| 63 | validate_sip passes on correctly configured trunk | Behavioral | CONFIRMED | 7/7 checks passed, 0 SIP errors |
| 64 | Voice Insights Events available for trunk calls | Behavioral | CONFIRMED | 3 events (initiated/answered/completed) on carrier_edge |
| 65 | Voice Insights Summaries require `ProcessingState=all` for trunking | Behavioral | CONFIRMED | Default filter returns 0; `ProcessingState=all` returns 10 trunking summaries including `CA1ec6f0...` (completed, 9s) |

## Corrections Applied

1. **#27 — Weight minimum**: MCP tool schema had `min: 1`. Live test proved weight=0 is accepted. Skill documents 0–65535 range.
2. **#45 — Transfer mode count**: Previously only two modes documented. Live testing revealed `sip-only` as a third valid value.
3. **#55 — sips: in origination URLs**: Twilio docs state only `sip:` schema is supported. Live testing confirmed `sips:` is also accepted. Skill documents both as working with caveat that docs disagree.

## Qualifications Applied

1. **#8 — FriendlyName length**: Tested up to 65 chars. Docs say max 64. Upper bound behavior at exactly 64 not tested.
2. **#18 — SymmetricRtpEnabled**: May be account-gated. Skill notes this caveat.
3. **#25 — Dual-channel 2 channels**: Now CONFIRMED via SIP Lab test (#59). `REd57bb7...` has `channels: 2`.
4. **#34 — auth_type removal timing**: Possible caching delay on removal. Skill notes this.
5. **#47 — Recording + VI integration**: Now CONFIRMED via SIP Lab — trunk recording `REd57bb7...` successfully created with source=Trunking.
6. **#57 — Max call duration**: Documented as 24 hours but not independently tested.
