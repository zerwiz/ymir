#!/usr/bin/env bash
# crash-sense.sh — surface machine crashes to the Allfather on Omarchy.
#
# A crash nobody sees is a crash nobody fixes. This watches systemd-coredump for
# NEW crashes since the last look, records each one, and raises an Omarchy desktop
# notification so the Allfather learns about it the moment it happens.
#
# It is a sensor: it reads coredumpctl and notifies. It never fixes, deletes, or
# changes anything on the machine.
#
# Usage:
#   bin/crash-sense.sh check [--quiet] [--no-notify]
#   bin/crash-sense.sh status
#   bin/crash-sense.sh --version
#
# State: state/crash-seen.json  (gitignored — per machine)
# Output: Galdr TOON.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="${BROKK_STATE_OVERRIDE:-$ROOT/state}"
SEEN="$STATE_DIR/crash-seen.json"
QUIET=0; NOTIFY=1

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-check}"; shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    --no-notify) NOTIFY=0; shift ;;
    *) shift ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
have coredumpctl || { printf 'crash-sense[1]{state,detail}:\n  "skip","no coredumpctl (not a systemd host)"\n'; exit 0; }

# Collect recent crashes as: <boot-id>|<pid>|<comm>|<sig>|<time>
collect() {
  coredumpctl list --no-pager --since "7 days ago" 2>/dev/null \
    | awk 'NR>1 && NF>=5 {print $NF"|"$5"|"$1" "$2" "$3}' \
    | head -200
}

# Use a stable identity for a crash: the executable name + pid + signal.
fingerprints() {
  coredumpctl list --no-pager --since "7 days ago" 2>/dev/null | awk 'NR>1 {print $NF"|"$1"|"$2"|"$3"|"$4"|"$5}' | head -200
}

notify() {  # <headline> <body> [urgency]
  local h="$1" b="$2" u="${3:-normal}"
  [ "$NOTIFY" = 1 ] || return 0
  if have omarchy-notification-send; then
    omarchy-notification-send -u "$u" -g "" "$h" "$b" >/dev/null 2>&1 || true
  elif have notify-send; then
    notify-send -u "$u" "$h" "$b" >/dev/null 2>&1 || true
  fi
}

case "$ACTION" in
  check)
    mkdir -p "$STATE_DIR"
    local_prev="{}"
    [ -r "$SEEN" ] && local_prev="$(cat "$SEEN")"

    # New fingerprints = anything not in the seen set.
    new_rows="$(python3 - "$SEEN" <<'PY'
import json, os, subprocess, sys
seen_path = sys.argv[1]
seen = set()
if os.path.exists(seen_path):
    try:
        seen = set(json.load(open(seen_path)).get("fingerprints", []))
    except Exception:
        seen = set()
out = subprocess.run(["coredumpctl", "list", "--no-pager", "--since", "7 days ago"],
                     capture_output=True, text=True).stdout.splitlines()[1:]
new = []
all_fp = []
for line in out:
    parts = line.split()
    if len(parts) < 5:
        continue
    # TIME is 3 tokens (date, clock, tz); then PID UID GID SIG COREFILE EXE
    date, clock, tz = parts[0], parts[1], parts[2]
    rest = parts[3:]
    pid = rest[0] if rest else "?"
    comm = os.path.basename(rest[-1]) if rest else "?"
    sig = rest[3] if len(rest) > 3 else "?"
    fp = f"{pid}|{comm}|{sig}|{date} {clock}"
    all_fp.append(fp)
    if fp not in seen:
        new.append({"pid": pid, "comm": comm, "sig": sig, "when": f"{date} {clock}", "fp": fp})
print(json.dumps({"new": new, "all": all_fp}))
PY
)"
    count="$(printf '%s' "$new_rows" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["new"]))' 2>/dev/null || echo 0)"

    if [ "$count" -gt 0 ]; then
      # One notification per crash, newest first, capped so we never spam.
      printf '%s' "$new_rows" | python3 -c '
import json, sys
d = json.load(sys.stdin)["new"]
for c in d[-3:]:
    print(c["comm"] + "\t" + c["sig"] + "\t" + c["when"] + "\t" + c["pid"])
' | while IFS=$'\t' read -r comm sig when pid; do
        notify "Process crashed: $comm" "$sig at $when (pid $pid) — run bin/crash-sense.sh status, or ask Brokk to diagnose." "critical"
      done
    fi

    # Persist the union as the new seen set (feed the captured string, not a pipe).
    printf '%s' "$new_rows" >"$STATE_DIR/.crash-new.json"
    python3 - "$SEEN" "$STATE_DIR/.crash-new.json" <<'PY'
import json, sys, tempfile, os, datetime
path, src = sys.argv[1], sys.argv[2]
d = json.load(open(src))
payload = {
    "fingerprints": d["all"],
    "updated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".")
with os.fdopen(fd, "w") as f:
    json.dump(payload, f, indent=2)
os.replace(tmp, path)
PY
    rm -f "$STATE_DIR/.crash-new.json"

    [ "$QUIET" = 1 ] && exit 0
    printf 'crash-sense[1]{new_crashes,notified,since}:\n  %s,"%s","7 days"\n' "$count" "$([ "$count" -gt 0 ] && echo yes || echo no)"
    if [ "$count" -gt 0 ]; then
      printf '%s' "$new_rows" | python3 -c '
import json, sys
for c in json.load(sys.stdin)["new"][-5:]:
    print(f'"'"'  "{c["comm"]}","{c["sig"]}","{c["when"]}","pid {c["pid"]}"'"'"')
' 2>/dev/null | sed '1i crashes[]:' || true
    fi
    ;;

  status)
    if have coredumpctl; then
      total="$(coredumpctl list --no-pager --since "7 days ago" 2>/dev/null | awk 'NR>1' | wc -l | tr -d ' ')"
      printf 'crash-sense[1]{window,total_crashes,state_file}:\n  "7 days",%s,"%s"\n' "$total" "${SEEN#"$ROOT"/}"
      coredumpctl list --no-pager --since "7 days ago" 2>/dev/null | awk 'NR>1 {print $NF}' | sort | uniq -c | sort -rn | head -5 | \
        awk '{printf "  \"%s\",%s\n", $2, $1}'
    fi
    ;;
  *) printf 'error: unknown action %s\nhelp: bin/crash-sense.sh [check|status]\n' "$ACTION" >&2; exit 2 ;;
esac
