#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/docker-aio/tests/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  ./docker-aio/tests/run.sh
  ./docker-aio/tests/run.sh subscribe
  ./docker-aio/tests/run.sh get
  ./docker-aio/tests/run.sh list
  ./docker-aio/tests/run.sh delete
  ./docker-aio/tests/run.sh filters
  ./docker-aio/tests/run.sh maxreports
EOF
}

run_case() {
  local case_name="$1"
  log "running case: $case_name"
  "$ROOT_DIR/docker-aio/tests/cases/$case_name.sh"
}

main() {
  require_prereqs
  assert_stack_running
  ensure_sink

  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
  fi

  if [ $# -eq 0 ]; then
    run_case subscribe
    run_case delete
    run_case filters
    run_case maxreports
    exit 0
  fi

  case "$1" in
    subscribe|get|list|delete|filters|maxreports)
      run_case "$1"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
