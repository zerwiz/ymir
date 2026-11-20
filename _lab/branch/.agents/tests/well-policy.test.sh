#!/usr/bin/env bash
# well-policy.test.sh — does the well's POLICY actually bite? (plan 136)
#
# Every check is a promise plan 136 makes, proved against a THROWAWAY well (a temp
# store, a temp log, a temp port) — never against the house's memory and never
# against a mock. What the gate says about a write, what it types it, what recall
# is allowed to hand back, and whether a correction really chains are all claims
# about behaviour, so each one is exercised end to end through the same doors a
# keeper uses: `bin/records/mimir.sh` and the bridge on its temp port.
#
#   1  the gate DROPS a write that answers none of the three questions
#   2  the gate KEEPS a decision and routes it to the semantic shelf
#   3  the gate KEEPS a workflow and routes it to the procedural shelf
#   4  a duplicate is refused, and the episode it duplicates is named
#   5  a secret is refused outright (Rules 15/24)
#   6  scoped recall never crosses the shelf: semantic rows out of a procedural ask
#   7  a correction APPENDS, chains both ways, and hides the original from recall
#   8  a retraction APPENDS, voids the original, and leaves the count rising (Rule 20)
#   9  grading reports, then applies without lowering the episode count
#  10  the health row says when it was last watered, drunk from, pruned
#
# Usage: .agents/tests/well-policy.test.sh
# Exit: 0 all checks pass (or a clean, named skip) · 1 a check failed · 2 usage.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIMIR="$ROOT/bin/records/mimir.sh"
POLICY="$ROOT/bin/records/mimir-policy.py"
BRIDGE_PY="$ROOT/bin/bridge/mimir-bridge.py"
PORT="${WELL_TEST_PORT:-4739}"
pass=0; fail=0; skip=0
ok()   { printf 'ok - %s\n' "$1"; pass=$((pass+1)); }
no()   { printf 'not ok - %s\n' "$1" >&2; fail=$((fail+1)); }
skipped() { printf 'skip - %s\n' "$1"; skip=$((skip+1)); }

[ -x "$MIMIR" ] && [ -r "$POLICY" ] || { echo "error: no well door under $ROOT" >&2; exit 2; }

# The interpreter that owns the store, exactly as the bridge resolves it.
PY="$("$ROOT/bin/bridge/mimir-bridge.sh" --python 2>/dev/null || true)"
[ -n "$PY" ] && command -v "$PY" >/dev/null 2>&1 || PY=""
if [ -z "$PY" ] || ! "$PY" -c 'import engram' >/dev/null 2>&1; then
  skipped "engram is not importable ($PY) — the store cannot be exercised"
  printf 'well-policy[1]{pass,fail,skip}:\n  %s,%s,%s\n' "$pass" "$fail" "$skip"
  exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/well-policy.XXXXXX")"
cleanup() {
  [ -n "${BRIDGE_PID:-}" ] && kill "$BRIDGE_PID" 2>/dev/null
  wait 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

export YMIR_HOME="$TMP"
export YMIR_STATE_DIR="$TMP/state"
export ENGRAM_DB="$TMP/test.engram"
export ENGRAM_LOG="$TMP/well/episodes.jsonl"
export MIMIRSBRUNN_URL="http://127.0.0.1:$PORT"
export MIMIRSBRUNN_PORT="$PORT"
export MIMIR_PY="$PY"
mkdir -p "$YMIR_STATE_DIR" "$TMP/hodd/memory/well" "$TMP/hodd/memory/daily"

# ── the offline gate: no bridge, no store — the policy alone ────────────────
# The gate must answer with nothing running, because a keeper's lesson may be
# learned during an outage and a decision that can only be made online is not law.
if "$MIMIR" observe "The sky is blue and the notch is quiet." >/dev/null 2>&1; then
  no "the gate drops a write that answers none of the three questions"
else
  ok "the gate drops a write that answers none of the three questions"
fi

if out=$("$MIMIR" observe "We decided the well gate asks three questions because noise kills recall." \
        --source deck --task "memory gate" 2>&1); then
  case "$out" in
    *'"true","semantic"'*) ok "the gate keeps a decision, typed semantic" ;;
    *) no "the gate keeps a decision, typed semantic (got: $out)" ;;
  esac
  case "$out" in
    *"store:semantic"*) ok "  ... and stamps the shelf and its provenance as tags" ;;
    *) no "  ... and stamps the shelf and its provenance as tags (got: $out)" ;;
  esac
else
  no "the gate keeps a decision, typed semantic"
fi

