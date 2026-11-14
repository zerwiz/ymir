#!/usr/bin/env bash
# release.sh — Ymir runs from a RELEASE: a complete, built, proved copy behind one link (plan 275 S9; plans 80 and 226).
#
#   bin/engine/release.sh build [--ref <ref>] [--from <repo>]   build releases/<sha>: clone, install (Electron included),
#                                                              build every app, then prove it; prints the release dir
#   bin/engine/release.sh prove <dir|sha>                      the proof alone (every app; changes nothing)
#   bin/engine/release.sh flip <sha>                           point `current` at a PROVED release (one atomic rename)
#   bin/engine/release.sh rollback                             point `current` back at the release before it
#   bin/engine/release.sh adopt                                turn the old in-place pin into the first release (once)
#   bin/engine/release.sh status                               what current is, what is kept, what is proved
#
# WHY (measured 2026-11-12 on the dev machine and on a second one). The pin was a git checkout moved in place with
# `git reset --hard` under open windows; dependencies were installed only on a fresh clone and without Electron
# (a dev dependency); no app was built (Hlidskjalf served Vite's DEV server, Sessrúmnir built itself at the click);
# and every app found its own Electron (v33.0.0, v33.4.11, v43.7.3, the distribution's 43.8.3 and 41). This door ends
# that: an update builds a NEW folder beside the running one, proves every app in it without opening a window on the
# desk, and only then moves one link. An open window keeps the release it started from; a rollback is the same move.
#
# Layout (Rule 07 — every path resolved, one documented default each):
#   YMIR_RELEASES       $XDG_DATA_HOME/ymir (~/.local/share/ymir)    releases/<sha>, current, shared/
#   YMIR_RUNTIME_DIR    ~/ymir-runtime — after `adopt` a LINK to <YMIR_RELEASES>/current, so every unit, launcher and
#                       script that names the pin keeps working unchanged
#   YMIR_RELEASE_KEEP   3 — releases kept beside current
# State a running Ymir writes inside its tree (.run, state, .a2a, .yggdrasil, opencode.json, …) lives ONCE in shared/
# and is linked into each release, so a flip never loses it. Private data stays in $YMIR_HOME (RULES/04).
set -uo pipefail

SELF="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DEFAULT="$(CDPATH='' cd "$SELF/../.." && pwd)"
BASE="${YMIR_RELEASES:-${XDG_DATA_HOME:-$HOME/.local/share}/ymir}"
REL="$BASE/releases"; CUR="$BASE/current"; SHARED="$BASE/shared"
PIN="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"
KEEP="${YMIR_RELEASE_KEEP:-3}"
LOGDIR="$BASE/logs"
# the state a running tree writes into itself — shared across releases, never rebuilt
SHARED_PATHS=".run state .a2a .yggdrasil .hermes.md opencode.json .pi/mcp-adapter.json apps/odrerir/public/livehall.json apps/odrerir/dist/livehall.json"
# the desktop apps: name · folder · how it is built · what must exist after the build
APPS="hlidskjalf odrerir sessrumnir bilskirnir rodd"

say()  { printf '%s\n' "$*"; }
fail() { printf 'FAIL\t%s\n' "$*" >&2; exit 1; }
row()  { printf '  "%s","%s","%s"\n' "$1" "$2" "$3"; }

mkdir -p "$REL" "$SHARED" "$LOGDIR"

resolve_sha() {  # <dir|sha> → a release dir
  local a="$1"
  if [ -d "$a" ]; then (cd "$a" && pwd -P); return; fi
  local d; d="$(ls -d "$REL/$a"* 2>/dev/null | head -1)"
  [ -n "$d" ] && printf '%s' "$d"
}

# ── the shared state: one copy, linked into every release ──────────────────────────────────────────────────────
link_shared() {  # <release-dir>
  local d="$1" p
  for p in $SHARED_PATHS; do
    mkdir -p "$(dirname "$SHARED/$p")" "$(dirname "$d/$p")"
    if [ -e "$d/$p" ] && [ ! -L "$d/$p" ]; then
      # the release shipped or made one: the shared copy wins once it exists, else this one seeds it
      if [ -e "$SHARED/$p" ]; then rm -rf "$d/$p"; else mv "$d/$p" "$SHARED/$p"; fi
    fi
    case "$p" in .run|state|.a2a|.yggdrasil) mkdir -p "$SHARED/$p" ;; esac   # the folders; the rest are files
    [ -L "$d/$p" ] || ln -s "$SHARED/$p" "$d/$p"
  done
}

