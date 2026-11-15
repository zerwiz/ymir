#!/usr/bin/env bash
# The ward for "the audit says, in one line, whether a seat's work can be let go"
# (plan 293 · parts 1–2, 2026-11-14).
#
# Every case runs on a PLANTED repository — one bare remote, one main checkout and
# ten linked worktrees, each in one of the states the runbook's table names — read
# through a STUBBED herdr and a STUBBED gh. Nothing here touches the real hall, the
# real $HOME, the real GitHub, or this repository's own worktrees.
#
# The states are the runbook's, one per row: clean-merged, clean-unmerged, dirty,
# unpushed, working, a recon with a report and one without, an open PR that
# conflicts, an open PR that waits, and a squash-merged PR whose commits are NOT
# ancestors of origin/main (the case `git merge-base` alone calls unfinished).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# ── the planted repository: one remote, one checkout, ten worktrees ───────────
R="$T/repo"; W="$R/.yggdrasil"
git init -q --bare "$T/remote.git"
git init -q -b main "$R"
# `origin` carries a GitHub-shaped URL — the slug the audit asks GitHub about — and
# a SECOND remote does the real traffic against a bare repository on this box.
# `get-url` is never consulted for the push road, so no network is used and the
# audit still sees the URL it would see in the hall.
git -C "$R" remote add origin "https://github.com/planted/repo.git"
git -C "$R" remote add local "$T/remote.git"
mkdir -p "$R/.pi" "$R/RULES" "$W"
: >"$R/.pi/x"; : >"$R/RULES/x"
git -C "$R" add -A && git -C "$R" commit -qm base
# what git would have written had it really pushed to `origin`
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

for n in merged unmerged dirty unpushed working conflict squashed openpr recon noreport; do
  git -C "$R" worktree add -q -b "eindri/$n" "$W/$n" main
done

commit_here() {  # <name> — one commit in that worktree
  ( cd "$W/$1" && printf 'work from %s\n' "$1" > "work-$1.txt" && git add -A \
    && git commit -qm "work from $1" )
}
for n in merged unmerged dirty working conflict squashed openpr; do
  commit_here "$n"
  git -C "$W/$n" push -q local "eindri/$n"
done
# unpushed: a commit on the branch that no remote holds
( cd "$W/unpushed" && printf 'x\n' > only-here.txt && git add -A && git commit -qm 'never pushed' )
# merged and working: origin/main now contains these worktrees' HEAD
git -C "$R" merge -q --no-ff -m "merge merged" eindri/merged
git -C "$R" merge -q --no-ff -m "merge working" eindri/working
git -C "$R" push -q local main
# dirty: a real modification on an otherwise pushed, clean tree
printf 'dirt\n' >>"$W/dirty/work-dirty.txt"
sync_origin

# ── the planted PRs: GitHub is the only side asked, `git merge-tree` never ────
mkdir -p "$T/fixtures" "$T/state/eindri-reports"
cat >"$T/fixtures/prs.json" <<'JSON'
[
 {"headRefName":"eindri/conflict","number":901,"state":"OPEN","mergeable":"CONFLICTING"},
 {"headRefName":"eindri/squashed","number":902,"state":"MERGED","mergeable":"UNKNOWN"},
 {"headRefName":"eindri/openpr","number":903,"state":"OPEN","mergeable":"MERGEABLE"}
]
JSON
# recon filed its report; noreport filed nothing. The id is the folder's name.
printf '# recon\n\nthe findings\n' >"$T/state/eindri-reports/recon.md"

mkdir -p "$T/bin" "$T/bin-badgh" "$T/bin-bare" "$T/loose"
for c in bash python3 mktemp git sed cut awk tr wc date rm grep basename sort head tail cat printf mkdir dirname; do
  [ -x "$(command -v "$c" 2>/dev/null)" ] && ln -sf "$(command -v "$c")" "$T/bin-bare/$c"
done
cat >"$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "agent list") cat "${STUB_DIR:?}/agents.json" ;;
  *) exit 0 ;;
esac
STUB
cat >"$T/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "pr list") cat "${STUB_DIR:?}/prs.json" ;;
  *) exit 0 ;;
esac
STUB
cat >"$T/bin-badgh/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh: could not resolve host (planted failure)" >&2
exit 1
STUB
ln -sf "$T/bin/herdr" "$T/bin-badgh/herdr"
chmod +x "$T/bin/herdr" "$T/bin/gh" "$T/bin-badgh/gh"

