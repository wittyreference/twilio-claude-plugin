---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Trust Hub API patterns and code examples for Branded Calling setup. -->
<!-- ABOUTME: Covers Trust Products, Customer Profiles, End Users, Documents, and Entity Assignments. -->

# Trust Hub API Patterns

Code patterns for working with the Trust Hub API to manage Branded Calling resources.

## Authentication

Trust Hub API uses the same authentication as other Twilio APIs:

```javascript
const client = require('twilio')(accountSid, authToken);
// Or with API key:
const client = require('twilio')(apiKeySid, apiKeySecret, { accountSid });
```

All Trust Hub resources are under `client.trusthub.v1`.

---

## Resource Hierarchy

```
Account
├── CustomerProfiles (business identity)
│   ├── EntityAssignments → EndUsers, SupportingDocuments
│   └── Evaluations (compliance check)
├── TrustProducts (branded calling, voice integrity, etc.)
│   ├── EntityAssignments → EndUsers, SupportingDocuments, other TrustProducts
│   ├── ChannelEndpointAssignments → Phone Numbers
│   └── Evaluations (compliance check)
├── EndUsers (people and business entities)
└── SupportingDocuments (addresses, LOAs, etc.)
```

**Key relationships:**
- EndUsers and SupportingDocuments are reusable across multiple Trust Products
- A phone number can only be assigned to one Trust Product of a given type at a time
- Trust Products can require other Trust Products as prerequisites (Enhanced requires Voice Integrity)

---

## Common Patterns

### List All Trust Products with Status

```javascript
const products = await client.trusthub.v1.trustProducts.list({ limit: 50 });
for (const p of products) {
  console.log(`${p.sid}: ${p.friendlyName} [${p.status}]`);
}
```

### Check If a Number Is Already Assigned

```javascript
const assignments = await client.trusthub.v1
  .trustProducts(trustProductSid)
  .trustProductsChannelEndpointAssignment.list();

const assigned = assignments.find(
  (a) => a.channelEndpointSid === phoneNumberSid
);
console.log(assigned ? 'Already assigned' : 'Not assigned');
```

### Remove a Number from a Trust Product

```javascript
// First find the assignment SID
const assignments = await client.trusthub.v1
  .trustProducts(trustProductSid)
  .trustProductsChannelEndpointAssignment.list();

const assignment = assignments.find(
  (a) => a.channelEndpointSid === phoneNumberSid
);

if (assignment) {
  await client.trusthub.v1
    .trustProducts(trustProductSid)
    .trustProductsChannelEndpointAssignment(assignment.sid)
    .remove();
}
```

### Get Policy Requirements

```javascript
// Useful for understanding what fields are needed before creating resources
const policy = await client.trusthub.v1.policies('RNec5c6f3b750ed0d117c1951b5d5ce8c1').fetch();
console.log(JSON.stringify(policy.requirements, null, 2));
```

### Batch Assign Multiple Numbers

```javascript
const phoneNumberSids = ['PN111...', 'PN222...', 'PN333...'];

for (const pnSid of phoneNumberSids) {
  try {
    await client.trusthub.v1
      .trustProducts(trustProductSid)
      .trustProductsChannelEndpointAssignment.create({
        channelEndpointType: 'phone-number',
        channelEndpointSid: pnSid,
      });
    console.log(`Assigned ${pnSid}`);
  } catch (err) {
    console.error(`Failed to assign ${pnSid}: ${err.message}`);
    // Common error: number already assigned to another trust product of same type
  }
}
```

---

## Error Handling

### Common Error Codes

| HTTP Status | Error Code | Meaning |
|-------------|------------|---------|
| 400 | 45008 | Entity already assigned to this Trust Product |
| 400 | 45009 | Channel endpoint already assigned to another Trust Product of same policy type |
| 400 | 45010 | Trust Product is not in `draft` status (cannot modify after submission) |
| 400 | 45015 | Evaluation failed — missing required entities |
| 404 | 20404 | Resource not found (wrong SID) |

### Handling Evaluation Failures

```javascript
try {
  const evaluation = await client.trusthub.v1
    .trustProducts(trustProductSid)
    .trustProductsEvaluations.create({
      policySid: policySid,
    });

  if (evaluation.status === 'noncompliant') {
    // evaluation.results contains per-requirement pass/fail
    for (const [key, result] of Object.entries(evaluation.results)) {
      if (result.status === 'invalid') {
        console.log(`Missing: ${key} — ${result.errors.join(', ')}`);
      }
    }
  }
} catch (err) {
  console.error('Evaluation error:', err.message);
}
```

---

## Direct REST API (curl)

For quick testing or when not using the SDK:

```bash
# List trust products
curl -s -u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN" \
  "https://trusthub.twilio.com/v1/TrustProducts?PageSize=20" | jq .

# Get a specific trust product
curl -s -u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN" \
  "https://trusthub.twilio.com/v1/TrustProducts/BUxxxxxxxx" | jq .

# List policies (to find correct policy SID)
curl -s -u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN" \
  "https://trusthub.twilio.com/v1/Policies?PageSize=50" | jq '.results[] | {sid, friendly_name}'

# API key auth also works
curl -s -u "$TWILIO_API_KEY:$TWILIO_API_SECRET" \
  "https://trusthub.twilio.com/v1/TrustProducts" | jq .
```

---

## Idempotency Notes

- Creating a Trust Product with the same `friendlyName` does NOT deduplicate — it creates a new one
- EndUsers and SupportingDocuments with the same attributes also create duplicates
- Use `list()` calls to check for existing resources before creating
- ChannelEndpointAssignments are enforced unique: a number cannot be in two Trust Products of the same policy type
