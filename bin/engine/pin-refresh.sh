#!/usr/bin/env bash
# pin-refresh.sh — bring the PINNED runtime to main, from a tree that is NOT the pin.
#
#   bin/engine/pin-refresh.sh             fetch, then fast-forward the pin to origin/<branch>
#   bin/engine/pin-refresh.sh --check     report only; exit 3 when the pin is behind, absent or dirty
#   bin/engine/pin-refresh.sh --quiet     one line instead of the TOON block
#   bin/engine/pin-refresh.sh --from-tree DIR   run the copy of this door in DIR (which must not be the pin)
#   bin/engine/pin-refresh.sh --auto-tree       find such a tree (the source checkout, then a release) and use it
#   bin/engine/pin-refresh.sh --help
#
# WHY THIS DOOR EXISTS (measured 2026-11-15). Every Ymir unit and app runs from the pinned runtime
# (plan 269). That pin is refreshed by Gróa's update step, which calls bin/engine/runtime-seat.sh —
# and on the heart Gróa itself runs FROM the pin, because the scheduler runs there. So a pin that
# froze before the refresh step existed could never mend itself: on 2026-11-15 the heart's pin stood
# 75 commits behind main and sixteen cron rows answered 127 ("No such file or directory") for 28
# days, 213 failing runs, first 2026-10-12T21:00Z. A refresher that lives inside the thing it
# refreshes is not a refresher.
#
# THE LAW THIS DOOR ENFORCES, and it is the refusal that carries it:
#   the refresh is applied only from a tree OTHER than the pin.
# A script seated inside the pin proves nothing about the pin — if its copy is stale, the stale copy
# is what runs. So `--check` answers anywhere (a question about the pin is always fair), and the
# apply path refuses with exit 4 when this script's own root IS the pin, naming a tree to run it from.
#
# Read-only on everything except the pin's working tree, and one append-only log line at
# <state>/pin-refresh.log. Configuration (Rule 07): YMIR_RUNTIME_DIR · YMIR_RUNTIME_BRANCH from
# <home>/config/runtime.env, with the documented defaults ~/ymir-runtime and main.
#
# Exit: 0 current (or refreshed) · 3 behind/absent/dirty on --check · 4 refused (this tree is the pin)
#       6 the pin is a release: never merged in place, Gróa builds and flips a new one (2026-11-20)
#       5 the fast-forward failed (the pin has diverged) · 2 usage · 1 no pin/configuration at all.
set -uo pipefail

VERSION="1.0.0"
HERE="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)"
[ -n "$ROOT" ] || ROOT="$(CDPATH='' cd "$HERE/../.." && pwd)"
ROOT="$(cd "$ROOT" && pwd)"

# The home is resolved by the one resolver, never restated (Rule 07).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$HERE/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi
home="${YMIR_HOME:-}"
if [ -z "$home" ] && declare -f ymir_home_root >/dev/null 2>&1; then ymir_home_root home 2>/dev/null; fi
[ -n "$home" ] || home="$ROOT"
STATE_DIR="${YMIR_STATE_DIR:-$home/state}"
if [ -z "${YMIR_STATE_DIR:-}" ] && declare -f hoard_state_dir >/dev/null 2>&1; then
  hoard_state_dir STATE_DIR 2>/dev/null || STATE_DIR="$home/state"
fi

mode=apply
quiet=0
FROM_TREE=""
AUTO_TREE=0
while [ $# -gt 0 ]; do
  case "$1" in
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --check) mode=check ;;
    --quiet|-q) quiet=1 ;;
    --from-tree) shift; FROM_TREE="${1:-}" ;;
    --auto-tree) AUTO_TREE=1 ;;
    "") ;;
    *) printf 'error: unknown option %s\nhelp: bin/engine/pin-refresh.sh [--check] [--quiet]\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

conf="$home/config/runtime.env"
[ -r "$conf" ] && . "$conf"
PIN="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"
BRANCH="${YMIR_RUNTIME_BRANCH:-main}"

say() { [ "$quiet" = 1 ] || printf '%s\n' "$*"; }
verdict() {  # <state> <behind> <detail> <rc>
  if [ "$quiet" = 1 ]; then
    printf 'pin: %s — %s\n' "$1" "$3"
  else
    printf 'pin-refresh[5]{fact,value}:\n'
    printf '  "pin","%s"\n' "$PIN"
    printf '  "branch","%s"\n' "$BRANCH"
    printf '  "state","%s"\n' "$1"
    printf '  "behind","%s"\n' "$2"
    printf '  "detail","%s"\n' "$3"
  fi
  exit "${4:-0}"
}

