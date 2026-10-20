#!/usr/bin/env bash
# ward-ask.sh — Vörðr reports, then ASKS. A finding is not a decision.
#
# The audit measures; Vörðr writes the report; this door turns the findings into a
# short list of decisions the operator can answer. It changes nothing. Each decision
# carries: what was found, what closing it means, the exact command, and the risk of
# closing it. Silence is not consent.
#
# Usage:
#   ward-ask.sh             # print the decisions and write the dated ask
#   ward-ask.sh --speak     # also speak one line on the desktop
#   ward-ask.sh --json
#
# Exit: 0 nothing to decide · 3 decisions pending · 1 error
set -u
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;; esac
SPEAK=0; JSON=0
for a in "$@"; do case "$a" in --speak) SPEAK=1 ;; --json) JSON=1 ;; esac; done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$SCRIPT_DIR/../vault/hoard-lib.sh" 2>/dev/null || true; fi
HOME_DIR=""; [ -n "${YMIR_HOME:-}" ] && HOME_DIR="$YMIR_HOME"
[ -n "$HOME_DIR" ] || { command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR; }
[ -n "$HOME_DIR" ] || { printf 'error: YMIR_HOME unresolved\n' >&2; exit 1; }
WARD_DIR="$HOME_DIR/hodd/memory/ward"; mkdir -p "$WARD_DIR"
STAMP="$(date +%Y-%m-%d)"
OUT="$WARD_DIR/$STAMP-ask.md"
AUDIT="$(bash "$SCRIPT_DIR/security-audit.sh" check 2>/dev/null)" || true
HIGH="$(printf '%s' "$AUDIT" | grep -cE '"(HIGH|CRITICAL)"' || true)"
CRIT="$(printf '%s' "$AUDIT" | grep -c '"CRITICAL"' || true)"

python3 - "$AUDIT" "$OUT" "$STAMP" "$JSON" "$WARD_DIR/answers.yaml" <<'PY'
import sys, re, json, datetime, yaml
audit, out, stamp, as_json, answers_path = sys.argv[1:6]
try: answers = (yaml.safe_load(open(answers_path)) or {}).get("answers", {})
except Exception: answers = {}
rows = []
for line in audit.splitlines():
    m = re.match(r'\s*"(CRITICAL|HIGH|MEDIUM|LOW)","([^"]*)","([^"]*)","([^"]*)"', line)
    if m: rows.append({"severity": m.group(1), "what": m.group(2), "detail": m.group(3), "remedy": m.group(4)})
# one decision per finding at HIGH or CRITICAL; medium only where a command exists
decisions = []
seen = set()
for r in rows:
    if r["severity"] not in ("HIGH", "CRITICAL"): continue
    key = f'{r["what"]}|{r["detail"]}'
    if key in seen: continue
    seen.add(key)
    if answers.get(key, {}).get("status") in ("close", "keep"): continue
    decisions.append(r)
for i, d in enumerate(decisions, 1):
    d["id"] = f"WARD-{stamp.replace('-','')}-{i:02d}"
    d["options"] = ["close it (run the command)", "keep it (write the reason)", "ask for a plan first"]
doc = [f"# Vörðr asks — {stamp}", "",
       f"{len(decisions)} decision(s): {sum(1 for d in decisions if d['severity']=='CRITICAL')} critical, "
       f"{sum(1 for d in decisions if d['severity']=='HIGH')} high.", "",
       "Nothing has been changed. Answer each: **close**, **keep** (with a reason), or **plan**.", ""]
for d in decisions:
    doc += [f"## {d['id']} — {d['what']}", "",
            f"**Found:** {d['detail']}  ",
            f"**Severity:** {d['severity']}  ",
            f"**What closing means:** {d['remedy']}  ",
            "**Options:** close · keep (write why) · plan", ""]
open(out, "w").write("\n".join(doc) + "\n")
if as_json == "1":
    print(json.dumps({"pending": len(decisions), "file": out, "decisions": decisions}, indent=2))
else:
    print(f"ward-ask[{len(decisions)}]{{id,severity,what,remedy}}:")
    for d in decisions:
        print(f'  "{d["id"]}","{d["severity"]}","{d["what"].replace(chr(34),chr(39))}","{d["remedy"].replace(chr(34),chr(39))}"')
    print(f"\nask written: {out}")
    print("answer: close · keep (with a reason) · plan — silence is not consent.")
PY

if [ "$SPEAK" = 1 ] && [ "$HIGH" -gt 0 ] && [ -x "$ROOT/bin/time/snotra/ymir-say.sh" ]; then
  "$ROOT/bin/time/snotra/ymir-say.sh" --note "Vörðr: $HIGH security decision(s) waiting — bin/ward/ward-ask.sh" >/dev/null 2>&1 || true
fi
[ "$HIGH" -eq 0 ] && exit 0 || exit 3
