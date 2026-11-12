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
# A body that opens with a MERGE WITH A MERGE COMMIT banner (a gathered batch) keeps it as the
# PR's first line, above the signature, so the button's reader sees it before anything else.
case "$body" in
  "MERGE WITH A MERGE COMMIT"*)
    banner=${body%%$'\n'*}; rest=${body#"$banner"}
    full="$banner

$sig$rest" ;;
esac
# check forbidden patterns
tmp=$(mktemp); printf '%s\n' "$full" > "$tmp"
if m=$(pr_pattern_match "$tmp"); then
  rm -f "$tmp"; echo "refused: $m" >&2; exit 3
fi
rm -f "$tmp"
if [ "$dry" = 1 ]; then
  printf '%s\n' "$full"; echo "DRY RUN OK"; exit 0
fi
pbody=$(mktemp)
printf '%s\n' "$full" > "$pbody"
url=$(gh pr create --title "$title" --body-file "$pbody"); grc=$?
rm -f "$pbody"
url=$(printf '%s\n' "$url" | grep -Eo 'https://[^[:space:]]+/pull/[0-9]+' | tail -1)
# An empty URL is a failure, never a PR: gh refused, the shim refused, or nothing printed.
if [ "$grc" -ne 0 ] || [ -z "$url" ]; then
  echo "error: no pull request was opened (gh pr create exit $grc, no PR URL printed)" >&2; exit 1
fi
echo "$url"