[ -e "$PIN" ] || verdict absent 0 "no pinned runtime at $PIN — run bin/engine/runtime-seat.sh" 3
[ -d "$PIN/.git" ] || verdict not-a-checkout 0 "$PIN exists and is not a git checkout" 3
command -v git >/dev/null 2>&1 || verdict no-git 0 "git is not on PATH — cannot tell" 3

# THE SCHEDULE'S ROAD (2026-11-20). The scheduler on this machine runs FROM the pin, so the one place this door
# must not run is exactly the place a schedule finds it — and so the refresher was never scheduled at all, only
# measured weekly. `--auto-tree` resolves a tree that is not the pin and re-execs ITS copy of this door, which
# keeps the refusal intact: the code that moves the pin is still never the pin's own possibly-stale copy.
if [ "$mode" = apply ] && { [ -n "$FROM_TREE" ] || [ "$AUTO_TREE" = 1 ]; }; then
  pin_real0="$(cd "$PIN" 2>/dev/null && pwd -P)"
  tree="$FROM_TREE"
  tries=""
  if [ -z "$tree" ] && [ "$AUTO_TREE" = 1 ]; then
    for cand in "${YMIR_SOURCE_TREE:-}" "$HOME/ymir" "${YMIR_RELEASES:-$HOME/.local/share/ymir}/current"; do
      [ -n "$cand" ] || continue
      tries="$tries $cand"
      [ -d "$cand" ] || continue
      [ "$(cd "$cand" 2>/dev/null && pwd -P)" = "$pin_real0" ] && continue
      [ -x "$cand/bin/engine/pin-refresh.sh" ] || continue
      tree="$cand"; break
    done
  fi
  if [ -z "$tree" ] || [ ! -x "$tree/bin/engine/pin-refresh.sh" ]; then
    verdict no-source-tree 0 "no tree to run from: tried${tries:- (none)} — set YMIR_SOURCE_TREE, or run Gróa from the working tree" 4
  fi
  tree_real="$(cd "$tree" 2>/dev/null && pwd -P)"
  [ "$tree_real" = "$pin_real0" ] && verdict refused 0 "the tree named IS the pin ($tree) — a refresher seated in the thing it refreshes proves nothing" 4
  if [ "$quiet" = 1 ]; then exec "$tree/bin/engine/pin-refresh.sh" --quiet
  else exec "$tree/bin/engine/pin-refresh.sh"; fi
fi

# THE REFUSAL. The apply path must not run from inside the pin: a refresher in the thing it refreshes
# cannot be trusted to be current, and that is exactly how the heart's pin froze for 28 days.
if [ "$mode" = apply ]; then
  pin_real="$(cd "$PIN" 2>/dev/null && pwd -P)"
  root_real="$(cd "$ROOT" 2>/dev/null && pwd -P)"
  if [ -n "$pin_real" ] && [ "$pin_real" = "$root_real" ]; then
    if [ "$quiet" = 1 ]; then
      printf 'pin: refused — this door lives inside the pin (%s); run it from the working tree\n' "$PIN"
    else
      printf 'pin-refresh[3]{fact,value,why}:\n'
      printf '  "refused","this door lives inside the pin","a refresher seated in the thing it refreshes proves nothing: if its copy is stale, the stale copy is what runs"\n'
      printf '  "pin","%s"\n' "$PIN"
      printf '  "run_it_from","the working tree that seats the pin (e.g. ~/ymir) — bin/engine/pin-refresh.sh"\n'
    fi
    exit 4
  fi
fi

# Local edits are reported, never pre-empted: a seat renders its own agent cards into the tree it runs
# from, so a pin with a modified card is normal, and a fast-forward that does not touch those files is
# safe. What must never happen is an edit being OVERWRITTEN by a schedule — so the door attempts the
# merge and lets git refuse, which it does, rather than deciding for git what is safe.
dirty="$(git -C "$PIN" status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')"
untracked="$(git -C "$PIN" status --porcelain --untracked-files=all 2>/dev/null | grep -c '^??' || true)"

git -C "$PIN" fetch -q origin "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH" 2>/dev/null
if [ $? -ne 0 ]; then
  verdict unreadable 0 "could not fetch origin/$BRANCH (offline, or no remote) — nothing changed" 3
fi

