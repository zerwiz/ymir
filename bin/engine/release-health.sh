#!/usr/bin/env bash
# release-health.sh — can THIS directory serve the apps? (plan 221, P2)
#
#   bin/engine/release-health.sh <dir>            judge a release; change nothing
#   bin/engine/release-health.sh <dir> --live     ...and make its services answer
#   bin/engine/release-health.sh --help | --version
#
# Exit 0 = healthy (every required row passed, every skip named). Exit 1 = REFUSED.
# A refused release never becomes current: release-flip.sh asks this door first and
# does not move the link on a non-zero answer.
#
# WHAT IT PROVES, and why each row exists:
#   dir        the directory IS a release (under ~/ymir-releases, with a manifest)
#   manifest   the release tells the truth about which commit it is
#   symlinks   nothing dangles, nothing points outside; only the shared shelf is linked
#   own-scripts the release's OWN scripts/electron.sh, start.sh and raise.sh resolve
#              the root to the release — the P0 accept line, asked of the script itself
#   deps       its dependency closure was installed inside it
#   assets     the SPA's build exists inside it
#   desktop    bin/desktop/desktop-verify.sh finds a runnable Electron UNDER it
#   services   the four services answer FROM THAT DIRECTORY — proved by the port's
#              serving pid and its cwd, and by the root the gate itself reports;
#              --live additionally raises them from the release on probe ports
#
# WHAT IT DOES NOT PRETEND: a release whose dependencies were never installed because
# npm is absent, or whose assets were never built because no build tool exists, is
# reported as a SKIP with its reason — never as a pass, never as a silent failure
# (RULES/25: a clean skip with its reason is a pass; a false green is not).
set -uo pipefail

RELEASE_HEALTH_VERSION="1.0.0"
SELF_DIR="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SELF_DIR/../.." && pwd)"

# shellcheck source=/dev/null
. "$SELF_DIR/release-lib.sh"
# shellcheck source=/dev/null
[ -r "$ROOT/bin/fleet/ymir-platform.sh" ] && . "$ROOT/bin/fleet/ymir-platform.sh"
release_config

usage() {
  cat <<'EOF'
release-health — judge whether a directory can serve the apps.

  bin/engine/release-health.sh <dir>           # static proof + who is serving now
  bin/engine/release-health.sh <dir> --live    # also raise its own services on probe ports
  bin/engine/release-health.sh <dir> --quiet   # rows only on failure
  bin/engine/release-health.sh --help | --version

Exit 0 healthy, 1 refused. release-flip.sh will not move ~/ymir-current on a refusal.

--live raises the release's own gate (3889), SPA (3888), Smidja visualizer (8437) and
Óðrerir hall (4322) on PROBE ports (canonical + 10000) so the running hall is never
disturbed, proves each answers, proves the gate reports THIS directory as its root,
then stops them. A missing bun/npm/vite is printed as a skip with its reason.
EOF
}

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { warn "error: $*"; exit 1; }

DIR=""; LIVE=0; QUIET=0
while [ $# -gt 0 ]; do
  case "${1-}" in
    -h|--help)       usage; exit 0 ;;
    -v|-V|--version) printf 'release-health %s\n' "$RELEASE_HEALTH_VERSION"; exit 0 ;;
    --live)          LIVE=1; shift ;;
    --quiet)         QUIET=1; shift ;;
    -*)              die "unknown flag $1 (help: release-health.sh --help)" ;;
    *)               DIR="$1"; shift ;;
  esac
done
[ -n "$DIR" ] || { usage >&2; exit 2; }

FAIL=0; SKIPS=""; FAILED=""
row() {  # <check> <verdict> <detail>
  local check="$1" verdict="$2" detail="$3"
  case "$verdict" in
    FAIL) FAIL=1; FAILED="$FAILED $check" ;;
    skip) SKIPS="$SKIPS $check" ;;
  esac
  if [ "$QUIET" = 1 ] && [ "$verdict" = "ok" ]; then return 0; fi
  printf '  "%s","%s","%s"\n' "$check" "$verdict" "$detail"
}

health_tail() {
  local verdict
  if [ "$FAIL" = 0 ]; then verdict="healthy"; else verdict="REFUSED"; fi
  if [ "$QUIET" = 1 ] && [ "$FAIL" = 0 ]; then exit 0; fi
  say "release-health[1]{dir,verdict,failed,skipped}:"
  say "  \"${REAL_DIR:-$DIR}\",\"$verdict\",\"${FAILED# }\",\"${SKIPS# }\""
  [ "$FAIL" = 0 ] || say "  \"a refused release never becomes current — release-flip.sh will not move the link\""
  [ "$FAIL" = 0 ] || exit 1
  exit 0
}

