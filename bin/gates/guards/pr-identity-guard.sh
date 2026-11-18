#!/usr/bin/env bash
# pr-identity-guard.sh — the ward that judges a pull request, and the place the signature lives.
#
#   pr-identity-guard.sh <pr-number>        # locally, through gh
#   pr-identity-guard.sh --ci               # in the workflow, through GITHUB_EVENT_PATH
#
# WHAT IT JUDGES (and always has): what a pull request PUBLISHES — a maker's name in its title
# or body (RULES/53), an address, a mailbox, a pane id, a credential, a concrete home path
# (RULES/04). Those refusals stand, because a body is public the moment it is opened.
#
# WHAT IT NO LONGER JUDGES: CEREMONY (2026-11-16). The five-line signature block — `house:`,
# `fleet:`, `agent:`, `authority:`, `proves:` — was a hard refusal: a body without it, or with an
# `agent:` that disagreed with the branch's errand id, was refused until a hand retyped facts the
# ward could read for itself. A day went to writing ceremony to satisfy a gate that had the same
# facts in the event it was already holding. So the four facts are now DERIVED from the pull
# request's own commits and author, printed (paste it into the body to make it permanent), and a
# disagreement between the body's `agent:` and the branch is a NOTE, never a refusal — the branch
# and the commits are the authority; the body is a description of them.
#
# Exit: 0 judged clean · 1 refused · 2 usage.
set -uo pipefail
source "$(dirname "$0")/../../forge/pr-patterns.sh"
_root() { local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ "$d" != "/" ]; do [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }; d="$(dirname "$d")"; done; printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; }
ROOT="${YMIR_GUARD_ROOT:-$(_root)}"
cd "$ROOT" 2>/dev/null || true

mode="local"; pr=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ci) mode="ci"; shift;;
    --local) mode="local"; shift;;
    *) pr="$1"; shift;;
  esac
done

# the event (or `gh`) is read ONCE, and every derived fact comes from it
base=""; commits=""; author=""; head_sha=""
if [ "$mode" = "ci" ]; then
  [ -z "${GITHUB_EVENT_PATH:-}" ] && { echo "no GITHUB_EVENT_PATH" >&2; exit 2; }
  # one read of the event, five facts out — no python expression is built from a variable
  ev="$(python3 - "$GITHUB_EVENT_PATH" <<'PY'
import json, sys
pr = (json.load(open(sys.argv[1])).get("pull_request") or {})
for key, val in (
    ("body", pr.get("body") or ""),
    ("branch", (pr.get("head") or {}).get("ref") or ""),
    ("title", pr.get("title") or ""),
    ("base", (pr.get("base") or {}).get("ref") or ""),
    ("commits", pr.get("commits") or ""),
    ("author", (pr.get("user") or {}).get("login") or ""),
    ("head_sha", (pr.get("head") or {}).get("sha") or ""),
):
    print(f"{key}\t{str(val).replace(chr(10), chr(92) + 'n')}")
