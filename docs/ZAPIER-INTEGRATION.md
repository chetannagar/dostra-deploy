# Zapier Integration

Connects WPForms submissions to the Dostra CRM via a signed webhook. Each form submission creates a lead under the configured client.

---

## How It Works

```text
WPForms submission
  → Zapier trigger (New Form Entry)
  → Code by Zapier (HMAC signing)
  → POST /api/webhook/leads
  → Lead created in Dostra CRM
```

The webhook endpoint requires HMAC-SHA256 signing. Each client has a unique `client_key` and `webhook_secret` used to authenticate requests.

---

## Step 1 — Get Credentials from Admin Panel

Log in to the Dostra admin panel. Navigate to **Clients** and open the client you want to connect.

You need two values:

- **Client Key** (`client_key`) — e.g. `wp_acme_corp`
- **Webhook Secret** (`webhook_secret`) — 64-character random string

The webhook secret is shown once after creation or rotation. Copy and store it securely. If lost, rotate it via **Clients → {client} → Rotate Webhook Secret**.

---

## Step 2 — Create the Zap

### Trigger: WPForms

1. Create a new Zap
2. Trigger app: **WPForms**
3. Trigger event: **New Form Entry**
4. Connect your WPForms account
5. Select the form
6. Test the trigger — pull a sample submission

---

### Action: Code by Zapier

1. Add action: **Code by Zapier**
2. Action event: **Run JavaScript**

#### Input Data

Define these keys exactly:

| Key | Value |
| --- | ----- |
| `webhook_url` | Your API URL — e.g. `https://yourdomain.com/api/webhook/leads` |
| `client_key` | Your client key — Request Admin for this |
| `webhook_secret` | Your webhook secret — Request Admin for this |
| `name` | Map from WPForms name field |
| `email` | Map from WPForms email field |
| `message` | Map from WPForms message field |

#### Code

```javascript
const crypto = require('crypto');
const webhookUrl = inputData.webhook_url;
const clientKey = inputData.client_key;
const webhookSecret = inputData.webhook_secret;

const payloadObject = {
  name: inputData.name || null,
  email: inputData.email || null,
  message: inputData.message || null,
};

const rawBody = JSON.stringify(payloadObject);
const timestamp = Math.floor(Date.now() / 1000).toString();
const eventId = `evt_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;

const signature = crypto
  .createHmac('sha256', webhookSecret)
  .update(`${timestamp}.${rawBody}`)
  .digest('hex');

const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), 900);

try {
  const response = await fetch(webhookUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Key': clientKey,
      'X-Webhook-Id': eventId,
      'X-Webhook-Timestamp': timestamp,
      'X-Webhook-Signature': signature,
    },
    body: rawBody,
    signal: controller.signal,
  });

  clearTimeout(timeoutId);

  if (!response.ok) {
    throw new Error(`Webhook failed: ${response.status}`);
  }

  return { status: response.status, event_id: eventId };
} catch (error) {
  clearTimeout(timeoutId);
  throw error;
}
```

---

## Webhook Endpoint Reference

| Property | Value |
| -------- | ----- |
| URL | `POST /api/webhook/leads` |
| Rate limit | 60 requests/min per client key |
| Idempotency | Duplicate `X-Webhook-Id` values are silently deduplicated |

### Required Headers

| Header | Description |
| ------ | ----------- |
| `X-Client-Key` | Client identifier |
| `X-Webhook-Id` | Unique event ID for idempotency |
| `X-Webhook-Timestamp` | Unix timestamp (seconds) — rejected if >5 minutes old |
| `X-Webhook-Signature` | HMAC-SHA256 hex digest |

### Payload Fields

All fields are optional (nullable):

| Field | Type | Description |
| ----- | ---- | ----------- |
| `name` | string | Lead's full name |
| `email` | string | Lead's email address |
| `message` | string | Message or notes from the form |

### Signature Algorithm

```text
signed_payload = timestamp + "." + raw_json_body
signature      = HMAC-SHA256(signed_payload, webhook_secret) as hex
```

The raw JSON body must be signed — do not modify the body between signing and sending.

### Success Response (201)

```json
{
  "message": "Lead received successfully",
  "data": {
    "id": 42,
    "name": "Jane Doe",
    "email": "jane@example.com",
    "message": "Interested in your services",
    "source": "wpforms-zapier",
    "client": { },
    "created_at": "2026-04-22T10:00:00Z"
  }
}
```

### Duplicate Event Response (200)

```json
{
  "message": "Webhook event already processed.",
  "data": { }
}
```

---

## Rotating the Webhook Secret

If the secret is compromised or lost:

1. Admin panel → **Clients** → select client → **Rotate Webhook Secret**
2. Copy the new secret immediately
3. Update the `webhook_secret` value in the Zapier Code step input data
4. Test the Zap to confirm it works

Old secret is invalidated immediately on rotation.

---

## Troubleshooting

### `401 Invalid webhook signature`

- Confirm `webhook_secret` in Zapier matches the current value in admin panel
- Ensure raw JSON body is not modified after signing
- Check that `Content-Type: application/json` is set

### `401 Webhook timestamp is too old`

- Timestamp must be within 5 minutes of server time
- The code generates a fresh timestamp per execution — this should not occur unless the Zap is replaying very old events

### `401 Invalid webhook client`

- `client_key` is wrong or the client is deactivated in admin panel

### `422 Unprocessable Content`

- `email` field exists but is not a valid email format

### Zapier: "Execution exceeded 1 seconds"

Code by Zapier has a 1-second execution limit on Zapier's free and Starter plans. The limit is 30 seconds on Professional and above.

If the API response time plus network latency exceeds 1 second, Zapier will report an error even though the lead was created successfully (idempotency prevents duplicates on retries).

Options:

- Upgrade to Zapier Professional for the 30-second limit
- Ensure the API server is running and warm before the Zap fires (avoid cold Docker starts)