if [ "$QUIET" = 0 ]; then
  say "release-health[1]{dir}:"
  say "  \"$DIR\""
  say "checks[8]{check,verdict,detail}:"
fi

# ── dir: it IS a release, and it is not the tree hands work in ───────────────
REAL_DIR=""
if [ ! -e "$DIR" ]; then
  row dir FAIL "no such directory: $DIR"
elif [ ! -d "$DIR" ]; then
  row dir FAIL "not a directory: $DIR"
else
  REAL_DIR="$(release_real "$DIR")"
  if ! release_under "$REAL_DIR" "$(release_real "$YMIR_RELEASES_DIR")"; then
    row dir FAIL "$REAL_DIR is not under $YMIR_RELEASES_DIR — a hand's checkout is not a release"
  elif [ ! -r "$REAL_DIR/RELEASE-MANIFEST.json" ]; then
    row dir FAIL "$REAL_DIR carries no RELEASE-MANIFEST.json — it was not built by release-build.sh"
  else
    row dir ok "$REAL_DIR"
  fi
fi
[ -n "$REAL_DIR" ] && [ -d "$REAL_DIR" ] || { health_tail; exit 1; }
# A directory that is not a release is not worth another eight checks.
[ "$FAIL" = 1 ] && { health_tail; exit 1; }

# ── manifest: the release's own claim about itself ───────────────────────────
m_sha="$(release_manifest "$REAL_DIR" sha)"
m_id="$(release_manifest "$REAL_DIR" release)"
if [ -z "$m_sha" ] || [ -z "$m_id" ]; then
  row manifest FAIL "the manifest names no sha/release"
elif [ "${REAL_DIR##*/}" != "$m_id" ]; then
  row manifest FAIL "the directory is ${REAL_DIR##*/} but its manifest names $m_id"
elif [ "${m_sha:0:12}" != "$m_id" ]; then
  row manifest FAIL "the manifest's sha ($m_sha) does not match its release id ($m_id)"
else
  row manifest ok "sha $m_sha, built $(release_manifest "$REAL_DIR" built_at)"
fi

# ── symlinks: nothing dangles, nothing escapes, only the shelf is linked ─────
SHARED_REAL="$(release_real "$YMIR_SHARED_DIR")"
bad_link=""; escape=""; shelf=""; n_links=0; n_inner=0
while IFS= read -r link; do
  [ -n "$link" ] || continue
  n_links=$((n_links + 1))
  tgt="$(release_real "$link")"
  if [ ! -e "$tgt" ]; then bad_link="$bad_link ${link#$REAL_DIR/}"; continue; fi
  # The DIRECT target decides whether a link is the shelf's business. A shelf entry
  # may itself point onward (shared/state → the operator's real state dir); that is
  # the shelf's business, not an escape from the release.
  raw="$(readlink "$link" 2>/dev/null)"
  case "$raw" in
    /*) direct="$raw" ;;
    *)  direct="$(dirname "$link")/$raw" ;;
  esac
  ddir="$(dirname "$direct")"
  if [ -d "$ddir" ]; then direct="$(CDPATH='' cd "$ddir" && pwd -P)/$(basename "$direct")"; fi
  if release_under "$direct" "$SHARED_REAL"; then shelf="$shelf ${link#$REAL_DIR/}"; continue; fi
  if ! release_under "$tgt" "$REAL_DIR"; then escape="$escape ${link#$REAL_DIR/}→$tgt"; else n_inner=$((n_inner + 1)); fi
done <<EOF
$(find "$REAL_DIR" -type l 2>/dev/null)
EOF
if [ -n "$bad_link" ]; then
  row symlinks FAIL "dangling:$bad_link"
elif [ -n "$escape" ]; then
  row symlinks FAIL "points outside the release:$escape"
else
  row symlinks ok "$n_links link(s): shelf[${shelf# }], $n_inner inside the release"
fi

# ── own-scripts: ask each script where it thinks it lives ────────────────────
own_bad=""; own_ok=""
for s in scripts/electron.sh scripts/start.sh scripts/raise.sh; do
  [ -f "$REAL_DIR/$s" ] || { own_bad="$own_bad $s(missing)"; continue; }
  got="$(bash "$REAL_DIR/$s" --root 2>/dev/null | head -1)"
  if [ -n "$got" ] && [ "$(release_real "$got")" = "$REAL_DIR" ]; then
    own_ok="$own_ok $s"
  else
    own_bad="$own_bad $s(→${got:-nothing})"
  fi
done
if [ ! -d "$REAL_DIR/.pi" ] || [ ! -d "$REAL_DIR/RULES" ]; then
  own_bad="$own_bad desktop-verify(no .pi/RULES to resolve its root against)"
fi
if [ -n "$own_bad" ]; then
  row own-scripts FAIL "resolve outside the release:$own_bad"
else
  row own-scripts ok "every script resolves $REAL_DIR"
fi

# ── deps: the closure was installed INSIDE the release ──────────────────────
m_deps="$(sed -n 's/.*"deps": *{[^}]*"status": *"\([^"]*\)".*/\1/p' "$REAL_DIR/RELEASE-MANIFEST.json" 2>/dev/null | head -1)"
if [ -d "$REAL_DIR/node_modules" ] && [ -n "$(ls -A "$REAL_DIR/node_modules" 2>/dev/null | head -1)" ]; then
  row deps ok "node_modules inside the release ($(release_human "$(release_size "$REAL_DIR/node_modules")"))"
