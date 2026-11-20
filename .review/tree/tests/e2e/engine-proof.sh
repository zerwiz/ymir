#!/usr/bin/env bash
# engine-proof.sh — the engine's proofs, runnable, not asserted (plan 58, Phase 1).
#
#   tests/e2e/engine-proof.sh proof    seat a REAL errand through the engine,
#                                      watch it, steer it, and reap it — all
#                                      four verbs, on a live box
#   tests/e2e/engine-proof.sh parity   the old door (bin/einherjar-spawn.sh) and
#                                      the engine, the same errand, the records
#                                      diffed
#
# Everything runs in a throwaway project and a throwaway home/state, so no proof
# touches the primary's records. The backend is tmux on its own session so the
# proof never disturbs a live herdr workspace.
#
# Env:
#   PROOF_HARNESS=pi          the harness the `proof` errand wears
#   PROOF_MODEL=<token>       the model; default is the first served local one
#   PROOF_WAIT=25             seconds to let the seat breathe before reap
#   PROOF_DEADLINE=90         seconds to wait for the worker's own answer
#
# Exit: 0 both proofs held · 1 a proof failed · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE="$ROOT/bin/ymir-engine.sh"
OLD_DOOR="$ROOT/bin/einherjar-spawn.sh"
SESSION="${PROOF_TMUX_SESSION:-engine-proof}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  proof|parity) ACTION="$1" ;;
  *) printf 'error: unknown verb %s\nhelp: bin/engine-proof.sh [proof|parity]\n' "$1" >&2; exit 2 ;;
esac

fail() { printf 'proof: FAIL — %s\n' "$1" >&2; exit 1; }