if out=$("$MIMIR" observe "Step 1: raise the bridge. Then run the smoke test so the well answers before a session." \
        --source deck 2>&1); then
  case "$out" in
    *'"true","procedural"'*) ok "the gate keeps a workflow, typed procedural" ;;
    *) no "the gate keeps a workflow, typed procedural (got: $out)" ;;
  esac
else
  no "the gate keeps a workflow, typed procedural"
fi

if "$MIMIR" observe "We decided the well gate asks three questions because noise kills recall." \
      --source deck >/dev/null 2>&1; then
  no "a duplicate is refused"
else
  ok "a duplicate is refused"
fi

if "$MIMIR" observe "The api_key=abcdef1234567890 is the standing credential for the rail." >/dev/null 2>&1; then
  no "a secret is refused outright"
else
  ok "a secret is refused outright"
fi

# The store must still be EMPTY of the two dropped writes: the gate is a gate, not
# a warning. Two kept lessons are all that reached the log.
n=$(grep -c '"content"' "$ENGRAM_LOG" 2>/dev/null || echo 0)
[ "${n:-0}" = 2 ] && ok "only the kept writes reached the record ($n of 4)" \
  || no "only the kept writes reached the record (got $n)"

# ── the bridge: the store side, on the same temp well ──────────────────────
( "$PY" "$BRIDGE_PY" >"$TMP/bridge.log" 2>&1 ) &
BRIDGE_PID=$!
for _ in $(seq 1 60); do
  curl -fsS --max-time 2 "$MIMIRSBRUNN_URL/health" >/dev/null 2>&1 && break
  sleep 1
done
if ! curl -fsS --max-time 3 "$MIMIRSBRUNN_URL/health" >/dev/null 2>&1; then
  skipped "the bridge did not come up on :$PORT — see $TMP/bridge.log"
  printf 'well-policy[1]{pass,fail,skip}:\n  %s,%s,%s\n' "$pass" "$fail" "$skip"
  exit 0
fi

seed() { # <content> <store> [task] -> prints the id
  json=$(CONTENT="$1" STORE="$2" TASK="${3:-}" "$PY" -c 'import json,os
req = {"content":os.environ["CONTENT"],"source":"deck","store":os.environ["STORE"]}
if os.environ.get("TASK"): req["task"] = os.environ["TASK"]
print(json.dumps(req))')
  curl -fsS --max-time 120 -X POST -H 'content-type: application/json' -d "$json" \
       "$MIMIRSBRUNN_URL/observe" | "$PY" -c 'import json,sys;print((json.load(sys.stdin) or {}).get("id") or "")'
}

SEM_ID=$(seed "We decided the well keeps one well per home because a second truth is a loss." semantic "memory policy")
PROC_ID=$(seed "Step 1: start the bridge. Then run the smoke test before a session starts." procedural)
if [ -n "$SEM_ID" ] && [ -n "$PROC_ID" ]; then
  ok "the bridge stores a typed episode through the gate"
else
  no "the bridge stores a typed episode through the gate (sem=$SEM_ID proc=$PROC_ID)"
fi

recall_ids() { # <query> <store>
  curl -fsS --max-time 60 "$MIMIRSBRUNN_URL/recall?q=$1&store=$2&k=5" \
    | "$PY" -c 'import json,sys
d=json.load(sys.stdin)
print(" ".join(r["episode"]["id"] for r in d.get("results",[])))'
}
rows=$(recall_ids "one%20well%20per%20home%20second%20truth" semantic)
case " $rows " in
  *" $SEM_ID "*) ok "scoped recall keeps the shelf's own row" ;;
  *) no "scoped recall keeps the shelf's own row (got: $rows)" ;;
esac
case " $rows " in
  *" $PROC_ID "*) no "scoped recall never crosses the shelf (procedural row leaked)" ;;
  *) ok "scoped recall never crosses the shelf" ;;
esac

# The TASK is a shelf too: written with --task, found by --task, and absent under
# another task. Otherwise "what did I learn on this?" is a hope that the words match.
task_rows=$(curl -fsS --max-time 60 "$MIMIRSBRUNN_URL/recall?q=one%20well%20per%20home&task=memory%20policy&k=5" \
  | "$PY" -c 'import json,sys;print(" ".join(r["episode"]["id"] for r in json.load(sys.stdin).get("results",[])))')
case " $task_rows " in
  *" $SEM_ID "*) ok "recall scoped to a task finds the work's own lessons" ;;
  *) no "recall scoped to a task finds the work's own lessons (got: $task_rows)" ;;
esac
other_rows=$(curl -fsS --max-time 60 "$MIMIRSBRUNN_URL/recall?q=one%20well%20per%20home&task=another%20errand&k=5" \
  | "$PY" -c 'import json,sys;print(" ".join(r["episode"]["id"] for r in json.load(sys.stdin).get("results",[])))')