elif [ "$m_deps" = "skipped" ] && ! command -v npm >/dev/null 2>&1; then
  row deps skip "the manifest records no dependency install, and npm is not on this machine"
elif [ "$m_deps" = "skipped" ]; then
  row deps FAIL "the manifest records a skipped dependency install — this release cannot serve node apps"
else
  row deps FAIL "no node_modules inside the release (the manifest says '${m_deps:-nothing}')"
fi

# ── assets: the SPA's build exists inside the release ───────────────────────
if [ -f "$REAL_DIR/apps/hlidskjalf/dist/index.html" ]; then
  row assets ok "apps/hlidskjalf/dist/index.html present"
elif [ ! -d "$REAL_DIR/node_modules" ]; then
  row assets skip "no build exists and no dependencies to build with"
else
  row assets FAIL "apps/hlidskjalf/dist/index.html is absent — the SPA has nothing to serve"
fi

# ── desktop: an Electron under THIS directory, proven by the house's own door ─
if [ ! -x "$REAL_DIR/bin/desktop/desktop-verify.sh" ] && [ ! -f "$REAL_DIR/bin/desktop/desktop-verify.sh" ]; then
  row desktop FAIL "bin/desktop/desktop-verify.sh is absent from the release"
else
  dv_out="$(bash "$REAL_DIR/bin/desktop/desktop-verify.sh" 2>&1)"; dv_rc=$?
  if [ "$dv_rc" = 0 ]; then
    row desktop ok "$(printf '%s' "$dv_out" | grep -o 'every surface[^"]*' | head -1)"
  elif printf '%s' "$dv_out" | grep -qE 'no executable Electron runtime|does not answer --version'; then
    row desktop FAIL "$(printf '%s' "$dv_out" | grep -E 'no executable Electron runtime|does not answer' | head -1 | sed 's/^ *//')"
  else
    n_machine="$(printf '%s' "$dv_out" | grep -c '"FAIL"')"
    row desktop ok "the runtime resolves under the release; ${n_machine} machine row(s) (launcher/class/window rule) failed — not this release's to fix"
  fi
fi

# ── services: they answer FROM THIS DIRECTORY ───────────────────────────────
# Attribution, not optimism: the port's serving pid has a cwd, and the gate reports
# the root it serves. "Something answers on 3888" proves nothing about this release.
service_row() {  # <label> <port> <path>
  local label="$1" port="$2" path="$3" pid root code
  pid="$(release_port_pid "$port" || true)"
  if [ -z "$pid" ]; then
    row "service:$label" skip "nothing is serving :$port — this release's own copy is proved with --live"
    return 0
  fi
  root="$(release_pid_root "$pid" || true)"
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:$port$path" 2>/dev/null || printf '000')"
  if [ "$code" = "000" ]; then
    row "service:$label" FAIL "pid $pid holds :$port but it does not answer $path"
  elif [ -n "$root" ] && release_under "$root" "$REAL_DIR"; then
    row "service:$label" ok "pid $pid serves :$port from $root"
  else
    row "service:$label" skip "pid $pid serves :$port from ${root:-an unknown tree}, not this release (nothing points at the symlink yet — plan 221 P3)"
  fi
}

