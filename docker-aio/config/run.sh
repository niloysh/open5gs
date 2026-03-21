#!/bin/bash
set -euo pipefail

config_path="${CONFIG_PATH:-/open5gs-aio/config}"
debug_mode="${DEBUG_MODE:-false}"

declare -a processes=(
  "/open5gs/install/bin/open5gs-nrfd -c $config_path/nrf.yaml"
  "/open5gs/install/bin/open5gs-scpd -c $config_path/scp.yaml"
  "/open5gs/install/bin/open5gs-amfd -c $config_path/amf.yaml"
  "/open5gs/install/bin/open5gs-smfd -c $config_path/smf.yaml"
  "/open5gs/install/bin/open5gs-ausfd -c $config_path/ausf.yaml"
  "/open5gs/install/bin/open5gs-udmd -c $config_path/udm.yaml"
  "/open5gs/install/bin/open5gs-udrd -c $config_path/udr.yaml"
  "/open5gs/install/bin/open5gs-pcfd -c $config_path/pcf.yaml"
  "/open5gs/install/bin/open5gs-nssfd -c $config_path/nssf.yaml"
  "/open5gs/install/bin/open5gs-bsfd -c $config_path/bsf.yaml"
  "/open5gs/install/bin/open5gs-upfd -c $config_path/upf.yaml"
)

start_processes() {
  for process in "${processes[@]}"; do
    bash -lc "$process" &
    sleep 2
    echo "Started process: $process"
  done
  echo "All Open5GS processes started."
}

stop_processes() {
  for process in "${processes[@]}"; do
    pid=$(pgrep -f "$process" || true)
    if [ -n "${pid}" ]; then
      kill "${pid}"
      echo "Stopped process: $process (PID: $pid)"
    fi
  done
  exit 0
}

trap stop_processes SIGINT SIGTERM

start_processes

if [ "$debug_mode" = "true" ]; then
  echo "Open5GS AIO is running in debug mode."
fi

while true; do
  sleep 1
done
