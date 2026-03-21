#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/docker-aio/tests/lib.sh"

RUN_ID="$(new_run_id)"
sink_snapshot "filters-before-$RUN_ID"

create_payload() {
  local file="$1"
  local corr="$2"
  local dnn="$3"
  local sst="$4"
  local sd="$5"
  cat > "$file" <<EOF
{
  "subscription": {
    "eventNotifyUri": "http://$SINK_CONTAINER:$SINK_PORT/notify",
    "notifyCorrelationId": "$corr",
    "nfId": "docker-aio-test",
    "anyUe": true,
    "dnn": "$dnn",
    "snssai": { "sst": $sst, "sd": "$sd" },
    "eventReportingMode": {
      "trigger": "PERIODIC",
      "maxReports": 2,
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
}

UE1_CORR="filter-ue1-$RUN_ID"
UE2_CORR="filter-ue2-$RUN_ID"
ANY_CORR="filter-anyue-$RUN_ID"

UE1_PAYLOAD="$OUT_DIR/$UE1_CORR.json"
UE2_PAYLOAD="$OUT_DIR/$UE2_CORR.json"
ANY_PAYLOAD="$OUT_DIR/$ANY_CORR.json"

create_payload "$UE1_PAYLOAD" "$UE1_CORR" "internet" 1 "000001"
create_payload "$UE2_PAYLOAD" "$UE2_CORR" "streaming" 2 "000002"
cat > "$ANY_PAYLOAD" <<EOF
{
  "subscription": {
    "eventNotifyUri": "http://$SINK_CONTAINER:$SINK_PORT/notify",
    "notifyCorrelationId": "$ANY_CORR",
    "nfId": "docker-aio-test",
    "anyUe": true,
    "eventReportingMode": {
      "trigger": "PERIODIC",
      "maxReports": 2,
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

trap 'for id in "${SUB_IDS[@]:-}"; do delete_subscription "$id" || true; done' EXIT
SUB_IDS=()

for pair in \
  "$UE1_PAYLOAD:$UE1_CORR" \
  "$UE2_PAYLOAD:$UE2_CORR" \
  "$ANY_PAYLOAD:$ANY_CORR"
do
  payload="${pair%%:*}"
  corr="${pair##*:}"
  IFS='|' read -r _ create_body < <(http_request POST /nupf-ee/v1/ee-subscriptions "$payload" "$corr-create")
  json_assert_valid "$create_body"
  SUB_IDS+=("$(json_get "$create_body" "data['subscriptionId']")")
done

sleep 7
sink_snapshot "filters-after-$RUN_ID"

python3 - <<'PY' \
  "$OUT_DIR/sink-filters-after-$RUN_ID.log" \
  "$UE1_CORR" "$UE2_CORR" "$ANY_CORR"
import json
import pathlib
import sys

parts = [p for p in pathlib.Path(sys.argv[1]).read_text().split('\n---\n') if p.strip()]
corrs = sys.argv[2:]

def rows_for(corr):
    rows = []
    for p in parts:
        obj = json.loads(p)
        if obj.get('correlationId') != corr:
            continue
        ni = (obj.get('notificationItems') or [{}])[0]
        rows.append((ni.get('ueIpv4Addr'), ni.get('dnn')))
    return rows

ue1 = set(rows_for(corrs[0]))
ue2 = set(rows_for(corrs[1]))
anyue = set(rows_for(corrs[2]))

assert ue1 == {('10.41.0.2', 'internet')}, ue1
assert ue2 == {('10.42.0.2', 'streaming')}, ue2
assert anyue == {('10.41.0.2', 'internet'), ('10.42.0.2', 'streaming')}, anyue
PY

log "filters case passed"
