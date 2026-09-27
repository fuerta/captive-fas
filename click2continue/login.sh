#!/bin/sh

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
LANDING_URL="https://info.fizjoterapia.uk"
SESSION_DURATION="1440" # 24 hours in minutes

# 4. Authenticate client by MAC or IP via ndsctl
if [ -n "$CLIENT_MAC" ]; then
    ndsctl auth "$CLIENT_MAC" "$SESSION_DURATION" >/dev/null 2>&1
elif [ -n "$CLIENT_IP" ]; then
    ndsctl auth "$CLIENT_IP" "$SESSION_DURATION" >/dev/null 2>&1
fi

# 5. Success response
printf "Content-Type: text/html; charset=utf-8\r\n\r\n"

cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Connected to Internet</title>
  <style>
    :root {
      --primary: #0f172a;
      --accent: #2563eb;
      --success: #16a34a;
      --bg: #f8fafc;
      --card-bg: #ffffff;
      --text: #0f172a;
      --text-muted: #64748b;
      --border: #e2e8f0;
      --radius: 12px;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 16px;
    }

    .container {
      width: 100%;
      max-width: 380px;
      background: var(--card-bg);
      border-radius: var(--radius);
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
      border: 1px solid var(--border);
      padding: 32px 24px;
      text-align: center;
    }

    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 4px 12px;
      background: #dcfce7;
      color: var(--success);
      font-size: 13px;
      font-weight: 600;
      border-radius: 999px;
      margin-bottom: 16px;
    }

    .status-dot {
      width: 8px;
      height: 8px;
      background-color: var(--success);
      border-radius: 50%;
      box-shadow: 0 0 0 2px rgba(22, 163, 74, 0.2);
    }

    h1 {
      font-size: 22px;
      font-weight: 600;
      letter-spacing: -0.02em;
    }

    p.subtitle {
      font-size: 13px;
      color: var(--text-muted);
      margin: 8px 0 24px 0;
      line-height: 1.4;
    }

    /* Network Diagnostics Card */
    .net-card {
      background: #f1f5f9;
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 14px;
      margin-bottom: 24px;
      text-align: left;
    }

    .net-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 12px;
      padding: 5px 0;
      border-bottom: 1px solid rgba(226, 232, 240, 0.8);
    }

    .net-row:last-child {
      border-bottom: none;
      padding-bottom: 0;
    }

    .net-label {
      color: var(--text-muted);
      font-weight: 500;
    }

    .net-val {
      font-family: ui-monospace, Menlo, monospace;
      font-weight: 600;
      color: var(--text);
    }

    .pulse {
      animation: pulse 1.5s infinite;
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.4; }
    }

    .btn-action {
      display: block;
      width: 100%;
      height: 44px;
      line-height: 44px;
      background-color: var(--accent);
      color: #ffffff;
      text-decoration: none;
      border-radius: 8px;
      font-size: 15px;
      font-weight: 600;
      transition: background-color 0.15s ease;
    }

    .btn-action:hover {
      background-color: #1d4ed8;
    }

    .ios-hint {
      margin-top: 14px;
      font-size: 11px;
      color: var(--text-muted);
    }
  </style>
</head>
<body>

  <div class="container">
    <div class="status-badge">
      <div class="status-dot"></div>
      Online &amp; Active
    </div>

    <h1>Internet Connected</h1>
    <p class="subtitle">Your device is authenticated. On Apple devices, tap <strong>Done</strong> in the top-right corner to start browsing.</p>

    <!-- Visual Network Info Widget -->
    <div class="net-card">
      <div class="net-row">
        <span class="net-label">Public IP</span>
        <span class="net-val" id="wan-ip"><span class="pulse">Detecting...</span></span>
      </div>
      <div class="net-row">
        <span class="net-label">Location</span>
        <span class="net-val" id="wan-loc"><span class="pulse">Locating...</span></span>
      </div>
      <div class="net-row">
        <span class="net-label">Link Latency</span>
        <span class="net-val" id="wan-ping"><span class="pulse">Measuring...</span></span>
      </div>
    </div>

    <!-- Direct Action Button -->
    <a href="${LANDING_URL}" class="btn-action">
      Finish &amp; Browse
    </a>

    <p class="ios-hint">Tap "Done" at top right to return to your apps.</p>
  </div>

  <script>
    (function() {
      // 1100ms delay to ensure openNDS & kernel firewall rules are active
      setTimeout(runDiagnostics, 1100);

      function runDiagnostics() {
        const pingStart = performance.now();

        // Fetch trace directly from Cloudflare (HTTPS, CORS-enabled, minimal payload)
        fetch('https://1.1.1.1/cdn-cgi/trace', { cache: 'no-store' })
          .then(response => {
            // Calculate round-trip link latency to the nearest Anycast edge
            const latency = Math.round(performance.now() - pingStart);
            const pingEl = document.getElementById('wan-ping');
            if (pingEl) pingEl.textContent = latency + ' ms';
            return response.text();
          })
          .then(text => {
            const lines = text.split('\\n');
            const trace = {};
            lines.forEach(line => {
              const parts = line.split('=');
              if (parts.length === 2) trace[parts[0]] = parts[1];
            });

            // Display Public IP
            const ipEl = document.getElementById('wan-ip');
            if (ipEl && trace.ip) {
              ipEl.textContent = trace.ip;
            }

            // Display Edge Location (Airport/Colo Code, e.g. LHR, DUB, MAD)
            const locEl = document.getElementById('wan-loc');
            if (locEl && trace.loc) {
              locEl.textContent = trace.loc + ' Edge (' + (trace.colo || 'WAN') + ')';
            }
          })
          .catch(() => {
            // Graceful fallback if Cloudflare is unreachable
            const ipEl = document.getElementById('wan-ip');
            const locEl = document.getElementById('wan-loc');
            const pingEl = document.getElementById('wan-ping');

            if (ipEl) ipEl.textContent = 'Active (Protected)';
            if (locEl) locEl.textContent = 'Online';
            if (pingEl) pingEl.textContent = 'OK';
          });

      }
    })();
  </script>

</body>
</html>
EOF