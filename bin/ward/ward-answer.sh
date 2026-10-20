#!/usr/bin/env bash
# ward-answer.sh — answer a ward decision. close · keep (with a reason) · plan.
#
# The ask door writes questions; this door records the answer so the same finding is
# not asked again. `keep` REQUIRES a reason: RULES/24 says a door is named, or it is
# closed. `close` records the intent and prints the exact command — this door does
# not run the mend; harden.sh does, and the firewall stays the operator's act.
#
# Usage:
#   ward-answer.sh list
#   ward-answer.sh answer <WARD-ID> close|keep|plan ["reason"]
#
# Exit: 0 recorded · 1 unknown id · 2 usage · 3 keep without a reason
set -u
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$SCRIPT_DIR/../vault/hoard-lib.sh" 2>/dev/null || true; fi
HOME_DIR=""; [ -n "${YMIR_HOME:-}" ] && HOME_DIR="$YMIR_HOME"
[ -n "$HOME_DIR" ] || { command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR; }
[ -n "$HOME_DIR" ] || { printf 'error: YMIR_HOME unresolved\n' >&2; exit 1; }
WARD_DIR="$HOME_DIR/hodd/memory/ward"; mkdir -p "$WARD_DIR"
ANSWERS="$WARD_DIR/answers.yaml"
AUDIT="$(bash "$SCRIPT_DIR/security-audit.sh" check 2>/dev/null)" || true

python3 - "$AUDIT" "$ANSWERS" "$@" <<'PY'
import sys, re, yaml, datetime
audit, answers_path = sys.argv[1], sys.argv[2]
args = sys.argv[3:]
cmd = args[0] if args else "list"
try: store = yaml.safe_load(open(answers_path)) or {"answers": {}}
except Exception: store = {"answers": {}}
answers = store.setdefault("answers", {})

def decisions():
    rows = []
    for line in audit.splitlines():
        m = re.match(r'\s*"(CRITICAL|HIGH|MEDIUM|LOW)","([^"]*)","([^"]*)","([^"]*)"', line)
        if m: rows.append({"severity": m.group(1), "what": m.group(2), "detail": m.group(3), "remedy": m.group(4)})
    out, seen = [], set()
    for r in rows:
        if r["severity"] not in ("HIGH", "CRITICAL"): continue
        key = f'{r["what"]}|{r["detail"]}'
        if key in seen: continue
        seen.add(key); r["key"] = key; out.append(r)
    for i, r in enumerate(out, 1):
        r["id"] = f"WARD-{datetime.date.today().strftime('%Y%m%d')}-{i:02d}"
    return out

def pending():
    return [d for d in decisions() if answers.get(d["key"], {}).get("status") not in ("close", "keep")]

if cmd == "list":
    ps = pending()
    print(f"ward-answer[{len(ps)}]{{id,severity,what,state}}:")
    for d in ps:
        st = answers.get(d["key"], {}).get("status", "open")
        print(f'  "{d["id"]}","{d["severity"]}","{d["what"].replace(chr(34),chr(39))}","{st}"')
    sys.exit(0)

if cmd == "answer":
    if len(args) < 3: print("usage: ward-answer.sh answer <ID> close|keep|plan [reason]", file=sys.stderr); sys.exit(2)
    wid, status = args[1], args[2]
    reason = " ".join(args[3:]).strip()
    d = next((x for x in decisions() if x["id"] == wid), None)
    if not d: print(f"error: unknown decision {wid} (run: ward-answer.sh list)", file=sys.stderr); sys.exit(1)
    if status not in ("close", "keep", "plan"):
        print("error: status must be close|keep|plan", file=sys.stderr); sys.exit(2)
    if status == "keep" and not reason:
        print("error: keep requires a reason — a door is named, or it is closed (RULES/24)", file=sys.stderr); sys.exit(3)
    answers[d["key"]] = {"id": wid, "status": status, "reason": reason,
                          "at": datetime.datetime.now().astimezone().isoformat(timespec="seconds")}
    yaml.safe_dump(store, open(answers_path, "w"), sort_keys=True)
    print(f"answered\t{wid}\t{status}\t{reason or ''}")
    if status == "close": print(f"mend\t{d['remedy']}")
    sys.exit(0)

print("usage: ward-answer.sh list | answer <ID> close|keep|plan [reason]", file=sys.stderr); sys.exit(2)
PY
