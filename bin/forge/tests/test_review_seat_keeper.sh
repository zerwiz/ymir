#!/usr/bin/env bash
# test_review_seat_keeper.sh — the keeper: the reviewer's seat says WHY it refuses, and a dead seat
# is re-raised instead of being counted forever.
#
# Plan 293 part 10, measured on the heart 2026-11-14. Four faults, each with the reason it mattered:
#
#   · the refusal went to fd 3, which nothing opens — the keeper's journal said
#     "line 60: 3: Bad file descriptor" instead of the reason it refused (fixed on main 2026-11-09;
#     fenced here, with fd 3 CLOSED, so it cannot come back);
#   · the keeper counted a pane whose cwd was the review clone as "the seat" even when it held NO
#     agent — a bare shell after pi died at start — so nothing re-raised it and review-watch
#     prompted a shell every ten minutes;
#   · `ensure --primary` refused EVERY run while a live primary held the lock, so the machine had no
#     reviewer at all: the helm is the only thing that may be refused, never the seat;
#   · when pi died at start the keeper said "agent start failed" and nothing else, hiding the first
#     line of the reason (RULES/13 — two extension sets registering the same tool names).
#
# Hermetic by construction: herdr is a temp file this test writes, the home and the state are a
# throwaway under $TMPDIR, and the machine lock is read under its own XDG_STATE_HOME. The real herdr
# server, the real home, the real lock and every live workspace are never touched.
#
# Usage: test_review_seat_keeper.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
SEAT="$ROOT/bin/forge/review-seat.sh"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
STUB="$T/stub"; FIX="$T/fixtures"
mkdir -p "$STUB" "$FIX" "$T/hm/state" "$T/hm/config" "$T/home" "$T/clone/.git"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$(printf '%s' "$2" | head -3)"; return 0; }

# ── the fixtures: a herdr that answers from files, a pi that lists one model ────────────────────
cat >"$STUB/herdr" <<'STUB_HERDR'
#!/usr/bin/env bash
S="${STUB_DIR:?}"
a="${1:-}"; b="${2:-}"
shift 2 2>/dev/null || true
case "$a $b" in
  "agent list")
      [ -f "$S/no-server" ] && exit 1
      cat "$S/agents.json" 2>/dev/null || printf '{"result":{"agents":[]}}\n' ;;
  "agent get")
      # MEASURED 2026-11-14 (herdr 0.9.1): a pane with no agent is answered on STDERR with exit 1,
      # a live agent on STDOUT with exit 0. The fixture mirrors that, so a reader that watches only
      # stdout fails here instead of passing on a machine-shaped assumption.
      pane="${1:-}"
      if [ -f "$S/get-$pane" ]; then cat "$S/get-$pane"; exit 0; fi
      printf '{"error":{"code":"agent_not_found","message":"agent target %s not found"},"id":"cli:agent:get"}\n' "$pane" >&2
      exit 1 ;;
  "pane list") cat "$S/panes.json" 2>/dev/null || printf '{"result":{"panes":[]}}\n' ;;
  "pane close") printf '%s\n' "${1:-}" >>"$S/closed" ;;
  "pane read") cat "$S/pane-${1:-}.txt" 2>/dev/null || true ;;
  "workspace list") cat "$S/workspaces.json" 2>/dev/null || printf '{"result":{"workspaces":[]}}\n' ;;
  "workspace create")
      printf '%s\n' "$*" >"$S/ws-create"
      printf '{"result":{"workspace":{"workspace_id":"wRev"}}}\n' ;;
  "tab create")
      printf '%s\n' "$*" >"$S/tab-create"
      printf '{"result":{"root_pane":{"pane_id":"wRev:pNEW"}}}\n' ;;
  "agent start")
      printf '%s\n' "$*" >"$S/agent-start"
      if [ -f "$S/start-fail" ]; then cat "$S/start-fail" >&2; exit 1; fi
      if [ ! -f "$S/get-wRev:pNEW" ]; then
        printf '{"id":"cli:agent:start","result":{"agent":{"agent":"pi","agent_status":"working","pane_id":"wRev:pNEW"}}}\n' >"$S/get-wRev:pNEW"
      fi ;;
esac
exit 0
STUB_HERDR
chmod +x "$STUB/herdr"

cat >"$STUB/pi" <<'STUB_PI'
#!/usr/bin/env bash
case "${1:-}" in
  --list-models) printf 'Provider Model Context MaxOut\nstub seat-model 8192 2048\n' ;;
  --version) printf '0.0.0-fixture\n' ;;
esac
STUB_PI
chmod +x "$STUB/pi"

# the model this seat would resolve for the judge, in the throwaway home
printf 'agents:\n  forseti:\n    model: stub/seat-model\n' >"$T/hm/config/agents.yaml"

