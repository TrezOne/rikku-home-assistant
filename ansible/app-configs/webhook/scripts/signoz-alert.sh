#!/bin/sh
set -e

# Accept arguments:
#   $1 -> payload from SigNoz
#   $2 -> debug flag ("true" or "false"), defaults to false
PAYLOAD="$1"
DEBUG="${2:-false}"

# Save raw payload for debugging if debug is true
if [ "$DEBUG" = "true" ]; then
    echo "$PAYLOAD" > /tmp/raw_payload.json
fi

# Iterate over each alert in the "alerts" array
printf '%s' "$PAYLOAD" | jq -c '.alerts[]' | while read -r alert; do

  # Transform the alert into Apprise-compatible JSON
  TRANSFORMED=$(printf '%s' "$alert" | jq -r '
    . as $a |
    {
      title: ($a.labels.alertname // "SigNoz Alert"),
      body: (
        (
          ($a.annotations // {})
          + ($a.labels // {} | del(.alertname))
          + {
              status: ($a.status // "unknown"),
              startsAt: ($a.startsAt // "unknown")
            }
          + (if $a.endsAt != null and $a.endsAt != "" then {endsAt: $a.endsAt} else {} end)
        ) | to_entries | map("\(.key): \(.value)") | join("\n")
      )
    }
  ')

  # Save transformed alert for debugging if debug is true
  if [ "$DEBUG" = "true" ]; then
      echo "$TRANSFORMED" | jq . > /tmp/out_$(echo "$alert" | jq -r '.fingerprint').json
  fi

  # Send to Apprise API
  echo "$TRANSFORMED" | jq -c . | curl -s -X POST -H "Content-Type: application/json" -d @- http://192.168.1.254:54995/notify/apprise

done
