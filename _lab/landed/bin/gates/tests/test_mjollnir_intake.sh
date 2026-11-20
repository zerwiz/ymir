#!/usr/bin/env bash
# test_mjollnir_intake.sh — the forge's senses (plan 210 P0/P1), proved without a network.
#
# Four things are proved, and each one is a fault this house has already paid for:
#
#   1 · a repo with no usable git{} block is reported with its reason — never a silent zero,
#       and never a single `gh` call spent on a repo that cannot be named;
#   2 · the read is a CACHE with a TTL — a second run inside the TTL makes NO call at all
#       (a door that re-reads GitHub on every render is a rate-limit bomb with a nice face);
#   3 · a source that fails alone leaves the rest of the read standing and names itself;
#   4 · a count is not a presentation: the JSON says how many issues, and the unread table
#       says which source did not answer.
#
# Usage: bash bin/gates/tests/test_mjollnir_intake.sh
# Exit: 0 every proof held · 1 one failed.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

HOME_FIX="$TMPD/home"
mkdir -p "$HOME_FIX/hodd/identity" "$TMPD/bin" "$HOME_FIX/state"
CALLS="$TMPD/calls.log"
: >"$CALLS"

cat >"$HOME_FIX/hodd/identity/projects.yaml" <<'YAML'
projects:
- id: probe-good
  realm: work
  repo: probe-good
  git:
    host: github.com
    owner: probe-org
    repo: probe-good
    remote: origin
    default_branch: main
    auth: gh
- id: probe-silent
  realm: work
  repo: probe-silent
- id: probe-broken
  realm: work
  repo: probe-broken
  git:
    host: github.com
    owner: probe-org
    repo: probe-broken
    remote: origin
    default_branch: main
    auth: gh
YAML

# The fake gh: every read answers from a fixture, every call is logged, and `run list`
# fails for probe-broken so a lone source failure can be proved.
cat >"$TMPD/bin/gh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
case "$*" in
  "auth status") exit 0 ;;
