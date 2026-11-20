#!/usr/bin/env bash
# park.sh — the SURVIVAL push: an errand's commits leave this disk without paying the whole gate.
#
# WHY (plan 339.1, 2026-11-20). Three finished branches never left the machine that day, because the
# only road off the disk was a delivery push, and a delivery push pays every ward. A crash would have
# taken them. Parking is not delivery:
#
#   · the commits go to refs/parked/<errand> — a ref, NOT a branch: no PR can be opened from it,
#     nothing merges from it, and `git clone` does not fetch it;
#   · only the PRIVACY wards judge it (secret, public-data, and the NDA gate) — what may never be
#     published is still never published; everything else waits for the delivery push;
#   · the delivery road is untouched: the work still ships by `bin/forge/gather.sh` and a PR.
#
# THE ROAD IS OFF until the operator names where parked refs may go (plan 339, question 2: may they go
# to the public repository, or only to a private mirror?). It arms only when a remote is named:
#   YMIR_PARK_REMOTE=<remote>         (env), or
#   PARK_REMOTE=<remote>              in $YMIR_HOME/config/park.env  (the operator's own word)
# A remote that is not configured in this checkout is refused, never guessed.
#
# Usage:
#   park.sh <errand>            park HEAD as refs/parked/<errand>
#   park.sh <errand> --dry-run  say what would be parked, push nothing
#   park.sh --list              the parked refs on the remote
#   park.sh --restore <errand>  fetch refs/parked/<errand> into the local branch eindri/<errand>
#   park.sh --drop <errand>     delete refs/parked/<errand> once the work has shipped
#
# Exit: 0 done · 1 a fault or a ward refused · 2 usage · 3 the road is off (not configured).
set -u
VERSION="1.0.0"
REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)"

err() { printf 'error: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf 'help: %s\n' "$2" >&2; exit "${3:-1}"; }

ACT="park"; ID=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    --dry-run) DRY=1 ;;
    --list) ACT=list ;;
    --restore) ACT=restore; ID="${2-}"; shift ;;
    --drop) ACT=drop; ID="${2-}"; shift ;;
    -*) err "unknown flag $1" "park.sh --help" 2 ;;
    *) ID="$1" ;;
  esac
  shift
done

# the errand id is a ref component: plain words only, never a path that climbs or a refspec
case "$ID" in *..*|*/*|*:*|*' '*|-*) err "'$ID' is not an errand id" "an errand id is one word, e.g. push-road" 2 ;; esac
[ "$ACT" = list ] || [ -n "$ID" ] || err "name the errand" "park.sh <errand>" 2

# ── where parked refs may go: the operator's word, or nothing ────────────────────────────────
REMOTE="${YMIR_PARK_REMOTE:-}"
if [ -z "$REMOTE" ]; then
  home=""
  if [ -n "$REPO_ROOT" ] && [ -r "$REPO_ROOT/bin/vault/hoard-lib.sh" ]; then
    # shellcheck disable=SC1091
    home="$(. "$REPO_ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1; ymir_home_root h 2>/dev/null; printf '%s' "${h:-}")"
  fi
  [ -n "$home" ] || home="${YMIR_HOME:-}"
  if [ -n "$home" ] && [ -r "$home/config/park.env" ]; then
    REMOTE="$(sed -n 's/^PARK_REMOTE=//p' "$home/config/park.env" | tail -1 | tr -d "\"' ")"
  fi
fi
if [ -z "$REMOTE" ]; then
  printf 'park[1]{state,why}:\n  "off","no parking remote is named — the Allfather has not ruled where refs/parked/* may go (plan 339, question 2)"\n'
  printf 'help: when he rules, name it once: PARK_REMOTE=<remote> in $YMIR_HOME/config/park.env\n' >&2
  exit 3
fi
git remote get-url "$REMOTE" >/dev/null 2>&1 || err "the parking remote '$REMOTE' is not configured in this checkout" "git remote -v names the ones that are"

case "$ACT" in
  list)
    printf 'parked{ref,sha}:\n'
    git ls-remote "$REMOTE" 'refs/parked/*' | while read -r sha ref; do printf '  "%s","%s"\n' "$ref" "${sha:0:12}"; done
    exit 0 ;;
  restore)
    git fetch -q "$REMOTE" "refs/parked/$ID" || err "no refs/parked/$ID on $REMOTE"
    if git show-ref --verify --quiet "refs/heads/eindri/$ID"; then
      git merge-base --is-ancestor "eindri/$ID" FETCH_HEAD \
        || err "eindri/$ID exists here and is not an ancestor of the parked sha" "inspect: git log eindri/$ID..FETCH_HEAD"
    fi
    git branch -f "eindri/$ID" FETCH_HEAD >/dev/null || err "could not set eindri/$ID (is it checked out here?)"
    printf 'park[1]{action,errand,branch,sha}:\n  "restored","%s","eindri/%s","%s"\n' "$ID" "$ID" "$(git rev-parse --short FETCH_HEAD)"
    exit 0 ;;
  drop)
    YMIR_PARK_ALLOW=1 git push -q "$REMOTE" ":refs/parked/$ID" || err "could not delete refs/parked/$ID on $REMOTE"
    printf 'park[1]{action,errand}:\n  "dropped","%s"\n' "$ID"
    exit 0 ;;
esac

# ── park ─────────────────────────────────────────────────────────────────────────────────────
sha="$(git rev-parse HEAD)" || err "no HEAD here"
branch="$(git rev-parse --abbrev-ref HEAD)"
fork="$(git merge-base HEAD origin/main 2>/dev/null || printf 'HEAD')"
ahead="$(git rev-list --count "$fork..HEAD" 2>/dev/null || printf '?')"
row() { printf 'park[1]{errand,branch,sha,commits,remote,ref}:\n  "%s","%s","%s","%s","%s","refs/parked/%s"\n' "$ID" "$branch" "${sha:0:12}" "$ahead" "$REMOTE" "$ID"; }
if [ "$DRY" = 1 ]; then
  row
  printf 'dry-run: would push HEAD to %s refs/parked/%s, judged by the privacy wards only\n' "$REMOTE" "$ID"
  exit 0
fi
[ -z "$(git status --porcelain --untracked-files=no)" ] || printf 'warning: uncommitted changes are NOT parked — only commits leave the disk\n' >&2
# A parked ref is overwritten as the errand moves on (survival keeps the newest), so the push is
# forced — but only over the ref this road owns, and with a lease on what was there.
YMIR_PARK_ALLOW=1 git push -q --force-with-lease="refs/parked/$ID" "$REMOTE" "HEAD:refs/parked/$ID" \
  || err "the parked push was refused — see the ward rows above"
row
printf 'park: survival only — this is not a delivery; the work still ships by bin/forge/gather.sh and a PR\n'
