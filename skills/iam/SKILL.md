---
name: "iam"
description: "Twilio development skill: iam"
---

---
name: iam
description: Twilio IAM development guide. Use when choosing authentication methods, managing API keys, rotating auth tokens, creating subaccounts, generating Access Tokens for client SDKs, or debugging 401/403 errors.
---

<!-- verified: twilio.com/docs/iam, twilio.com/docs/iam/api-keys, twilio.com/docs/iam/access-tokens, twilio.com/docs/iam/test-credentials, twilio.com/docs/iam/credentials/public-key-client-validation, twilio.com/docs/iam/api/account, twilio.com/docs/iam/api/keys, twilio.com/docs/iam/api/signing-keys, twilio.com/docs/iam/api/sub-account + live testing 2026-03-27 -->

# Twilio IAM

Authentication, authorization, and account hierarchy for Twilio APIs. Covers API key types (Standard, Main, Restricted), Access Tokens for client SDKs, auth token rotation, subaccount isolation, test credentials, and Public Key Client Validation (PKCV).

Evidence date: 2026-03-27. Account prefix: AC...

## Scope

### CAN

- Authenticate via three methods: Account SID + Auth Token, API Key + Secret, or PKCV (Enterprise/Security) <!-- verified: all three tested live -->
- Create Standard API keys via v2010 REST API or MCP tools <!-- verified: SK5d87b5ae created -->
- Create Restricted API keys via v1 IAM API with fine-grained per-endpoint permissions <!-- verified: SKfb70101d created with messaging/messages/read policy -->
- Create Main API keys via Console only (not REST API)
- Rotate auth tokens via secondary token creation and promotion (zero-downtime) <!-- verified: secondary token created, authenticated with it, deleted -->
- Generate Access Tokens (JWT) for Voice, Video, Sync, and Conversations client SDKs
- Manage subaccounts: create, suspend, close, reactivate (main account only) <!-- verified: subaccount creation blocked on subaccount with error 21101 -->
- Transfer phone numbers between subaccounts using main account credentials
- Use test credentials for free API testing (4 endpoints, magic phone numbers)
- List/fetch/update/delete keys via REST API or MCP tools (`list_api_keys`, `get_api_key`, `create_api_key`, `update_api_key`, `delete_api_key`) <!-- verified: all CRUD operations tested -->
- Manage signing keys via MCP (`list_signing_keys`, `create_signing_key`, `delete_signing_key`) <!-- verified: signing keys list returns same SK-prefixed keys -->
- Upload PKCV public keys via Credentials API (`POST /v1/Credentials/PublicKeys`)
- Use API key auth for all standard API operations (calls, SMS, phone numbers, etc.) <!-- verified: SK key successfully listed phone numbers -->
- Use secondary auth token for authentication while rotating primary <!-- verified: secondary token worked for account fetch -->

### CANNOT

<!-- verified: all CANNOT items live-tested 2026-03-27 unless noted -->

