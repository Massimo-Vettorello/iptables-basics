#!/bin/bash
# Uso: check [IP_SERVER]   (default 172.28.0.10)
# Distingue: OPEN (risponde) / REFUSED (REJECT o porta chiusa) / TIMEOUT (DROP)
T=${1:-172.28.0.10}
printf "Verifica da %s verso %s\n" "$(hostname -i | awk '{print $1}')" "$T"
printf "%-14s %s\n" "SERVICE" "OUTCOME"

if ping -c1 -W2 "$T" >/dev/null 2>&1; then r="OPEN (ping risponds)"; else r="TIMEOUT / blocked"; fi
printf "%-14s %s\n" "ICMP ping" "$r"

for entry in "SSH:22" "HTTP:80" "MySQL:3306" "Postgres:5432"; do
  name=${entry%%:*}; port=${entry##*:}
  out=$(nc -z -w2 -v "$T" "$port" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then r="OPEN"
  elif echo "$out" | grep -qi "refused"; then r="REFUSED  (REJECT or no service)"
  else r="TIMEOUT  (DROP: packet vanished)"; fi
  printf "%-14s %s\n" "$name/$port" "$r"
done
