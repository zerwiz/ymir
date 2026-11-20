#!/usr/bin/env bash
# The ward for "the arm closes finished Eindri seats" (2026-11-10).
#
# Every case runs against a STUBBED herdr and a THROWAWAY home: no live herdr
# workspace is ever touched by this test, and nothing is written under the real
# $HOME. The stub is a `herdr` on PATH, so both readers — bin/seat/herdr-agents.py
# and bin/seat/seats.sh — are exercised exactly as they are in the hall.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home/.pi/agent/extensions" "$T/state" "$T/repo/.yggdrasil"

# ── the stub: herdr, answering from JSON in $STUB ─────────────────────────────
cat >"$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
S="${STUB_DIR:?}"
case "${1:-} ${2:-}" in
  "workspace list") cat "$S/workspaces.json" ;;
  "workspace close")
    printf '%s\n' "$3" >>"$S/closed"
    [ -f "$S/refuse-close" ] && exit 1
    exit 0 ;;
  "pane list") cat "$S/panes.json" ;;
  "pane close") printf '%s\n' "$3" >>"$S/panes-closed"; exit 0 ;;
  "agent list") cat "$S/agents.json" ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$T/bin/herdr"
export STUB_DIR="$T/stub"; mkdir -p "$STUB_DIR"
printf '{"result":{"workspaces":[]}}' >"$STUB_DIR/workspaces.json"
printf '{"result":{"panes":[]}}' >"$STUB_DIR/panes.json"
printf '{"result":{"agents":[]}}' >"$STUB_DIR/agents.json"

ok=0; fail=0
t() { local n=$1; shift; if "$@" >"$T/out" 2>&1; then ok=$((ok+1)); printf 'ok   %s\n' "$n"; else fail=$((fail+1)); printf 'FAIL %s\n' "$n"; head -6 "$T/out"; fi; }
# reap runs the door under the stub PATH, the throwaway HOME and the test state
reap() { env PATH="$T/bin:$PATH" HOME="$T/home" BROKK_HOME="$T/repo" \
             BROKK_STATE_OVERRIDE="$T/state" BROKK_DATA_OVERRIDE="$T/state/data" \
             bash "$root/bin/seat/seat-reap.sh" "$@"; }

# ── fixtures: two errands, one closed and one live ───────────────────────────
mkdir -p "$T/state/data"
printf 'id=alpha\nworkspace=wA\nseat_pane=wA:p1\nworktree=%s\n' "$T/repo/.yggdrasil/alpha" >"$T/state/alpha.meta"
printf 'failed: the launch produced NO agent\n' >"$T/state/alpha.status"
printf 'id=beta\nworkspace=wB\nseat_pane=wB:p1\nworktree=%s\n' "$T/repo/.yggdrasil/beta" >"$T/state/beta.meta"
printf 'working: a live agent stands here\n' >"$T/state/beta.status"
printf 'id=gamma\nworkspace=wC\n' >"$T/state/gamma.meta"     # recordless: no status at all
printf 'id=fresh\nworkspace=wF\nworktree=%s\n' "$T/repo/.yggdrasil/fresh" >"$T/state/fresh.meta"
printf 'working: young\n' >"$T/state/fresh.status"

cat >"$STUB_DIR/workspaces.json" <<JSON
{"result":{"workspaces":[
 {"workspace_id":"wA","label":"eindri-alpha","agent_status":"unknown"},
 {"workspace_id":"wB","label":"eindri-beta","agent_status":"working"},
 {"workspace_id":"wC","label":"eindri-gamma","agent_status":"unknown"},
 {"workspace_id":"wF","label":"eindri-fresh","agent_status":"working"},
 {"workspace_id":"wZ","label":"ymir","agent_status":"idle"}
]}}
JSON
cat >"$STUB_DIR/panes.json" <<JSON
{"result":{"panes":[
 {"pane_id":"wA:p1","cwd":"$T/repo/.yggdrasil/alpha"},
 {"pane_id":"wB:p1","cwd":"$T/repo/.yggdrasil/beta"},
 {"pane_id":"wC:p1","cwd":"$T/repo/.yggdrasil/gamma"},
 {"pane_id":"wF:p1","cwd":"$T/repo/.yggdrasil/fresh"}
]}}
JSON
cat >"$STUB_DIR/agents.json" <<JSON
{"result":{"agents":[
 {"agent":"pi","agent_status":"working","pane_id":"wB:p1","workspace_id":"wB",
  "cwd":"$T/repo/.yggdrasil/beta","foreground_cwd":"$T/repo/.yggdrasil/beta"},
 {"agent":"pi","agent_status":"working","pane_id":"wF:p1","workspace_id":"wF",
  "cwd":"$T/repo/.yggdrasil/fresh","foreground_cwd":"$T/repo/.yggdrasil/fresh"}
]}}
JSON

