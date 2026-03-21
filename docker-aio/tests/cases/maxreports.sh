#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/docker-aio/tests/lib.sh"

RUN_ID="$(new_run_id)"
CORR="maxreports-$RUN_ID"
PAYLOAD="$OUT_DIR/$CORR.json"

sink_snapshot "maxreports-before-$RUN_ID"

cat > "$PAYLOAD" <<EOF
{
  "subscription": {
    "eventNotifyUri": "http://$SINK_CONTAINER:$SINK_PORT/notify",
    "notifyCorrelationId": "$CORR",
    "nfId": "docker-aio-test",
    "anyUe": true,
    "eventReportingMode": {
      "trigger": "PERIODIC",
      "maxReports": 3,
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
IFS='|' read -r _ create_body < <(http_request POST /nupf-ee/v1/ee-subscriptions "$PAYLOAD" "$CORR-create")
json_assert_valid "$create_body"
SUB_ID="$(json_get "$create_body" "data['subscriptionId']")"

sleep 10
sink_snapshot "maxreports-after-$RUN_ID"

python3 - <<'PY' \
  "$OUT_DIR/sink-maxreports-before-$RUN_ID.log" \
  "$OUT_DIR/sink-maxreports-after-$RUN_ID.log" \
  "$CORR"
import json
import pathlib
import sys

def rows(path, corr):
    parts = [p for p in pathlib.Path(path).read_text().split('\n---\n') if p.strip()]
    out = []
    for p in parts:
        obj = json.loads(p)
        if obj.get('correlationId') != corr:
            continue
        ni = (obj.get('notificationItems') or [{}])[0]
        out.append((ni.get('timeStamp'), ni.get('ueIpv4Addr'), ni.get('dnn')))
    return out

before = rows(sys.argv[1], sys.argv[3])
after = rows(sys.argv[2], sys.argv[3])
new_rows = after[len(before):]

assert len(new_rows) == 6, new_rows
assert {row[1] for row in new_rows} == {'10.41.0.2', '10.42.0.2'}, new_rows
assert len({row[0] for row in new_rows}) == 3, new_rows
PY

log "maxreports case passed"