export STUB_DIR="$FIX"
seat() { env PATH="$STUB:$PATH" HOME="$T/home" YMIR_HOME="$T/hm" YMIR_STATE_DIR="$T/hm/state" \
             XDG_STATE_HOME="$T/xdg" PI_BIN="$STUB/pi" STUB_DIR="$FIX" \
             bash "$SEAT" "$@" 2>&1; }
clone="$T/clone"

# every scenario starts from the same clean room: no panes, no agents, no lock
reset() {
  rm -rf "$FIX"; mkdir -p "$FIX"
  printf '{"result":{"panes":[]}}\n'      >"$FIX/panes.json"
  printf '{"result":{"agents":[]}}\n'     >"$FIX/agents.json"
  printf '{"result":{"workspaces":[]}}\n' >"$FIX/workspaces.json"
  rm -f "$T/xdg/ymir/brokk.lock"
}
# a pane standing at the clone, in the seat's own `review` room, holding NO agent (a bare shell)
shell_pane() {
  printf '{"result":{"workspaces":[{"workspace_id":"wRev","label":"review"}]}}\n' >"$FIX/workspaces.json"
  printf '{"result":{"panes":[{"pane_id":"wRev:pOLD","cwd":"%s","workspace_id":"wRev"}]}}\n' "$clone" >"$FIX/panes.json"
}
lock_with() { mkdir -p "$T/xdg/ymir"; printf '%s\n' "$1" >"$T/xdg/ymir/brokk.lock"; }

# ── 1 · the refusal speaks, with fd 3 CLOSED (the fault the keeper's journal recorded) ──────────
reset
: >"$FIX/no-server"        # herdr is installed, the server does not answer — the timer's case
out="$(seat ensure --clone "$clone" 3>&-)"; rc=$?
[ "$rc" = 3 ] && ok "a refusal still exits 3 (the shape of it is unchanged)" \
              || bad "a refusal still exits 3" "rc=$rc — $out"
case "$out" in *"REFUSED — the herdr server does not answer"*) ok "the reason reaches stderr with fd 3 closed" ;;
  *) bad "the reason reaches stderr with fd 3 closed" "$out" ;; esac
case "$out" in *"Bad file descriptor"*) bad "the refusal no longer dies on a descriptor nobody opened" "$out" ;;
  *) ok "the refusal no longer dies on a descriptor nobody opened" ;; esac

# ── 2 · a pane that holds no agent is NOT the seat, and the keeper re-raises ────────────────────
reset
shell_pane
out="$(seat status "$clone")"
case "$out" in *"wRev:pOLD"*"not the seat"*) ok "status names a shell pane as not the seat" ;;
  *) bad "status names a shell pane as not the seat" "$out" ;; esac
out="$(seat ensure --clone "$clone")"; rc=$?
[ "$rc" = 0 ] && ok "ensure raises a seat over a dead pane (exit 0)" || bad "ensure raises a seat over a dead pane" "rc=$rc — $out"
grep -qx 'wRev:pOLD' "$FIX/closed" 2>/dev/null \
  && ok "the agentless pane is CLOSED, not counted as the seat" \
  || bad "the agentless pane is CLOSED, not counted as the seat" "$(cat "$FIX/closed" 2>/dev/null)"
case "$out" in *reaped*"wRev:pOLD"*) ok "the keeper says out loud that it reaped the pane" ;;
  *) bad "the keeper says out loud that it reaped the pane" "$out" ;; esac
case "$out" in *'"wRev:pNEW"'*'"working"'*) ok "a fresh agent is standing in a fresh pane" ;;
  *) bad "a fresh agent is standing in a fresh pane" "$out" ;; esac
[ -f "$FIX/ws-create" ] && bad "the existing review room was reused" "$(cat "$FIX/ws-create")" \
                       || ok "the existing review room was reused"

# ── 3 · the same on an older herdr whose `pane list` says nothing (agent list is the fallback) ──
reset
printf '{"result":{"workspaces":[{"workspace_id":"wRev","label":"review"}]}}\n' >"$FIX/workspaces.json"
printf '{"result":{"panes":[]}}\n' >"$FIX/panes.json"
printf '{"result":{"agents":[{"pane_id":"wRev:pOLD","cwd":"%s","workspace_id":"wRev","agent":"","agent_status":"unknown"}]}}\n' "$clone" >"$FIX/agents.json"
out="$(seat ensure --clone "$clone")"; rc=$?
[ "$rc" = 0 ] && ok "a herdr with no pane list still re-raises (exit 0)" || bad "a herdr with no pane list still re-raises" "rc=$rc — $out"
grep -qx 'wRev:pOLD' "$FIX/closed" 2>/dev/null \
  && ok "the dead pane is found through agent list too" \
  || bad "the dead pane is found through agent list too" "$(cat "$FIX/closed" 2>/dev/null)"

