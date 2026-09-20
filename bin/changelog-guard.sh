#!/usr/bin/env bash
# changelog-guard.sh — every push must carry a CHANGELOG entry.
#
# The house law: a change that ships is a change that was told. CHANGELOG.md is
# append-only (RULES/06-append-only.md) and is the record the operator reads
# after the fact. This guard refuses a push whose range never touches it, so the
# record can never lag silently behind the code.
#
# Two tiers, so a follow-up commit needs no micro-entry:
#   1. the pushed range (remote..local) touches CHANGELOG.md, or
#   2. the branch's whole range since it left the trunk does — the record is
#      already told, and this push merely lands a file it describes.
# What can never pass is a branch whose entire range leaves with no entry.
#
#   bin/changelog-guard.sh                 # pre-push: refs on stdin (hook mode)
#   bin/changelog-guard.sh --range A..B    # check one explicit range
#   bin/changelog-guard.sh --install       # wire pre-push (branch + changelog)
#
# Exit codes: 0 = a changelog entry is present (or nothing is being pushed),
#             1 = blocked, 2 = usage.
#
# Override (deliberate, loud): YMIR_SKIP_CHANGELOG_GUARD=1 git push …
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHANGELOG="CHANGELOG.md"
# A change may tell its story either way: an entry appended to the ledger, or a
# fragment in CHANGELOG.d/ that the assembler will fold in. The fragment is the
# preferred form — two branches never touch the same fragment file, so the duty
# is met without the O(N^2) conflict every branch appending to one file causes.
FRAGMENT_DIR="CHANGELOG.d"
ZERO="0000000000000000000000000000000000000000"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

# changes_touch_changelog <base> <head> — exit 0 when the change TELLS ITS STORY,
# either by appending to CHANGELOG.md or by adding a CHANGELOG.d/ fragment.
changes_touch_changelog() {
  local base=${1-} head=${2-} f
  [ -n "$head" ] || return 1
  if [ -z "$base" ]; then
    # No base to compare against (root commit range): look at every commit.
    f="$(git -C "$ROOT" ls-tree -r --name-only "$head" -- "$CHANGELOG" 2>/dev/null)"
    [ -n "$f" ] && return 0
    f="$(git -C "$ROOT" ls-tree -r --name-only "$head" -- "$FRAGMENT_DIR" 2>/dev/null | grep -v '/README.md$' | grep '\.md$')"
    [ -n "$f" ] && return 0
    return 1
  fi
  git -C "$ROOT" diff --name-only "$base" "$head" -- "$CHANGELOG" 2>/dev/null | grep -q . && return 0
  # A fragment ADDED in the range satisfies the duty. A fragment merely deleted
  # (the assembler folding it into the ledger) does not count on its own — but in
  # that same push the ledger changed, which the test above already caught.
  git -C "$ROOT" diff --name-only --diff-filter=A "$base" "$head" -- "$FRAGMENT_DIR" 2>/dev/null \
    | grep -v '/README.md$' | grep -q '\.md$' && return 0
  return 1
}

# branch_touches_changelog <sha> — the branch's own range since it left the trunk.
# The fallback for a follow-up push: a commit that merely lands a file already
# told by an earlier entry is not a new untold change. What must never happen is
# a branch whose whole range leaves without an entry.
branch_touches_changelog() {
  local sha=${1-} default_ref base
  [ -n "$sha" ] || return 1
  for default_ref in "origin/HEAD" "origin/main" "origin/master"; do
    git -C "$ROOT" rev-parse --verify --quiet "$default_ref" >/dev/null 2>&1 || continue
    base="$(git -C "$ROOT" merge-base "$sha" "$default_ref" 2>/dev/null || true)"
    [ -n "$base" ] && { changes_touch_changelog "$base" "$sha" && return 0; return 1; }
  done
  return 1
}

# check_ref <local_sha> <remote_sha> — resolve the range and test it
check_ref() {
  local local_sha=${1-} remote_sha=${2-} base="" default_ref=""
  [ -n "$local_sha" ] || return 1
  case "$local_sha" in "$ZERO") return 1 ;; esac   # a deletion pushes no content

  if [ -n "$remote_sha" ] && [ "$remote_sha" != "$ZERO" ]; then
    base="$remote_sha"
  else
    # A brand-new remote branch: measure from where it forked off the trunk.
    for default_ref in "origin/HEAD" "origin/main" "origin/master"; do
      git -C "$ROOT" rev-parse --verify --quiet "$default_ref" >/dev/null 2>&1 || continue
      base="$(git -C "$ROOT" merge-base "$local_sha" "$default_ref" 2>/dev/null || true)"
      [ -n "$base" ] && break
    done
  fi
  changes_touch_changelog "$base" "$local_sha" && return 0
  # Nothing in THIS push told the record; the branch may yet have told it.
  branch_touches_changelog "$local_sha"
}