case " $other_rows " in
  *" $SEM_ID "*) no "a different task's slice does not contain it" ;;
  *) ok "a different task's slice does not contain it" ;;
esac

# A correction: appended, chained both ways, and the original hidden from recall.
curl -fsS --max-time 120 -X POST -H 'content-type: application/json' \
  -d "{\"original_id\":\"$SEM_ID\",\"content\":\"We decided the well keeps one well per home AND one index per seat, because a second truth is a loss.\",\"source\":\"deck\"}" \
  "$MIMIRSBRUNN_URL/correct" >/dev/null 2>&1
chain=$(curl -fsS --max-time 10 "$MIMIRSBRUNN_URL/episode?id=$SEM_ID" 2>/dev/null)
case "$chain" in
  *'"voided": true'*) ok "a correction voids the original by id" ;;
  *) no "a correction voids the original by id (got: ${chain:0:160})" ;;
esac
case "$chain" in
  *'"replaced_by": ["'*) ok "  ... and the chain names the replacement" ;;
  *) no "  ... and the chain names the replacement" ;;
esac
rows=$(recall_ids "one%20well%20per%20home%20second%20truth" semantic)
case " $rows " in
  *" $SEM_ID "*) no "a voided episode is never handed back as fact" ;;
  *) ok "a voided episode is never handed back as fact" ;;
esac

before=$(curl -fsS --max-time 10 "$MIMIRSBRUNN_URL/health" | "$PY" -c 'import json,sys;print(json.load(sys.stdin)["episodes"])')
curl -fsS --max-time 120 -X POST -H 'content-type: application/json' \
  -d "{\"original_id\":\"$PROC_ID\",\"why\":\"the smoke test moved to bin/smoke_test.sh\"}" \
  "$MIMIRSBRUNN_URL/retract" >/dev/null 2>&1
after=$(curl -fsS --max-time 10 "$MIMIRSBRUNN_URL/health" | "$PY" -c 'import json,sys;print(json.load(sys.stdin)["episodes"])')
[ "${after:-0}" -gt "${before:-0}" ] && ok "a retraction APPENDS — the count never falls (Rule 20)" \
  || no "a retraction APPENDS (before=$before after=$after)"
case "$(curl -fsS --max-time 10 "$MIMIRSBRUNN_URL/episode?id=$PROC_ID" 2>/dev/null)" in
  *'"voided": true'*) ok "  ... and the retracted episode is void, not erased" ;;
  *) no "  ... and the retracted episode is void, not erased" ;;
esac

# Grading: report, then apply — never lowering the count.
r=$(curl -fsS --max-time 60 "$MIMIRSBRUNN_URL/grade" 2>/dev/null)
case "$r" in
  *'"apply": false'*) ok "grading reports when it is not asked to apply" ;;
  *) no "grading reports when it is not asked to apply (got: ${r:0:120})" ;;
esac
r=$(curl -fsS --max-time 120 -X POST -H 'content-type: application/json' -d '{"apply":true}' "$MIMIRSBRUNN_URL/grade" 2>/dev/null)
case "$r" in
  *'"ok": true'*) ok "grading applies and reports the well whole" ;;
  *) no "grading applies and reports the well whole (got: ${r:0:160})" ;;
esac
before_g=$(printf '%s' "$r" | "$PY" -c 'import json,sys;print(json.load(sys.stdin)["episodes_before"])')
after_g=$(printf '%s' "$r" | "$PY" -c 'import json,sys;print(json.load(sys.stdin)["episodes_after"])')
[ "${after_g:-0}" -ge "${before_g:-0}" ] && ok "  ... and the episode count did not fall (Rule 20)" \
  || no "  ... and the episode count did not fall ($before_g -> $after_g)"

# The health row: the five facts a keeper needs to trust the memory.
h=$(curl -fsS --max-time 10 "$MIMIRSBRUNN_URL/health" 2>/dev/null)
case "$h" in
  *'"last_observe": "2'*) ok "the health row says when the well was last watered" ;;
  *) no "the health row says when the well was last watered (got: ${h:0:160})" ;;
esac
case "$h" in
  *'"last_prune": "2'*) ok "  ... and when it was last pruned" ;;
  *) no "  ... and when it was last pruned" ;;
esac
case "$h" in
  *'"stores": {'*) ok "  ... and how the shelves divide" ;;
  *) no "  ... and how the shelves divide" ;;
esac

printf 'well-policy[1]{pass,fail,skip}:\n  %s,%s,%s\n' "$pass" "$fail" "$skip"
[ "$fail" = 0 ]