# ── the proof: every app, judged on fit, not presence ──────────────────────────────────────────────────────────
electron_for() {  # <release> <app> → the binary this app will run
  local d="$1" a="$2"
  # shellcheck disable=SC1091
  ( . "$d/bin/desktop/electron-lib.sh"; electron_bin "$d/apps/$a" "$d" ) 2>/dev/null
}
declared_major() {  # <release> <app> → the Electron major the app declares (empty when it declares none)
  python3 - "$1/apps/$2/package.json" <<'PY' 2>/dev/null
import json,re,sys
d=json.load(open(sys.argv[1]))
v=(d.get('dependencies',{}) or {}).get('electron') or (d.get('devDependencies',{}) or {}).get('electron') or ''
m=re.search(r'(\d+)',v); print(m.group(1) if m else '')
PY
}
prove() {  # <release> → prints a TOON table, exit 0 only when every row passes
  local d="$1" bad=0 a bin ver want out n
  n=$(echo $APPS | wc -w)
  [ -d "$d/apps/smidja-factory/apps/visualizer" ] && n=$((n+1))   # the smithy's eye is judged too
  say "release-proof[$n]{app,state,detail}:"
  for a in $APPS; do
    [ -d "$d/apps/$a" ] || { row "$a" skip "not in this release"; continue; }
    bin="$(electron_for "$d" "$a")"
    case "$a" in bilskirnir|rodd) [ -n "$bin" ] || bin="" ;; esac
    if [ -z "$bin" ]; then row "$a" FAIL "no Electron inside the release"; bad=1; continue; fi
    case "$bin" in "$d"/*) ;; *) row "$a" FAIL "Electron comes from outside the release: $bin"; bad=1; continue ;; esac
    ver="$("$bin" --version 2>/dev/null | tr -d v)"
    [ -n "$ver" ] || { row "$a" FAIL "$bin does not answer --version"; bad=1; continue; }
    want="$(declared_major "$d" "$a")"
    if [ -n "$want" ] && [ "${ver%%.*}" != "$want" ]; then row "$a" FAIL "declares Electron $want, would run $ver"; bad=1; continue; fi
    case "$a" in
      hlidskjalf|odrerir) [ -f "$d/apps/$a/dist/index.html" ] || { row "$a" FAIL "not built (no dist/index.html)"; bad=1; continue; } ;;
      sessrumnir) [ -d "$d/apps/$a/out/main" ] || { row "$a" FAIL "not built (no out/main)"; bad=1; continue; }
                  out="$(cd "$d/apps/$a" && ELECTRON_RUN_AS_NODE=1 "$bin" -e "require('node-pty');console.log('ok')" 2>&1 | tail -1)"
                  [ "$out" = ok ] || { row "$a" FAIL "node-pty does not load in Electron $ver: $out"; bad=1; continue; } ;;
      bilskirnir) [ -f "$d/apps/$a/web/dist/index.html" ] || { row "$a" FAIL "not built (no web/dist/index.html)"; bad=1; continue; } ;;
      rodd) [ -d "$d/apps/$a/ui" ] || { row "$a" FAIL "the face is not fetched (no ui/)"; bad=1; continue; } ;;
    esac
    row "$a" ok "Electron $ver from the release"
  done
  # the smithy's eye (plan 288 step 7): its bundle is built in the release, and the server that serves it
  # reads ./dist — so a release without it answers :8437 with an empty view. Judged, never assumed.
  if [ -d "$d/apps/smidja-factory/apps/visualizer" ]; then
    if [ -f "$d/apps/smidja-factory/apps/visualizer/dist/index.html" ]; then
      row visualizer ok "UI built in the release (served on :8437)"
    elif command -v bun >/dev/null 2>&1; then
      row visualizer FAIL "not built (no dist/index.html) — bun is present, so the build was skipped, not impossible"; bad=1
    else
      row visualizer skip "not built and no bun on this machine — the smithy serves its API with no UI"
    fi
  fi
  return "$bad"
}

# ── build ──────────────────────────────────────────────────────────────────────────────────────────────────────
build() {
  local ref="origin/main" from="$SRC_DEFAULT" sha url tmp log d prev
  while [ $# -gt 0 ]; do case "$1" in
    --ref) ref="$2"; shift 2 ;; --from) from="$2"; shift 2 ;; *) fail "unknown option $1" ;; esac; done
  git -C "$from" fetch -q origin 2>/dev/null || true
  sha="$(git -C "$from" rev-parse --verify -q "$ref^{commit}")" || fail "no commit $ref in $from"
  sha="${sha:0:12}"; d="$REL/$sha"
  if [ -f "$d/.release-proved" ]; then say "release	$d	already built and proved"; return 0; fi
  tmp="$REL/.building-$sha-$$"; log="$LOGDIR/build-$sha.log"; rm -rf "$tmp"
  say "build	$sha	from $from ($ref) — log $log"
  (
    # a build must never touch the running machine: no service restart, no launcher or key redrawn from this folder
    export YMIR_FLEET_DEPLOY=off YMIR_SKIP_DESKTOP=1 BILSKIRNIR_DESKTOP=0
    set -x
    git clone -q --no-checkout --local "$from" "$tmp" || exit 10
    url="$(git -C "$from" remote get-url origin 2>/dev/null)"; [ -n "$url" ] && git -C "$tmp" remote set-url origin "$url"
    git -C "$tmp" checkout -q -B main "$sha" || exit 11
    git -C "$tmp" branch -q --set-upstream-to=origin/main main 2>/dev/null || true
    prev="$(readlink -f "$CUR" 2>/dev/null)"
    # the dependency closure — a release whose lock files match the running one borrows its modules as hard links
    for m in . apps/bilskirnir apps/rodd; do
      [ -f "$tmp/$m/package-lock.json" ] || continue
      if [ -n "$prev" ] && [ -d "$prev/$m/node_modules" ] && cmp -s "$prev/$m/package-lock.json" "$tmp/$m/package-lock.json"; then
        cp -al "$prev/$m/node_modules" "$tmp/$m/node_modules" || exit 12
      else
        ( cd "$tmp/$m" && npm ci --include=dev --no-audit --no-fund ) || exit 13
      fi
    done
    # Electron's own runtime: npm may refuse its download script; the house fetch places it without npm's permission
    for a in hlidskjalf sessrumnir rodd; do
      [ -d "$tmp/apps/$a" ] || continue
      ( . "$tmp/bin/desktop/electron-lib.sh"; [ "$(electron_runtime_state "$tmp/apps/$a" "$tmp")" = ok ] || electron_fetch_runtime "$tmp/apps/$a" "$tmp" ) || exit 14
    done
    # every app built inside the release — nothing builds at a click, nothing serves a dev server
    ( cd "$tmp" && npm run build -w apps/hlidskjalf && npm run build -w apps/odrerir ) || exit 15
    ( cd "$tmp/apps/sessrumnir" && npm run build ) || exit 16
    ( cd "$tmp/apps/sessrumnir" && npx --no-install electron-builder install-app-deps ) || exit 17
    ( cd "$tmp/apps/bilskirnir" && npm run build -w web ) || exit 18
    # The smithy's EYE is a nested app with its own bun lockfile, so the root `npm ci` never installs it
    # and its bundle was never built here — a release therefore served :8437 with no UI at all
    # ("No ./dist build found"), while the tree kept a committed dist/ that hid the fault. The bundle
    # left git on 2026-11-14 (plan 288 step 7, plan 287 P4); the release builds it, or says it did not.
    if command -v bun >/dev/null 2>&1; then
      ( cd "$tmp/apps/smidja-factory/apps/visualizer" && bun install --frozen-lockfile && bunx vite build ) || exit 19
    else
      printf 'visualizer SKIP no bun on this machine — the smithy serves its API with no UI\n'
    fi
    # the house's git guards, as the installer seats them in a working tree (Eir judges the pin's hooks too)
    for h in "$tmp"/.githooks/*; do [ -f "$h" ] && install -m 755 "$h" "$tmp/.git/hooks/$(basename "$h")"; done
    link_shared "$tmp"
  ) > "$log" 2>&1
  local rc=$?
  if [ "$rc" != 0 ]; then say "FAIL	build stopped at step $rc — the last lines of $log:"; tail -15 "$log"; return 1; fi
  # the house's own per-app setup runs IN the release (the data home links, Rödd's face, the launcher entries)
  if [ -x "$tmp/apps/rodd/setup.sh" ]; then ( cd "$tmp/apps/rodd" && YMIR_FLEET_DEPLOY=off YMIR_SKIP_DESKTOP=1 YMIR_RUNTIME_DIR="$PIN" ./setup.sh ) >> "$log" 2>&1 || { say "FAIL	apps/rodd/setup.sh — see $log"; return 1; }; fi
  if [ -x "$tmp/apps/bilskirnir/scripts/data-home.sh" ]; then ( "$tmp/apps/bilskirnir/scripts/data-home.sh" ) >> "$log" 2>&1 || true; fi
  # Óðrerir's live board is written by a nightly job into the app's folder; a release whose shared copy is still
  # empty gets one now, so the hall never opens on a 404 (plan 275 S16)
  if [ ! -s "$SHARED/apps/odrerir/public/livehall.json" ] && [ -x "$tmp/bin/time/nornir-job-hall-snapshot.sh" ]; then
    BROKK_ROOT_OVERRIDE="$tmp" bash "$tmp/bin/time/nornir-job-hall-snapshot.sh" >> "$log" 2>&1 || true
  fi
  if ! prove "$tmp"; then say "FAIL	the release did not prove — it stays unbuilt at $tmp"; return 1; fi
  date -Is > "$tmp/.release-proved"
  rm -rf "$d"; mv -T "$tmp" "$d"
  say "release	$d	built and proved"
}

# ── flip and rollback: one atomic rename ──────────────────────────────────────────────────────────────────────
flip() {
  local d; d="$(resolve_sha "${1:?flip <sha>}")"
  [ -n "$d" ] && [ -f "$d/.release-proved" ] || fail "no PROVED release for $1"
  readlink -f "$CUR" 2>/dev/null > "$BASE/previous" || true
  ln -sfn "$d" "$CUR.tmp-$$" && mv -T "$CUR.tmp-$$" "$CUR" || fail "the flip did not land"
  say "current	$d"
  # keep KEEP releases besides current and previous; never delete either
  local keep_cur keep_prev n=0 r
  keep_cur="$(readlink -f "$CUR")"; keep_prev="$(cat "$BASE/previous" 2>/dev/null)"
  for r in $(ls -1dt "$REL"/*/ 2>/dev/null); do
    r="${r%/}"; [ "$r" = "$keep_cur" ] || [ "$r" = "$keep_prev" ] && continue
    # a release a running process still uses (its folder, its command line) is never deleted: an app server
    # started from it would answer 404 the moment its files vanished (a second machine, 2026-11-12: Óðrerir's page)
    if in_use "$r"; then say "kept	$r	(still in use by a running process)"; continue; fi
    n=$((n+1)); if [ "$n" -gt "$KEEP" ]; then rm -rf "$r" && say "pruned	$r"; fi
  done
  return 0
}
in_use() {  # <release-dir> → 0 when any process runs from it
  local p
  for p in /proc/[0-9]*; do
    case "$(readlink "$p/cwd" 2>/dev/null)" in "$1"|"$1"/*) return 0 ;; esac
    { tr '\0' ' ' < "$p/cmdline"; } 2>/dev/null | grep -qF "$1/" && return 0
  done
  return 1
}
rollback() {
  local p; p="$(cat "$BASE/previous" 2>/dev/null)"
  [ -n "$p" ] && [ -d "$p" ] || fail "no previous release recorded"
  flip "$p"
}

# ── adopt: the old in-place pin becomes the first release, and its path becomes the link ───────────────────────
adopt() {
  [ -L "$PIN" ] && { say "adopt	$PIN is already a link → $(readlink "$PIN")"; return 0; }
  [ -d "$PIN/.git" ] || fail "no pin at $PIN"
  local sha d; sha="$(git -C "$PIN" rev-parse --short=12 HEAD)"; d="$REL/$sha"
  [ -e "$d" ] && fail "$d already exists — build a release and flip it instead"
  # the links are made in the same breath as the move, so the pin's path is absent for microseconds, not for the
  # whole of link_shared (a dev machine, 2026-11-12: a timer started in that gap and failed its CHDIR)
  ln -sfn "$d" "$CUR.tmp-$$" && mv -T "$PIN" "$d" && mv -T "$CUR.tmp-$$" "$CUR" && ln -sfn "$CUR" "$PIN" \
    || fail "could not move the pin"
  link_shared "$d"
  date -Is > "$d/.release-adopted"
  say "adopt	$PIN → $CUR → $d"
}

status() {
  say "release[1]{current,previous,pin}:"
  say "  \"$(readlink -f "$CUR" 2>/dev/null || echo none)\",\"$(cat "$BASE/previous" 2>/dev/null || echo none)\",\"$PIN$([ -L "$PIN" ] && echo " (link)")\""
  say "releases:"; ls -1dt "$REL"/*/ 2>/dev/null | while read -r r; do r="${r%/}"; printf '  %s %s\n' "$(basename "$r")" "$([ -f "$r/.release-proved" ] && echo proved || echo adopted)"; done
}

case "${1:-}" in
  build) shift; build "$@" ;;
  prove) shift; d="$(resolve_sha "${1:?prove <dir|sha>}")"; [ -n "$d" ] || fail "no release $1"; prove "$d" ;;
  flip) shift; flip "$@" ;;
  rollback) rollback ;;
  adopt) adopt ;;
  status) status ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
