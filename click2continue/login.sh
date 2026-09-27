#!/bin/sh
printf "Content-Type: text/html; charset=utf-8\r\n\r\n"

# 1. Read POST payload safely in BusyBox
POST_BODY=""
if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ]; then
    POST_BODY=$(head -c "$CONTENT_LENGTH")
fi

# 2. BusyBox-safe URL-decode
urldecode() {
    echo -e "$(echo "$1" | sed 's/+/ /g; s/%/\\x/g')"
}

# 3. Extract form parameters
get_param() {
    local key="$1"
    local raw_val
    raw_val=$(echo "$POST_BODY" | tr '&' '\n' | grep "^${key}=" | head -n 1 | cut -d '=' -f 2-)
    urldecode "$raw_val"
}

CLIENT_MAC=$(get_param "clientmac")
CLIENT_IP=$(get_param "clientip")
GATEWAY_URL=$(get_param "gatewayurl")

# Configuration
LANDING_URL="https://prokop.dev"
SESSION_DURATION="1440" # 24 hours in minutes

# 4. Authenticate client by MAC or IP via ndsctl
if [ -n "$CLIENT_MAC" ]; then
    ndsctl auth "$CLIENT_MAC" "$SESSION_DURATION" >/dev/null 2>&1
elif [ -n "$CLIENT_IP" ]; then
    ndsctl auth "$CLIENT_IP" "$SESSION_DURATION" >/dev/null 2>&1
fi

# 5. Success response
cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Connected</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #f8fafc;
      color: #0f172a;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      padding: 16px;
    }
    .card {
      background: #fff;
      max-width: 360px;
      width: 100%;
      border-radius: 12px;
      padding: 32px 24px;
      text-align: center;
      border: 1px solid #e2e8f0;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
    }
    h2 { font-size: 18px; margin-bottom: 8px; color: #16a34a; }
    p { font-size: 13px; color: #64748b; line-height: 1.5; margin-bottom: 20px; }
    a.btn {
      display: block;
      text-decoration: none;
      background: #2563eb;
      color: #fff;
      padding: 12px 20px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="card">
    <h2>Access Granted</h2>
    <p>You are now connected to the internet. Tap Done in the top corner or continue below.</p>
    <a href="${LANDING_URL}" class="btn" target="_blank">Continue to prokop.dev</a>
  </div>
</body>
</html>
EOF