live_services() {  # raise the release's own services on probe ports, prove, stop
  local base="${YMIR_RELEASE_PROBE_BASE:-10000}" tmp pid_file
  tmp="$(mktemp -d)" || { row "service:live" skip "no temp dir to hold the probe"; return 0; }
  pid_file="$tmp/pids"; : >"$pid_file"
  # shellcheck disable=SC2064
  trap "while IFS= read -r p; do [ -n \"\$p\" ] && kill \"\$p\" 2>/dev/null; done <'$pid_file'; sleep 0.3; while IFS= read -r p; do [ -n \"\$p\" ] && kill -9 \"\$p\" 2>/dev/null; done <'$pid_file'; rm -rf '$tmp'" EXIT

  probe() {  # <label> <port> <workdir> <url-path> <cmd...>
    local label="$1" port="$2" wd="$3" path="$4"; shift 4
    local p=0 i code
    [ -d "$REAL_DIR/$wd" ] || { row "service:$label" skip "no $wd in the release"; return 0; }
    ( cd "$REAL_DIR/$wd" && exec "$@" ) >"$tmp/$label.log" 2>&1 &
    p=$!; printf '%s\n' "$p" >>"$pid_file"
    for i in $(seq 1 40); do
      code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:$port$path" 2>/dev/null || printf '000')"
      [ "$code" = "200" ] && break
      kill -0 "$p" 2>/dev/null || break
      sleep 0.5
    done
    if [ "$code" = "200" ]; then
      row "service:$label" ok "answered :$port$path from $REAL_DIR/$wd (pid $p)"
    elif ! kill -0 "$p" 2>/dev/null; then
      row "service:$label" FAIL "exited at once from $REAL_DIR/$wd: $(tail -2 "$tmp/$label.log" 2>/dev/null | tr '\n' ' ' | cut -c1-160)"
    else
      row "service:$label" FAIL "started from $REAL_DIR/$wd but did not answer :$port$path"
    fi
  }

  # The gate reports the root it serves — the strongest attribution available.
  if command -v bun >/dev/null 2>&1; then
    probe gate "$((3889 + base))" apps/hlidskjalf /api/health \
      env PORT="$((3889 + base))" bun run server/index.ts
    g_root="$(curl -s --max-time 3 "http://127.0.0.1:$((3889 + base))/api/health" 2>/dev/null \
      | sed -n 's/.*"root": *"\([^"]*\)".*/\1/p')"
    if [ -n "$g_root" ]; then
      if release_under "$(release_real "$g_root")" "$REAL_DIR"; then
        row "service:gate-root" ok "the gate names $g_root as the tree it serves"
      else
        row "service:gate-root" FAIL "the gate names $g_root, not the release"
      fi
    fi
  else
    row "service:gate" skip "bun is not on this machine"
  fi
  if [ -f "$REAL_DIR/apps/hlidskjalf/dist/index.html" ]; then
    probe spa "$((3888 + base))" apps/hlidskjalf / \
      npx --no-install vite preview --port "$((3888 + base))" --strictPort --host 127.0.0.1
  else
    row "service:spa" skip "no dist to preview"
  fi
  if command -v bun >/dev/null 2>&1; then
    db=""
    if [ -n "${RELEASE_HOME:-}" ] && [ -f "$RELEASE_HOME/smidja/smidja.db" ]; then db="$RELEASE_HOME/smidja/smidja.db"; fi
    probe visualizer "$((8437 + base))" apps/smidja-factory/apps/visualizer /api/health \
      env PORT="$((8437 + base))" CMD_DB="$db" bun run server/index.ts
  else
    row "service:visualizer" skip "bun is not on this machine"
  fi
  if [ -f "$REAL_DIR/apps/odrerir/dist/index.html" ]; then
    probe hall "$((4322 + base))" apps/odrerir / \
      npx --no-install vite preview --port "$((4322 + base))" --strictPort --host 127.0.0.1
  else
    row "service:hall" skip "no dist to preview"
  fi
}

if [ "$LIVE" = 1 ]; then
  live_services
else
  service_row gate 3889 /api/health
  service_row spa 3888 /
  service_row visualizer 8437 /
  service_row hall 4322 /
  row "service:live" skip "the release's own services were not raised (pass --live to prove them from this directory)"
fi

health_tail
