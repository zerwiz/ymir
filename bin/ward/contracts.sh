#!/usr/bin/env bash
# contracts.sh — is every system BEHAVING as it should, today, on this machine? (plan 350 part F)
#
# Eir asks "is it installed and up?"; the lore audit asks "does the page tell the truth?". This asks "does it do the
# real thing?". On 2026-11-22 the nightly renewal failed on three machines, a house unit sat `failed` on a second
# machine, and the review watcher handed the same head again and again — and every one of them was "up".
#
# A contract is one file in bin/ward/contracts.d/ (NN-name.sh). It does the real thing, read-only, and prints ONE line:
#   ok: <what was shown>      red: <what is wrong, and the command to look closer>      skip: <why it cannot be asked here>
# and exits 0 (ok/skip) or 1 (red). The runner gives each one CONTRACT_TIMEOUT_S (60) seconds; a contract that runs
# out of time is red, named as hung.
#
#   contracts.sh run [--json]          run every contract here; exit 1 when any is red
#   contracts.sh check [--notify]      run, keep <state>/contracts/<host>.json (the trouble panel's `contracts` row and
#                                      its fleet view read it), and on a contract's TURN to red hand it to the arm
#                                      holder through the Veil (a receipt); a red that stays red is not said twice
#
# The board: the trouble panel (bin/ward/trouble.sh read|fleet) carries one `contracts` row per machine. When the
# operator chooses Gatus, set GATUS_URL and GATUS_TOKEN (in the home's env, never here) and every result is also
# pushed to its external endpoint `contracts_<host>-<contract>` — one board, no second dashboard.
# Exit: 0 every contract ok or skipped · 1 one or more red · 2 usage.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
case "${1:-}" in -h|--help|'') sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
VERB=$1; shift
JSON=0; NOTIFY=0
for a in "$@"; do case "$a" in --json) JSON=1 ;; --notify) NOTIFY=1 ;; *) printf 'contracts: unknown argument %s\n' "$a" >&2; exit 2 ;; esac; done
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
H="${YMIR_HOME:-}"; [ -n "$H" ] || { declare -f ymir_home_root >/dev/null && ymir_home_root H 2>/dev/null; }
S="${YMIR_STATE_DIR:-}"; [ -n "$S" ] || { declare -f hoard_state_dir >/dev/null && hoard_state_dir S 2>/dev/null; }
export YMIR_HOME="${H:-}" YMIR_STATE="${S:-${H:-}/state}" YMIR_ROOT="$ROOT"
DIR="${CONTRACTS_DIR:-$SCRIPT_DIR/contracts.d}"
host="${CONTRACTS_HOST:-$(hostname -s 2>/dev/null || uname -n)}"

measure() {  # → JSON lines {contract, state, line, seconds}
  local f name out rc t0 state
  for f in "$DIR"/*.sh; do
    [ -r "$f" ] || continue
    name="$(basename "$f" .sh)"; name="${name#[0-9][0-9]-}"
    t0=$SECONDS
    out="$(cd "$ROOT" && timeout "${CONTRACT_TIMEOUT_S:-60}" bash "$f" </dev/null 2>&1)"; rc=$?
    out="$(printf '%s\n' "$out" | tail -n 1)"
    case "$rc:$out" in
      124:*) state=red; out="red: the contract hung (over ${CONTRACT_TIMEOUT_S:-60}s)" ;;
      *:ok:*) state=ok ;;
      *:skip:*) state=skip ;;
      *) state=red; case "$out" in red:*) ;; *) out="red: ${out:-no answer} (exit $rc)" ;; esac ;;
    esac
    python3 -c 'import json,sys; print(json.dumps({"contract":sys.argv[1],"state":sys.argv[2],"line":sys.argv[3],"seconds":int(sys.argv[4])}))' \
      "$name" "$state" "$out" "$((SECONDS - t0))"
  done
}

push_gatus() {  # <name> <ok:true|false> <error> <seconds>
  [ -n "${GATUS_URL:-}" ] && [ -n "${GATUS_TOKEN:-}" ] || return 0
  local key; key="$(printf 'contracts_%s-%s' "$host" "$1" | tr -c 'A-Za-z0-9_\n' '-')"
  curl -s -o /dev/null --max-time 10 -X POST -H "Authorization: Bearer $GATUS_TOKEN" \
    "${GATUS_URL%/}/api/v1/endpoints/$key/external?success=$2&error=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$3")&duration=${4}s" || true
}

rows="$(measure)"
case "$VERB" in
  run)
    if [ "$JSON" = 1 ]; then printf '%s\n' "$rows"
    else
      printf 'contracts[%s]{host,contract,state,line}:\n' "$(printf '%s\n' "$rows" | grep -c .)"
      printf '%s\n' "$rows" | python3 -c '
import json, sys
for l in sys.stdin:
    if l.strip():
        r = json.loads(l); print("  \"%s\",\"%s\",\"%s\",\"%s\"" % (sys.argv[1], r["contract"], r["state"], r["line"].replace("\"", "'"'"'")))' "$host"
    fi ;;
  check)
    d="$YMIR_STATE/contracts"; mkdir -p "$d"
    turned="$(python3 - "$d/$host.json" "$host" "$rows" <<'PY'
import json, os, sys, time
path, host, rows = sys.argv[1], sys.argv[2], [json.loads(l) for l in sys.argv[3].splitlines() if l.strip()]
try:
    before = {r["contract"]: r["state"] for r in json.load(open(path)).get("contracts", [])}
except Exception:
    before = {}
for r in rows:
    if r["state"] == "red" and before.get(r["contract"]) != "red":
        print(f'{r["contract"]}: {r["line"]}')
tmp = path + ".tmp"
json.dump({"host": host, "ts": int(time.time()), "contracts": rows}, open(tmp, "w"))
os.replace(tmp, path)
PY
)"
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      r="$(printf '%s' "$l" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r["contract"], "true" if r["state"]!="red" else "false", r["seconds"], r["line"], sep="\t")')"
      IFS=$'\t' read -r n okk secs line <<<"$r"
      push_gatus "$n" "$okk" "$line" "$secs"
    done <<<"$rows"
    if [ -n "$turned" ]; then
      printf 'contracts: turned red on %s:\n%s\n' "$host" "$turned"
      if [ "$NOTIFY" = 1 ] && [ -x "$ROOT/bin/agents/veil.sh" ]; then
        timeout 120 bash "$ROOT/bin/agents/veil.sh" send --from "script the behaviour contracts ($host)" --kind finding \
          "a system is not behaving on $host — $(printf '%s' "$turned" | tr '\n' ';')" >/dev/null 2>&1 || true
      fi
    fi
    red="$(printf '%s\n' "$rows" | grep -c '"state": "red"')"
    printf 'contracts: %s red of %s on %s\n' "$red" "$(printf '%s\n' "$rows" | grep -c .)" "$host"
    [ "$red" = 0 ] || exit 1
    exit 0 ;;
  *) printf 'contracts: unknown verb %s\n' "$VERB" >&2; exit 2 ;;
esac
printf '%s\n' "$rows" | grep -q '"state": "red"' && exit 1
exit 0