# 1. the sweep lists before it closes
t "--list closes nothing" bash -c "! test -s $STUB_DIR/closed"
t "--list names the closed errand" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state bash $root/bin/seat/seat-reap.sh --list | grep -q '\"alpha\",\"wA\"'"
t "--list keeps the live one" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state bash $root/bin/seat/seat-reap.sh --list | grep -q '\"beta\",\"wB\",\"wB:p1\",\"a live agent stands here'"

# 2. the sweep closes the closed and the recordless, and never the live
t "sweep closes the finished seats" reap --sweep
t "alpha's workspace was closed" bash -c "grep -qx wA $STUB_DIR/closed"
t "gamma's workspace was closed" bash -c "grep -qx wC $STUB_DIR/closed"
t "the live agent's workspace was NOT closed" bash -c "! grep -qx wB $STUB_DIR/closed"
t "the fresh record was NOT closed" bash -c "! grep -qx wF $STUB_DIR/closed"
t "the main hall was never considered" bash -c "! grep -qx wZ $STUB_DIR/closed"
t "one TOON row says what closed" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state bash $root/bin/seat/seat-reap.sh --list | head -2 | grep -q 'seat-reap\\[1\\]{would-close,kept,refused}'"

# 3. the marker makes a second sweep a no-op
t "a closed seat is recorded" bash -c "test -f $T/state/alpha.seat-closed && grep -q workspace=wA $T/state/alpha.seat-closed"
cat >"$STUB_DIR/workspaces.json" <<JSON
{"result":{"workspaces":[
 {"workspace_id":"wB","label":"eindri-beta","agent_status":"working"},
 {"workspace_id":"wF","label":"eindri-fresh","agent_status":"working"}
]}}
JSON
t "the second sweep closes nothing new" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state bash $root/bin/seat/seat-reap.sh --sweep | head -2 | grep -q '\"0\",\"2\",\"0\"'"

# 4. one errand, by its recorded workspace id, refuses a live agent
t "single close of a live errand is refused" bash -c "! PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state bash $root/bin/seat/seat-reap.sh beta | grep -q '\"beta\",\"wB\",\"wB:p1\",\"closed\"'"
t "refusal names the live agent" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state bash $root/bin/seat/seat-reap.sh beta | grep -q 'refused: a live agent stands here'"

# 5. the bare shell that keeps a worktree in use can be closed, and only a bare one
mkdir -p "$T/repo/.yggdrasil/shellonly" "$T/repo/.yggdrasil/held"
cat >"$STUB_DIR/panes.json" <<JSON
{"result":{"panes":[
 {"pane_id":"wS:p1","cwd":"$T/repo/.yggdrasil/shellonly"},
 {"pane_id":"wB:p1","cwd":"$T/repo/.yggdrasil/beta"}
]}}
JSON
t "a bare shell is closed" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state bash $root/bin/seat/seat-reap.sh --shell $T/repo/.yggdrasil/shellonly | grep -q 'closed (bare shell, no agent)'"
t "a live agent's pane is refused" bash -c "! PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state bash $root/bin/seat/seat-reap.sh --shell $T/repo/.yggdrasil/beta | grep -q closed"

# 6. housekeeping: an idle shell with no agent is not in-use
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
git init -q -b main "$T/hk" 2>/dev/null && (
  cd "$T/hk" || exit 1
  mkdir -p .pi RULES && : > .pi/x && : > RULES/x
  git add -A && git commit -qm base
  git branch merged-branch
  git worktree add -q "$T/hk/.yggdrasil/merged" merged-branch >/dev/null 2>&1
  git branch other-branch
  git worktree add -q "$T/hk/.yggdrasil/held" other-branch >/dev/null 2>&1
  # one real commit that exists nowhere else: the tree must be KEPT
  ( cd "$T/hk/.yggdrasil/held" && printf 'work\n' > only-here.txt && git add -A && git commit -qm 'unpushed work' ) >/dev/null 2>&1
) >/dev/null 2>&1
cat >"$STUB_DIR/panes.json" <<JSON
{"result":{"panes":[
 {"pane_id":"wS:p1","cwd":"$T/hk/.yggdrasil/merged"}
]}}
JSON
printf '{"result":{"agents":[]}}' >"$STUB_DIR/agents.json"
# A REAL bare shell standing in the worktree: a process whose cwd is the tree and
# which no agent owns. That is the exact shape of the fault (an Eindri exits to a
# shell, herdr restores it, the tree stays `in-use` forever).
( cd "$T/hk/.yggdrasil/merged" && exec sleep 60 ) &
SHELL_PID=$!
sleep 0.3
t "a bare shell is not keep:in-use" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_ROOT_OVERRIDE=$T/hk bash $root/bin/forge/housekeeping.sh report | grep -q '\"merged\",\"merged-branch\",\"reclaimable:merged\"'"
t "the report names the bare shell" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_ROOT_OVERRIDE=$T/hk bash $root/bin/forge/housekeeping.sh report | grep -q 'bare shell, no agent'"
# the same tree with a LIVE AGENT in it is never reclaimed
cat >"$STUB_DIR/agents.json" <<JSON
{"result":{"agents":[{"agent":"pi","agent_status":"working","pane_id":"wS:p1","workspace_id":"wS",
 "cwd":"$T/hk/.yggdrasil/merged","foreground_cwd":"$T/hk/.yggdrasil/merged"}]}}
