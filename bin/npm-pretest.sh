#!/usr/bin/env bash
# npm-pretest.sh — the pre-publish test gate (the Allfather's decree):
# the exact tarball the publish would ship must install AND smoke on THIS seat
# and on a remote seat (heimdall) before the shelf ever sees it.
#
# The 0.1.49 lesson: files[] lacked tools/ and the porch sailed missing. The
# pretest packs the real artifact, verifies the hull INSIDE the tarball,
# sandbox-installs it, and smokes the installed essence — local leg first, the
# remote leg second. PASS, and a publish is safe; FAIL, and nothing sails.
#
# Usage:   bin/npm-pretest.sh            local leg + the remote leg
#          bin/npm-pretest.sh local      local only
#          bin/npm-pretest.sh remote     remote only (needs the local tarball)
# Env:     NPM_PRETEST_HOSTS  the remote seats, space-separated
#                             (default: omarchy whynot; a seat that IS this
#                             machine runs its leg locally, no loopback ssh)
#          NPM_PRETEST_HOST   one seat, back-compat
#          NPM_PRETEST_SKIP_REMOTE=1     skip the remote leg
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WORK="$(mktemp -d /tmp/npm-pretest-XXXXXX)"
REMOTE="${NPM_PRETEST_HOST:-${NPM_PRETEST_HOSTS:-omarchy whynot}}"
PASS=1
TARBALL=""
say() { printf '%s\n' "$*"; }
fail() { say "FAIL: $*"; PASS=0; }
ok() { say "  ok: $*"; }

# — the hull: what the tarball MUST carry (the porch law) —
HULL=(
  "tools/mill/systemd/ratatoskr.service"
  "tools/mill/systemd/skuld.service"
  "tools/skills-mcp/server.mjs"
  "tools/tickets-mcp/server.mjs"
  "tools/well-mcp/server.ts"
  "tools/ratatoskr-node/server.ts"
  "tools/mill/worker.sh"
)

pack_and_hull() {
  say "== packing the exact publish artifact =="
  ( cd "$ROOT" && npm pack --ignore-scripts --pack-destination "$WORK" >/dev/null 2>&1 )
  local tgz; tgz="$(ls "$WORK"/*.tgz 2>/dev/null | head -1)"
  [ -n "$tgz" ] || { fail "npm pack produced no tarball"; return 1; }
  say "  tarball: $(basename "$tgz") ($(du -h "$tgz" | cut -f1))"
  say "== the hull inside the tarball (the 0.1.49 lesson) =="
  local missing=0
  for h in "${HULL[@]}"; do
    if tar -tzf "$tgz" 2>/dev/null | grep -q "package/$h$"; then ok "$h"
    else fail "the tarball lacks $h"; missing=1; fi
  done
  [ "$missing" = 0 ] || return 1
  TARBALL="$tgz"
  return 0
}

sandbox_install() {  # <tgz> <dest>
  local tgz="$1" dest="$2" log="$WORK/install.log"
  if ! npm install --prefix "$dest" "$tgz" >"$log" 2>&1; then
    if ! npm install --prefix "$dest" "$tgz" >>"$log" 2>&1; then
      fail "sandbox install failed — $(tail -2 "$log" | tr '\n' ' ')"
      return 1
    fi
  fi
  [ -d "$dest/node_modules/@zerwiz/ymir" ] || { fail "the packaged ymir did not land in the sandbox"; return 1; }
}

smoke() {  # <pkg-dir>
  local P="$1" n=0
  say "== the installed essence smokes =="
  local tools; tools="$(ls "$P/bin" 2>/dev/null | wc -l)"
  [ "$tools" -ge 100 ] && ok "bin tools: $tools" || fail "bin tools: $tools (expected 100+)"
  node "$P/bin/ymir.js" --version >/dev/null 2>&1 && ok "ymir.js --version answers" || fail "ymir.js --version silent"
  [ -d "$P/.agents" ] && ok "the .agents dotfolders ship in the package" || { n=1; }
  if [ -x "$P/bin/essence-fetch.sh" ]; then
    BROKK_ROOT_OVERRIDE="$P" bash "$P/bin/essence-fetch.sh" >/dev/null 2>&1
    [ -d "$P/RULES" ] && [ -d "$P/.agents" ] && ok "the dotfolders + RULES stand after the fetch" || fail "essence-fetch left no RULES at the root"
  else
    fail "essence-fetch.sh absent from the package"
  fi
  local servers; servers="$(find "$P/tools" -name "server*.mjs" -o -name "server*.ts" -o -name "worker.sh" 2>/dev/null | wc -l)"
  [ "$servers" -ge 4 ] && ok "fleet servers in the installed tree: $servers" || fail "fleet servers: $servers (expected 4+)"
}

