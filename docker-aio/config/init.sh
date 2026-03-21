#!/bin/bash
set -euo pipefail

ip tuntap add name ogstun mode tun || true
ip address add 10.41.0.1/16 dev ogstun || true
ip address add 10.42.0.1/16 dev ogstun || true
sysctl -w net.ipv6.conf.all.disable_ipv6=1
ip link set ogstun up
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -C POSTROUTING -s 10.41.0.0/16 ! -o ogstun -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 10.41.0.0/16 ! -o ogstun -j MASQUERADE
iptables -t nat -C POSTROUTING -s 10.42.0.0/16 ! -o ogstun -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 10.42.0.0/16 ! -o ogstun -j MASQUERADE

/bin/bash /open5gs-aio/config/run.sh
