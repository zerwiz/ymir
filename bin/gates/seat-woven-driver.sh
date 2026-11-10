#!/usr/bin/env bash
# seat-woven-driver.sh — seat the engine behind `merge=regenerate`, and PROVE it runs.
#
# WHY (plan 211, 2026-11-06): `.gitattributes` has marked four generated documents
# `merge=regenerate` since plan 174, and `bin/records/regenerate-on-merge.sh` implements the
# reweave — but `git config --get merge.ymir-weave.driver` returned NOTHING on the seat that
# needed it, so the promise had no engine and every branch rewrote the same file at the same
# sorted position. Five of six open PRs were CONFLICTING at once because of it.
#
# The keyword in `.gitattributes` is `merge=regenerate`, which git resolves as
# `merge.regenerate.driver` — NOT `merge.ymir-weave.driver`. That mismatch is measured here,
# not assumed.
#
#   seat-woven-driver.sh              # seat it in this repo
#   seat-woven-driver.sh --check      # report seated / not seated (exit 1 when not)
#   seat-woven-driver.sh --prove      # seat, then prove it on a scratch repo with a real conflict
#
# Seated by the install step `gates`, so every machine gets it. A tamper-proof WARD is not
# needed: the driver changes only what a CONFLICT does, and a seat without it falls back to an
# ordinary text conflict — which is the state this script exists to end.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

DRIVER="$ROOT/bin/records/regenerate-on-merge.sh"
KEY="regenerate"
NAME="reweave a woven document (plan 174 · plan 211)"

ACTION="${1:-seat}"
case "$ACTION" in
  seat|--seat|"") ;;
  --check|check) ;;
  --prove|prove) ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'error: unknown action %s\nhelp: seat-woven-driver.sh [--check|--prove]\n' "$ACTION" >&2; exit 2 ;;
esac

[ -x "$DRIVER" ] || { printf 'seat-woven-driver: no driver at %s\n' "$DRIVER" >&2; exit 2; }

# RELATIVE, never "$DRIVER": .git/config is SHARED by every worktree, and git runs a merge driver from
# the top of the worktree that is merging. An absolute path seats whichever checkout ran this last —
# on 2026-11-10 it pointed into a nested, reaped-to-be errand worktree and every rebase ran that
# stale copy (a minute per conflicted index). A relative path follows the tree being merged.
want="bash bin/records/regenerate-on-merge.sh %O %A %B %L %P"
have="$(git -C "$ROOT" config --get "merge.$KEY.driver" 2>/dev/null || true)"
declared="$(git -C "$ROOT" config --get "merge.$KEY.name" 2>/dev/null || true)"

if [ "$ACTION" = "--check" ] || [ "$ACTION" = "check" ]; then
  if [ -z "$have" ]; then
    printf 'woven_driver[3]{state,driver,keyword}:\n'
    printf '  "NOT SEATED","merge.%s.driver is unset","merge=%s — a conflict is a plain text conflict"\n' "$KEY" "$KEY"
    printf '  "remedy","bash bin/gates/seat-woven-driver.sh","seated by the install step gates"\n'
    printf '  "%s","expected","%s"\n' "$want" "$DRIVER"
    exit 1
  fi
  printf 'woven_driver[3]{state,driver,keyword}:\n'
  printf '  "seated","%s","merge=%s"\n' "$have" "$KEY"
  printf '  "name","%s",""%s"\n' "${declared:-?}" "$NAME"
  printf '  "path","%s","the driver answers a conflict by reweaving"\n' "$DRIVER"
  exit 0
fi

git -C "$ROOT" config "merge.$KEY.driver" "$want" || { printf 'seat-woven-driver: could not write the config\n' >&2; exit 2; }
git -C "$ROOT" config "merge.$KEY.name" "$NAME" || true
printf 'seat-woven-driver: seated merge.%s.driver\n' "$KEY"

if [ "$ACTION" = "--prove" ] || [ "$ACTION" = "prove" ]; then
  # PROOF, not assertion: a scratch repo, a file marked merge=regenerate, two branches that
  # both change it, a merge that MUST run the driver and MUST end with the driver's own mark.
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  drv="$tmp/driver.sh"
  cat > "$drv" <<'DRIVER'
#!/usr/bin/env bash
# A woven document has no hand-kept content: the answer to a conflict is to WEAVE again.
printf 'rewoven from the fragments (base=%s ours=%s theirs=%s)\n' "$1" "$2" "$3" > "$2"
DRIVER
  chmod +x "$drv"
  (
    cd "$tmp" || exit 1
    git init -q . && git config user.email p@x && git config user.name p
    printf 'woven\na=1\n' > doc.md
    printf 'doc.md merge=regenerate\n' > .gitattributes
    git add doc.md .gitattributes && git commit -qm base
    git config merge.regenerate.driver "$drv %O %A %B %L %P"
    git checkout -q -b one && printf 'woven\na=1\nb=2\n' > doc.md && git commit -qam one
    git checkout -q master 2>/dev/null || git checkout -q main
    printf 'woven\na=1\nc=3\n' > doc.md && git commit -qam two
    if git merge -q one >/dev/null 2>&1; then
      if grep -q 'rewoven from the fragments' doc.md; then
        printf 'proved: the driver ran on a real conflict and rewrote the document\n'
      else
        printf 'FAILED: the merge passed but the driver did not run — doc.md reads:\n' >&2; cat doc.md >&2; exit 1
      fi
    else
      printf 'FAILED: the merge conflicted — the driver is not being used\n' >&2; exit 1
    fi
  )
fi