# ── 4 · a LIVE primary keeps the helm — and the seat is still raised (never exit 3) ────────────
reset
lock_with "$$"                       # this test's own shell: a live pid, never the machine's lock
out="$(seat ensure --primary --clone "$clone")"; rc=$?
[ "$rc" = 0 ] && ok "ensure --primary raises the seat while a live primary holds the lock" \
              || bad "ensure --primary raises the seat while a live primary holds the lock" "rc=$rc — $out"
case "$out" in *"helm[2]"*"$$"*) ok "the refusal names the primary that keeps the helm" ;;
  *) bad "the refusal names the primary that keeps the helm" "$out" ;; esac
case "$out" in *"raised as a plain seat"*) ok "the decision says the seat is raised, not refused" ;;
  *) bad "the decision says the seat is raised, not refused" "$out" ;; esac
grep -q 'BROKK_MACHINE_STATE_DIR=' "$FIX/ws-create" 2>/dev/null \
  && ok "a private seat state was set, so the helm was never taken" \
  || bad "a private seat state was set, so the helm was never taken" "$(cat "$FIX/ws-create" 2>/dev/null)"

# ── 5 · with NO live primary the seat does take the helm, as it always did ──────────────────────
reset
lock_with "999999"                   # a dead pid: the case --primary exists for
out="$(seat ensure --primary --clone "$clone")"; rc=$?
[ "$rc" = 0 ] && ok "with no live primary the seat is raised as the primary" || bad "with no live primary the seat is raised as the primary" "rc=$rc — $out"
case "$out" in *"seat[1]{helm}"*) ok "the helm is taken and said out loud" ;;
  *) bad "the helm is taken and said out loud" "$out" ;; esac
grep -q 'BROKK_MACHINE_STATE_DIR=' "$FIX/ws-create" 2>/dev/null \
  && bad "the primary seat carries no private state (it owns the helm)" "$(cat "$FIX/ws-create")" \
  || ok "the primary seat carries no private state (it owns the helm)"

# ── 6 · pi dies at start and the keeper reports the PANE's own line, never "start failed" ───────
reset
printf 'herdr: the pane must sit at an interactive shell prompt\n' >"$FIX/start-fail"
out="$(seat ensure --clone "$clone")"; rc=$?
[ "$rc" != 0 ] && ok "a seat that cannot start fails loudly" || bad "a seat that cannot start fails loudly" "rc=$rc"
case "$out" in *"the pane must sit at an interactive shell prompt"*) ok "the reason herdr gave is reported" ;;
  *) bad "the reason herdr gave is reported" "$out" ;; esac

# ── 7 · pi starts, then dies: the pane's first error line is the report (RULES/13's conflict) ──
reset
printf '{"error":{"code":"agent_not_found","message":"agent target wRev:pNEW not found"},"id":"cli:agent:get"}\n' >"$FIX/get-wRev:pNEW"
printf 'pi starting\nError: Tool "todo" conflicts with an existing tool "todo"\n' >"$FIX/pane-wRev:pNEW.txt"
out="$(seat ensure --clone "$clone")"; rc=$?
[ "$rc" != 0 ] && ok "a seat whose agent died is a fault, not a silent success" || bad "a seat whose agent died is a fault, not a silent success" "rc=$rc"
case "$out" in *'Tool "todo" conflicts with an existing tool'*) ok "the pane's first error line is what the keeper reports" ;;
  *) bad "the pane's first error line is what the keeper reports" "$out" ;; esac
case "$out" in *"agent start failed"*) bad "the keeper still says only 'agent start failed'" "$out" ;;
  *) ok "the keeper does not hide the reason behind 'agent start failed'" ;; esac

# ── 8 · a LIVE seat is left exactly as it stands (nothing reaped, nothing re-raised) ────────────
reset
printf '{"result":{"workspaces":[{"workspace_id":"wRev","label":"review"}]}}\n' >"$FIX/workspaces.json"
printf '{"result":{"panes":[{"pane_id":"wRev:pLIVE","cwd":"%s","workspace_id":"wRev"}]}}\n' "$clone" >"$FIX/panes.json"
printf '{"id":"cli:agent:get","result":{"agent":{"agent":"pi","agent_status":"idle","pane_id":"wRev:pLIVE"}}}\n' >"$FIX/get-wRev:pLIVE"
out="$(seat ensure --clone "$clone")"; rc=$?
[ "$rc" = 0 ] && ok "a live seat is reported, not touched (exit 0)" || bad "a live seat is reported, not touched" "rc=$rc — $out"
case "$out" in *'"wRev:pLIVE"'*'"idle"'*) ok "the live seat's own pane and state are reported" ;;
  *) bad "the live seat's own pane and state are reported" "$out" ;; esac
[ -s "$FIX/closed" ] && bad "a live seat was closed" "$(cat "$FIX/closed")" || ok "a live seat was never closed"
[ -f "$FIX/tab-create" ] && bad "a second agent was raised beside a live seat" || ok "no second agent was raised beside a live seat"

printf '\nreview-seat keeper: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
