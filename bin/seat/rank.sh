#!/usr/bin/env bash
# rank.sh — ask a jev judge to score items on jev's three categories.
#
#   printf '[{"id":"a","text":"..."}]' | bin/seat/rank.sh
#   bin/seat/rank.sh --door jev-kev-4b  < items.json
#
# WHAT IT DOES AND DOES NOT DO. It is TRANSPORT: it posts one `score` question per
# category (hype · facts · signal) to a decision door and returns the engine's RAW
# answers. It does not turn them into a number — the ranking policy is jev's
# (`apps/odrerir/src/vendor/jev/policy.ts`), and the gate applies it. A second copy of
# jev's thresholds here would be exactly the second table this house refuses.
#
# FAIL-CLOSED. No door up means `{"error": ...}` and no scores at all: a card with no
# classification must say so, never invent a figure to fill the slot.
#
# The door is chosen by being UP, in this order (measured 2026-11-09, the dev machine):
#   $JEV_RANK_DOOR            the operator's word
#   jev-laya                  1.77 decisions/sec, and RIGHT on the money case (billing 0.83)
#   jev-kev-4b                the authority (billing 0.99) but 0.21/sec — a 20-card page
#                             would take 95 s, so it is the ESCALATION judge, not the default
#   jev-julia-1               fastest (7.86/sec) and WRONG on that same case (shipping 0.85)
# The answer names which door spoke, so a score can always be traced to its judge.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_DIR 2>/dev/null || { printf '%s: the home is unresolved\n' "$(basename "$0")" >&2; exit 2; }

WANT="${JEV_RANK_DOOR:-}"          # the env override the header promises, and it really works
[ "${1-}" = "--door" ] && { WANT="${2-}"; shift 2 || true; }
ITEMS="$(cat)"

python3 - "$ROOT" "$HOME_DIR" "$WANT" "$ITEMS" <<'PY'
import json, os, subprocess, sys

root, home, want, raw = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    items = json.loads(raw)
except Exception:
    print(json.dumps({"error": "rank: stdin is not a JSON array of {id,text}"}))
    raise SystemExit(0)
if not isinstance(items, list) or not items:
    print(json.dumps({"error": "rank: nothing to rank"}))
    raise SystemExit(0)

doors_sh = os.path.join(root, "bin/model/jev-doors.sh")

def up_doors():
    try:
        out = subprocess.run(["bash", doors_sh, "list", "--json"], capture_output=True, text=True, timeout=25).stdout
        d = json.loads(out)
        return [x for x in d.get("doors", []) if x.get("state") == "up"]
    except Exception:
        return []

def pick():
    if want:
        return want
    names = [d["id"] for d in up_doors()]
    for preference in ("jev-laya", "jev-kev-4b", "jev-julia-1"):
        if preference in names:
            return preference
    return names[0] if names else ""

door = pick()
if not door:
    print(json.dumps({"error": "rank: no decision door is up — nothing is scored, and the cards say so"}))
    raise SystemExit(0)

# The score wire: `criteria` is the legend, 2..10 levels (learned from the engine's own
#   refusal: `"criteria" must be an array of 2 to 10 levels`).
LEGEND = ["none", "slight", "some", "strong", "extreme"]
QUESTIONS = {
    "hype": {"type": "score", "criteria": LEGEND,
             "instructions": "how much unearned excitement is here — claims without proof?"},
    "facts": {"type": "score", "criteria": LEGEND,
              "instructions": "how much is checkable evidence — numbers, methods, sources?"},
    "signal": {"type": "score", "criteria": LEGEND,
               "instructions": "how much does this actually matter to the work?"},
}

key = ""
try:
    env = subprocess.run(["bash", os.path.join(root, "bin/vault/hodd.sh"), "emit", "secrets/platform.env"],
                         capture_output=True, text=True, timeout=20).stdout
    for line in env.splitlines():
        if line.startswith("export LLAMA_SWAP_API_KEY="):
            key = line.split("=", 1)[1].strip().strip('"').strip("'")
            break
except Exception:
    pass

base = subprocess.run(["bash", doors_sh, "url", door], capture_output=True, text=True, timeout=15).stdout.strip()
if not base:
    print(json.dumps({"error": f"rank: no reachable door for {door}"}))
    raise SystemExit(0)

answers, failed = {}, []
for it in items:
    if not isinstance(it, dict):
        continue
    ident = str(it.get("id") or "")
    text = str(it.get("text") or "").strip()
    if not ident or not text:
        continue
    body = json.dumps({"state": text[:2000], "questions": QUESTIONS})
    r = subprocess.run(["curl", "-s", "-m", "30", "-X", "POST", base,
                        "-H", "content-type: application/json",
                        "-H", f"Authorization: Bearer {key}", "-d", body],
                       capture_output=True, text=True)
    try:
        d = json.loads(r.stdout or "{}")
    except Exception:
        failed.append(ident); continue
    a = d.get("answers") or {}
    if not all(k in a and a[k].get("type") == "score" for k in ("hype", "facts", "signal")):
        failed.append(ident); continue
    answers[ident] = {k: a[k] for k in ("hype", "facts", "signal")}

print(json.dumps({"door": door, "answers": answers, "failed": failed}))
PY
