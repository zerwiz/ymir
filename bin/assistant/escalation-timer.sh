#!/usr/bin/env bash
# escalation-timer.sh — the fifth part of a stop rule: what happens if nobody answers.
#
#   bin/assistant/escalation-timer.sh
#
# An approval or an escalation older than four hours gets ONE reminder; older than a day it joins the
# morning digest instead of being quietly forgotten. Run every thirty minutes by a user timer.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
DIR="$HOME_R/hodd/state/notify/approvals"
DOOR="$ROOT/bin/notify/send.sh"
[ -d "$DIR" ] || { printf 'escalation-timer[1]{state}: "nothing pending"\n'; exit 0; }

ROOT_DIR="$ROOT" DIR_Q="$DIR" DOOR_Q="$DOOR" python3 - <<'PY'
import glob, json, os, subprocess, time
reminded = 0; digest = []
for path in glob.glob(os.path.join(os.environ["DIR_Q"], "*.json")):
    try:
        rec = json.load(open(path))
    except Exception:
        continue
    if rec.get("decision"):
        continue
    asked = rec.get("asked_at", "")
    try:
        age_h = (time.time() - time.mktime(time.strptime(asked[:19], "%Y-%m-%dT%H:%M:%S"))) / 3600
    except Exception:
        continue
    if age_h >= 24:
        digest.append(rec.get("question", "")[:100])
    elif age_h >= 4 and not rec.get("reminded"):
        subprocess.run(["bash", os.environ["DOOR_Q"], "--source", "assistant", "--severity", "MEDIUM",
                        "--message", f"still waiting on you ({int(age_h)}h): {rec.get('question','')[:120]}",
                        "--key", f"remind:{rec.get('id','')}"],
                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        rec["reminded"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        json.dump(rec, open(path, "w"))
        reminded += 1
print(f'escalation-timer[1]{{reminded,digest}}:"{reminded}","{len(digest)}"')
for line in digest:
    print(f'  "unanswered for a day: {line}"')
PY