head="$(git -C "$PIN" rev-parse --short HEAD 2>/dev/null)"
target="$(git -C "$PIN" rev-parse --short "origin/$BRANCH" 2>/dev/null)"
behind="$(git -C "$PIN" rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || printf '0')"
ahead="$(git -C "$PIN" rev-list --count "origin/$BRANCH..HEAD" 2>/dev/null || printf '0')"

# A pin that is a LINK to a release (plan 275 S9) is never merged in place (2026-11-20). A release is a proved copy
# named for its sha; on the dev machine this door fast-forwarded releases/abefc4f06932 to 149f38ebd, so the seat ran code
# its proof never saw under a name that lied. A release is moved by building a new one beside it and flipping:
# bin/engine/runtime-deploy.sh, which Gróa runs. This door reports, and refuses the merge.
if [ -L "$PIN" ]; then
  rel_name="$(basename "$(cd "$PIN" 2>/dev/null && pwd -P)")"
  rel_head="$(git -C "$PIN" rev-parse HEAD 2>/dev/null)"
  case "$rel_name" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) case "$rel_head" in "$rel_name"*) ;; *)
      verdict moved-in-place "$behind" "release $rel_name carries ${rel_head:0:12} — it was merged in place; Gróa (bin/engine/runtime-deploy.sh) builds and flips an honest one" "$([ "$mode" = check ] && echo 3 || echo 6)" ;; esac ;;
  esac
  if [ "${behind:-0}" != 0 ] && [ "$mode" = apply ]; then
    verdict release-road "$behind" "the pin is a release, never merged in place — Gróa (bin/engine/runtime-deploy.sh) builds a new release of origin/$BRANCH and flips it" 6
  fi
fi

if [ "${ahead:-0}" != 0 ]; then
  verdict diverged "$behind" "$ahead commit(s) on the pin are not on origin/$BRANCH — a human must decide" 5
fi
if [ "${behind:-0}" = 0 ]; then
  if [ "$quiet" = 1 ]; then
    printf 'pin: %s at %s (current)\n' "$BRANCH" "$head"
  else
    printf 'pin-refresh[3]{fact,value}:
'
    printf '  "pin","%s"\n' "$PIN"
    printf '  "head","%s"\n' "$head"
    printf '  "state","current"\n'
  fi
  exit 0
fi

if [ "$mode" = check ]; then
  if [ "$quiet" = 1 ]; then printf 'pin: %s behind main at %s — bin/engine/pin-refresh.sh from the working tree\n' "$behind" "$head"
  else
    # THE STATE IS ALWAYS A FACT (2026-11-17). The current-verdict block prints `state`; this one
    # printed only the number, so a reader had to infer "behind" from the presence of `behind` — and
    # a consumer that asked for `state` got nothing and called a behind pin unreadable.
    printf 'pin-refresh[5]{fact,value}:\n'
    printf '  "pin","%s"\n' "$PIN"
    printf '  "head","%s"\n' "$head"
    printf '  "state","behind"\n'
    printf '  "behind","%s"\n' "$behind"
    printf '  "detail","the pin is behind origin/%s — a refresher outside the pin brings it home"\n' "$BRANCH"
  fi
  exit 3
fi

if ! git -C "$PIN" merge --ff-only "origin/$BRANCH" >/dev/null 2>&1; then
  verdict ff-failed "$behind" "git refused the fast-forward (a local edit would be overwritten, or the history diverged) — nothing changed; see git -C $PIN status" 5
fi
after="$(git -C "$PIN" rev-parse --short HEAD 2>/dev/null)"
mkdir -p "$STATE_DIR" 2>/dev/null || true
printf '%s pin-refresh: %s %s..%s (+%s) from %s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$BRANCH" "$head" "$after" "$behind" "$ROOT" \
  >>"$STATE_DIR/pin-refresh.log" 2>/dev/null || true

if [ "$quiet" = 1 ]; then
  printf 'pin: %s moved %s..%s (+%s) — now current\n' "$BRANCH" "$head" "$after" "$behind"
else
  printf 'pin-refresh[5]{fact,value}:\n'
  printf '  "pin","%s"\n' "$PIN"
  printf '  "branch","%s"\n' "$BRANCH"
  printf '  "before","%s"\n' "$head"
  printf '  "after","%s"\n' "$after"
  printf '  "state","refreshed"\n'
  printf '  "moved","%s commit(s) toward origin/%s"\n' "$behind" "$BRANCH"
fi
exit 0