- **Standard keys cannot access /Accounts or /Keys endpoints** — Returns 20003 "Authenticate" (401). Must use Auth Token or Main API Key for account management and key creation. <!-- verified: SK5d87b5ae returned 401 on both /Accounts and /Keys -->
- **No restricted key creation via v2010 API** — The v2010 `/Keys.json` endpoint silently ignores `KeyType=restricted` and `Policy` parameters, creating a standard key instead. No error is returned. Use the v1 IAM API (`POST https://iam.twilio.com/v1/Keys`) for restricted keys. <!-- verified: SKa5b2af06 created via v2010 with KeyType=restricted had policy: null in v1 -->
- **Restricted keys cannot generate Access Tokens** — Only Standard and Main keys can create client SDK tokens. <!-- verified: docs -->
- **No individual Access Token revocation** — Tokens are valid until expiration (max 24h). To revoke, delete the API key that issued them (revokes all tokens from that key).
- **No MCP tools for restricted key creation** — MCP `create_api_key` uses v2010 under the hood; it cannot set `keyType` or `policy`. Use REST API directly for restricted keys. <!-- verified: iam.ts source code shows client.newKeys.create() with no keyType param -->
- **No MCP tools for auth token rotation** — No `create_secondary_auth_token` or `promote_auth_token` tools. Use REST API against `accounts.twilio.com/v1/AuthTokens/`. <!-- verified: REFERENCE.md tool inventory -->
- **No MCP tools for PKCV credential management** — PublicKey CRUD on the Credentials API has no MCP tool equivalents.
- **Subaccounts cannot create sub-subaccounts** — Error 21101 "Subaccounts cannot contain subaccounts". The hierarchy is flat: one main account with up to 1000 direct subaccounts. <!-- verified: POST /Accounts.json from test account (subaccount) returned 21101 -->
- **Subaccount credentials cannot access parent or sibling subaccounts** — Each subaccount's auth token is scoped to its own resources only.
- **PKCV incompatible with Flex, Studio, and TaskRouter** — Cannot enforce PKCV if you use these products. <!-- verified: docs -->
- **PKCV enforcement kills Auth Token authentication** — Once enabled, all requests must use API Key + PKCV JWT. Auth Token requests stop working. <!-- verified: docs -->
- **Test credentials work with only 4 endpoints** — Messages, Calls, IncomingPhoneNumbers, and Lookups. All other endpoints return 403 Forbidden. No status callbacks are triggered. <!-- verified: docs -->
- **API key secret shown only at creation** — Cannot be retrieved after the initial response. Must store immediately. <!-- verified: SK5d87b5ae fetch returned no secret field -->
- **FriendlyName max 64 characters for keys** — 65+ characters returns error 70001 "The request has constraint violations". <!-- verified: 64 chars OK (SKd950a663), 65 chars rejected with 70001 -->
- **Restricted keys limited to 100 permissions per key** — Exceeding this limit is rejected at creation. <!-- verified: docs -->

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Local development / quick testing | Account SID + Auth Token | Simplest setup; full access to all endpoints |
| Production server-to-server | Standard API Key + Secret | Individually revocable; don't expose main Auth Token |
| Least-privilege microservice | Restricted API Key (v1) | Per-endpoint permission control; max 100 perms |
| Client-side Voice/Video/Sync SDK | Access Token (JWT) | Short-lived (max 24h); scoped grants per product |
| Console-only admin operations | Main API Key | Full access including /Accounts and /Keys |
| Tenant isolation / multi-customer | Subaccounts | Separate credentials, resources, and billing rollup |
| Free API testing in CI | Test credentials | No charges; magic numbers for predictable outcomes |
| Zero-downtime auth rotation | Secondary Auth Token + Promote | Two valid tokens during rotation window |
| Enterprise request signing | PKCV (Public Key Client Validation) | Eliminates shared secrets; per-request JWT signing |

## Decision Frameworks

### Choosing an Authentication Method

| Factor | Auth Token | Standard Key | Restricted Key | PKCV |
|--------|-----------|-------------|---------------|------|
| Setup complexity | None (comes with account) | One API call | v1 API + policy design | Keypair + credential upload + JWT per request |
| Revocation granularity | Rotation only (affects everything) | Per-key | Per-key | Per-credential |
| Can create other keys | Yes | No (401) | With `/twilio/iam/api-keys/create` perm | With Main API Key |
| Can access /Accounts | Yes | No (401) | With explicit permission | With Main API Key |
| Can generate Access Tokens | Yes | Yes | No | Yes (Main/Standard key needed) |
| Least-privilege support | No (full access) | No (all except /Accounts, /Keys) | Yes (per-endpoint) | No (auth method, not authz) |
| Availability | All accounts | All accounts | All accounts (US region in Console) | Enterprise + Security Edition only |

### API Key Types Compared

| Attribute | Main | Standard | Restricted |
|-----------|------|----------|------------|
| Creation method | Console only | Console, REST (v2010 or v1), MCP | Console, REST (v1 only) |
| SID prefix | SK | SK | SK |
| Secret format | 32 chars, base62 | 32 chars, base62 | 32 chars, base62 |
| Access level | All endpoints (equivalent to Auth Token) | All except `/Accounts` and `/Keys` | Defined by `policy.allow` array |
| Can create Access Tokens | Yes | Yes | No |
| `policy` field (v1 API) | null | null | `{"allow": [...]}` |
| `flags` field (v1 list) | `["rest_api", "signing"]` | `["rest_api", "signing"]` | Not present in v1 list |
| Max permissions | N/A | N/A | 100 |

### Access Token Grants

| Grant | SDK | Required params | Key constraint |
|-------|-----|----------------|---------------|
| VoiceGrant | Voice JS/iOS/Android | `outgoingApplicationSid` | None |
| VideoGrant | Video JS/iOS/Android | None (`room` optional) | API key must be in US1 region |
| SyncGrant | Sync JS | `serviceSid` | None |
| ChatGrant | Conversations JS | `serviceSid` | None |

