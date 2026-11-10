#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/pr-patterns.sh"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
role=""; house=""; fleet=""; errand=""; authority=""; proves=""; title=""; bodyfile=""; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --role) role="$2"; shift 2;;
    --house) house="$2"; shift 2;;
    --fleet) fleet="$2"; shift 2;;
    --errand) errand="$2"; shift 2;;
    --authority) authority="$2"; shift 2;;
    --proves) proves="$2"; shift 2;;
    --title) title="$2"; shift 2;;
    --body-file) bodyfile="$2"; shift 2;;
    --dry-run) dry=1; shift;;
    *) echo "unknown flag $1" >&2; exit 2;;
  esac
done
body="${bodyfile:+$(cat "$bodyfile")}"
sig="house: $house
fleet: $fleet
agent: $role (role: ship, errand: $errand)
authority: $authority
proves: $proves
never: a hostname, a tailnet or LAN address, a pane id, a home path, a mailbox, a token"
full="$sig"
[ -n "$body" ] && full="$sig

$body"
# check forbidden patterns
tmp=$(mktemp); printf '%s\n' "$full" > "$tmp"
if m=$(pr_pattern_match "$tmp"); then
  rm -f "$tmp"; echo "refused: $m" >&2; exit 3
fi
rm -f "$tmp"
if [ "$dry" = 1 ]; then
  printf '%s\n' "$full"; echo "DRY RUN OK"; exit 0
fi
printf '%s\n' "$full" > /tmp/pr-body.$$.md
url=$(gh pr create --title "$title" --body-file /tmp/pr-body.$$.md)
rm -f /tmp/pr-body.$$.md
echo "$url"
