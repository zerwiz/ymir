#!/usr/bin/env bash
# changelog-guard.sh — every push must carry a CHANGELOG entry.
#
# The house law: a change that ships is a change that was told. CHANGELOG.md is
# append-only (RULES/06-append-only.md) and is the record the operator reads
# after the fact. This guard refuses a push whose range never touches it, so the
# record can never lag silently behind the code.
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
ZERO="0000000000000000000000000000000000000000"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

# changes_touch_changelog <base> <head> — exit 0 when CHANGELOG.md differs
changes_touch_changelog() {
  local base=${1-} head=${2-} f
  [ -n "$head" ] || return 1
  if [ -z "$base" ]; then
    # No base to compare against (root commit range): look at every commit.
    f="$(git -C "$ROOT" ls-tree -r --name-only "$head" -- "$CHANGELOG" 2>/dev/null)"
    [ -n "$f" ] && return 0
    return 1
  fi
  git -C "$ROOT" diff --name-only "$base" "$head" -- "$CHANGELOG" 2>/dev/null | grep -q . && return 0
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
  changes_touch_changelog "$base" "$local_sha"
}

verdict() {  # <ok|blocked>
  if [ "$1" = "ok" ]; then
    printf 'changelog-guard[1]{gate,result}:\n  "push","ok"\n'
    exit 0
  fi
  cat >&2 <<'EOF'
changelog-guard: blocked — this push carries no CHANGELOG entry.

  Every change that ships is a change that was told. Append an entry to
  CHANGELOG.md under the current date (append-only — never rewrite an
  existing entry; RULES/06-append-only.md), commit it, and push again.

  Deliberate override, when an entry truly does not belong:
    YMIR_SKIP_CHANGELOG_GUARD=1 git push ...
EOF
  printf 'error: changelog-guard blocked the push (no CHANGELOG.md change in range)\n' >&2
  printf 'help: append a CHANGELOG entry, or set YMIR_SKIP_CHANGELOG_GUARD=1\n' >&2
  exit 1
}

case "${1:-}" in
  -v|-V|--version) printf '1.0.0\n'; exit 0 ;;
  -h|--help) usage ;;
  --install)
    hook="$ROOT/.git/hooks/pre-push"
    mkdir -p "$(dirname "$hook")" || exit 1
    cat >"$hook" <<EOF
#!/usr/bin/env bash
# pre-push hook — the delivery gate. Installed by bin/changelog-guard.sh --install.
#   1. branch-guard   — Rule 08: never push a protected branch
#   2. changelog-guard — every push carries a CHANGELOG entry
set -u
refs="\$(mktemp)"
trap 'rm -f "\$refs"' EXIT
cat >"\$refs"
"$SCRIPT_DIR/branch-guard.sh" <"\$refs" || exit 1
"$SCRIPT_DIR/changelog-guard.sh" <"\$refs" || exit 1
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
