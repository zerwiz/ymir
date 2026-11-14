#!/usr/bin/env bash
# The ward for "the reaper sees hand-seated tabs, not only `eindri-*` workspaces"
# (plan 293 · part 1, 2026-11-14).
#
# The fault: the sweep walked the workspaces the SPAWNER raises, so a worker the
# helm seated by hand — a TAB in his own workspace — was invisible to it. 36 panes
# stood on one machine; the reaper could see none of them.
#
# Every case below runs on a PLANTED repository and a STUBBED herdr, so nothing
# touches the real hall, the real $HOME or this repository's own worktrees. The
# stubs RECORD what was asked of them, and most of the test is about what was never
# asked: no working pane, no dirty pane, no unpushed pane, no pane the operator is
# looking at, and never the workspace the whole hall lives in.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# ── the planted repository ────────────────────────────────────────────────────
R="$T/repo"; W="$R/.yggdrasil"
git init -q --bare "$T/remote.git"
git init -q -b main "$R"
git -C "$R" remote add origin "https://github.com/planted/repo.git"
git -C "$R" remote add local "$T/remote.git"
mkdir -p "$R/.pi" "$R/RULES" "$W"
: >"$R/.pi/x"; : >"$R/RULES/x"
git -C "$R" add -A && git -C "$R" commit -qm base
sync_origin() {
  git -C "$R" fetch -q local
  git -C "$R" for-each-ref --format='%(refname:lstrip=3)' refs/remotes/local 2>/dev/null \
    | while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        git -C "$R" update-ref "refs/remotes/origin/$ref" "refs/remotes/local/$ref" 2>/dev/null || true
      done
}
git -C "$R" push -q local main
sync_origin

for n in landed working dirty unpushed recon ownseat; do
  git -C "$R" worktree add -q -b "eindri/$n" "$W/$n" main
done
land_it() {  # <name> — a pushed commit, merged into main
  ( cd "$W/$1" && printf 'work from %s\n' "$1" > "w-$1.txt" && git add -A && git commit -qm "work $1" \
    && git push -q local "eindri/$1" )
  git -C "$R" merge -q --no-ff -m "merge $1" "eindri/$1"
}
land_it landed
land_it ownseat
push_only() {  # <name> — a pushed commit, NOT merged
  ( cd "$W/$1" && printf 'work from %s\n' "$1" > "w-$1.txt" && git add -A && git commit -qm "work $1" \
    && git push -q local "eindri/$1" )
}
push_only working
push_only dirty
( cd "$W/unpushed" && printf 'x\n' > only-here.txt && git add -A && git commit -qm 'never pushed' )
printf 'dirt\n' >>"$W/dirty/w-dirty.txt"
git -C "$R" push -q local main
sync_origin
# recon made no commit at all; its report is its work
mkdir -p "$T/state/eindri-reports"
printf '# recon\n\nthe findings\n' >"$T/state/eindri-reports/recon.md"

# ── the stubbed hall ──────────────────────────────────────────────────────────
mkdir -p "$T/bin" "$T/fixtures"
cat >"$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
S="${STUB_DIR:?}"
case "${1:-} ${2:-}" in
  "workspace list") cat "$S/workspaces.json" ;;
  "workspace close")
    printf '%s\n' "$3" >>"$S/ws-closed"
    # a closed workspace takes its agents out of the list, as herdr does
    python3 - "$S/agents.json" "$3" ws <<'PY'
import json,sys
path,key,field=sys.argv[1],sys.argv[2],"workspace_id"
d=json.load(open(path))
d["result"]["agents"]=[a for a in d["result"]["agents"] if a.get(field)!=key]
json.dump(d,open(path,"w"))
PY
    exit 0 ;;
  "tab close")
    printf '%s\n' "$3" >>"$S/tab-closed"
    # a closed tab takes its agent out of the list, as herdr does — so a second
    # sweep meets a hall that has actually changed, not a stub that never moves
    python3 - "$S/agents.json" "$3" tab <<'PY'
import json,sys
path,key,field=sys.argv[1],sys.argv[2],"tab_id"
d=json.load(open(path))
d["result"]["agents"]=[a for a in d["result"]["agents"] if a.get(field)!=key]
json.dump(d,open(path,"w"))
PY
    exit 0 ;;
  "pane close")      printf '%s\n' "$3" >>"$S/pane-closed"; exit 0 ;;
  "agent list")      cat "$S/agents.json" ;;
  "pane list")       cat "$S/panes.json" ;;
  "pane send-text"|"pane send-keys") exit 0 ;;
  *) exit 0 ;;
