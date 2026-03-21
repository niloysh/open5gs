#!/bin/bash
set -euo pipefail

UE1_CONTAINER="${UE1_CONTAINER:-ueransim-ue1}"
UE2_CONTAINER="${UE2_CONTAINER:-ueransim-ue2}"
PING_TARGET="${PING_TARGET:-www.google.ca}"
PING_IFACE="${PING_IFACE:-uesimtun0}"
PID_FILE="/tmp/ees-traffic.pid"
LOG_FILE="/tmp/ees-traffic.log"

usage() {
  cat <<'EOF'
Usage:
  ./docker-aio/tests/ue-traffic.sh start
  ./docker-aio/tests/ue-traffic.sh stop
  ./docker-aio/tests/ue-traffic.sh status
EOF
}

run_in_container() {
  local container="$1"
  shift
  docker exec "$container" /bin/sh -lc "$*"
}

start_one() {
  local container="$1"
  run_in_container "$container" "
    if [ -f '$PID_FILE' ]; then
      kill \$(cat '$PID_FILE') >/dev/null 2>&1 || true
      rm -f '$PID_FILE'
    fi
    nohup ping -I '$PING_IFACE' '$PING_TARGET' >'$LOG_FILE' 2>&1 &
    echo \$! > '$PID_FILE'
  "
  echo "started traffic in $container"
}

stop_one() {
  local container="$1"
  run_in_container "$container" "
    if [ -f '$PID_FILE' ]; then
      kill \$(cat '$PID_FILE') >/dev/null 2>&1 || true
      rm -f '$PID_FILE'
    fi
  "
  echo "stopped traffic in $container"
}

status_one() {
  local container="$1"
  if run_in_container "$container" "
    [ -f '$PID_FILE' ] && kill -0 \$(cat '$PID_FILE') >/dev/null 2>&1
  "; then
    echo "$container: running"
    run_in_container "$container" "
      if [ -f '$LOG_FILE' ]; then
        tail -n 3 '$LOG_FILE'
      else
        echo 'no log output yet'
      fi
    "
  else
    echo "$container: stopped"
  fi
}

cmd="${1:-}"

case "$cmd" in
  start)
    start_one "$UE1_CONTAINER"
    start_one "$UE2_CONTAINER"
    ;;
  stop)
    stop_one "$UE1_CONTAINER"
    stop_one "$UE2_CONTAINER"
    ;;
  status)
    status_one "$UE1_CONTAINER"
    status_one "$UE2_CONTAINER"
    ;;
  *)
    usage
    exit 1
    ;;
esac
