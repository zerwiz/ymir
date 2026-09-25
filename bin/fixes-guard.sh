#!/usr/bin/env bash
# fixes-guard.sh — the delivery gate reads, and it checks the RECORD.
#
# What it replaces, and why: `changelog-guard` passed if a push range merely
# *touched* CHANGELOG.md — a stray line satisfied it, so it never verified that
# anything was recorded. And the hook in front of it FOLDED fragments into the
# monolith, mutating the tree mid-push and then demanding a commit for the edit it
# had just made.
#
# This gate only READS. A push must carry at least one new fix note
# (`docs/fixes/<component>/<version>-<slug>.md`), and it says which of the push's
# touched paths that note's component covers — a mismatch is reported, never
# silently accepted.
#
#   fixes-guard.sh --install     # seat it as the pre-push hook (replacing the old one)
#   fixes-guard.sh --check       # judge the current branch against its base, by hand
#   git push                     # the hook runs it with the refs on stdin
#
# Override, loudly: YMIR_SKIP_FIXES_GUARD=1
#
# Exit: 0 the record is there, 1 it is not, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT" || exit 1

[ "${YMIR_SKIP_FIXES_GUARD:-0}" = 1 ] && { printf 'fixes-guard[1]{gate,result}:\n  "push","skipped (YMIR_SKIP_FIXES_GUARD=1)"\n'; exit 0; }

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --install)
    H="$(git rev-parse --git-path hooks)/pre-push"
    mkdir -p "$(dirname "$H")"
    cat >"$H" <<EOF
#!/usr/bin/env bash
# pre-push — the delivery gate. Installed by bin/fixes-guard.sh --install.
#   1. guards       — the TREE wards: the tree is not a runtime, and one place knows where
#                     things live. First, because it is fast and a dirty tree should fail
#                     before anything else is argued about.
#   2. branch-guard — never push a protected branch.
#   3. fixes-guard  — every push carries a fix note for what it changed.
set -u
refs="\$(mktemp)"; trap 'rm -f "\$refs"' EXIT
cat >"\$refs"
"$ROOT/bin/guards.sh" || exit 1
"$ROOT/bin/branch-guard.sh" <"\$refs" || exit 1
"$ROOT/bin/fixes-guard.sh" <"\$refs" || exit 1
EOF
    chmod +x "$H"
    printf 'fixes-guard[1]{gate,result}:\n  "hook","installed at %s"\n' "${H#"$ROOT"/}"
    exit 0 ;;
  --check) ;;
  "") ;;
  *) printf 'error: unknown flag %s\nhelp: bin/fixes-guard.sh [--install|--check]\n' "$1" >&2; exit 2 ;;
esac

# ── the judgement ────────────────────────────────────────────────────────────
# The range: from stdin when a hook calls us, else the branch against its base.
refs="$(cat 2>/dev/null || true)"
head_sha=""; remote_sha=""
if [ -n "$refs" ]; then
  while read -r _local local_sha _remote remote_sha2; do
    [ -n "${local_sha:-}" ] || continue
    case "$local_sha" in 000000*) continue ;; esac
    head_sha="$local_sha"; remote_sha="${remote_sha2:-}"
  done <<<"$refs"
fi
[ -n "$head_sha" ] || head_sha="$(git rev-parse HEAD)"

base=""
if [ -n "$remote_sha" ] && [ "$remote_sha" != 0000000000000000000000000000000000000000 ]; then
  base="$remote_sha"
else
  for cand in origin/main main master; do
    git rev-parse --verify -q "$cand" >/dev/null 2>&1 || continue
    base="$(git merge-base "$head_sha" "$cand" 2>/dev/null || true)"
    [ -n "$base" ] && break
  done
fi
[ -n "$base" ] || { printf 'fixes-guard[1]{gate,result}:\n  "push","no base to compare — first push of a branch is judged on its own"\n'; exit 0; }

range="${base}..${head_sha}"
# The note's name is <version>-<slug>.md, and a version is whatever bin/fixes.sh was
# TOLD it is: `--version=unversioned` is legitimate, and 158 of the repo's notes use
# it. Accepting only a digit-first version made the gate blind to those notes and
# refused every push that carried one (2026-09-25) — the guard demanded a format its
# own writer does not require. A note the gate cannot SEE is a note it cannot judge.
notes="$(git diff --name-only --diff-filter=A "$range" 2>/dev/null | grep -E '^docs/fixes/[a-z]+/([0-9]|unversioned-)[^/]*\.md$' || true)"
touched="$(git diff --name-only "$range" 2>/dev/null | grep -v '^docs/fixes/' | grep -v '^CHANGELOG' || true)"

if [ -z "$notes" ]; then
  printf 'fixes-guard[1]{gate,result}:\n  "push","refused — no fix note in this range"\n' >&2
  printf 'help: bin/fixes.sh record --component=<%s> --version=<v> --title="what changed"\n' \
    "install|runtime|skills|agents|hlidskjalf|odrerir|sessrumnir|smidja|hoard|gate" >&2
  printf 'note: a note is a file under docs/fixes/<component>/ — write one, commit it, push again.\n' >&2
  exit 1
fi

# The record is there: now say whether it speaks to what the push changed.
covered=0
for n in $notes; do
  c="$(printf '%s' "${n#docs/fixes/}" | cut -d/ -f1)"
  case "$touched" in
    *"$c"*) covered=$((covered+1)) ;;
    *bin/fixes*|*install*) [ "$c" = install ] && covered=$((covered+1)) ;;
    *bin/ymir*|*bin/sessrumnir*|*bin/smidja*|*bin/npm-publish*|*.agents/skills/*) covered=$((covered+1)) ;;
  esac
done

count="$(printf '%s\n' "$notes" | grep -c . || true)"
if [ "$covered" -gt 0 ]; then
  printf 'fixes-guard[1]{gate,result}:\n  "push","ok — %s note(s), and the record speaks to the change"\n' "$count"
else
  printf 'fixes-guard[1]{gate,result}:\n  "push","ok — %s note(s); none names a path this range touched"\n' "$count"
  printf 'note: a note for another component is still a record — but say what THIS push changed.\n' >&2
  printf '      components touched: %s\n' "$(printf '%s' "$touched" | head -4 | tr '\n' ' ')" >&2
fi
exit 0
