#!/usr/bin/env bash
# registries-refresh.sh — write the four measured registries for this host into the home.
#
# One entry point for the daily row: what is restartable, which tunnels answer, who is working, what is scheduled.
# Kept separate from running-inventory.sh because that one is about containers and takes longer; this one is the four
# questions an operator actually asks at the start of a day.
set -uo pipefail
HOST="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"
HOME_DIR="${YMIR_HOME:-$HOME/Documents/ymirhome}"
OUT="$HOME_DIR/hodd/machines/$HOST"
REPO="${YMIR_REPO:-$HOME/ymir}"
mkdir -p "$OUT"

{ printf 'host: %s\ntracked: %s\n' "$HOST" "$(date -u +%FT%TZ)"; "$REPO/bin/records/tunnels-status.sh" --yaml 2>/dev/null; } > "$OUT/tunnels.yaml"
{ printf 'host: %s\ntracked: %s\n' "$HOST" "$(date -u +%FT%TZ)"; "$REPO/bin/records/agents-status.sh" --yaml 2>/dev/null; } > "$OUT/agents.yaml"
{ printf 'host: %s\ntracked: %s\n' "$HOST" "$(date -u +%FT%TZ)"; "$REPO/bin/records/cron-registry.sh" --yaml 2>/dev/null; } > "$OUT/cron.yaml"

ok=$(grep -oE 'http: "[23][0-9]{2}"' "$OUT/tunnels.yaml" 2>/dev/null | wc -l)
broken=$(grep -oE 'http: "5[0-9]{2}"' "$OUT/tunnels.yaml" 2>/dev/null | wc -l)
down=$(grep -oE 'http: "(000|530)"' "$OUT/tunnels.yaml" 2>/dev/null | wc -l)
agents=$(grep -c '  - pane:' "$OUT/agents.yaml" 2>/dev/null || echo 0)
missing=$(grep -c 'script: missing' "$OUT/cron.yaml" 2>/dev/null || echo 0)
printf 'registries: %s — %s public names: %s answering · %s broken (5xx, upstream dead) · %s unreachable · %s agents · %s cron rows with a missing script\n' \
  "$HOST" "$((ok+broken+down))" "$ok" "$broken" "$down" "$agents" "$missing"