Access Token constraints:
- Max TTL: 86,400 seconds (24 hours)
- Algorithm: HS256 (HMAC-SHA256 with API key secret)
- Identity: alphanumeric + underscore only for Voice
- Voice: max 10 concurrent registrations per identity (11th evicts oldest)
- Content type header: `cty: twilio-fpa;v=1`

### Subaccount Isolation Model

| Operation | Main Account Creds | Subaccount Creds |
|-----------|-------------------|------------------|
| Access main account resources | Yes | No |
| Access subaccount v2010 resources | Yes | Yes (own only) |
| Access sibling subaccount | Yes | No |
| Access subdomain APIs (Studio, TaskRouter) | No (need subaccount creds) | Yes |
| Create sub-subaccounts | N/A | No (error 21101) |
| Transfer phone numbers | Yes | No |
| Create API keys for subaccount | Yes (Auth Token) | Yes (own Auth Token) |

## Auth Token Rotation

Zero-downtime rotation workflow using REST API (no SDK helper):

```
POST https://accounts.twilio.com/v1/AuthTokens/Secondary
→ Returns: { secondary_auth_token: "...", account_sid: "..." }
→ Both primary and secondary are valid simultaneously

POST https://accounts.twilio.com/v1/AuthTokens/Promote
→ Secondary becomes primary; old primary is deleted

DELETE https://accounts.twilio.com/v1/AuthTokens/Secondary
→ Deletes secondary without promoting (if rotation is aborted)
```

## Restricted Key Permission Format

Permissions follow the pattern `/twilio/{product}/{resource}/{action}`:

```json
{
  "allow": [
    "/twilio/messaging/messages/read",
    "/twilio/messaging/messages/list",
    "/twilio/messaging/messages/create",
    "/twilio/voice/calls/read",
    "/twilio/voice/calls/create"
  ]
}
```

`read` and `list` are separate permissions. `read` permits fetching a single resource by SID; `list` permits listing the collection. Error 70051 tells you exactly which permission is missing.

Invalid permission paths return error 70002: `"assertion '/twilio/fakepermission/doesnotexist' is invalid"`.

Supported products: Studio, Voice, Conversational Intelligence, Voice Insights, SIP, Messaging, Phone Numbers, Regulatory Compliance, TaskRouter, Monitor, Lookup, Verify, Video, Event Streams, Usage Records, Serverless, IAM, Flex (private beta).

## Test Credentials

Separate Account SID + Auth Token found in Console > Admin > Account management > API keys & tokens.

**Supported endpoints only**: Messages (create), Calls (create), IncomingPhoneNumbers (create), Lookups (fetch). Everything else returns 403. No status callbacks are triggered. Cannot sign into Twilio CLI.

See `references/test-results.md` for the full magic phone number table.

## Gotchas

### Key Management

1. **v2010 silently ignores restricted key params**: Passing `KeyType=restricted` and `Policy=...` to `POST /2010-04-01/.../Keys.json` creates a standard key with no error. The key has `policy: null` when checked via v1. Only the v1 IAM API (`POST https://iam.twilio.com/v1/Keys`) supports restricted key creation. [Evidence: SKa5b2af06]

2. **Keys and SigningKeys are the same resource**: Both v2010 endpoints (`/Keys.json` and `/SigningKeys.json`) return the same SK-prefixed keys. The v1 API shows `flags: ["rest_api", "signing"]` on standard keys, confirming dual purpose. There is no separate "signing-only" key type. [Evidence: SK5d87b5ae appeared in both list responses]

3. **Key secret is 32 chars, base62; auth token is 32 chars, hex**: API key secrets use alphanumeric characters (base62). Auth tokens use lowercase hex characters only. Both are 32 characters. [Evidence: Ma9ZHnBHKYxFgDWbh5AcliMYdbJgxtjL vs ff5711b12ae90b6da1d9753da7959c2f]

4. **FriendlyName omission produces null, not a default**: Creating a key without `FriendlyName` sets it to `null`, not a generated default name. [Evidence: SK40efc57a]

5. **FriendlyName max 64 chars enforced with generic error**: Error 70001 "The request has constraint violations" — no field-level detail. [Evidence: 65-char name rejected]

### Authentication Boundaries