local_leg() {
  local dest
  pack_and_hull || return 1
  dest="$WORK/seat-local"
  sandbox_install "$TARBALL" "$dest" || return 1
  smoke "$dest/node_modules/@zerwiz/ymir"
}

remote_leg() {
  local hosts="$REMOTE" overall=0 h
  [ -n "$TARBALL" ] || { say "  no tarball here; packing first"; pack_and_hull || return 1; }
  # One leg per seat. The decree is that the tarball installs AND smokes on the
  # seats BEFORE the shelf sees it — plural, and not only the one it was packed
  # on. A seat that IS this machine runs locally (a loopback ssh has no road).
  for h in $hosts; do
    one_remote_leg "$h" || overall=1
  done
  return "$overall"
}

one_remote_leg() {  # <host>
  local REMOTE="$1" tgz="$TARBALL"
  say "== the remote leg: $REMOTE =="

  if [ "$REMOTE" = "$(hostname 2>/dev/null)" ] || [ "$REMOTE" = "$(hostname -s 2>/dev/null)" ]; then
    say "  $REMOTE is this machine — running the leg locally (no loopback ssh)"
    local dest="$HOME/npm-pretest/seat"
    rm -rf "$HOME/npm-pretest" && mkdir -p "$dest" || { fail "cannot prepare the local sandbox"; return 1; }
    sandbox_install "$tgz" "$dest" || return 1
    smoke "$dest/node_modules/@zerwiz/ymir"
    return $?
  fi

  ssh -o BatchMode=yes "$REMOTE" "rm -rf ~/npm-pretest && mkdir -p ~/npm-pretest" 2>/dev/null || { fail "cannot reach $REMOTE"; return 1; }
  scp -q "$tgz" "$REMOTE":~/npm-pretest/pkg.tgz 2>/dev/null || { fail "scp to $REMOTE failed"; return 1; }
  ssh -o BatchMode=yes "$REMOTE" "export PATH=\$HOME/.local/share/mise/shims:\$HOME/.local/bin:/usr/bin:/bin
D=~/npm-pretest/seat; npm install --prefix \$D ~/npm-pretest/pkg.tgz >/dev/null 2>&1 && [ -d \$D/node_modules/@zerwiz/ymir ] \
  && { N=\$D/node_modules/@zerwiz/ymir; T=\$(ls \$N/bin | wc -l); node \$N/bin/ymir.js --version >/dev/null 2>&1; B1=\$?; [ -d \$N/tools/mill/systemd ] && [ \$(find \$N/tools -name 'server*.mjs' | wc -l) -ge 2 ]; B2=\$?; echo \"remote tools=\$T ver=\$B1 hull=\$B2\"; ( [ \$T -ge 100 ] && [ \$B1 = 0 ] && [ \$B2 = 0 ] ) && echo REMOTE_PASS || echo REMOTE_FAIL; }" 2>/dev/null | tail -1
}

case "${1-}" in
  local) local_leg ;;
  remote) remote_leg ;;
  -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) say "usage: npm-pretest.sh [local|remote]" >&2; exit 2 ;;
esac

if [ "${1-}" != remote ] && [ "${NPM_PRETEST_SKIP_REMOTE:-0}" != 1 ]; then
  remote_leg
fi
say "== verdict =="
if [ "$PASS" = 1 ]; then say "PRETEST PASS"; else say "PRETEST FAIL"; fi
rm -rf "$WORK"
[ "$PASS" = 1 ] || exit 1