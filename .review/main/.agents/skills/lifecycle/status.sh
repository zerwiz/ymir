#!/usr/bin/env bash
# status.sh — what of the stack is up (the lifecycle interface).
#
# Reports the five surfaces by port and the two desktop windows, so an operator
# (or a compliance gate) gets one honest answer instead of five guesses.
#
# Usage: status.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)"

# port=name — the runtime's surfaces (see docs/PORTS.md). Names carry no
# spaces: the loop below splits on whitespace.
SURFACES="3888=Hlidskjalf 3889=gate-API 4602=Mimir 4603=Bifrost 8437=Smidja-visualizer"
up=0; rows=""

for pair in $SURFACES; do
  port=${pair%%=*}; name=${pair#*=}
  if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
    rows="$rows  \"$name\",\"$port\",\"up\"\n"; up=$((up+1))
  else
    rows="$rows  \"$name\",\"$port\",\"down\"\n"
  fi
done

# the desktop shells, when electron.sh is present
views=""
if [ -x "$ROOT/scripts/electron.sh" ]; then
  views="$(bash "$ROOT/scripts/electron.sh" status 2>/dev/null | grep -cE '"(hlidskjalf|smidja)","up"')"
fi

printf 'lifecycle[%s]{surface,port,state}:\n' "$(printf "$rows" | grep -c .)"
printf "$rows"
printf 'windows[1]{count,detail}:\n  %s,"electron views up (hlidskjalf + smidja)"\n' "${views:-0}"
printf 'summary[1]{surfaces_up,surfaces_total}:\n  %s,%s\n' "$up" "5"
[ "$up" -gt 0 ] || exit 1
