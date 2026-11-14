#!/usr/bin/env bash
# tunnels-status.sh — every public name this machine publishes, whether its tunnel is up, and whether its upstream answers.
#
# A tunnel that is up while its upstream is dead publishes a 502 — worse than no tunnel, because it looks like a broken
# product rather than a retired one. This answers both halves: the process, and the far side.
#
#   tunnels-status.sh           human table
#   tunnels-status.sh --yaml    the record (for hodd/machines/<host>/running.yaml)
set -uo pipefail
CD="${CLOUDFLARED_DIR:-$HOME/.cloudflared}"
mode="${1:-table}"

pairs() {
  for cfg in "$CD"/config-*.yml "$CD"/config.yml; do
    [ -f "$cfg" ] || continue
    tunnel="$(basename "$cfg" | sed 's/^config-//;s/\.yml$//')"
    [ "$tunnel" = "config" ] && tunnel="default"
    awk -v t="$tunnel" '
      /hostname:/ {h=$NF}
      /service:/ {if (h!="") {print t"\t"h"\t"$NF; h=""}}
    ' "$cfg"
  done
}

is_up() { pgrep -f "cloudflared$" >/dev/null 2>&1 || true; }

if [ "$mode" = "--yaml" ]; then
  printf 'tunnels:\n'
  pairs | while IFS=$'\t' read -r t h svc; do
    code="$(curl -s -o /dev/null -w '%{http_code}' -m 8 "https://$h/" 2>/dev/null)"
    [ "$code" = "000" ] && state=down || state=up
    printf '  - tunnel: %s\n    hostname: %s\n    upstream: "%s"\n    http: "%s"\n    state: %s\n' \
      "$t" "$h" "$svc" "$code" "$state"
  done
  exit 0
fi

printf '%-18s %-34s %-26s %s\n' TUNNEL HOSTNAME UPSTREAM HTTP
pairs | while IFS=$'\t' read -r t h svc; do
  code="$(curl -s -o /dev/null -w '%{http_code}' -m 8 "https://$h/" 2>/dev/null)"
  note="$code"; [ "$code" = "000" ] && note="DOWN"; [ "$code" = "502" ] && note="502 (upstream dead)"
  printf '%-18s %-34s %-26s %s\n' "$t" "$h" "$(printf '%.24s' "$svc")" "$note"
done
