---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Live test results for IAM skill assertions with SID-level evidence. -->
<!-- ABOUTME: 29 tests covering API keys, restricted keys, auth tokens, subaccounts, and error behaviors. -->

# IAM Live Test Results

**Date**: 2026-03-27
**Account**: ACxx...xx (subaccount of ACf30a17)
**Auth method**: API Key SK1e9a284b + Auth Token (both available)

## Test Summary

| Category | Tests | Key findings |
|----------|-------|-------------|
| API Key CRUD | 6 | Keys and SigningKeys are identical resources; secret is 32-char base62 |
| v1 IAM API | 4 | `flags` and `policy` fields only in v1; v2010 is simpler |
| Restricted Keys | 5 | v2010 silently ignores keyType; `read` vs `list` are separate perms |
| Auth Boundaries | 4 | Standard keys get 401 (not 403) on /Accounts and /Keys |
| Auth Token Rotation | 3 | Secondary token works immediately; 204 on delete |
| Subaccounts | 2 | Sub-subaccount creation blocked with 21101 |
| Error Behaviors | 3 | Wrong SID format → 70002; FriendlyName > 64 chars → 70001 |
| PKCV | 1 | Empty credentials list (not Enterprise edition) |

## Detailed Results

### Test 1: List API Keys (v2010)

```
GET /2010-04-01/Accounts/{SID}/Keys.json?PageSize=5
```

**Result**: 5 keys returned. Fields: `sid`, `friendly_name`, `date_created`, `date_updated`. No `secret`, no `policy`, no `flags`.

Evidence SIDs: SK4f7dea0c, SK508d5dc4, SK1e9a284b, SK24567d05, SK18dbf1d7

### Test 2: Create Standard API Key (v2010)

```
POST /2010-04-01/Accounts/{SID}/Keys.json
FriendlyName=iam-skill-test-key
```

**Result**: Key created. Response includes `secret` (32 chars, base62: `Ma9ZHnBHKYxFgDWbh5AcliMYdbJgxtjL`).

Evidence: SK...

### Test 3: List Subaccounts

```
GET /2010-04-01/Accounts.json?PageSize=5
```

**Result**: 1 account returned — the test account itself. Shows `owner_account_sid: ACf30a1...`, confirming the test account is a subaccount.

### Test 4: Create Secondary Auth Token

```
POST https://accounts.twilio.com/v1/AuthTokens/Secondary
```

**Result**: `secondary_auth_token: "ff5711b12ae90b6da1d9753da7959c2f"` (32 chars, hex). Dates in ISO 8601 format (unlike v2010 RFC 2822).

### Test 5: List Signing Keys (v2010)

```
GET /2010-04-01/Accounts/{SID}/SigningKeys.json?PageSize=5
```

**Result**: Same 5 keys as Test 1, including the newly created SK5d87b5ae. **Confirms: Keys and SigningKeys are the same resource.**

### Test 6: Fetch Key Details (no secret)

```
GET /2010-04-01/Accounts/{SID}/Keys/SK5d87b5ae.json
```

**Result**: Returns `sid`, `friendly_name`, `date_created`, `date_updated`. **No `secret` field.** Confirms secret is only at creation.

### Test 7: Standard Key Cannot Create Keys

```
POST /2010-04-01/Accounts/{SID}/Keys.json (auth: SK1e9a284b)
```

**Result**: `{ code: 20003, message: "Authenticate", status: 401 }`

### Test 8: v1 Keys API

```
GET https://iam.twilio.com/v1/Keys?AccountSid={SID}&PageSize=3
```

**Result**: Returns `flags: ["rest_api", "signing"]` and pagination `meta` object. `flags` field not present in v2010. v1 requires `AccountSid` query param (20001 error without it).

Evidence: SK5d87b5ae, SK4f7dea0c, SK508d5dc4

### Test 9: Secondary Auth Token Authentication

```
GET /2010-04-01/Accounts/{SID}.json (auth: SID + secondary token)
```

**Result**: Successfully returned account details. Secondary token is immediately valid for API calls.

### Test 10: Subaccount Cannot Create Sub-Subaccount

```
POST /2010-04-01/Accounts.json (from subaccount ACxx...xx)
```

**Result**: `{ code: 21101, message: "Subaccounts cannot contain subaccounts", status: 400 }`

### Test 11: Update Key FriendlyName

```
POST /2010-04-01/Accounts/{SID}/Keys/SK5d87b5ae.json
FriendlyName=iam-skill-test-key-renamed
```

**Result**: Success. `date_updated` changed.

### Test 12: Standard Key for Regular API Calls

```
GET /2010-04-01/Accounts/{SID}/IncomingPhoneNumbers.json (auth: SK5d87b5ae)
```

**Result**: Success. Returned phone number +15551234567. Standard keys work for non-Accounts/Keys endpoints.

