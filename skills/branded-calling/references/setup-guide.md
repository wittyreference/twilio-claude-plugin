---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Step-by-step setup guide for Basic and Enhanced Branded Calling via Trust Hub API. -->
<!-- ABOUTME: Covers the full prerequisite chain from Primary Customer Profile through phone number assignment. -->

# Branded Calling Setup Guide

Complete walkthrough for setting up Branded Calling via the Trust Hub API. Each step includes the API call and expected response.

## Prerequisites

Before starting, ensure you have:
- A Twilio account with voice-capable phone numbers
- Business registration information (EIN, business name, address)
- A signed Letter of Authorization (LOA) for the phone numbers you want to brand
- For Enhanced: a square logo image (300x300px+, PNG/JPG, <1MB)

---

## Setup Flow Overview

```
1. Create Primary Customer Profile
   └── Add End Users (business info, authorized rep)
   └── Add Documents (address)
   └── Submit for review → wait for approval (1-3 business days)

2. SHAKEN/STIR → automatic once Profile approved

3. Voice Integrity (Enhanced only)
   └── Set up via Console → wait for carrier registration (3-7 business days)

4. Create Branded Calling Trust Product
   └── Add End Users (brand info, business info, use case, auth rep, auth contact)
   └── Add Documents (address, LOA)
   └── Assign phone numbers
   └── Submit for review → wait for approval (5-15+ business days)
```

---

## Step 1: Create Primary Customer Profile

### 1a. Create the Customer Profile

```javascript
// POST /v1/CustomerProfiles
const client = require('twilio')(accountSid, authToken);

const customerProfile = await client.trusthub.v1.customerProfiles.create({
  friendlyName: 'My Business Profile',
  policySid: 'RN6433641899984f951173ef1738c3bdd0', // Primary Customer Profile - Business
  email: 'compliance@yourbusiness.com',
});
// Returns: { sid: 'BU...', status: 'draft' }
```

### 1b. Create End User (Business Information)

```javascript
const endUser = await client.trusthub.v1.endUsers.create({
  friendlyName: 'Business Info',
  type: 'customer_profile_business_information',
  attributes: {
    business_name: 'Acme Corp',
    business_type: 'Corporation',
    business_registration_number: '12-3456789', // EIN
    business_registration_identifier: 'EIN',
    business_identity: 'direct_customer',
    business_industry: 'TECHNOLOGY',
    website_url: 'https://www.acmecorp.com',
    business_regions_of_operation: 'USA_AND_CANADA',
    social_media_profile_urls: 'https://twitter.com/acmecorp',
  },
});
// Returns: { sid: 'IT...' }
```

### 1c. Create End User (Authorized Representative)

```javascript
const authRep = await client.trusthub.v1.endUsers.create({
  friendlyName: 'Auth Rep',
  type: 'authorized_representative_1',
  attributes: {
    first_name: 'Jane',
    last_name: 'Smith',
    email: 'jane@acmecorp.com',
    phone_number: '+12025551234',
    business_title: 'VP Engineering',
    job_position: 'Director',
  },
});
```

### 1d. Create Supporting Document (Business Address)

```javascript
const address = await client.trusthub.v1.supportingDocuments.create({
  friendlyName: 'Business Address',
  type: 'customer_profile_address',
  attributes: {
    street: '123 Business St',
    city: 'San Francisco',
    region: 'CA',
    postal_code: '94105',
    iso_country: 'US',
  },
});
```

### 1e. Assign Entities to Customer Profile

```javascript
// Assign business info
await client.trusthub.v1
  .customerProfiles(customerProfile.sid)
  .customerProfilesEntityAssignments.create({ objectSid: endUser.sid });

// Assign authorized representative
await client.trusthub.v1
  .customerProfiles(customerProfile.sid)
  .customerProfilesEntityAssignments.create({ objectSid: authRep.sid });

// Assign address document
await client.trusthub.v1
  .customerProfiles(customerProfile.sid)
  .customerProfilesEntityAssignments.create({ objectSid: address.sid });
```

### 1f. Submit for Review

```javascript
const evaluation = await client.trusthub.v1
  .customerProfiles(customerProfile.sid)
  .customerProfilesEvaluations.create({
    policySid: 'RN6433641899984f951173ef1738c3bdd0',
  });
// Returns: { status: 'compliant' or 'noncompliant' }
// If compliant, profile transitions to 'pending-review'

// Then update status to trigger review:
await client.trusthub.v1.customerProfiles(customerProfile.sid).update({
  status: 'pending-review',
});
```

**Wait for approval**: 1-3 business days. Check status via:
```javascript
const profile = await client.trusthub.v1
  .customerProfiles(customerProfile.sid)
  .fetch();
console.log(profile.status); // 'twilio-approved' when ready
```

---

## Step 2: SHAKEN/STIR (Automatic)

Once your Primary Customer Profile is approved, SHAKEN/STIR A-level attestation is automatically applied to outbound calls from your Twilio numbers. No additional configuration is required.

Verify by making a test call and checking Voice Insights:
```javascript
const summary = await client.insights.v1.calls(callSid).summary().fetch();
console.log(summary.attributes.stir_verstat);
// Expected: 'TN-Validation-Passed-A'
```

---

## Step 3: Voice Integrity (Enhanced Only)

Voice Integrity setup is done through the **Twilio Console** (not API):

1. Navigate to **Trust Hub** → **Voice Integrity**
2. Follow the guided setup wizard
3. Select the phone numbers to register
4. Submit for carrier registration

**Timeline**: 3-7 business days for carrier-side registration to propagate.

There is no REST API or MCP tool to check Voice Integrity status — monitor via Console.

---

## Step 4: Create Branded Calling Trust Product