6. **Standard API key auth returns 401 on /Accounts, not 403**: The error is 20003 "Authenticate" with HTTP 401, which looks like bad credentials rather than a permissions issue. Misleading if you're debugging. [Evidence: SK5d87b5ae on /Accounts.json]

7. **MCP `validate_environment` shows "(unavailable — API key auth)" for account name**: When authenticated via API Key, the account friendly name cannot be fetched because the /Accounts endpoint is blocked. The account SID is still available. [Evidence: validate_environment output]

8. **Restricted key `read` vs `list` are distinct permissions**: `/twilio/messaging/messages/read` allows `GET /Messages/{Sid}` but NOT `GET /Messages` (the list). You need both `/read` and `/list` for full read access. Error 70051 names the exact missing permission. [Evidence: SKfb70101d could fetch SM335a923f but not list messages]

### Auth Token Rotation

9. **Secondary auth token works immediately**: No propagation delay observed for API-level authentication. Both primary and secondary tokens are valid simultaneously until promotion or deletion. [Evidence: secondary token ff5711... authenticated successfully for account fetch]

10. **Serverless Functions have up to 1-minute propagation delay**: If auth tokens are hardcoded in Functions environment variables (not using `context.getTwilioClient()`), promoted tokens may take up to 1 minute to propagate. Premature requests return 403.

### Subaccounts

11. **Subaccount cannot create subaccounts**: Error 21101 "Subaccounts cannot contain subaccounts". The hierarchy is strictly one level deep. [Evidence: POST /Accounts.json from test account returned 21101]

12. **Subaccount limit is 1000 per main account by default**: Contact Twilio support to increase.

13. **Closed subaccounts are deleted after 30 days**: Resources (phone numbers, recordings) must be transferred before closure.

14. **Subdomain APIs require subaccount-specific credentials**: Main account credentials cannot access `studio.twilio.com` or `taskrouter.twilio.com` resources on subaccounts. You need the subaccount's own SID + Auth Token.

### PKCV

15. **PKCV JWT max expiration is 300 seconds (5 minutes)**: Much shorter than Access Token max of 86,400 seconds (24 hours). Each API request needs a fresh JWT.

16. **PKCV is Enterprise/Security Edition only**: Attempting to enable it on standard accounts will not work.

17. **Enabling PKCV enforcement disables Auth Token authentication**: This is irreversible in practice — you must have Main API Keys set up before enabling enforcement.

### MCP Tool Gaps

18. **No MCP tools for auth token rotation**: Must use REST API directly against `accounts.twilio.com/v1/AuthTokens/`.

19. **No MCP tools for restricted key management**: `create_api_key` creates standard keys only. `list_api_keys` and `get_api_key` work for all key types but don't show the `policy` field (v2010 responses don't include it).

20. **No MCP tools for PKCV public key management**: Must use REST API against `accounts.twilio.com/v1/Credentials/PublicKeys`.

21. **IAM MCP tools are P3 tier**: Not loaded by default (default is P0 + validation). Configure `toolTiers: ['P0', 'P3', 'validation']` or `['all']` to enable them.

## Related Resources

### MCP Tools

**IAM tools** (P3 tier): `mcp__twilio__list_api_keys`, `mcp__twilio__get_api_key`, `mcp__twilio__create_api_key`, `mcp__twilio__update_api_key`, `mcp__twilio__delete_api_key`, `mcp__twilio__list_signing_keys`, `mcp__twilio__create_signing_key`, `mcp__twilio__delete_signing_key`

**Accounts tools** (P3 tier): `mcp__twilio__get_account`, `mcp__twilio__list_accounts`, `mcp__twilio__create_subaccount`, `mcp__twilio__update_account`, `mcp__twilio__list_usage_records`, `mcp__twilio__get_account_balance`

**Validation**: `mcp__twilio__validate_environment` (checks account identity, credentials, service SIDs)

### Cross-References

- MCP server tool source: `twilio/src/tools/iam.ts`, `twilio/src/tools/accounts.ts`
- MCP tool reference: `twilio/REFERENCE.md` §IAM Tools, §Accounts Tools
- Tool boundaries: `references/tool-boundaries.md`
- Environment invariants: `rules/environment-invariants.md`
- Twilio CLI skill: `skills/twilio-cli/SKILL.md` (profiles, deployment — CLI-only operations)

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Live test results | `references/test-results.md` | When you need SID-level evidence for specific IAM behaviors |
| Assertion audit | `references/assertion-audit.md` | When verifying provenance of any claim in this skill |
