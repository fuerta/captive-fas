#!/bin/sh

# RFC 8908 requires application/captive+json and no-cache headers
printf "Content-Type: application/captive+json\r\n"
printf "Cache-Control: private, no-cache, no-store, must-revalidate\r\n\r\n"

CLIENT_IP="$REMOTE_ADDR"
PORTAL_URL="https://fas-bel.prokop.dev:8443/cgi-bin/entry.sh"
VENUE_URL="https://prokop.dev"

# Default state: unauthenticated
IS_CAPTIVE="true"
SECONDS_REMAINING=0

if [ -n "$CLIENT_IP" ]; then
    CLIENT_DATA=$(ndsctl json "$CLIENT_IP" 2>/dev/null)

    # Use grep -qi for case-insensitive match on "authenticated"
    if echo "$CLIENT_DATA" | grep -qi '"state":"authenticated"'; then
        IS_CAPTIVE="false"

        # Safely extract epoch digits from "session_end":"1790539430"
        SESSION_END=$(echo "$CLIENT_DATA" | grep -i '"session_end"' | tr -dc '0-9')
        NOW=$(date +%s)

        if [ -n "$SESSION_END" ] && [ "$SESSION_END" -gt "$NOW" ]; then
            SECONDS_REMAINING=$((SESSION_END - NOW))
        else
            SECONDS_REMAINING=86400
        fi
    fi
fi

# Output the RFC 8908 standard JSON payload
cat <<EOF
{
  "captive": ${IS_CAPTIVE},
  "user-portal-url": "${PORTAL_URL}",
  "venue-info-url": "${VENUE_URL}",
  "seconds-remaining": ${SECONDS_REMAINING},
  "can-extend-session": false
}
EOF