### Basic Branded Calling

#### 4a. Create Trust Product

```javascript
const trustProduct = await client.trusthub.v1.trustProducts.create({
  friendlyName: 'Acme Branded Calling',
  policySid: 'RNec5c6f3b750ed0d117c1951b5d5ce8c1', // Basic Branded Calling
  email: 'compliance@acmecorp.com',
});
// Returns: { sid: 'BU...', status: 'draft' }
```

#### 4b. Create End Users

```javascript
// Brand information
const brandInfo = await client.trusthub.v1.endUsers.create({
  friendlyName: 'Brand Display Info',
  type: 'branded_calls_information',
  attributes: {
    branded_calls_display_name: 'Acme Corp', // Max 32 chars
  },
});

// Authorized representative
const authRep = await client.trusthub.v1.endUsers.create({
  friendlyName: 'Auth Rep for Branded',
  type: 'authorized_representative_1',
  attributes: {
    first_name: 'Jane',
    last_name: 'Smith',
    email: 'jane@acmecorp.com',
    phone_number: '+12025551234',
    job_position: 'Director',
  },
});

// Authorized contact (for verification)
const authContact = await client.trusthub.v1.endUsers.create({
  friendlyName: 'Auth Contact',
  type: 'authorized_contact',
  attributes: {
    first_name: 'Jane',
    last_name: 'Smith',
    verification_email: 'jane@acmecorp.com',
    mobile_phone_number: '+12025551234',
  },
});

// Business information
const business = await client.trusthub.v1.endUsers.create({
  friendlyName: 'Business for Branded',
  type: 'business',
  attributes: {
    business_name: 'Acme Corp',
    trade_name: 'Acme',
    business_type: 'Corporation',
    business_identity: 'direct_customer',
    business_registration_number: '12-3456789',
    business_registration_identifier: 'EIN',
    business_industry: 'TECHNOLOGY',
    business_website: 'https://www.acmecorp.com',
    is_subassigned: 'false',
    privacy_notice_url: 'https://www.acmecorp.com/privacy',
    business_employee_count: '100-499',
  },
});

// Use case
const useCase = await client.trusthub.v1.endUsers.create({
  friendlyName: 'Use Case for Branded',
  type: 'use_case',
  attributes: {
    category: 'CUSTOMER_SERVICE',
    use_case_description: 'Outbound customer service calls for order updates',
    consent_description: 'Customers opt in during checkout',
    call_volume_daily: '100-499',
  },
});
```

#### 4c. Create Documents

```javascript
// Business address
const address = await client.trusthub.v1.supportingDocuments.create({
  friendlyName: 'Business Address',
  type: 'business_address',
  attributes: {
    street: '123 Business St',
    city: 'San Francisco',
    region: 'CA',
    postal_code: '94105',
    iso_country: 'US',
  },
});

// Letter of Authorization (upload the signed LOA file)
// Note: LOA must be uploaded via Console or multipart form upload
```

#### 4d. Assign Everything to Trust Product

```javascript
const entities = [brandInfo, authRep, authContact, business, useCase, address];
for (const entity of entities) {
  await client.trusthub.v1
    .trustProducts(trustProduct.sid)
    .trustProductsEntityAssignments.create({ objectSid: entity.sid });
}
```

#### 4e. Assign Phone Numbers

```javascript
await client.trusthub.v1
  .trustProducts(trustProduct.sid)
  .trustProductsChannelEndpointAssignment.create({
    channelEndpointType: 'phone-number',
    channelEndpointSid: 'PNxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', // Your phone number SID
  });
```

#### 4f. Submit for Review

```javascript
// Run evaluation first
const evaluation = await client.trusthub.v1
  .trustProducts(trustProduct.sid)
  .trustProductsEvaluations.create({
    policySid: 'RNec5c6f3b750ed0d117c1951b5d5ce8c1',
  });

// If compliant, submit
await client.trusthub.v1.trustProducts(trustProduct.sid).update({
  status: 'pending-review',
});
```

### Enhanced Branded Calling

Same as Basic, but:

1. Use Enhanced policy SID: `RNca63d1066fbd5e44eac02d0b3cf6d019`
2. Brand info includes additional fields:
   ```javascript
   const brandInfo = await client.trusthub.v1.endUsers.create({
     friendlyName: 'Enhanced Brand Info',
     type: 'branded_calls_information',
     attributes: {
       branded_calls_display_name: 'Acme Corp',
       branded_calls_long_display_name: 'Acme Corporation - Customer Service',
       branded_calls_call_purpose_code: 'CUSTOMER_SERVICE',
       branded_calls_call_reason: 'Order status update',  // Max 40 chars
       branded_calls_logo_name: 'acme-logo',  // Reference to uploaded logo
     },
   });
   ```
3. Must assign an approved Voice Integrity trust product to the Enhanced trust product

---

## Checking Status

### Via API

```javascript
const trustProduct = await client.trusthub.v1
  .trustProducts('BUxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
  .fetch();
console.log(trustProduct.status);       // 'draft', 'pending-review', 'in-review', 'twilio-approved', 'twilio-rejected'
console.log(trustProduct.failureReason); // null or rejection reason
```

### Via Console

Navigate to **Trust Hub** → **Trust Products** to see visual status and any action items.

---

## Adding Numbers to an Approved Trust Product

After approval, you can add additional phone numbers without re-submitting the trust product:

```javascript
await client.trusthub.v1
  .trustProducts(approvedTrustProductSid)
  .trustProductsChannelEndpointAssignment.create({
    channelEndpointType: 'phone-number',
    channelEndpointSid: 'PNnewNumberSid',
  });
```

Numbers added to an approved trust product inherit the branding configuration. Carrier-side propagation may take 1-3 business days.