esac
repo=""
for a in "$@"; do case "$a" in repos/*) repo="$a" ;; -R) ;; esac; done
name="${repo#repos/}"
case "$1" in
  api)
    case "$name" in
      */vulnerability-alerts) printf '[]\n' ;;
      */dependabot/alerts)     printf '[]\n' ;;
      repos/*/*)               exit 1 ;;   # the "repo" read takes the two-segment form only
      *) printf '{"default_branch":"main","has_issues":true,"archived":false,"private":true}\n' ;;
    esac ;;
  issue) printf '%s\n' '[{"number":1,"title":"the first one","labels":[{"name":"bug"}],"createdAt":"2026-11-01T00:00:00Z","updatedAt":"2026-11-02T00:00:00Z","assignees":[],"comments":0},{"number":2,"title":"the second one","labels":[],"createdAt":"2026-11-03T00:00:00Z","updatedAt":"2026-11-03T00:00:00Z","assignees":[],"comments":1}]' ;;
  pr)    printf '%s\n' '[{"number":7,"title":"a change","headRefName":"x","reviewDecision":"","mergeable":"MERGEABLE","statusCheckRollup":[{"name":"ci","conclusion":"SUCCESS"}],"updatedAt":"2026-11-05T00:00:00Z"}]' ;;
  run)
    case "$*" in *probe-broken*) printf 'gh: a lone source failed\n' >&2; exit 1 ;; esac
    printf '%s\n' '[{"databaseId":11,"name":"ci","status":"completed","conclusion":"success","createdAt":"2026-11-05T00:00:00Z"}]' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TMPD/bin/gh"

intake() {  # <args…>
  FAKE_GH_LOG="$CALLS" PATH="$TMPD/bin:$PATH" \
    python3 "$ROOT/bin/forge/intake.py" --home "$HOME_FIX" "$@"
}

# 1 · the read, uncached
out="$(intake --limit 0 --ttl 0 --json 2>"$TMPD/err")"
rc=$?
if [ "$rc" -eq 0 ]; then ok "intake exits 0 on a readable registry"; else bad "intake exited $rc: $(cat "$TMPD/err")"; fi

python3 - "$out" <<'PY' && ok "a readable repo carries its counts and a source failure names itself" || bad "the read is not honest"
import json, sys
doc = json.loads(sys.argv[1])
repos = {r["repo"]: r for r in doc["repos"]}
good = repos.get("probe-org/probe-good") or {}
if len(good.get("data", {}).get("issues") or []) != 2:
    sys.exit("probe-good should carry two issues")
if (good.get("data", {}).get("prs") or [{}])[0].get("failing"):
    sys.exit("a SUCCESS check must not be reported as failing")
broken = repos.get("probe-org/probe-broken") or {}
if not any(u["source"] == "runs" for u in broken.get("unread") or []):
    sys.exit("probe-broken's failed run read must be named")
if "base" in (broken.get("data") or {}):
    sys.exit("a base that could not be read must not appear as a conclusion")
PY

# 2 · a row that cannot name a remote costs no network call at all
if grep -q "probe-silent" "$CALLS"; then
  bad "a registry row with no git{} block spent a gh call"
else
  ok "a row with no git{} block is named locally and costs no call"
fi
if intake --limit 0 --ttl 0 --json | python3 -c \
   'import json,sys; d=json.load(sys.stdin); sys.exit(0 if any(u["source"]=="registry" and u["repo"]=="probe-silent" for u in d["unread"]) else 1)'; then
  ok "the unread table names the registry row and its reason"
else
  bad "a row with no git{} block is missing from the unread table"
fi

# 3 · the cache: inside the TTL, zero calls; at ttl 0, the calls come back
: >"$CALLS"
intake --limit 0 --ttl 3600 >/dev/null 2>&1
first=$(wc -l <"$CALLS" | tr -d ' ')
intake --limit 0 --ttl 3600 >/dev/null 2>&1
second=$(wc -l <"$CALLS" | tr -d ' ')
if [ "$first" -eq 0 ] && [ "$second" -eq 0 ]; then
  ok "a second run inside the TTL makes no network call"
else
  bad "the cache was not honoured ($first then $second calls)"
fi
intake --limit 0 --ttl 0 >/dev/null 2>&1
after=$(wc -l <"$CALLS" | tr -d ' ')
if [ "$after" -gt 0 ]; then ok "an expired TTL re-reads"; else bad "an expired TTL still served the cache"; fi

# 4 · the filter reads one project and leaves the rest alone
: >"$CALLS"
one="$(intake --repo probe-good --ttl 0 --json 2>&1)"
if printf '%s' "$one" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if len(d["repos"])==1 else 1)'; then
  ok "--repo reads exactly the named project"
else
  bad "--repo did not filter ($one)"
fi
if grep -q "probe-broken" "$CALLS"; then bad "--repo still read an unasked repo"; else ok "--repo spends no call on an unasked repo"; fi
if intake --repo no-such-project >/dev/null 2>&1; then bad "an unknown project id was accepted"; else ok "an unknown project id is refused"; fi

# 5 · cache-only never touches the network
: >"$CALLS"
if intake --cache-only --ttl 0 >/dev/null 2>&1 && [ ! -s "$CALLS" ]; then
  ok "--cache-only reads no network"
else
  bad "--cache-only made a call, or failed"
fi

# 6 · the registry's own truth (P0) — shape, and an unusable row named as a finding
doc="$(YMIR_HOME="$HOME_FIX" bash "$ROOT/bin/agents/project-git.sh" doctor --json 2>/dev/null)" || doc=""
if [ -n "$doc" ] && printf '%s' "$doc" | python3 -c '
import json,sys
d=json.load(sys.stdin)
rows={r["id"]:r for r in d["rows"]}
if rows["probe-silent"]["verdict"] != "no-git": sys.exit(1)
if not any(f["id"]=="probe-silent" for f in d["findings"]): sys.exit(1)
if int(d["summary"]["rows"]) != 3: sys.exit(1)
sys.exit(0)'; then
  ok "doctor names the row that cannot name a remote"
else
  bad "doctor did not report the unusable row ($doc)"
fi

if [ "$fail" -ne 0 ]; then
  printf '\n%d proof(s) failed\n' "$fail"
  exit 1
fi
printf '\nall proofs held\n'