JSON
t "a live agent keeps its worktree in-use" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_ROOT_OVERRIDE=$T/hk bash $root/bin/forge/housekeeping.sh report | grep -q '\"merged\",\"merged-branch\",\"keep:in-use\"'"
printf '{"result":{"agents":[]}}' >"$STUB_DIR/agents.json"
kill "$SHELL_PID" 2>/dev/null || true
t "an unpushed worktree is still kept" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_ROOT_OVERRIDE=$T/hk bash $root/bin/forge/housekeeping.sh report | grep -q '\"held\",\"other-branch\",\"keep:unpushed'"
t "a dirty worktree is still kept" bash -c "cd $T/hk/.yggdrasil/merged && echo dirt >> .pi/x && PATH=$T/bin:\$PATH HOME=$T/home BROKK_ROOT_OVERRIDE=$T/hk bash $root/bin/forge/housekeeping.sh report | grep -q '\"merged\",\"merged-branch\",\"keep:dirty\"'"

# 7. the migration: a worktree path is pruned from the root record, with a backup
printf '%s\n%s\n' "$T/repo" "$T/repo/.yggdrasil/alpha" >"$T/home/.pi/agent/extensions/.ymir-root"
t "the migration runs" bash -c "HOME=$T/home YMIR_HOME=$T/home BROKK_ROOT_OVERRIDE=$T/repo bash $root/.agents/migrations/0018-a-worktree-is-not-a-root.sh >/dev/null"
t "the worktree path is pruned" bash -c "! grep -q yggdrasil $T/home/.pi/agent/extensions/.ymir-root"
t "the real root survives" bash -c "grep -qx $T/repo $T/home/.pi/agent/extensions/.ymir-root"
t "a backup was kept" bash -c "test -f $T/home/.pi/agent/extensions/.ymir-root.pre-0018"
t "a second run is clean" bash -c "HOME=$T/home YMIR_HOME=$T/home BROKK_ROOT_OVERRIDE=$T/repo bash $root/.agents/migrations/0018-a-worktree-is-not-a-root.sh | grep -q 'root record: clean'"

# 8. the migration heals a worktree that reports its extensions deleted
if [ -d "$T/hk/.git" ] || [ -f "$T/hk/.git" ]; then
  ( cd "$T/hk" && git sparse-checkout disable >/dev/null 2>&1 || true )
  mkdir -p "$T/hk/.pi/extensions" && printf 'x\n' >"$T/hk/.pi/extensions/a.ts" && ( cd "$T/hk" && git add .pi/extensions/a.ts && git commit -qm ext ) >/dev/null 2>&1
  git -C "$T/hk/.yggdrasil/merged" checkout -q . 2>/dev/null
  mkdir -p "$T/hk/.yggdrasil/merged/.pi" 2>/dev/null
  rm -rf "$T/hk/.yggdrasil/merged/.pi/extensions"
  ( cd "$T/hk/.yggdrasil/merged" && git update-index --assume-unchanged .pi/extensions 2>/dev/null )
  t "the fault is visible first" bash -c "test -n \"\$(git -C $T/hk/.yggdrasil/merged status --porcelain | grep 'D  *\\.pi/extensions')\" || true"
  t "the migration heals it" bash -c "HOME=$T/home YMIR_HOME=$T/home BROKK_ROOT_OVERRIDE=$T/hk bash $root/.agents/migrations/0018-a-worktree-is-not-a-root.sh | grep -qE 'healed to the sparse-checkout exclusion|already clean'"
  t "git status is clean after the mend" bash -c "test -z \"\$(git -C $T/hk/.yggdrasil/merged status --porcelain)\""
fi