cat >"$T/fixtures/agents.json" <<JSON
{"result":{"agents":[
 {"agent":"pi","agent_status":"idle","pane_id":"wA:p1","tab_id":"wA:t1","workspace_id":"wA","focused":false,"cwd":"$W/merged","foreground_cwd":"$W/merged"},
 {"agent":"pi","agent_status":"idle","pane_id":"wA:p2","tab_id":"wA:t2","workspace_id":"wA","focused":false,"cwd":"$W/unmerged","foreground_cwd":"$W/unmerged"},
 {"agent":"pi","agent_status":"idle","pane_id":"wA:p3","tab_id":"wA:t3","workspace_id":"wA","focused":false,"cwd":"$W/dirty","foreground_cwd":"$W/dirty"},
 {"agent":"pi","agent_status":"idle","pane_id":"wA:p4","tab_id":"wA:t4","workspace_id":"wA","focused":false,"cwd":"$W/unpushed","foreground_cwd":"$W/unpushed"},
 {"agent":"pi","agent_status":"working","pane_id":"wA:p5","tab_id":"wA:t5","workspace_id":"wA","focused":false,"cwd":"$W/working","foreground_cwd":"$W/working"},
 {"agent":"pi","agent_status":"idle","pane_id":"wA:p6","tab_id":"wA:t6","workspace_id":"wA","focused":false,"cwd":"$W/conflict","foreground_cwd":"$W/conflict"},
 {"agent":"pi","agent_status":"idle","pane_id":"wA:p7","tab_id":"wA:t7","workspace_id":"wA","focused":false,"cwd":"$W/squashed","foreground_cwd":"$W/squashed"},
 {"agent":"pi","agent_status":"idle","pane_id":"wA:p8","tab_id":"wA:t8","workspace_id":"wA","focused":false,"cwd":"$W/openpr","foreground_cwd":"$W/openpr"},
 {"agent":"claude","agent_status":"idle","pane_id":"wA:p9","tab_id":"wA:t9","workspace_id":"wA","focused":false,"cwd":"$W/recon","foreground_cwd":"$W/recon"},
 {"agent":"claude","agent_status":"idle","pane_id":"wA:p0","tab_id":"wA:t0","workspace_id":"wA","focused":false,"cwd":"$W/noreport","foreground_cwd":"$W/noreport"},
 {"agent":"claude","agent_status":"idle","pane_id":"wA:pS","tab_id":"wA:tS","workspace_id":"wA","focused":false,"cwd":"$W/merged","foreground_cwd":"$W/merged"},
 {"agent":"claude","agent_status":"done","pane_id":"wM:p1","tab_id":"wM:t1","workspace_id":"wM","focused":true,"cwd":"$R","foreground_cwd":"$R"},
 {"agent":"pi","agent_status":"idle","pane_id":"wL:p1","tab_id":"wL:t1","workspace_id":"wL","focused":false,"cwd":"$T/loose","foreground_cwd":"$T/loose"}
]}}
JSON

ok=0; fail=0
t() { local n=$1; shift; if "$@" >"$T/out" 2>&1; then ok=$((ok+1)); printf 'ok   %s\n' "$n"; else fail=$((fail+1)); printf 'FAIL %s\n' "$n"; head -8 "$T/out"; fi; }

# The audit runs under the stub PATH, a throwaway HOME and the planted state shelf.
audit() { env PATH="$1:$PATH" HOME="$T/home" BROKK_HOME="$T/repo" \
              BROKK_STATE_OVERRIDE="$T/state" STUB_DIR="$T/fixtures" \
              HERDR_PANE_ID="${AUDIT_SELF:-}" bash "$root/bin/seat/seat-audit.sh" "${@:2}"; }
# ONE measurement, read many times: the run under the good stubs.
audit "$T/bin" >"$T/toon"
audit "$T/bin" --tsv >"$T/tsv"
audit "$T/bin" --no-pr >"$T/toon-nopr"

row() { grep "^  \"$1\"," "$T/toon" || true; }
row_has() { row "$1" | grep -q -- "$2"; }
tsv_has() { grep "^$1"$'\t' "$T/tsv" | grep -q -- "$2"; }

