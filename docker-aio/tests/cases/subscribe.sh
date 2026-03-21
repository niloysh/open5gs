#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/docker-aio/tests/lib.sh"

RUN_ID="$(new_run_id)"
CORR="subscribe-$RUN_ID"
PAYLOAD="$OUT_DIR/$CORR.json"

cat > "$PAYLOAD" <<EOF
{
  "subscription": {
    "eventNotifyUri": "http://$SINK_CONTAINER:$SINK_PORT/notify",
    "notifyCorrelationId": "$CORR",
    "nfId": "docker-aio-test",
    "anyUe": true,
    "eventReportingMode": {
      "trigger": "PERIODIC",
      "maxReports": 1,
      "expiry": "2026-12-31T23:59:59Z",
      "repPeriod": 2,
      "sampRatio": 100,
      "partitioningCriteria": [],
      "notifFlag": "ACTIVATE",
      "mutingExcInstructions": {
        "subscription": "CONTINUE_WITHOUT_MUTING",
        "bufferedNotifs": "SEND_ALL"
      }
    },
    "eventList": [
      {
        "type": "USER_DATA_USAGE_MEASURES",
        "immediateFlag": true,
        "measurementTypes": ["VOLUME_MEASUREMENT"],
        "appIds": [],
        "trafficFilters": [],
        "granularityOfMeasurement": "PER_SESSION",
        "reportingSuggestionInfo": {
          "reportingUrgency": "DELAY_TOLERANT",
          "reportingTimeInfo": 0
        }
      }
    ]
  }
}
EOF

trap '[ -n "${SUB_ID:-}" ] && delete_subscription "$SUB_ID" || true' EXIT

IFS='|' read -r create_headers create_body < <(http_request POST /nupf-ee/v1/ee-subscriptions "$PAYLOAD" "subscribe-create-$RUN_ID")
json_assert_valid "$create_body"
grep -Eq 'HTTP/1.1 (200|201)' "$create_headers" || fail "create request did not return success"

SUB_ID="$(json_get "$create_body" "data['subscriptionId']")"
[ -n "$SUB_ID" ] || fail "create response missing subscriptionId"

log "subscribe case passed (subscription $SUB_ID)"
