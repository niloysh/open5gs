#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/docker-aio/tests/lib.sh"

RUN_ID="$(new_run_id)"
CORR="delete-$RUN_ID"
PAYLOAD="$OUT_DIR/$CORR.json"

sink_snapshot "delete-before-$RUN_ID"

cat > "$PAYLOAD" <<EOF
{
  "subscription": {
    "eventNotifyUri": "http://$SINK_CONTAINER:$SINK_PORT/notify",
    "notifyCorrelationId": "$CORR",
    "nfId": "docker-aio-test",
    "anyUe": true,
    "eventReportingMode": {
      "trigger": "PERIODIC",
      "maxReports": 10,
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

IFS='|' read -r _ create_body < <(http_request POST /nupf-ee/v1/ee-subscriptions "$PAYLOAD" "$CORR-create")
json_assert_valid "$create_body"
SUB_ID="$(json_get "$create_body" "data['subscriptionId']")"

sleep 5
sink_snapshot "delete-mid-$RUN_ID"

BEFORE_DELETE="$(count_correlation "$OUT_DIR/sink-delete-before-$RUN_ID.log" "$CORR")"
MID_DELETE="$(count_correlation "$OUT_DIR/sink-delete-mid-$RUN_ID.log" "$CORR")"
[ $((MID_DELETE - BEFORE_DELETE)) -gt 0 ] || fail "subscription did not generate callbacks before delete"

IFS='|' read -r _ delete_body < <(http_request DELETE "/nupf-ee/v1/ee-subscriptions/$SUB_ID" "" "$CORR-delete")
json_assert_valid "$delete_body"

sleep 5
sink_snapshot "delete-after-$RUN_ID"

python3 - <<'PY' \
  "$OUT_DIR/sink-delete-before-$RUN_ID.log" \
  "$OUT_DIR/sink-delete-mid-$RUN_ID.log" \
  "$OUT_DIR/sink-delete-after-$RUN_ID.log" \
  "$CORR"
import json
import pathlib
import sys

def count(path, corr):
    parts = [p for p in pathlib.Path(path).read_text().split('\n---\n') if p.strip()]
    return sum(1 for p in parts if json.loads(p).get('correlationId') == corr)

before = count(sys.argv[1], sys.argv[4])
mid = count(sys.argv[2], sys.argv[4])
after = count(sys.argv[3], sys.argv[4])

assert mid > before, (before, mid, after)
assert after == mid, (before, mid, after)
PY

IFS='|' read -r check_headers check_body < <(http_request GET "/nupf-ee/v1/ee-subscriptions/$SUB_ID" "" "$CORR-check")
json_assert_valid "$check_body"
grep -q 'HTTP/1.1 404' "$check_headers" || fail "deleted subscription did not return 404"

log "delete case passed (subscription $SUB_ID)"
