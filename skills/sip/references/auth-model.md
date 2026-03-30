---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Deep-dive on SIP Domain authentication models — legacy vs v2 paths, -->
<!-- ABOUTME: IP ACL vs credential auth, setup order, and interaction behavior. -->

# SIP Domain Authentication Model

## Two Auth Mechanisms

SIP Domains authenticate inbound SIP traffic using two independent mechanisms:

### IP Access Control Lists (IP ACL)

- Allowlist of IPv4 addresses and CIDR ranges
- Source IP of the SIP INVITE must match an entry in a mapped ACL
- No challenge — unmatched IPs are silently dropped
- IPv4 only, no wildcards, no IPv6
- Max 1,000 ACLs per account, 100 IPs per ACL

### Digest Credentials (Credential Lists)

- Username/password pairs for SIP digest authentication (RFC 2617)
- INVITE is challenged with `407 Proxy Authentication Required`
- Endpoint must respond with matching credentials
- Passwords: min 12 chars, mixed case, at least 1 digit
- Passwords stored as MD5 hash — irrecoverable after creation
- Max 100 credential lists per account, 1,000 credentials per list

## Both-Auth Enforcement

When both IP ACL and credential list are mapped to a domain, **both are enforced**. The source IP must be in the ACL AND the INVITE must pass digest auth. This is AND logic — not OR.

The `authType` field on the SIP Domain resource reflects the current state:

| State | `authType` value |
|-------|-----------------|
| No auth | `""` (empty string) |
| IP ACL only | `"IP_ACL"` |
| Credentials only | `"CREDENTIAL_LIST"` |
| Both configured | `"CREDENTIAL_LIST,IP_ACL"` |

[Evidence: SD88afbff455158e914746c49219ca7c4c — tested all four states in sequence]

## API Paths: Legacy vs v2

The REST API provides two sets of endpoints for mapping auth resources to domains. They are NOT independent — they share the same backend storage.

### Legacy Paths (top-level)

```
POST /SIP/Domains/{SD}/IpAccessControlListMappings
POST /SIP/Domains/{SD}/CredentialListMappings
```

These map ACLs and credential lists to the domain for **call authentication**. No distinction between calls and registrations.

### v2 Paths (auth-scoped)

```
# Call authentication
POST /SIP/Domains/{SD}/Auth/Calls/IpAccessControlListMappings
POST /SIP/Domains/{SD}/Auth/Calls/CredentialListMappings

# Registration authentication
POST /SIP/Domains/{SD}/Auth/Registrations/CredentialListMappings
```

The v2 paths separate **call auth** from **registration auth**. This is the recommended approach because:

1. Registration auth is a distinct concern — different endpoints may need different credentials
2. Registration only supports credentials (no IP ACL option)
3. The same credential list can be mapped to both calls and registrations without conflict

### Shared Storage Proof

Mapping an ACL via the legacy path and then attempting to map the same ACL via the v2 calls path returns error **21231** ("IpAccessControlList already associated with this domain"). They write to the same backend store.

[Evidence: Legacy map of ALf9e96... succeeded, v2 map of same ACL returned 21231]

**Recommendation:** Use v2 paths exclusively. They provide the same functionality as legacy paths plus registration auth separation.

## Setup Order

When provisioning a SIP Domain with full auth from scratch:

```
1. Create IP ACL                         → AL sid
2. Add IP address(es) to ACL             → IP sid(s)
3. Create Credential List                → CL sid
4. Add Credential(s) to list             → CR sid(s)
5. Create SIP Domain                     → SD sid
6. Map ACL for calls                     → (v2 Auth/Calls/IpAccessControlListMappings)
7. Map CL for calls                      → (v2 Auth/Calls/CredentialListMappings)
8. (If registration) Enable sipRegistration on domain
9. (If registration) Map CL for registration → (v2 Auth/Registrations/CredentialListMappings)
10. Set voiceUrl on domain
11. Validate with validate_sip(domainSid)
```

Steps 1-4 can be done in any order. Steps 6-7 require the domain (step 5) and auth resources (steps 1-4) to exist. Step 9 can reuse the same CL from step 7 or use a different one.

## Teardown Order

Reverse of setup — remove mappings before deleting resources:

```
1. Remove registration CL mapping
2. Remove call CL mapping
3. Remove call ACL mapping
4. Delete SIP Domain
5. Delete credentials from list
6. Delete credential list
7. Delete IPs from ACL
8. Delete IP ACL
```

Attempting to delete an ACL or CL that is still mapped to a domain will fail.

## Registration Auth

Registration authentication is a separate concern from call authentication:

- **Call auth** controls who can send SIP INVITEs (make/receive calls) through the domain
- **Registration auth** controls who can REGISTER (bind their AOR to a network location)

Key differences:

| Aspect | Call Auth | Registration Auth |
|--------|----------|-------------------|
| IP ACL | Supported | Not supported |
| Credential List | Supported | Supported |
| API path | `Auth/Calls/*` | `Auth/Registrations/*` |
| Purpose | Gate INVITEs | Gate REGISTERs |

An endpoint that is registered for calls (registration auth passed) must also pass call auth to actually place calls through the domain. The two are layered — registration lets you be reachable; call auth lets you initiate.

## Password Generation

Credentials require passwords with specific constraints:

- Minimum 12 characters
- Must contain at least 1 uppercase letter
- Must contain at least 1 lowercase letter
- Must contain at least 1 digit

The SIP lab uses a 20-character random generation with confusable characters excluded (`I`, `l`, `0`, `O`). This is a good pattern for programmatic credential management.

```javascript
const CHARS = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
function generatePassword(length = 20) {
  let pass = '';
  for (let i = 0; i < length; i++) {
    pass += CHARS[Math.floor(Math.random() * CHARS.length)];
  }
  // Ensure requirements are met
  if (!/[a-z]/.test(pass)) pass = pass.slice(0, -1) + 'a';
  if (!/[A-Z]/.test(pass)) pass = pass.slice(0, -1) + 'A';
  if (!/[0-9]/.test(pass)) pass = pass.slice(0, -1) + '3';
  return pass;
}
```
