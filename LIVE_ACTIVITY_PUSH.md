# Live Activity Push Notifications Setup

This app now supports updating the Live Activity via push notifications, allowing continuous background updates!

## Setup Steps

### 1. Enable Push Notifications in Xcode
1. Select your **PostureDetector** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **Push Notifications**

### 2. Get Your Push Token
1. Run the app on a **physical device** (push tokens don't work on simulator)
2. Start monitoring (tap play button)
3. Check Xcode console logs for:
```
🔑 PUSH TOKEN: abc123def456...
📋 Activity ID: 12345-67890-...
```
4. Copy both values - you'll need them!

### 3. Set Up Push Notifications

You have several options to send push notifications:

#### Option A: Simple Mac Script (For Testing)

```bash
# Install dependencies
npm install -g apn

# Create a script: send_push.js
const apn = require('apn');

// Your values from console
const PUSH_TOKEN = 'YOUR_PUSH_TOKEN_HERE';
const ACTIVITY_ID = 'YOUR_ACTIVITY_ID_HERE';

const options = {
    token: {
        key: 'path/to/AuthKey_XXXXX.p8',  // Download from Apple Developer
        keyId: 'YOUR_KEY_ID',
        teamId: 'YOUR_TEAM_ID'
    },
    production: false  // Use false for development
};

const apnProvider = new apn.Provider(options);

// Posture update payload
const notification = new apn.Notification({
    topic: 'com.yourapp.PostureDetector.push-type.liveactivity',
    pushType: 'liveactivity',
    payload: {
        aps: {
            timestamp: Math.floor(Date.now() / 1000),
            event: 'update',
            'content-state': {
                postureStatus: 'Good Posture ✓',
                pitch: 0.1,
                roll: 0.05,
                timestamp: new Date().toISOString(),
                isConnected: true
            },
            'alert': {
                'title': 'Posture Update',
                'body': 'Live Activity updated'
            }
        }
    }
});

apnProvider.send(notification, PUSH_TOKEN).then(result => {
    console.log('Push sent:', result);
});
```

#### Option B: Python Script

```python
import jwt
import time
import requests
import json

# Your credentials
TEAM_ID = 'YOUR_TEAM_ID'
KEY_ID = 'YOUR_KEY_ID'
AUTH_KEY_PATH = 'AuthKey_XXXXX.p8'
PUSH_TOKEN = 'YOUR_PUSH_TOKEN'
ACTIVITY_ID = 'YOUR_ACTIVITY_ID'

# Generate JWT
with open(AUTH_KEY_PATH, 'r') as f:
    auth_key = f.read()

headers = {
    'alg': 'ES256',
    'kid': KEY_ID
}

payload = {
    'iss': TEAM_ID,
    'iat': time.time()
}

token = jwt.encode(payload, auth_key, algorithm='ES256', headers=headers)

# Send push
url = f'https://api.development.push.apple.com/3/device/{PUSH_TOKEN}'

headers = {
    'authorization': f'bearer {token}',
    'apns-push-type': 'liveactivity',
    'apns-topic': 'com.yourapp.PostureDetector.push-type.liveactivity',
    'apns-priority': '10'
}

payload = {
    'aps': {
        'timestamp': int(time.time()),
        'event': 'update',
        'content-state': {
            'postureStatus': 'Good Posture ✓',
            'pitch': 0.1,
            'roll': 0.05,
            'timestamp': time.time(),
            'isConnected': True
        }
    }
}

response = requests.post(url, headers=headers, json=payload)
print(f'Status: {response.status_code}')
print(f'Response: {response.text}')
```

#### Option C: Automated Server

Build a simple server that:
1. Receives posture updates from your Mac/device
2. Sends push notifications every few seconds
3. Keeps Live Activity updated continuously

### 4. Get Apple Push Notification Key

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Keys** → **+** (Create new key)
4. Check **Apple Push Notifications service (APNs)**
5. Download the `.p8` file (AuthKey_XXXXX.p8)
6. Note your **Key ID** and **Team ID**

## Payload Structure

The Live Activity expects this structure:

```json
{
  "aps": {
    "timestamp": 1234567890,
    "event": "update",
    "content-state": {
      "postureStatus": "Good Posture ✓",  // or "Leaning Forward", "Poor Posture", etc.
      "pitch": 0.1,                        // in radians
      "roll": 0.05,                        // in radians
      "timestamp": "2024-01-11T12:00:00Z",
      "isConnected": true
    }
  }
}
```

## Testing

1. Start monitoring in the app
2. Minimize the app
3. Send a push notification with updated posture data
4. Watch the Dynamic Island update!

## Posture Status Values

- `"Good Posture ✓"`
- `"Leaning Forward"`
- `"Leaning Sideways"`
- `"Poor Posture"`
- `"Waiting for data..."`

## Troubleshooting

- **No push token?** Must use physical device, not simulator
- **Push not working?** Check bundle ID matches in payload topic
- **Invalid token?** Token changes when you restart monitoring
- **403 error?** Check your APNs key permissions and team ID

## Next Steps

For production, you'd want to:
1. Build a simple backend that receives motion data
2. Backend processes and sends push notifications
3. Or use a Mac app that runs alongside PostureDetector
4. Or integrate with existing server infrastructure