### Test 13: Standard Key for /Accounts Endpoint

```
GET /2010-04-01/Accounts.json (auth: SK5d87b5ae)
```

**Result**: `{ code: 20003, message: "Authenticate", status: 401 }`. Same 401 as key creation — not 403.

### Test 14: Create Restricted Key via v1

```
POST https://iam.twilio.com/v1/Keys
AccountSid={SID}, FriendlyName=iam-skill-restricted-test, KeyType=restricted
Policy={"allow":["/twilio/messaging/messages/read"]}
```

**Result**: Success. Returns `policy: {"allow": ["/twilio/messaging/messages/read"]}` and `secret`.

Evidence: SK...

### Test 15: List PKCV Public Keys

```
GET https://accounts.twilio.com/v1/Credentials/PublicKeys?PageSize=5
```

**Result**: Empty list. No PKCV credentials on this account (not Enterprise/Security Edition).

### Test 16: Delete Secondary Auth Token

```
DELETE https://accounts.twilio.com/v1/AuthTokens/Secondary
```

**Result**: HTTP 204 No Content.

### Test 17: Key with No FriendlyName

```
POST /2010-04-01/Accounts/{SID}/Keys.json (no FriendlyName param)
```

**Result**: `friendly_name: null`, secret: 32 chars. No default name generated.

Evidence: SK...

### Test 18: Wrong SID Format

```
GET /2010-04-01/Accounts/{SID}/Keys/AC1234...json
```

**Result**: `{ code: 70002, message: "Invalid Sid provided in the request", status: 400 }`

### Test 19: Restricted Key Permission Boundaries

```
19a: GET /Messages/SM335a923f.json (auth: SKfb70101d with messages/read)
→ Success (returned message with status: "queued")

19b: GET /Messages.json (auth: SKfb70101d with messages/read only)
→ { code: 70051, message: "Authorization Error: required permission twilio/messaging/messages/list is missing", status: 401 }
```

**Key finding**: `read` permits single-resource fetch; `list` is a separate permission for collection access.

### Test 20: Restricted Key Details via v1

```
GET https://iam.twilio.com/v1/Keys/SKfb70101d?AccountSid={SID}
```

**Result**: Shows `policy: {"allow": [...]}`. No `flags` field on individual fetch (only in list).

### Test 21: Standard Key Details via v1

```
GET https://iam.twilio.com/v1/Keys/SK5d87b5ae?AccountSid={SID}
```

**Result**: `policy: null`. No `flags` field on individual fetch.

### Test 22: Account Fetch — Auth Token vs API Key

```
22a: GET /Accounts/{SID}.json (auth: Auth Token) → Success
22b: GET /Accounts/{SID}.json (auth: API Key) → 401 (20003)
```

### Test 23: Restricted Key Read vs List Granularity

Confirmed in Test 19. `read` = GET by SID. `list` = GET collection. Both are needed for "full read access."

### Test 24: Multi-Permission Restricted Key

```
POST https://iam.twilio.com/v1/Keys
Policy={"allow":["/twilio/messaging/messages/read","/twilio/messaging/messages/list","/twilio/voice/calls/read"]}
```

**Result**: Success. Policy reflected back (ordering may differ from input).

Evidence: SK...

### Test 25: Secret Format Analysis

- API Key secrets: 32 chars, base62 (e.g., `Ma9ZHnBHKYxFgDWbh5AcliMYdbJgxtjL`)
- Auth tokens: 32 chars, hex (e.g., `ff5711b12ae90b6da1d9753da7959c2f`)

### Test 26: Invalid Permission Path

```
POST https://iam.twilio.com/v1/Keys
Policy={"allow":["/twilio/fakepermission/doesnotexist"]}
```

**Result**: `{ code: 70002, message: "assertion '/twilio/fakepermission/doesnotexist' is invalid", status: 400 }`

### Test 27: Restricted Key via v2010 (Silent Downgrade)

```
POST /2010-04-01/Accounts/{SID}/Keys.json
FriendlyName=v2010-restricted, KeyType=restricted, Policy={...}
```

**Result**: Standard key created. No error. `policy: null` when checked via v1.

Evidence: SK...

### Test 28: Confirmed v2010 Silent Downgrade

v1 fetch of SKa5b2af06 shows `policy: null`. Confirmed: v2010 ignores restricted params.

### Test 29: FriendlyName Length Boundary

```
64 chars → Success (SK...)
65 chars → { code: 70001, message: "The request has constraint violations", status: 400 }
```

## Cleanup

All test resources deleted:
- SK5d87b5ae (standard key) → 204
- SKfb70101d (restricted key) → 204
- SK570efb2d (multi-perm key) → 204
- SK40efc57a (no-name key) → 204
- SKa5b2af06 (v2010 "restricted") → 204
- SKd950a663 (64-char name) → 204
- Secondary auth token → 204