PY
)"
  ev_get() { printf '%s\n' "$ev" | awk -F'\t' -v k="$1" '$1==k {sub(/^[^\t]*\t/,""); printf "%s", $0; exit}'; }
  body="$(ev_get body | sed 's/\\n/\n/g')"
  branch="$(ev_get branch)"
  title="$(ev_get title)"
  base="$(ev_get base)"
  commits="$(ev_get commits)"
  author="$(ev_get author)"
  head_sha="$(ev_get head_sha)"
  # A re-run of a workflow replays the event it was first given, so a title or body fixed since is
  # still judged as it was (measured 2026-11-18: a corrected PR title was refused again on re-run).
  # Ask the pull request itself when gh can answer; the event stays the fallback.
  _num="$(python3 -c 'import json,sys;print((json.load(open(sys.argv[1])).get("pull_request") or {}).get("number") or "")' "$GITHUB_EVENT_PATH" 2>/dev/null)"
  if [ -n "$_num" ] && command -v gh >/dev/null 2>&1 && [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
    _live="$(gh pr view "$_num" --json title,body 2>/dev/null)" && [ -n "$_live" ] && {
      _t="$(printf '%s' "$_live" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("title") or "")')"
      _b="$(printf '%s' "$_live" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("body") or "")')"
      [ -n "$_t" ] && title="$_t"
      body="$_b"
    }
  fi
else
  [ -z "$pr" ] && { echo "usage: pr-identity-guard.sh <pr-number> [--ci]" >&2; exit 2; }
  body=$(gh pr view "$pr" --json body -q .body 2>/dev/null)
  branch=$(gh pr view "$pr" --json headRefName -q .headRefName 2>/dev/null)
  title=$(gh pr view "$pr" --json title -q .title 2>/dev/null)
  base=$(gh pr view "$pr" --json baseRefName -q .baseRefName 2>/dev/null)
  commits=$(gh pr view "$pr" --json commits -q '.commits|length' 2>/dev/null)
  author=$(gh pr view "$pr" --json author -q .author.login 2>/dev/null)
  head_sha=$(gh pr view "$pr" --json headRefOid -q .headRefOid 2>/dev/null)
fi

# the title is prose too — the same matcher as the body (RULES/53)
ttmp=$(mktemp); printf '%s\n' "${title:-}" > "$ttmp"
if m=$(pr_maker_match "$ttmp"); then rm -f "$ttmp"; echo "refused: PR title: $m" >&2; exit 1; fi
rm -f "$ttmp"

# ── the signature, BUILT (2026-11-16) ────────────────────────────────────────────────────────────────
# Every field is a fact the pull request already carries: the origin's owner (public by design, it
# is the licence holder), the repository's own name, the branch's errand id, the author's handle,
# and the commits the branch carries onto its base. Nothing is invented, and nothing is required.
sig_field() { printf '%s\n' "$body" | grep -E "^$1:" | head -1 | sed "s/^$1:[[:space:]]*//"; }
owner="$(git remote get-url origin 2>/dev/null | sed -n 's#.*github\.com[:/]\([^/]*\)/.*#\1#p' | head -1)"
# the REPOSITORY, not the checkout: a worktree is named for its errand, and the fleet is the repo
repo="$(git remote get-url origin 2>/dev/null | sed -e 's#/*$##' -e 's#\.git$##' | awk -F/ '{print $NF}' | head -1)"
[ -n "$repo" ] || repo="$(basename "$(git rev-parse --git-common-dir 2>/dev/null | sed 's#/\.git$##; s#\.git$##')")"
[ -n "$repo" ] || repo="$(basename "$ROOT")"
errand=""; case "$branch" in eindri/*) errand="${branch#eindri/}";; esac
[ -n "$errand" ] || errand="$(printf '%s' "$branch" | tr '/' '-')"
[ -n "$errand" ] || errand="$(sig_field agent | sed 's/[[:space:]].*//')"
[ -n "$errand" ] || errand="a-branch-with-no-name"
[ -n "$author" ] || author="$(git log -1 --format='%an' 2>/dev/null)"
[ -n "$commits" ] || commits="$(git rev-list --count "origin/${base:-main}..HEAD" 2>/dev/null || echo '?')"
[ -n "$head_sha" ] || head_sha="$(git rev-parse --short=7 HEAD 2>/dev/null)"
short_sha="$(printf '%s' "$head_sha" | cut -c1-7)"

b_house="$(sig_field house)"; [ -n "$b_house" ] || b_house="$owner"
b_fleet="$(sig_field fleet)"; [ -n "$b_fleet" ] || b_fleet="$repo"
b_agent="$(sig_field agent | sed 's/[[:space:]].*//')"
b_authority="$(sig_field authority)"
b_proves="$(sig_field proves)"

built_agent="$errand"
# The branch is the authority (2026-11-16): a body that names another agent is described, not obeyed.
if [ -n "$b_agent" ] && [ "$b_agent" != "$errand" ] && [ "$b_agent" != "ship" ]; then
  printf 'note: agent "%s" in the body disagrees with branch errand "%s" — judged as "%s" (the branch and its commits are the record)\n' \
    "$b_agent" "$errand" "$errand"
fi

built=0
[ -z "$b_house" ] && built=1
[ -z "$b_fleet" ] && built=1
[ -z "$b_agent" ] && built=1
[ -z "$b_authority" ] && built=1
[ -z "$b_proves" ] && built=1

built_house="$b_house";     [ -n "$built_house" ] || built_house="${owner:-the repository}"
built_fleet="$b_fleet";     [ -n "$built_fleet" ] || built_fleet="$repo"
if [ -n "$b_agent" ] && [ "$b_agent" != "ship" ] && [ "$b_agent" != "$errand" ]; then
  # the branch and its commits are the record; the body is a description of them (2026-11-16)
  built_agent_line="$errand (role: ship, errand: $errand; the body said $b_agent)"
else
  built_agent_line="$errand (role: ship, errand: $errand)"
fi
built_authority="$b_authority"
if [ -z "$built_authority" ]; then
  built_authority="${author:-the author} — the pull request records ${commits} commit(s) onto ${base:-its base}"
fi
built_proves="$b_proves"
if [ -z "$built_proves" ]; then
  built_proves="head ${short_sha}: ${commits} commit(s) from ${author:-the author}; the gate is bin/gates/ci-verify.sh"
fi

sig="house: $built_house
fleet: $built_fleet
agent: $built_agent_line
authority: $built_authority
proves: $built_proves"

if [ "$built" = 1 ]; then
  printf 'pr-identity-guard: signature built from the pull request\x27s own commits and author\n' >&2
  printf '%s\n' "$sig" | sed 's/^/  /' >&2
  printf 'note: paste those five lines into the body to make the record permanent; the ward does not refuse their absence\n' >&2
fi

# ── what a body PUBLISHES (unchanged, and it still bites) ─────────────────────────────────────────────
tmp=$(mktemp); printf '%s\n\n%s\n' "$sig" "$body" > "$tmp"
if m=$(pr_pattern_match "$tmp"); then
  rm -f "$tmp"; echo "refused: $m" >&2; exit 1
fi
rm -f "$tmp"

echo "pr-identity-guard: OK"
exit 0
