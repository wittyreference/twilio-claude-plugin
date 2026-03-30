---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Verified Sync error codes with live evidence. Corrects multiple wrong codes in domain CLAUDE.md. -->
<!-- ABOUTME: Use when debugging Sync API errors or writing error handling for Sync operations. -->

# Sync Error Codes — Live Verified

Evidence date: 2026-03-25. All codes verified via direct REST API calls (`curl`) to capture raw JSON error responses.

## Error Codes You Will Actually Encounter

These codes were triggered and verified against live Twilio Sync API:

| Code | HTTP | Message | Trigger | Evidence |
|------|------|---------|---------|----------|
| 20404 | 404 | "The requested resource ... was not found" | Fetch/update/delete any nonexistent Sync resource (document, list, map, item) | Tested on doc, list, map item — all return 20404, not a Sync-specific code |
| 54006 | 413 | "Request entity too large" | Document/item data exceeds 16 KiB (or Stream message exceeds 4 KiB) | 20KB JSON data on document create |
| 54008 | 400 | "Invalid request body: the type of one of the attributes is invalid" | Invalid JSON in `Data` parameter, or malformed request body | `Data=not-valid-json` and `Data=invalid` both return 54008 |
| 54103 | 412 | "The revision of the Document does not match the expected revision" | Conditional update with wrong `If-Match` header value | `If-Match: 0` when current revision was "1" on ETf6783d |
| 54208 | 409 | "An Item with given key already exists in the Map" | Creating a Map item with a key that already exists | Duplicate `simple-key` on MPd79ca1ac |
| 54301 | 409 | "Unique name already exists" | Creating a Document/List/Map/Stream with a UniqueName already in use in the service | Duplicate `skill-test-doc-alpha` |

## Error Codes From Documentation (Not Live-Triggered)

These appear in official Twilio docs but were not triggered during testing. Listed for completeness:

| Code | HTTP | Documented Meaning | Notes |
|------|------|--------------------|-------|
| 54003 | 400 | Invalid If-Match header | Malformed revision value (not wrong, malformed) |
| 54007 | 403 | Access forbidden for identity | ACL-related; only when `aclEnabled=true` |
| 54009 | 429 | Rate limit exceeded | Would need sustained high-volume writes to trigger |
| 54010 | 400 | No parameters specified | Update with no params |
| 54011 | 400 | Invalid TTL | TTL outside 0–31,536,000 range |
| 54050 | 404 | Service Instance not found | Wrong Service SID |
| 54100 | 404 | Document not found | Documented but live API returns 20404 instead |
| 54101 | 400 | Invalid Document data | Null data (not invalid JSON — that's 54008) |
| 54150 | 404 | List not found | Documented but live API returns 20404 instead |
| 54151 | 404 | List Item not found | Documented but live API returns 20404 instead |
| 54200 | 404 | Map not found | Documented but live API returns 20404 instead |
| 54201 | 404 | Map Item not found | Documented but live API returns 20404 instead |
| 54250 | 404 | Message Stream not found | Documented but likely returns 20404 |
| 54300 | 404 | Unique name not found | Documented but likely returns 20404 |
| 54450 | 400 | Invalid Direction query parameter | Direction must be `forward` or `backward` |

## Corrections to Domain CLAUDE.md

The `CLAUDE.md` and `REFERENCE.md` error tables contained these errors (corrected as part of skill creation):

| CLAUDE.md Code | CLAUDE.md Claim | Actual | Correction |
|----------------|-----------------|--------|------------|
| 54007 | "Document not found" | 20404 is returned; 54007 is "Access forbidden for identity" | Wrong code and wrong meaning |
| 54008 | "List not found" | 20404 is returned; 54008 is "Invalid request body" | Wrong code and wrong meaning |
| 54009 | "Map not found" | 20404 is returned; 54009 is "Rate limit exceeded" | Wrong code and wrong meaning |
| 54011 | "List item not found" | 20404 is returned; 54011 is "Invalid TTL" | Wrong code and wrong meaning |
| 54012 | "Map item not found" | 20404 is returned; no 54012 exists in docs | Wrong code, fabricated |
| 54301 | "Document data too large (>16KB)" | 54006 is oversized; 54301 is "Unique name already exists" | Swapped meanings |
| 54302 | "Unique name already exists" | 54301 is the correct code; 54302 does not appear in docs | Wrong code |

## Error Handling Pattern

```javascript
try {
  const doc = await syncService.documents(docName).fetch();
  return callback(null, { success: true, data: doc.data });
} catch (error) {
  if (error.status === 404) {
    // All not-found errors return HTTP 404 (code 20404)
    // Create the document if it doesn't exist
    const newDoc = await syncService.documents.create({
      uniqueName: docName,
      data: { initialized: true }
    });
    return callback(null, { success: true, data: newDoc.data, created: true });
  }
  if (error.code === 54301) {
    // Race condition: another request created it between our fetch and create
    const doc = await syncService.documents(docName).fetch();
    return callback(null, { success: true, data: doc.data });
  }
  if (error.code === 54006) {
    // Data too large (>16 KiB)
    return callback(null, { error: 'Data exceeds 16 KiB limit' });
  }
  throw error;
}
```