# ── 1. the reading face: one line per agent pane, the runbook's columns ───────
t "the header names the runbook's columns" bash -c "head -1 $T/toon | grep -q 'seat-audit\\[12\\]{pane,status,agent,folder,branch,dirty,unpushed,in_main,pr,mergeable,verdict}'"
t "clean-merged reads landed"       row_has wA:p1 '"landed"'
t "clean-merged is in origin/main"  row_has wA:p1 '"yes"'
t "a squash-merged PR reads landed" row_has wA:p7 '"landed"'
t "and its HEAD is NOT in main"     row_has wA:p7 '"no"'
t "clean-unmerged reads unmerged"   row_has wA:p2 '"unmerged"'
t "no PR is a fact, not a silence"  row_has wA:p2 '"none"'
t "dirty reads dirty"               row_has wA:p3 '"dirty"'
t "dirty counts the entries"        row_has wA:p3 '"1"'
t "unpushed reads unpushed"         row_has wA:p4 '"unpushed"'
t "unpushed counts the commits"     row_has wA:p4 '"1"'
t "working wins over landed"        row_has wA:p5 '"working"'
t "a conflicting PR is named"       row_has wA:p6 '"open-pr-conflict"'
t "mergeability comes from GitHub"  row_has wA:p6 '"CONFLICTING"'
t "a waiting PR is named"           row_has wA:p8 '"open-pr"'
t "and carries its number"          row_has wA:p8 '"#903"'
t "recon with a report is named"    row_has wA:p9 '"recon-with-report"'
t "recon without one is named"      row_has wA:p0 '"recon-no-report"'

# ── 2. the two skips, and the tree that is not an errand ──────────────────────
t "a main checkout is skipped by name" bash -c "grep -q '\"wM:p1\",\"a repository main checkout — a seat, not an errand\"' $T/toon"
t "a seat outside git is a row, not a skip" row_has wL:p1 '"no-git"'
t "the caller's own pane is skipped" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state STUB_DIR=$T/fixtures HERDR_PANE_ID=wA:pS bash $root/bin/seat/seat-audit.sh | grep -q '\"wA:pS\",\"the caller.s own pane\"'"
t "and it is not measured as an errand" bash -c "PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state STUB_DIR=$T/fixtures HERDR_PANE_ID=wA:pS bash $root/bin/seat/seat-audit.sh | head -1 | grep -q 'seat-audit\[11\]'"

# ── 3. the machine face: what the reaper needs, and no empty field (a tab is a
#       whitespace character to `read`, so an empty field would shift the row) ──
t "tsv carries the tab and the workspace" tsv_has wA:p1 "idle	pi	wA:t1	wA	false	$W/merged	eindri/merged"
t "tsv has sixteen fields on every row" bash -c "awk -F'\t' 'NF!=16{print NR\": \"NF; bad=1} END{exit bad?1:0}' $T/tsv"
t "tsv never leaves a field empty" bash -c "! grep -qP '(^|\t)(\t|$)' $T/tsv"
t "tsv names the recon report's path" tsv_has wA:p9 "eindri-reports/recon.md"
t "tsv says there is no report" tsv_has wA:p0 "recon-no-report	no commit of its own and no report filed	-"
t "--pane measures only that pane" bash -c "test \$(PATH=$T/bin:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state STUB_DIR=$T/fixtures HERDR_PANE_ID= bash $root/bin/seat/seat-audit.sh --pane wA:p2 | grep -c '^  \"wA:p') -eq 1"

# ── 4. GitHub is asked, and its silence is never read as a verdict ───────────
t "--no-pr asks nothing and says so" bash -c "grep -q '\"wA:p2\",\"idle\",\"pi\",\"$W/unmerged\",\"eindri/unmerged\",\"0\",\"0\",\"no\",\"-\",\"-\",\"unmerged\"' $T/toon-nopr"
t "a failed question reads ?, never none" bash -c "PATH=$T/bin-badgh:\$PATH HOME=$T/home BROKK_HOME=$T/repo BROKK_STATE_OVERRIDE=$T/state STUB_DIR=$T/fixtures HERDR_PANE_ID= bash $root/bin/seat/seat-audit.sh --pane wA:p2 | grep -q '\"eindri/unmerged\",\"0\",\"0\",\"no\",\"?\",\"?\"'"
t "no herdr is a clean skip, not a failure" bash -c "PATH=$T/bin-bare HOME=$T/home BROKK_HOME=$T/repo bash $root/bin/seat/seat-audit.sh | grep -q 'no herdr on this host'"

# ── 5. the audit never reaches for the tool that hung, and the source is the
#       shipped one (fences: the real tree, not a copy) ─────────────────────────
t "merge-tree is never called" bash -c "! grep -qE '^[^#]*merge-tree' $root/bin/seat/seat-audit.sh"
t "the reaper never calls merge-tree either" bash -c "! grep -qE '^[^#]*merge-tree' $root/bin/seat/seat-reap.sh"
t "mergeability is asked of GitHub" bash -c "grep -q 'json number,state,mergeable' $root/bin/seat/seat-audit.sh"
t "the one herdr reader gained the tsv face" bash -c "grep -q '\"--tsv\" in args' $root/bin/seat/herdr-agents.py"

printf 'seat audit: %s ok / %s fail\n' "$ok" "$fail"
[ "$fail" = 0 ]
