#!/usr/bin/env bash
# inbox-watch.sh — notice when someone answers, without a human opening a mail client.
#
# Snotra's cron syncs MEETING mail. This watches the PEOPLE: every collaborator or client
# with an address and consent, once a run, for new messages from them. A new one is written
# to Runes, spoken on the desktop, and (above the phone threshold) sent to the pocket.
#
#   bin/people/inbox-watch.sh [--days 3] [--dry-run] [--quiet]
#
# State: $YMIR_HOME/hodd/state/people/inbox-seen.json — message ids already announced, so a
# reply is announced once. Stateless otherwise: read → compare → announce → exit.
#
# Exit: 0 ok (including "nothing new") · 1 a surface could not be read · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'error: the home is unresolved\n' >&2; exit 1; }

DAYS=3; DRY=0; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="${2:-3}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

REG="$HOME_R/hodd/identity/collaborators.yaml"
STATE_DIR="$HOME_R/hodd/state/people"
SEEN="$STATE_DIR/inbox-seen.json"
mkdir -p "$STATE_DIR" 2>/dev/null || true

[ -r "$REG" ] || { printf 'inbox-watch[1]{state}: "no collaborators registry — nothing to watch"\n'; exit 0; }

PEOPLE="$("$SCRIPT_DIR/collaborators.sh" list 2>/dev/null | tail -n +2)"
[ -n "$PEOPLE" ] || { printf 'inbox-watch[1]{state}: "no people in the registry"\n'; exit 0; }

new_count=0
printf 'inbox-watch{person,address,new}:\n'
while IFS= read -r row; do
  [ -n "$row" ] || continue
  id="$(printf '%s' "$row" | sed -E 's/^ *"([^"]*)".*/\1/')"
  status="$(printf '%s' "$row" | sed -E 's/^ *"[^"]*","[^"]*","[^"]*","([^"]*)".*/\1/')"
  emails="$(printf '%s' "$row" | sed -E 's/^ *"[^"]*","[^"]*","[^"]*","[^"]*","[^"]*","([^"]*)".*/\1/')"
  case "$status" in former) continue ;; esac
  [ -n "$emails" ] || continue
  IFS=',' read -ra ADDRS <<< "$emails"
  for addr in "${ADDRS[@]}"; do
    addr="$(printf '%s' "$addr" | tr -d ' ')"
    [ -n "$addr" ] || continue
    found="$(bash "$SCRIPT_DIR/inbox.sh" --from "$addr" --days "$DAYS" --limit 5 2>/dev/null | tail -n +2)"
    [ -n "$found" ] || continue
    while IFS= read -r msg; do
      [ -n "$msg" ] || continue
      mid="$(printf '%s' "$msg" | sed -E 's/^ *"([^"]*)".*/\1/')"
      [ -n "$mid" ] || continue
      if python3 - "$SEEN" "$mid" <<'PY'
import json, sys
path, mid = sys.argv[1], sys.argv[2]
try:
    seen = json.load(open(path))
except Exception:
    seen = {}
sys.exit(0 if mid in seen else 1)
PY
      then continue; fi
      subject="$(printf '%s' "$msg" | sed -E 's/^ *"[^"]*","[^"]*","[^"]*","([^"]*)".*/\1/')"
      new_count=$((new_count + 1))
      line="REPLY from ${id} <${addr}>: ${subject}"
      if [ "$DRY" = 0 ]; then
        bash "$ROOT/bin/records/runes-append.sh" brokk inbox --message "$line" >/dev/null 2>&1 || true
        [ "$QUIET" = 0 ] && bash "$ROOT/bin/time/snotra/ymir-say.sh" "reply from ${id}" >/dev/null 2>&1 || true
        # the pocket, through the hound's own mouth (the threshold lives in its config)
        [ -f "$ROOT/bin/ward/garmr/notify.py" ] && \
          GARMR_STATE_DIR="$HOME_R/hodd/state/garmr" python3 "$ROOT/bin/ward/garmr/notify.py" \
            --severity HIGH --line "reply from ${id}: ${subject}" >/dev/null 2>&1 || true
        python3 - "$SEEN" "$mid" <<'PY'
import json, sys
path, mid = sys.argv[1], sys.argv[2]
try:
    seen = json.load(open(path))
except Exception:
    seen = {}
seen[mid] = True
json.dump(seen, open(path, "w"))
PY
      fi
    done <<< "$found"
  done
  printf '  "%s","%s","%s"\n' "$id" "${emails}" "$(printf '%s' "$found" | grep -c . || true)"
done <<< "$PEOPLE"

if [ "$new_count" -eq 0 ]; then
  printf 'inbox-watch[1]{new,verdict}: "0","nothing new"\n'
else
  printf 'inbox-watch[1]{new,verdict}: "%s","announced%s"\n' "$new_count" "$([ "$DRY" = 1 ] && printf ' (dry run, not recorded)')"
fi
exit 0
