#!/bin/bash
set -euo pipefail

compose_file="docker-aio/docker-compose.yml"

docker compose -f "$compose_file" run --rm subscriber-init