verdict() {  # <ok|blocked>
  if [ "$1" = "ok" ]; then
    printf 'changelog-guard[1]{gate,result}:\n  "push","ok"\n'
    exit 0
  fi
  cat >&2 <<'EOF'
changelog-guard: blocked — this push carries no CHANGELOG entry.

  Every change that ships is a change that was told. Tell it either way:

    PREFERRED — add a fragment (no conflict with any other branch):
      CHANGELOG.d/<YYYY-MM-DD>-<slug>.md   starting with "## YYYY-MM-DD — title"
      bin/changelog-assemble.sh folds it into CHANGELOG.md

    OR — append an entry to CHANGELOG.md under the current date
    (append-only — never rewrite an existing entry; RULES/06-append-only.md).

  Commit it, and push again.

  Deliberate override, when an entry truly does not belong:
    YMIR_SKIP_CHANGELOG_GUARD=1 git push ...
EOF
  printf 'error: changelog-guard blocked the push (no CHANGELOG entry or fragment in range)\n' >&2
  printf 'help: add a CHANGELOG.d/ fragment (preferred), or append to CHANGELOG.md; override with YMIR_SKIP_CHANGELOG_GUARD=1\n' >&2
  exit 1
}

case "${1:-}" in
  -v|-V|--version) printf '1.0.0\n'; exit 0 ;;
  -h|--help) usage ;;
  --install)
    # The hook lives in the COMMON git dir: `git push` reads hooks from there, and
    # every worktree shares them. `$ROOT/.git/hooks` is a path under a FILE in a
    # linked worktree, so the old path could not even seat the gate from one.
    common="$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null || printf '.git')"
    case "$common" in /*) ;; *) common="$ROOT/$common" ;; esac
    hook="$common/hooks/pre-push"
    mkdir -p "$(dirname "$hook")" || exit 1
    cat >"$hook" <<EOF
#!/usr/bin/env bash
# pre-push hook — the delivery gate. Installed by bin/changelog-guard.sh --install.
#   0. changelog-assemble — fold CHANGELOG.d/ fragments into CHANGELOG.md, so the
#      ledger is never behind what the fragments already tell. Folding is an
#      append: existing entries are copied verbatim, never reordered.
#   1. branch-guard   — Rule 08: never push a protected branch
#   2. changelog-guard — every push carries a CHANGELOG entry (or a fragment)
set -u
refs="\$(mktemp)"
trap 'rm -f "\$refs"' EXIT
cat >"\$refs"
# The gate judges the tree being PUSHED, resolved now. Hooks live in the common
# .git/hooks and are shared by every worktree, so a root baked in at install time
# made a worktree push read the MAIN tree — and because git exports GIT_DIR to
# hooks, a plain 'git -C <other tree>' compared one tree's index against another
# tree's files and refused the push as "dirty". Never bake in a tree; never let
# the exported GIT_DIR cross trees.
root="\$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
git_at() { git --git-dir="\$root/.git" --work-tree="\$root" "\$@"; }
if [ -x "\$root/bin/changelog-assemble.sh" ]; then
  "\$root/bin/changelog-assemble.sh" >/dev/null 2>&1 || true
  # If folding changed the ledger, it is now a working-tree change the push does
  # not carry. Say so loudly rather than pushing a ledger the fragments are not in.
  if ! git_at diff --quiet -- "$CHANGELOG" 2>/dev/null; then
    printf 'changelog-assemble[1]{state}:\n  "folded fragments into %s — commit it, then push again"\n' "$CHANGELOG" >&2
    exit 1
  fi
fi
"\$root/bin/branch-guard.sh" <"\$refs" || exit 1
"\$root/bin/changelog-guard.sh" <"\$refs" || exit 1
exit 0
EOF
    chmod +x "$hook"
    printf 'changelog-guard[1]{action,path}:\n  "install","%s"\n' "$hook"
    exit 0 ;;
  --range)
    rng="${2:-}"; [ -n "$rng" ] || usage
    base="${rng%%..*}"; head="${rng##*..}"
    changes_touch_changelog "$base" "$head" || verdict blocked
    verdict ok ;;
  --all)
    # Every tracked CHANGELOG must exist and be non-empty.
    [ -s "$ROOT/$CHANGELOG" ] || verdict blocked
    verdict ok ;;
  "") : ;;
  *) usage ;;
esac

[ "${YMIR_SKIP_CHANGELOG_GUARD:-0}" = "1" ] && {
  printf 'changelog-guard[1]{gate,result}:\n  "push","skipped (YMIR_SKIP_CHANGELOG_GUARD=1)"\n'
  exit 0
}

# Hook mode: the refs git hands a pre-push hook, one per line:
#   <local_ref> <local_sha> <remote_ref> <remote_sha>
pushed=0
while read -r local_ref local_sha remote_ref remote_sha; do
  [ -n "${local_ref:-}" ] || continue
  case "$local_ref" in "$ZERO"|"") continue ;; esac
  pushed=1
  check_ref "$local_sha" "$remote_sha" && verdict ok
done

# Nothing pushable on stdin (a manual run): measure HEAD against the trunk.
if [ "$pushed" = "0" ]; then
  for default_ref in "origin/main" "origin/master" "origin/HEAD"; do
    git -C "$ROOT" rev-parse --verify --quiet "$default_ref" >/dev/null 2>&1 || continue
    base="$(git -C "$ROOT" merge-base HEAD "$default_ref" 2>/dev/null || true)"
    changes_touch_changelog "$base" "HEAD" && verdict ok
    break
  done
fi

verdict blocked