esac
STUB
cat >"$T/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in "pr list") cat "${STUB_DIR:?}/prs.json" ;; *) exit 0 ;; esac
STUB
chmod +x "$T/bin/herdr" "$T/bin/gh"
printf '[]' >"$T/fixtures/prs.json"
printf '{"result":{"workspaces":[{"workspace_id":"w39","label":"ymir","agent_status":"done"},{"workspace_id":"wE","label":"eindri-ownseat","agent_status":"idle"}]}}\n' \
  >"$T/fixtures/workspaces.json"
cat >"$T/fixtures/agents.json" <<JSON
{"result":{"agents":[
 {"agent":"pi","agent_status":"idle","pane_id":"w39:pR","tab_id":"w39:tR","workspace_id":"w39","focused":false,"cwd":"$W/landed","foreground_cwd":"$W/landed"},
 {"agent":"pi","agent_status":"working","pane_id":"w39:pW","tab_id":"w39:tW","workspace_id":"w39","focused":false,"cwd":"$W/working","foreground_cwd":"$W/working"},
 {"agent":"pi","agent_status":"idle","pane_id":"w39:pD","tab_id":"w39:tD","workspace_id":"w39","focused":false,"cwd":"$W/dirty","foreground_cwd":"$W/dirty"},
 {"agent":"pi","agent_status":"idle","pane_id":"w39:pU","tab_id":"w39:tU","workspace_id":"w39","focused":false,"cwd":"$W/unpushed","foreground_cwd":"$W/unpushed"},
 {"agent":"claude","agent_status":"idle","pane_id":"w39:pC","tab_id":"w39:tC","workspace_id":"w39","focused":false,"cwd":"$W/recon","foreground_cwd":"$W/recon"},
 {"agent":"claude","agent_status":"idle","pane_id":"w39:pF","tab_id":"w39:tF","workspace_id":"w39","focused":true,"cwd":"$W/landed","foreground_cwd":"$W/landed"},
 {"agent":"pi","agent_status":"idle","pane_id":"w39:pS","tab_id":"w39:tS","workspace_id":"w39","focused":false,"cwd":"$W/landed","foreground_cwd":"$W/landed"},
 {"agent":"pi","agent_status":"idle","pane_id":"wE:p1","tab_id":"wE:t1","workspace_id":"wE","focused":false,"cwd":"$W/ownseat","foreground_cwd":"$W/ownseat"},
 {"agent":"claude","agent_status":"done","pane_id":"w39:pM","tab_id":"w39:tM","workspace_id":"w39","focused":false,"cwd":"$R","foreground_cwd":"$R"}
]}}
JSON
printf '{"result":{"panes":[]}}' >"$T/fixtures/panes.json"

ok=0; fail=0
t() { local n=$1; shift; if "$@" >"$T/out" 2>&1; then ok=$((ok+1)); printf 'ok   %s\n' "$n"; else fail=$((fail+1)); printf 'FAIL %s\n' "$n"; head -10 "$T/out"; fi; }
reap() { env PATH="$T/bin:$PATH" HOME="$T/home" BROKK_HOME="$T/repo" BROKK_STATE_OVERRIDE="$T/state" \
             STUB_DIR="$T/fixtures" SEAT_REAP_REPORT="$T/state/eindri-reports/planted-helm.md" \
             HERDR_PANE_ID="${REAP_SELF:-}" bash "$root/bin/seat/seat-reap.sh" "$@"; }
closed_tabs() { cat "$T/fixtures/tab-closed" 2>/dev/null || true; }
closed_ws()   { cat "$T/fixtures/ws-closed" 2>/dev/null || true; }

# ── 1. the dry run names the hand-seated tabs and closes nothing ──────────────
t "--list runs" reap --list
t "--list names the landed tab" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state STUB_DIR=$T/fixtures HERDR_PANE_ID= bash $root/bin/seat/seat-reap.sh --list | grep -q 'would close the tab — landed'"
t "--list closed no tab"  bash -c "! test -s $T/fixtures/tab-closed"
t "--list closed no workspace" bash -c "! test -s $T/fixtures/ws-closed"
t "--list wrote no report" bash -c "! test -f $T/state/eindri-reports/planted-helm.md"

# ── 2. the sweep closes exactly the two that the runbook says may go ─────────
t "the sweep runs" reap --sweep
t "the landed tab is closed"      bash -c "grep -qx 'w39:tR' $T/fixtures/tab-closed"
t "the recon tab is closed"       bash -c "grep -qx 'w39:tC' $T/fixtures/tab-closed"
t "an owned seat closes its workspace" bash -c "grep -qx 'wE' $T/fixtures/ws-closed"
t "the owned seat's tab was not closed instead" bash -c "! grep -qx 'wE:t1' $T/fixtures/tab-closed"