# --- the throwaway world -----------------------------------------------------
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-engine-proof.XXXXXX")"
cleanup() {
  for meta in "$TMP"/state/*.meta; do
    [ -f "$meta" ] || continue
    win="$(grep '^window=' "$meta" 2>/dev/null | cut -d= -f2-)"
    [ -n "$win" ] && tmux kill-window -t "$win" 2>/dev/null
  done
  tmux kill-session -t "$SESSION" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT

REPO="$TMP/repo"
mkdir -p "$REPO"
git init -q -b main "$REPO"
printf 'the engine proof stands on nothing but this tree\n' >"$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" -c user.email=proof@ymir -c user.name=proof commit -qm init

export YMIR_HOME="$TMP/home"
export BROKK_ROOT_OVERRIDE="$REPO"
export BROKK_STATE_OVERRIDE="$TMP/state"
export BROKK_DATA_OVERRIDE="$TMP/home/hodd/data"
export BROKK_CONFIG_OVERRIDE="$TMP/home/config"
export XDG_STATE_HOME="$TMP/state-root"
export BROKK_TMUX_SESSION="$SESSION"
mkdir -p "$YMIR_HOME/config" "$BROKK_STATE_OVERRIDE" "$BROKK_DATA_OVERRIDE"

brief_for() {  # <id> -> writes the brief the doors read
  local id=$1
  mkdir -p "$BROKK_DATA_OVERRIDE/$id"
  cat >"$BROKK_DATA_OVERRIDE/$id/brief.md" <<BRIEF
# Task

Write the proof artefact: print the single word seated, then stop. Change no file.

Isolation: herdr — the ordinary road (the proof raises no container)

Delivery contract: mode=local-only
BRIEF
}

first_local_model() {
  pi --list-models 2>/dev/null | awk 'NR>1 && $2 ~ /@/ { printf "%s/%s\n", $1, $2; exit }'
}

meta_value() { grep "^$2=" "$1" 2>/dev/null | tail -1 | cut -d= -f2-; }

if [ "$ACTION" = proof ]; then
  ID="engine-proof"
  HARNESS="${PROOF_HARNESS:-pi}"
  MODEL="${PROOF_MODEL:-$(first_local_model)}"
  [ -n "$MODEL" ] || fail "no served local model found (pi --list-models); set PROOF_MODEL"
  brief_for "$ID"

  printf 'proof[1]{verb,id,harness,model,backend,worktree}\n'
  printf '  "%s","%s","%s","%s","%s","%s"\n' \
    "seat" "$ID" "$HARNESS" "$MODEL" "tmux" "$REPO/.yggdrasil/$ID"

  # verb 1 — seat (the engine's own line, the door's compat shape)
  seat_out="$("$ENGINE" seat "$ID" --project "$REPO" --harness "$HARNESS" --model "$MODEL" \
      --backend tmux --mode local-only --brief "$BROKK_DATA_OVERRIDE/$ID/brief.md" --compat)" \
    || fail "seat exit $? — $seat_out"
  printf '%s\n' "$seat_out"
  META="$BROKK_STATE_OVERRIDE/$ID.meta"
  [ -f "$META" ] || fail "no record at $META"
  WIN="$(meta_value "$META" window)"
  [ -n "$WIN" ] || fail "no backend target recorded"
  tmux list-windows -a -F '#{window_id}' | grep -qx "$WIN" || fail "the recorded window $WIN is not live"

  # verb 2 — status
  state="$("$ENGINE" status "$ID")" || true
  printf 'proof[1]{verb,id,state}\n  "%s","%s","%s"\n' "status" "$ID" "$state"
  [ "$state" = "working" ] || fail "expected working at seat time, got $state"

  # the worker must actually be a live process in the worktree, not a placeholder
  sleep "${PROOF_WAIT:-25}"
  deadline=$(( $(date +%s) + ${PROOF_DEADLINE:-90} ))
  pane=""
  while [ "$(date +%s)" -lt "$deadline" ]; do
    pane="$(tmux capture-pane -p -t "$WIN" 2>/dev/null | tr -s ' \n' ' ')"
    case "$pane" in *seated*) break ;; esac
    sleep 3
  done
  printf 'proof[1]{verb,id,pane}\n  "%s","%s","%s"\n' "pane" "$ID" "$(printf '%s' "$pane" | cut -c1-400)"
  [ -n "$pane" ] || fail "the pane is empty — nothing was seated"
  case "$pane" in
    *seated*) printf 'proof[1]{verb,id,evidence}\n  "%s","%s","the worker answered the errand in its own pane"\n' "worker" "$ID" ;;
    *) fail "the worker never answered the errand inside ${PROOF_DEADLINE:-90}s — the seat is real, the errand is not" ;;
  esac

  # verb 3 — send (durable first, then the pane)
  send_out="$("$ENGINE" send "$ID" "proof: report your state and stop")" || fail "send failed"
  printf '%s\n' "$send_out"
  ls "$BROKK_STATE_OVERRIDE/$ID.inbox"/*.msg >/dev/null 2>&1 || fail "no durable message was filed"

  # verb 4 — stop (reap, and prove it took)
  stop_out="$("$ENGINE" stop "$ID")" || fail "stop reported no reap: $stop_out"
  printf '%s\n' "$stop_out"
  tmux list-windows -a -F '#{window_id}' | grep -qx "$WIN" && fail "window $WIN still stands after stop"
  tail -n1 "$BROKK_STATE_OVERRIDE/$ID.status" | grep -q '^done: stopped' || fail "no terminal line was recorded"
  printf 'proof[1]{verdict,verbs,seat,status,send,stop}\n  "PASS","4","%s","%s","%s","%s"\n' "$WIN" "$state" "filed" "reaped"
  exit 0
fi

# --- parity: the old door vs the engine, the same errand ---------------------
OLD_ID="parity-old"
NEW_ID="parity-engine"
brief_for "$OLD_ID"
brief_for "$NEW_ID"

printf 'parity[1]{side,id,door}\n  "old","%s","bin/einherjar-spawn.sh"\n  "new","%s","bin/ymir-engine.sh seat"\n' "$OLD_ID" "$NEW_ID"

# The raw-launch escape hatch is the ONE harness both doors accept identically,
# so the parity is of the SEAT ROAD (worktree, record, backend), not of a model.
# YMIR_ENGINE=off is what makes this the OLD door: without it, the adapter would
# hand the errand to the engine and there would be nothing to compare.
RAW="bash -c 'sleep 120'"
old_out="$(YMIR_ENGINE=off "$OLD_DOOR" "$OLD_ID" "$REPO" --mode local-only --backend tmux --harness "$RAW" 2>&1)" \
  || fail "the old door refused: $old_out"
printf '%s\n' "$old_out"
new_out="$("$ENGINE" seat "$NEW_ID" --project "$REPO" --harness "$RAW" --backend tmux \
    --mode local-only --brief "$BROKK_DATA_OVERRIDE/$NEW_ID/brief.md" --compat)" \
  || fail "the engine refused: $new_out"
printf '%s\n' "$new_out"

OLD_META="$BROKK_STATE_OVERRIDE/$OLD_ID.meta"
NEW_META="$BROKK_STATE_OVERRIDE/$NEW_ID.meta"
for meta in "$OLD_META" "$NEW_META"; do
  [ -f "$meta" ] || fail "no record at $meta"
done

# Every key that must agree, and the fact that both records carry the rest.
AGREE="kind mode yolo harness raw_launch harness_provenance model_local backend isolation isolation_declared force locked worth_a_smith worth_why"
PRESENT="id worktree project window launched launch_iso launch spawn_gen"
mismatch=0
for key in $AGREE; do
  old_v="$(meta_value "$OLD_META" "$key")"
  new_v="$(meta_value "$NEW_META" "$key")"
  if [ "$old_v" = "$new_v" ]; then
    printf 'parity[1]{key,old,new,verdict}\n  "%s","%s","%s","same"\n' "$key" "$old_v" "$new_v"
  else
    printf 'parity[1]{key,old,new,verdict}\n  "%s","%s","%s","DIFFERENT"\n' "$key" "$old_v" "$new_v"
    mismatch=1
  fi
done
for key in $PRESENT; do
  old_v="$(meta_value "$OLD_META" "$key")"
  new_v="$(meta_value "$NEW_META" "$key")"
  [ -n "$old_v" ] || { printf 'parity: the old record carries no %s\n' "$key" >&2; mismatch=1; }
  [ -n "$new_v" ] || { printf 'parity: the engine record carries no %s\n' "$key" >&2; mismatch=1; }
done

# Both targets are live, then both reap — no orphans on either road.
for meta in "$OLD_META" "$NEW_META"; do
  win="$(meta_value "$meta" window)"
  tmux list-windows -a -F '#{window_id}' | grep -qx "$win" || fail "no live window $win for $(basename "$meta")"
done
"$ENGINE" stop "$NEW_ID" >/dev/null || fail "the engine could not reap its own seat"
tmux kill-window -t "$(meta_value "$OLD_META" window)" 2>/dev/null
for meta in "$OLD_META" "$NEW_META"; do
  win="$(meta_value "$meta" window)"
  tmux list-windows -a -F '#{window_id}' | grep -qx "$win" && fail "window $win survives the reap"
done

[ "$mismatch" -eq 0 ] || fail "the two records disagree — see the DIFFERENT rows"
printf 'parity[1]{verdict,agree,carried}\n  "PASS","%s","%s"\n' "$(printf '%s' "$AGREE" | wc -w | tr -d ' ')" "$(printf '%s' "$PRESENT" | wc -w | tr -d ' ')"
