#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="$ROOT_DIR/docker-aio/tests"
OUT_DIR="$TEST_DIR/out"
COMPOSE_FILE="$ROOT_DIR/docker-aio/docker-compose.yml"
OPEN5GS_URL="${OPEN5GS_URL:-http://127.0.0.1:4355}"
SINK_CONTAINER="${SINK_CONTAINER:-ees-sink-test}"
SINK_NETWORK="${SINK_NETWORK:-docker-aio_default}"
SINK_PORT="${SINK_PORT:-9998}"

mkdir -p "$OUT_DIR"

log() {
  printf '[tests] %s\n' "$*"
}

fail() {
  printf '[tests] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

require_prereqs() {
  need_cmd docker
  need_cmd curl
  need_cmd python3
}

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

assert_stack_running() {
  for name in open5gs-aio open5gs-mongodb ueransim-gnb ueransim-ue1 ueransim-ue2; do
    docker inspect "$name" >/dev/null 2>&1 || fail "container not found: $name"
  done
}

ensure_sink() {
  if docker inspect "$SINK_CONTAINER" >/dev/null 2>&1 &&
    [ "$(docker inspect -f '{{.State.Running}}' "$SINK_CONTAINER")" = "true" ]; then
    return
  fi

  log "starting callback sink $SINK_CONTAINER via docker compose"
  compose up -d "$SINK_CONTAINER" >/dev/null
}

cleanup_sink() {
  :
}

new_run_id() {
  date +%Y%m%d%H%M%S
}

json_assert_valid() {
  local file="$1"
  python3 - <<'PY' "$file"
import json
import pathlib
import sys
json.loads(pathlib.Path(sys.argv[1]).read_text())
PY
}

json_get() {
  local file="$1"
  local expr="$2"
  python3 - <<'PY' "$file" "$expr"
import json
import pathlib
import sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
expr = sys.argv[2]
print(eval(expr, {"__builtins__": {}}, {"data": data}))
PY
}

http_request() {
  local method="$1"
  local path="$2"
  local body_file="${3:-}"
  local prefix="$4"
  local url="$OPEN5GS_URL$path"
  local headers="$OUT_DIR/${prefix}.headers"
  local body="$OUT_DIR/${prefix}.body"

  if [ -n "$body_file" ]; then
    curl -sS -D "$headers" -o "$body" \
      -H 'Content-Type: application/json' \
      -X "$method" "$url" --data @"$body_file"
  else
    curl -sS -D "$headers" -o "$body" \
      -X "$method" "$url"
  fi

  printf '%s\n' "$headers|$body"
}

sink_snapshot() {
  local label="$1"
  docker exec "$SINK_CONTAINER" cat /tmp/callback_body.log > "$OUT_DIR/sink-${label}.log" 2>/dev/null || : > "$OUT_DIR/sink-${label}.log"
}

count_correlation() {
  local file="$1"
  local correlation="$2"
  python3 - <<'PY' "$file" "$correlation"
import json
import pathlib
import sys
parts = [p for p in pathlib.Path(sys.argv[1]).read_text().split('\n---\n') if p.strip()]
corr = sys.argv[2]
print(sum(1 for p in parts if json.loads(p).get('correlationId') == corr))
PY
}

summarize_correlation() {
  local file="$1"
  local correlation="$2"
  python3 - <<'PY' "$file" "$correlation"
import json
import pathlib
import sys
parts = [p for p in pathlib.Path(sys.argv[1]).read_text().split('\n---\n') if p.strip()]
corr = sys.argv[2]
rows = []
for p in parts:
    obj = json.loads(p)
    if obj.get('correlationId') != corr:
        continue
    ni = (obj.get('notificationItems') or [{}])[0]
    sn = ni.get('snssai') or {}
    rows.append({
        'ueIpv4Addr': ni.get('ueIpv4Addr'),
        'dnn': ni.get('dnn'),
        'sst': sn.get('sst'),
        'sd': sn.get('sd'),
        'timeStamp': ni.get('timeStamp'),
    })
print(json.dumps(rows))
PY
}

delete_subscription() {
  local id="$1"
  http_request DELETE "/nupf-ee/v1/ee-subscriptions/$id" "" "delete-$id" >/dev/null
}
