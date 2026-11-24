#!/usr/bin/env bash
# test_projects_status.sh — plan 367: the projects resolver, the kit's report, add and reap. Fixtures only: a throwaway
# home and repos, a fake gh, a fake ssh. Nothing real is touched (YMIR_HOME, YMIR_SEAT and YMIR_PROJECTS_DIR are fenced).
#   bash tests/test_projects_status.sh
set -u
ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
S="$ROOT/bin/records/projects-status.sh"; P="$ROOT/bin/records/projects.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/ymir-projects.XXXXXX")"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" YMIR_HOME="$T/ymirhome" YMIR_SEAT=seat-a YMIR_PROJECTS_DIR="$T/clones" YMIR_STATE_DIR="$T/state"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.org GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.org
mkdir -p "$HOME" "$YMIR_HOME/hodd/identity" "$YMIR_HOME/hodd/data"
pass=0; fail=0
ok() { if [ "$2" = 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1"; fi; }
has() { printf '%s' "$1" | grep -q -- "$2"; }
jq_() { python3 -c "import json,sys;d=json.load(sys.stdin);$1"; }

mkrepo() {  # <dir> — a repo with main and one commit
  git init -q -b main "$1" && git -C "$1" commit -q --allow-empty -m init
}
mkrepo "$T/alpha"; mkrepo "$T/beta"; mkrepo "$T/gamma"
# alpha: a merged branch (stale) and an unmerged one (kept)
git -C "$T/alpha" worktree add -q -b done/x "$T/alpha-done"
git -C "$T/alpha" worktree add -q -b wip/y "$T/alpha-wip"; git -C "$T/alpha-wip" commit -q --allow-empty -m work
# kit state: alpha reports and is behind; beta is seated but does not report
mkdir -p "$T/alpha/.githooks"
printf '{"kit":"1.0.0","applied":"2026-01-01T00:00:00Z","report":{"to":["house"],"project":"alpha"}}\n' >"$T/alpha/.collab-kit.json"
printf '{"kit":"2.0.0"}\n' >"$T/beta/.collab-kit.json"
cat >"$YMIR_HOME/hodd/identity/projects.yaml" <<E
projects:
- id: alpha
  name: Alpha
  realm: work
  repo: $T/alpha
  git: {host: github.com, owner: acme, repo: alpha, default_branch: main}
  handling: {visibility: {value: public}}
- id: beta
  name: Beta
  realm: other
  repo: $T/beta
  handling: {visibility: {value: private}}
- id: gamma
  name: Gamma
  realm: work
  repo: $T/nowhere
  clones: {seat-b: /srv/gamma}
- id: delta
  name: Delta
  realm: work
  repo: $T/missing
E
# fake gh: one red PR for acme/alpha
cat >"$T/gh" <<'E'
#!/usr/bin/env bash
echo '[{"number":7,"title":"x","headRefName":"wip/y","isDraft":false,"reviewDecision":"APPROVED","url":"u","statusCheckRollup":[{"conclusion":"FAILURE"}]}]'
E
printf '#!/usr/bin/env bash\nexit 255\n' >"$T/ssh"; chmod +x "$T/gh" "$T/ssh"
export PROJECTS_STATUS_GH="$T/gh" PROJECTS_STATUS_SSH="$T/ssh"

out="$(bash "$S" --json --refresh --fleet)"
bash "$S" --json --refresh | jq_ "assert 'gamma' not in [p['id'] for p in d['projects']]" 2>/dev/null; ok "default: this machine only, no other seat asked" $?
echo "$out" | jq_ "ids=[p['id'] for p in d['projects']];assert 'alpha' in ids and 'beta' in ids, ids" 2>/dev/null; ok "clones on a seat are listed" $?
echo "$out" | jq_ "ids=[p['id'] for p in d['projects']];assert 'delta' not in ids" 2>/dev/null; ok "a project with no clone anywhere is hidden by default" $?
echo "$out" | jq_ "g=[p for p in d['projects'] if p['id']=='gamma'][0];assert g['where'][0]['seat']=='seat-b' and not g['where'][0]['reachable']" 2>/dev/null; ok "an unreachable seat is a row, not an error" $?
bash "$S" --all --json --local | jq_ "assert 'delta' in [p['id'] for p in d['projects']]" 2>/dev/null; ok "--all lists registry rows with no clone" $?
echo "$out" | jq_ "a=[p for p in d['projects'] if p['id']=='alpha'][0];w=a['where'][0];assert w['worktree_count']==3 and w['stale_count']==1,(w['worktree_count'],w['stale_count'])" 2>/dev/null; ok "alpha: 3 worktrees, only the merged one stale" $?
echo "$out" | jq_ "a=[p for p in d['projects'] if p['id']=='alpha'][0];assert a['pr_count']==1 and a['ci']=='red'" 2>/dev/null; ok "open PRs and red CI come through" $?
echo "$out" | jq_ "a=[p for p in d['projects'] if p['id']=='alpha'][0];k=a['where'][0]['kit'];assert k['reporting'] and k['behind'] and k['update']=='ymir projects kit update alpha',k" 2>/dev/null; ok "a reporting repo two versions behind names the update command" $?
echo "$out" | jq_ "b=[p for p in d['projects'] if p['id']=='beta'][0];k=b['where'][0]['kit'];assert k=={'seated':True,'reporting':False},k" 2>/dev/null; ok "a kit seated without --report reports nothing" $?
bash "$S" --json --public-view --local | jq_ "assert [p['id'] for p in d['projects']]==['alpha']" 2>/dev/null; ok "a shared view drops private projects" $?
bash "$S" --json --local --stale | jq_ "assert [p['id'] for p in d['projects']]==['alpha']" 2>/dev/null; ok "--stale filters" $?
has "$(bash "$S" --local)" 'projects\[' ; ok "TOON rows print" $?

# reap: dry run names the merged worktree only; --apply removes it and its branch, keeps the unmerged one
d="$(bash "$P" reap alpha)"; has "$d" "alpha-done"; ok "reap dry-run names the merged worktree" $?
has "$d" "alpha-wip" && r=1 || r=0; ok "reap never names unmerged work" $r
bash "$P" reap alpha --apply >/dev/null
[ ! -d "$T/alpha-done" ] && [ -d "$T/alpha-wip" ]; ok "reap --apply removes only the merged worktree" $?
git -C "$T/alpha" rev-parse -q --verify done/x >/dev/null && r=1 || r=0; ok "reap deletes the merged branch" $r

# add: clone a bare repo, register it, seat the kit with --report; a second add is refused
git init -q --bare -b main "$T/src.git"; git clone -q "$T/src.git" "$T/seed" 2>/dev/null; git -C "$T/seed" commit -q --allow-empty -m i; git -C "$T/seed" push -q origin main 2>/dev/null
PROJECTS_MIN_FREE_GB=1 bash "$P" add "$T/src.git" --id newrepo --kit --report >"$T/add.out" 2>&1; ok "add succeeds ($(tail -1 "$T/add.out"))" $?
[ -d "$T/clones/src/.git" ]; ok "add clones into YMIR_PROJECTS_DIR" $?
python3 -c "import json;m=json.load(open('$T/clones/src/.collab-kit.json'));assert m['report']['to']==['house'],m" 2>/dev/null; ok "--report seats a report block" $?
bash "$S" --json --local --no-net | jq_ "assert 'newrepo' in [p['id'] for p in d['projects']]" 2>/dev/null; ok "an added project appears at once" $?
PROJECTS_MIN_FREE_GB=1 bash "$P" add "$T/clones/src" --id newrepo >/dev/null 2>&1 && r=1 || r=0; ok "a duplicate is refused" $r
PROJECTS_MIN_FREE_GB=999999 bash "$P" add "$T/src.git" --id other >/dev/null 2>&1 && r=1 || r=0; ok "the disk law refuses a clone" $r
# re-applying without --report keeps the report that was seated
bash "$ROOT/bin/collab/standardise.sh" --apply "$T/clones/src" >/dev/null 2>&1
python3 -c "import json;assert json.load(open('$T/clones/src/.collab-kit.json')).get('report')" 2>/dev/null; ok "a later --apply keeps the seated report" $?

# a solo user, clean HOME, no registry
rm -rf "$YMIR_HOME/hodd/identity/projects.yaml"
bash "$S" --json | jq_ "assert d['count']==0" 2>/dev/null; ok "no registry: an empty panel, no error" $?
YMIR_PROJECTS_DIR="$T/c2" PROJECTS_MIN_FREE_GB=1 bash "$P" add "$T/src.git" >/dev/null 2>&1; ok "a clean-HOME user adds a repo" $?
bash "$S" --json --no-net | jq_ "assert d['count']==1" 2>/dev/null; ok "...and sees it" $?

echo "projects-status: $pass passed, $fail failed"; [ "$fail" = 0 ]
