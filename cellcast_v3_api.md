# Cellcast API v3

A concise, developer-friendly reference for Cellcast’s v3 REST API with cURL examples. Secure HTTPS only.

- Base: https://cellcast.com.au/api/v3
- Auth: APPKEY header is required for all API calls
- Content type: application/json
- Rate limit: 15 requests/second (HTTP 429 + status OVER_LIMIT if exceeded)
- Pagination: page param, 25 items/page; responses include page.count and page.number
- Errors: Check HTTP status and meta.status in the body; meta.status == SUCCESS on success

## Table of contents

- [Security, authentication, throttling, pagination, errors](#security-authentication-throttling-pagination-errors)
- [Send SMS](#send-sms)
- [Get SMS](#get-sms)
- [Get Responses (inbound replies)](#get-responses-inbound-replies)
- [Inbound Read (mark read)](#inbound-read-mark-read)
- [Inbound Read Bulk (mark read)](#inbound-read-bulk-mark-read)
- [Inbound Webhook (real-time inbound)](#inbound-webhook-real-time-inbound)
- [Get Optout](#get-optout)
- [Delivery Reports (DLR callbacks)](#delivery-reports-dlr-callbacks)
- [Balance](#balance)
- [Get SMS Template](#get-sms-template)
- [Send SMS with Template](#send-sms-with-template)
- [Send Bulk SMS](#send-bulk-sms)
- [Register Custom ID (Alpha ID)](#register-custom-id-alpha-id)
- [Send New Zealand SMS](#send-new-zealand-sms)
- [SMS Pricing Structure](#sms-pricing-structure)
- [SMS character count](#sms-character-count)
- [Mobile format (AU)](#mobile-format-au)
- [Master List of Emojis](#master-list-of-emojis)
- [Postman Collection](#postman-collection)
- [Help](#help)

---

## Security, authentication, throttling, pagination, errors

- Security
  - HTTPS required for all requests. Don’t expose APPKEY in client-side code.
- Authentication
  - Provide your APPKEY via header on every request.
  - Headers to send on all endpoints:
    - APPKEY: <<APPKEY>>
    - Content-Type: application/json
- Throttling
  - 15 requests/second per account by default; contact Cellcast for higher limits.
  - On limit: HTTP 429 Too Many Requests + error.status OVER_LIMIT in body.
- Pagination
  - Use page query param (defaults to 1). 25 items/page. Response includes page.count and page.number.
- Error reporting
  - Check HTTP status (2xx success). Also verify meta.status == SUCCESS.
  - meta.status values include SUCCESS or error codes like AUTH_FAILED, FIELD_INVALID, etc.

Optional cURL header snippet you can reuse:

```bash
# Set these env vars once in your shell
export CELLCAST_APPKEY="your-app-key"
export CELLCAST_BASE="https://cellcast.com.au/api/v3"

# Example header usage
curl -sS -H "APPKEY: $CELLCAST_APPKEY" -H "Content-Type: application/json" "$CELLCAST_BASE/account"
```

---

## Send SMS

- Method: POST
- URL: https://cellcast.com.au/api/v3/send-sms
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json
- Body parameters
  - sms_text: string (required)
    - Use "\r\n" for a newline within double-quoted JSON strings
  - numbers: array of E.164 strings (required)
    - Example: ["+61400000000", "+61400000001"]
    - Up to 1000 numbers per API call
  - from: string (optional)
    - Sender ID (Custom ID). Valid: A–Z, a–z, 0–9, space, dash (-)
    - Max 16 digits for numeric; max 11 chars for alphanumeric
    - If omitted, defaults to Regular ID (different pricing)
  - source: string (optional)
    - Letters, numbers, and dashes allowed (e.g., ZOHO, Zapier)
  - custom_string: string (optional)
    - Letters, numbers, and dashes allowed
  - schedule_time: string (optional)
    - Format: YYYY-MM-DD HH:MM:SS (e.g., 2020-02-14 20:00:05)
  - delay: integer minutes (optional)
    - Valid 1–1440 (24 hours)

Example:

```bash
curl -sS -X POST "$CELLCAST_BASE/send-sms" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sms_text": "Hello from Cellcast v3!",
    "numbers": ["+61400000000"],
    "from": "SENDERID",
    "source": "Zapier",
    "custom_string": "lead",
    "schedule_time": "2025-08-15 10:00:00",
    "delay": 5
  }'
```

Success response (example):

```json
{
  "meta": { "code": 200, "status": "SUCCESS" },
  "msg": "Queued",
  "data": {
    "messages": [
      {
        "message_id": "6EF87246-52D3-74FB-C319-NNNNNNNNNN",
        "from": "SENDER_ID",
        "to": "+614NNNNNNNN",
        "body": "SMS body here",
        "date": "2019-06-15 14:02:29",
        "custom_string": "lead",
        "direction": "out"
      }
    ],
    "total_numbers": 1,
    "success_number": 1,
    "credits_used": 1
  },
  "low_sms_alert": "Your account credits are low, you have 36.80 credits remaining, please top-up via the platform"
}
```

---

## Get SMS

- Method: GET
- URL: https://cellcast.com.au/api/v3/get-sms?message_id=<<message_id>>
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json
- Query parameters
  - message_id: string (required) — message ID returned when sending

Example:

```bash
curl -sS "$CELLCAST_BASE/get-sms?message_id=6EF87246-52D3-74FB-C319-NNNNNNN" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json"
```

Success response (example):

```json
{
  "meta": { "code": 200, "status": "SUCCESS" },
  "msg": "Record founded",
  "data": [
    {
      "to": "+61NNNNNNNNN",
      "body": "Here is sent message content",
      "sent_time": "2019-06-15 14:04:46",
      "message_id": "6EF87246-52D3-74FB-C319-NNNNNNN",
      "status": "Delivered",
      "subaccount_id": ""
    }
  ]
}
```

---

## Get Responses (inbound replies)

- Method: GET
- URL: https://cellcast.com.au/api/v3/get-responses?page=<<page>>&type=sms
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json
- Query parameters
  - page: integer (optional) — defaults to 1
  - type: string (required) — sms

Example:

```bash
curl -sS "$CELLCAST_BASE/get-responses?page=1&type=sms" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json"
```

Success response (example):

```json
{
  "meta": { "code": 200, "status": "SUCCESS" },
  "msg": "You have 1 response(s)",
  "data": {
    "page": { "count": 1, "number": 1 },
    "total": "1",
    "responses": [
      {
        "from": "+614NNNNNNNN",
        "body": "Received ",
        "received_at": "2024-09-18 07:15:36",
        "custom_string": "",
        "original_body": "Hello Sent outbound",
        "original_message_id": "9ECD7AEC-C92B-B5F4-8EC8-278F028FEB8B",
        "message_id": "5000000001"
      }
    ]
  }
}
```

---

## Inbound Read (mark read)

- Method: POST
- URL: https://cellcast.com.au/api/v3/inbound-read
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json
- Body parameters (use one approach at a time)
  - message_id: string — mark a single inbound message as read
  - date_before: integer timestamp — mark all messages as read before this timestamp

Examples:

Mark by message_id:

```bash
curl -sS -X POST "$CELLCAST_BASE/inbound-read" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json" \
  -d '{"message_id": "5000000001"}'
```

Mark all before a timestamp:

```bash
curl -sS -X POST "$CELLCAST_BASE/inbound-read" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json" \
  -d '{"date_before": 1695011736}'
```

Success response (example):

```json
{
  "meta": { "code": 200, "status": "SUCCESS" },
  "msg": "Inbound messages have been marked as read.",
  "data": []
}
```

---

## Inbound Read Bulk (mark read)

- Method: POST
- URL: https://cellcast.com.au/api/v3/inbound-read-bulk
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json
- Body parameters
  - message_id: array of strings — inbound message IDs

Example:

```bash
curl -sS -X POST "$CELLCAST_BASE/inbound-read-bulk" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json" \
  -d '{"message_id": ["5000000001", "5000000002", "5000000003"]}'
```

---

## Inbound Webhook (real-time inbound)

Configure your URL in the Cellcast portal (HTTPS recommended). Cellcast will POST the inbound message JSON payload to your URL as messages are received.

Payload fields:

- from: mobile number that sent the reply (E.164)
- body: inbound message body
- received_at: received date/time (string)
- message_id: inbound message ID
- custom_string: custom string value (if set when sending)
- type: SMS or MMS
- original_message_id: original outbound message ID
- original_body: original outbound message body

Example payload:

```json
{
  "from": "+614NNNNNNNN",
  "body": "Reply text",
  "received_at": "2024-09-18 07:15:36",
  "message_id": "5000000001",
  "custom_string": "lead",
  "type": "SMS",
  "original_message_id": "9ECD7AEC-C92B-B5F4-8EC8-278F028FEB8B",
  "original_body": "Hello Sent outbound"
}
```

---

## Get Optout

- Method: GET
- URL: https://cellcast.com.au/api/v3/get-optout
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json
- Query parameters (optional)
  - DATESTART: datetime string — e.g., 2015-08-25 00:00:00
  - DATEEND: datetime string — e.g., 2015-08-25 23:59:59

Example (with date range):

```bash
curl -sS "$CELLCAST_BASE/get-optout?DATESTART=2015-08-25%2000:00:00&DATEEND=2015-08-25%2023:59:59" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json"
```

Success response (example):

```json
{
  "meta": { "code": 200, "status": "SUCCESS" },
  "msg": "You have 1 optout contact(s)",
  "data": {
    "page": { "count": 1, "number": 1 },
    "total": "3",
    "responses": [
      {
        "number": "+61NNNNNNNNN",
        "first_name": "Peter",
        "last_name": "berg",
        "gender": "Male",
        "post_code": "6688",
        "dob": "2010-11-12",
        "created_at": null
      }
    ]
  }
}
```

How to enable opt-out list via API (in portal):

- Settings → Inbound sms settings → Opt-out for API → set to Active

---

## Delivery Reports (DLR callbacks)

Cellcast POSTs delivery status updates to your configured callback URL. Contact Cellcast to set up your callback URL.

Example callback payload (array of objects):

```json
[
  {
    "message_id": "0061DF26-B015-D7F6-7B31-C446BA4FDE8B",
    "status": "Delivered",
    "recipient": "61NNNNNNNNN",
    "custom_string": "Custom string",
    "source": "Source"
  }
]
```

Statuses:

- Queued (Intermediate): Queued within REST system; dispatched per account rate
- Dispatched (Intermediate): Accepted by SMSC
- Aborted (Final): Aborted before reaching SMSC
- Rejected (Final): Rejected by SMSC
- Delivered (Final): Delivered
- Failed (Final): Failed delivery
- Expired (Final): Expired before delivery to SMSC
- Unknown (Final): No DLR received or could not be interpreted

Note: HTTPS certificates must match your domain; self-signed certs will fail verification.

---

## Balance

- Method: GET
- URL: https://cellcast.com.au/api/v3/account
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json

Example:

```bash
curl -sS "$CELLCAST_BASE/account" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json"
```

Success response (example):

```json
{
  "meta": { "code": 200, "status": "SUCCESS" },
  "msg": "Here's your account",
  "data": {
    "account_name": "John",
    "account_email": "john@domain.com",
    "sms_balance": "5831.43",
    "mms_balance": "1006.00"
  }
}
```

---

## Get SMS Template

- Method: GET
- URL: https://cellcast.com.au/api/v3/get-template
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json

Example:

```bash
curl -sS "$CELLCAST_BASE/get-template" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json"
```

Success response (example):

```json
{
  "meta": { "code": 200, "status": "SUCCESS" },
  "msg": "You have 2 Template(s)",
  "data": {
    "page": { "count": 1, "number": 1 },
    "total": "2",
    "per_page": 15,
    "responses": [
      {
        "template_id": "5e6786ade15ac71272e139b9f393e345",
        "message_title": "New template u",
        "Message": "Hello {fname},\r\n\r\nTest from Cellcast",
        "created_at": "2023-07-13 01:25:49"
      },
      {
        "template_id": "21b7acea52c12f59517e491fbecee169",
        "message_title": "Test Template",
        "Message": "Hello {fname}\r\n\r\nTest ",
        "created_at": "2023-07-13 01:33:21"
      }
    ]
  }
}
```

---

## Send SMS with Template

- Method: POST
- URL: https://cellcast.com.au/api/v3/send-sms-template
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json
- Body parameters
  - template_id: string (required)
    - Obtain via Get SMS Template
  - numbers: array of objects (required)
    - Each object can include fields used by your template placeholders
    - Common fields: number, fname, lname, gender, post_code, dob, custom_value_1..3, special
  - from, source, custom_string, schedule_time, delay — same semantics as Send SMS

Example:

```bash
curl -sS -X POST "$CELLCAST_BASE/send-sms-template" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json" \
  -d '{
    "template_id": "21b7acea52c12f59517e491fbecee169",
    "numbers": [
      { "number": "+61413XXXXXX", "fname": "First" },
      { "number": "+61413YYYYYY", "fname": "Second" }
    ],
    "from": "SENDERID",
    "source": "Zapier",
    "custom_string": "lead",
    "schedule_time": "2025-08-15 10:00:00",
    "delay": 5
  }'
```

---

## Send Bulk SMS

- Method: POST
- URL: https://cellcast.com.au/api/v3/bulk-send-sms
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json
- Body format
  - JSON array — each element is a message object with:
    - sms_text: string (required)
    - numbers: string or array (per doc examples; single number shown in sample)
    - from, source, custom_string (optional)

Example:

```bash
curl -sS -X POST "$CELLCAST_BASE/bulk-send-sms" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json" \
  -d '[
    { "sms_text": "Hi User Test one message", "numbers": "+61400000001" },
    { "sms_text": "Hi User Test two message", "numbers": "+61400000002" }
  ]'
```

Success responses are returned as an array, one per input:

```json
[
  {
    "meta": { "code": 200, "status": "SUCCESS" },
    "msg": "Queued",
    "data": { "messages": [ { "message_id": "..." } ], "total_numbers": 1, "success_number": 1, "credits_used": 1 }
  },
  {
    "meta": { "code": 200, "status": "SUCCESS" },
    "msg": "Queued",
    "data": { "messages": [ { "message_id": "..." } ], "total_numbers": 1, "success_number": 1, "credits_used": 1 }
  }
]
```

---

## Register Custom ID (Alpha ID)

- Method: POST
- URL: https://www.cellcast.com.au/api/v3/register-alpha-id
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json
- Body parameters
  - custom_id: string (required) — the Alpha ID
  - description: string (required) — description of the ID

Example:

```bash
curl -sS -X POST "https://www.cellcast.com.au/api/v3/register-alpha-id" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json" \
  -d '{ "custom_id": "TestCustomID", "description": "My Alpha ID" }'
```

---

## Send New Zealand SMS

- Method: POST
- URL: https://cellcast.com.au/api/v3/send-sms-nz
- Headers
  - APPKEY: <<APPKEY>>
  - Content-Type: application/json
- Body parameters
  - sms_text: string (required)
  - numbers: array of E.164 strings (required)
    - Example: ["+64200000000", "+64200000001"]
  - from: string (required)
    - NZ Shortcode; must be exactly 4 numeric digits

Example:

```bash
curl -sS -X POST "$CELLCAST_BASE/send-sms-nz" \
  -H "APPKEY: $CELLCAST_APPKEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sms_text": "Hello NZ!",
    "numbers": ["+64200000000"],
    "from": "1234"
  }'
```

---

## SMS Pricing Structure

- Regular ID: See pricing at https://www.cellcast.com.au
- Custom ID: Regular ID pricing + 33% per message

---

## SMS character count

- Messages > 160 chars are split into parts of 153 chars and reassembled by the handset.
- Max message length: 918 chars (GSM 7-bit), or 402 chars (Unicode set).
- Using Unicode reduces per-message character limit to 70.
- GSM 03.38 escape characters consume two slots: | ^ { } € [ ~ ] \
- Unicode reference: http://unicode-table.com/en/

---

## Mobile format (AU)

- You can send an SMS to any Australian mobile number.
- Valid formats:
  - +614NNNNNNNN
  - 04NNNNNNNN

---

## Master List of Emojis

- Emoji list: https://cellcast.com.au/api/documentation/emojis-list.html
- Reminder: Unicode decreases SMS character limit from 160 to 70.

---

## Postman Collection

- Import the Cellcast v3 collection JSON into Postman.
- Download: files/cellcast-v3-postman-collection.zip (from the original HTML doc’s assets)

---

## Help

- Email: info@cellcast.com
- Melbourne Office: Level 2, 40 Porter St, Prahran, VIC 3181, Australia
- Australia & NZ: +61 (03) 8560 7025

---

Notes

- Values such as limits and examples are reproduced from the provider’s v3 HTML doc for fidelity.
- Where the docs showed differing limits across sections (e.g., 1000 vs 10000 numbers), the conservative value (1000) is shown in parameters; error payloads may mention different limits.