# 9. the spawner never leaves the deletion state (the shape it must use)
t "the spawner uses sparse-checkout, not assume-unchanged on a directory" bash -c "grep -q \"sparse-checkout set --no-cone '/\\*' '!/.pi/extensions/'\" $root/bin/agents/einherjar-spawn.sh"
t "the spawner no longer rm -rf's the extension tree" bash -c "! grep -q 'rm -rf \"\$WT/.pi/extensions\"' $root/bin/agents/einherjar-spawn.sh"
t "everything the sweep needs is wired into the session start" bash -c "grep -q 'seat-reap.sh\" --sweep' $root/bin/time/saga-session-start.sh"
t "the arm road sweeps too" bash -c "grep -q 'seat-reap.sh\" --sweep' $root/bin/pi/syn-watch-arm.sh"
t "the review ack closes the seat" bash -c "grep -q 'seat_close \"\$id\" review' $root/bin/agents/eindri-dispatch.sh"


# ── 10. the seat's word reaches the ARM, not a desktop (2026-11-10) ──────────
mkdir -p "$T/wake"
wake() { env PATH="$T/bin:$PATH" HOME="$T/home" BROKK_HOME="$T" BROKK_STATE_OVERRIDE="$T/wake" \
           bash "$root/bin/seat/seat-wake.sh" "$@"; }
t "a failed seat writes the arm's wake queue" wake alpha failed --pane wA:p1 --worktree /w/alpha
t "the wake is one durable line" bash -c "grep -q 'SEAT FAILED: pane wA:p1, worktree /w/alpha' $T/wake/.wake-queue"
t "the wake is written once" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T BROKK_STATE_OVERRIDE=$T/wake bash $root/bin/seat/seat-wake.sh alpha failed | grep -q 'already written'"
t "a second write does not ring twice" bash -c "test \$(grep -c 'SEAT FAILED' $T/wake/.wake-queue) -eq 1"
t "an adopted seat tells the arm too" wake alpha adopted --pane wA:p1 --worktree /w/alpha
t "the adoption line is in the queue" bash -c "grep -q 'SEAT ADOPTED' $T/wake/.wake-queue"

# ── 11. the engine notifies nothing -> it calls the SAME helper ─────────────
t "the engine calls the shared wake door" bash -c "grep -q '_seat_wake(roots, seat_id, \"failed\"' $root/src/ymir_runtime/seat.py"
t "the shell road calls it too" bash -c "grep -q 'seat-wake.sh\" \"\$ID\" failed' $root/bin/agents/einherjar-spawn.sh"

# ── 12. a late boot is adopted, and told to the arm ──────────────────────────
mkdir -p "$T/late/wt" "$T/late/state"
printf 'id=late\nseat=no\nwindow=wL:p1\nworktree=%s\n' "$T/late/wt/late" >"$T/late/state/late.meta"
printf 'failed: the launch produced NO agent\n' >"$T/late/state/late.status"
cat >"$STUB_DIR/agents.json" <<JSON
{"result":{"agents":[{"agent":"pi","agent_status":"working","pane_id":"wL:p1","workspace_id":"wL",
 "cwd":"$T/late/wt/late","foreground_cwd":"$T/late/wt/late"}]}}
JSON
adopt() { env PATH="$T/bin:$PATH" HOME="$T/home" BROKK_HOME="$T/late" BROKK_STATE_OVERRIDE="$T/late/state" \
            bash "$root/bin/seat/seat-adopt.sh" "$@"; }
t "--list adopts nothing" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/late BROKK_STATE_OVERRIDE=$T/late/state bash $root/bin/seat/seat-adopt.sh --list >/dev/null; grep -q '^seat=no' $T/late/state/late.meta"
t "the record is adopted" adopt late
t "seat=yes is recorded" bash -c "grep -qx 'seat=yes' $T/late/state/late.meta"
t "the adoption names when" bash -c "grep -q '^adopted=' $T/late/state/late.meta"
t "the status says adopted, not failed" bash -c "tail -1 $T/late/state/late.status | grep -q '^working: adopted'"
t "the arm is woken once" bash -c "grep -c 'SEAT ADOPTED' $T/late/state/.wake-queue | grep -qx 1"
t "an already-seated record is left alone" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/late BROKK_STATE_OVERRIDE=$T/late/state bash $root/bin/seat/seat-adopt.sh late | grep -q 'already seated'"

# ── 13. the settle: ONE shipped default, and it is 60 (his correction) ──────
t "seat-prove carries the one default" bash -c "grep -q 'YMIR_SEAT_SETTLE:-60' $root/bin/seat/seat-prove.sh"
t "the spawner does not carry a second default" bash -c "! grep -q 'YMIR_SEAT_SETTLE:-25' $root/bin/agents/einherjar-spawn.sh"
t "the engine passes --settle only when the operator set it" bash -c "grep -q 'if settle:' $root/src/ymir_runtime/seat.py"
t "the runtime asset names the number" bash -c "grep -q 'YMIR_SEAT_SETTLE' $root/.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md"

printf 'seat reap: %s ok / %s fail\n' "$ok" "$fail"
[ "$fail" = 0 ]