# ── 3. what was NEVER closed: the whole point of the door ────────────────────
t "a working pane is never closed"         bash -c "! grep -qx 'w39:tW' $T/fixtures/tab-closed"
t "a dirty pane is never closed"           bash -c "! grep -qx 'w39:tD' $T/fixtures/tab-closed"
t "an unpushed pane is never closed"       bash -c "! grep -qx 'w39:tU' $T/fixtures/tab-closed"
t "a FOCUSED pane is never closed"         bash -c "! grep -qx 'w39:tF' $T/fixtures/tab-closed"
t "the main checkout is never closed"      bash -c "! grep -qx 'w39:tM' $T/fixtures/tab-closed"
t "the hall's own workspace is never closed" bash -c "! grep -qx 'w39' $T/fixtures/ws-closed"
t "a second sweep closes nothing new" bash -c "n=\$(grep -c . $T/fixtures/tab-closed); PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state STUB_DIR=$T/fixtures HERDR_PANE_ID= bash $root/bin/seat/seat-reap.sh --sweep >/dev/null; test \$(grep -c . $T/fixtures/tab-closed) -eq \$n"

# ── 4. the caller's own pane is never a candidate ────────────────────────────
# Asked of a DRY RUN, so the case is proved without depending on what an earlier
# sweep already closed: the pane holding the door is not named as a candidate.
t "the caller's own pane is never a candidate" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state STUB_DIR=$T/fixtures HERDR_PANE_ID=w39:pR bash $root/bin/seat/seat-reap.sh --list | grep -q 'w39:pS'; ! PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state STUB_DIR=$T/fixtures HERDR_PANE_ID=w39:pR bash $root/bin/seat/seat-reap.sh --list | grep -q 'w39:pR'"

# ── 5. the record the runbook names: one dated line per closed pane ──────────
t "a close is recorded" bash -c "test -f $T/state/eindri-reports/planted-helm.md"
t "the line names the pane"   bash -c "grep -q 'pane w39:tR\|pane w39:pR' $T/state/eindri-reports/planted-helm.md"
t "the line names the branch" bash -c "grep -q 'eindri/landed' $T/state/eindri-reports/planted-helm.md"
t "the line names the verdict" bash -c "grep -q 'landed' $T/state/eindri-reports/planted-helm.md"
t "the line is dated"         bash -c "grep -qE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z' $T/state/eindri-reports/planted-helm.md"
t "one line per closed pane, and no more" bash -c "test \$(grep -c \"^- \" $T/state/eindri-reports/planted-helm.md) -eq 4"

# ── 6. nothing is deleted: the branch and the worktree both survive ──────────
t "the closed pane's branch still exists" bash -c "git -C $R rev-parse --verify -q eindri/landed >/dev/null"
t "the closed pane's worktree still exists" bash -c "test -d $W/landed"
t "no worktree was removed" bash -c "test \$(git -C $R worktree list | wc -l) -ge 7"

# ── 7. the stage can be turned off, and says so by doing nothing ─────────────
rm -f "$T/fixtures/tab-closed" "$T/fixtures/ws-closed"
t "SEAT_REAP_TABS=0 closes nothing" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state STUB_DIR=$T/fixtures SEAT_REAP_REPORT=$T/state/eindri-reports/planted-helm.md SEAT_REAP_TABS=0 HERDR_PANE_ID= bash $root/bin/seat/seat-reap.sh --sweep >/dev/null; ! test -s $T/fixtures/tab-closed && ! test -s $T/fixtures/ws-closed"

# ── 8. the wiring: the tab stage asks the shipped audit, and the audit is the
#       one place a verdict is decided ─────────────────────────────────────────
t "the reaper runs the shipped audit"   bash -c "grep -q 'seat-audit.sh' $root/bin/seat/seat-reap.sh"
t "the reaper does not re-decide it"    bash -c "! grep -q 'verdict_for\\|merge-base --is-ancestor' $root/bin/seat/seat-reap.sh"
t "the tab stage is part of the sweep"  bash -c "grep -q 'sweep_tabs \"\$do_it\"' $root/bin/seat/seat-reap.sh"
t "herdr is read through the one door"  bash -c "grep -q 'herdr-agents.py' $root/bin/seat/seat-reap.sh"
t "the sweep is still called at session start" bash -c "grep -q 'seat-reap.sh\" --sweep' $root/bin/time/saga-session-start.sh"

printf 'seat reap tabs: %s ok / %s fail\n' "$ok" "$fail"
[ "$fail" = 0 ]
