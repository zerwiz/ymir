#!/usr/bin/env bash
# electron-ensure.sh — the Electron runtime is PRESENT and ANSWERS, or it is fetched.
#
#   bin/desktop/electron-ensure.sh status            what every desktop surface resolves
#   bin/desktop/electron-ensure.sh ensure            mend what is missing, then prove it
#   bin/desktop/electron-ensure.sh ensure --root DIR judge/mend the tree at DIR
#   bin/desktop/electron-ensure.sh --help | --version
#
# WHY THIS DOOR EXISTS (the Allfather, 2026-11-08: *"we also get a problem of electron when
# updating. electron are missing errors"* — and then *"all updates on all machines must solve
# this better for all kind of users"*). npm 11+ gates install scripts, and Electron's
# postinstall is what downloads the binary, so an update can install the package perfectly and
# leave `node_modules/electron/dist` holding nothing but `locales/`. Every desktop app then
# fails to open with "electron missing". Measured here on 2026-11-08: the package's own
# `install.js` is not enough either — it exits 0 having unpacked only `locales/`, so a door
# that trusts it reports a lie. EVERY ROAD IS VERIFIED BY RUNNING THE BINARY, and the door
# only says ok when `--version` answers.
#
# FOR EVERY MACHINE AND EVERY USER, not just this box:
#   · the artifact name is computed from THIS platform and arch (linux · darwin · win32,
#     x64 · arm64 · ia32), never a hardcoded `linux-x64`
#   · the cache is searched where each OS puts it (`~/.cache/electron`,
#     `~/Library/Caches/electron`, `%LOCALAPPDATA%\electron\Cache`)
#   · `ELECTRON_MIRROR` / `ELECTRON_CUSTOM_DIR` are honoured for users behind a mirror or a
#     corporate proxy, and `ELECTRON_SKIP_BINARY_DOWNLOAD` is honoured as a SKIP with its
#     reason (a headless server that deliberately carries no window)
#   · a surface whose app dir is not installed at all (the recorded `--no-desktop` install)
#     is a SKIP, never a failure
#   · unpacking uses whatever the OS has: unzip · tar · powershell
#
# CALLED BY every path that can move the tree: bin/engine/ymir-install.sh (the desktop step),
# bin/agents/groa-update.sh (after the fast-forward), bin/agents/eir-doctor.sh (the shells
# surface) and bin/engine/release-build.sh (inside a release). One mend, four callers.
set -uo pipefail

VERSION="1.1.0"
SCRIPT_DIR="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR/../.." && pwd)"

for _l in "$SCRIPT_DIR/app-lib.sh" "$ROOT/bin/desktop/app-lib.sh"; do
  [ -r "$_l" ] && { . "$_l"; break; }
done
for _l in "$SCRIPT_DIR/electron-lib.sh" "$ROOT/bin/desktop/electron-lib.sh"; do
  [ -r "$_l" ] && { . "$_l"; break; }
done
[ -r "$ROOT/bin/fleet/ymir-platform.sh" ] && . "$ROOT/bin/fleet/ymir-platform.sh"

usage() {
  cat <<'EOF'
electron-ensure — the Electron runtime is present and answers, or it is fetched.

  bin/desktop/electron-ensure.sh status             # every desktop surface, read-only
  bin/desktop/electron-ensure.sh ensure             # mend what is missing, then prove it
  bin/desktop/electron-ensure.sh ensure --root DIR  # judge/mend the tree at DIR
  bin/desktop/electron-ensure.sh status --quiet     # rows only where something is wrong

Exit 0 when every installed surface resolves an Electron that answers `--version`
(a surface that is not installed, or a machine that set ELECTRON_SKIP_BINARY_DOWNLOAD,
is a skip with its reason), 1 when one still cannot open.

The roads, in order, each verified before the next is tried:
  1  npm rebuild electron            (the script gate is the only problem)
  2  the package's install.js        (what the postinstall would have run)
  3  the cached artifact, unzipped   (this machine already holds it)
  4  the artifact fetched            (ELECTRON_MIRROR honoured; curl + unzip/tar/powershell)

Environment: ELECTRON_MIRROR · ELECTRON_CUSTOM_DIR · ELECTRON_SKIP_BINARY_DOWNLOAD ·
HTTPS_PROXY (curl) · YMIR_ELECTRON_MANUAL=1 to report without mending.
EOF
}

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { warn "error: $*"; exit 2; }

ACTION="status"; TREE="$ROOT"; QUIET=0
while [ $# -gt 0 ]; do
  case "${1-}" in
    -h|--help)       usage; exit 0 ;;
    -v|-V|--version) printf 'electron-ensure %s\n' "$VERSION"; exit 0 ;;
    status|ensure)   ACTION="$1"; shift ;;
    --root)          TREE="${2-}"; shift 2 ;;
    --quiet)         QUIET=1; shift ;;
    *)               die "unknown argument $1 (help: electron-ensure.sh --help)" ;;
  esac
done
[ -d "$TREE" ] || die "no such tree: $TREE"
TREE="$(CDPATH='' cd "$TREE" && pwd -P)"

surfaces() { printf '%s\n' hlidskjalf odrerir sessrumnir; }

# The app dir INSIDE THE TREE BEING JUDGED — never app-lib's own root, or `--root DIR`
# would report the tree the script lives in while naming DIR (measured: it did).
surface_dir() {  # <surface> <tree> → the app dir, or empty
  local pkg d
  pkg="$(app_pkg "${1-}")"
  for d in "$2/apps/$pkg" "$2/node_modules/@zerwiz/$pkg"; do
    [ -d "$d" ] && { printf '%s' "$d"; return 0; }
  done
  return 1
}

row() {  # <surface> <state> <detail>
  [ "$QUIET" = 1 ] && [ "$2" = "ok" ] && return 0
  printf '  "%s","%s","%s"\n' "$1" "$2" "$3"
}

# ── this platform's artifact, computed once ─────────────────────────────────
platform_artifact() {  # <version> → "<artifact-basename> <exe-inside-dist> <cache-name>"
  local v="$1" os arch art exe
  os="$(uname -s 2>/dev/null || printf unknown)"
  arch="$(uname -m 2>/dev/null || printf unknown)"
  case "$arch" in
    x86_64|amd64) arch=x64 ;;
    aarch64|arm64) arch=arm64 ;;
    i?86|x86) arch=ia32 ;;
  esac
  case "$os" in
    Linux*)  art="electron-v$v-linux-$arch.zip";  exe="electron" ;;
    Darwin*) art="electron-v$v-darwin-$arch.zip"; exe="Electron.app/Contents/MacOS/Electron" ;;
    MINGW*|MSYS*|CYGWIN*) art="electron-v$v-win32-$arch.zip"; exe="electron.exe" ;;
    *)       printf ''; return 1 ;;
  esac
  printf '%s %s' "$art" "$exe"
}

cache_roots() {
  printf '%s\n' "$HOME/.cache/electron" "$HOME/Library/Caches/electron" \
    "${LOCALAPPDATA:-}/electron/Cache" "${XDG_CACHE_HOME:-}/electron"
}

unpack_zip() {  # <zip> <dest>
  local z="$1" d="$2"
  if command -v unzip >/dev/null 2>&1; then unzip -oq "$z" -d "$d" >/dev/null 2>&1 && return 0; fi
  if command -v tar >/dev/null 2>&1; then tar -xf "$z" -C "$d" >/dev/null 2>&1 && return 0; fi
  if command -v powershell >/dev/null 2>&1; then
    powershell -NoProfile -Command "Expand-Archive -Force -LiteralPath '$z' -DestinationPath '$d'" >/dev/null 2>&1 && return 0
  fi
  return 1
}

# ── the mend: four roads, each verified ─────────────────────────────────────
mend() {  # <surface> <app-dir>
  local s="$1" app="$2" dir="" v="" ebin="" exe="" art="" zip="" base="" cand=""
  dir="$(electron_place_dir "$app" "$TREE" "$(app_pkg "$s")" 2>/dev/null || true)"
  [ -n "$dir" ] || { warn "  $s: no electron package dir to mend"; return 1; }
  v="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$dir/package.json" 2>/dev/null | head -1)"

  read -r art exe <<EOF
$(platform_artifact "$v" 2>/dev/null || true)
EOF
  ebin="$dir/dist/${exe:-electron}"

  # 1 · npm's own road (it can empty dist/ when the gated download fails, so it goes first)
  if [ -f "$TREE/package.json" ] && command -v npm >/dev/null 2>&1; then
    ( cd "$TREE" && npm install-scripts approve electron >/dev/null 2>&1 || true
      cd "$TREE" && npm rebuild electron >/dev/null 2>&1 ) || true
  fi

  # 2 · the package's own installer — what the postinstall would have run. It is NOT
  #     trusted: measured on this machine, it exits 0 having unpacked only locales/.
  if [ -z "$exe" ] || [ ! -x "$ebin" ]; then
    if [ -f "$dir/install.js" ] && command -v node >/dev/null 2>&1; then
      ( cd "$dir" && node install.js >/dev/null 2>&1 ) || true
    fi
  fi

  # 3 · the machine's own cache, for THIS platform
  if [ -n "$art" ] && { [ -z "$exe" ] || [ ! -x "$ebin" ]; }; then
    while IFS= read -r base; do
      [ -n "$base" ] && [ -d "$base" ] || continue
      for cand in "$base"/*/"$art"; do
        [ -s "$cand" ] || continue
        zip="$cand"; break
      done
      [ -n "$zip" ] && break
    done <<EOF
$(cache_roots)
EOF
  fi

  # 4 · fetch it — ELECTRON_MIRROR first (a mirror or a proxy user), then GitHub
  if [ -z "$zip" ] && [ -n "$art" ] && { [ -z "$exe" ] || [ ! -x "$ebin" ]; }; then
    local tmpd mdir
    tmpd="$(mktemp -d 2>/dev/null)" || tmpd=""
    if [ -n "$tmpd" ] && command -v curl >/dev/null 2>&1; then
      mdir="${ELECTRON_CUSTOM_DIR:-v$v}"
      for base in \
        "${ELECTRON_MIRROR:+${ELECTRON_MIRROR%/}/$mdir/$art}" \
        "https://github.com/electron/electron/releases/download/v$v/$art"; do
        [ -n "$base" ] || continue
        if curl -fsSL --max-time 600 -o "$tmpd/$art" "$base" 2>/dev/null && [ -s "$tmpd/$art" ]; then
          zip="$tmpd/$art"; break
        fi
      done
    fi
  fi

  if [ -n "$zip" ] && { [ -z "$exe" ] || [ ! -x "$ebin" ]; }; then
    mkdir -p "$dir/dist" 2>/dev/null
    unpack_zip "$zip" "$dir/dist" || true
    [ -n "$exe" ] && [ -x "$dir/dist/$exe" ] && printf '%s' "$exe" >"$dir/path.txt" 2>/dev/null
    case "$zip" in /*/tmp/*|"${TMPDIR:-/tmp}"/*) rm -f "$zip" ;; esac
  fi

  [ -n "$exe" ] && [ -x "$ebin" ] && "$ebin" --version >/dev/null 2>&1
}

FAILED=0
if [ "$QUIET" = 0 ]; then
  say "electron-ensure[1]{tree,action,platform}:"
  say "  \"$TREE\",\"$ACTION\",\"$(uname -s 2>/dev/null)/$(uname -m 2>/dev/null)\""
  say "surfaces[3]{surface,state,detail}:"
fi

if [ "${ELECTRON_SKIP_BINARY_DOWNLOAD:-}" = 1 ] && [ "$ACTION" = ensure ]; then
  ACTION=status
fi

while IFS= read -r s; do
  app="$(surface_dir "$s" "$TREE" || true)"
  if [ -z "$app" ] || [ ! -d "$app" ]; then
    row "$s" skip "not installed in this tree (a web-only / --no-desktop install is a recorded decision)"
    continue
  fi
  state="$(electron_runtime_state "$app" "$TREE" "$(app_pkg "$s")" 2>/dev/null || true)"
  state="${state:-absent}"
  bin="$(electron_bin "$app" "$TREE" "$(app_pkg "$s")" 2>/dev/null || true)"
  if [ "$state" = ok ] && [ -n "$bin" ] && [ -x "$bin" ] && "$bin" --version >/dev/null 2>&1; then
    row "$s" ok "$bin"
    continue
  fi
  if [ "${ELECTRON_SKIP_BINARY_DOWNLOAD:-}" = 1 ]; then
    row "$s" skip "ELECTRON_SKIP_BINARY_DOWNLOAD is set — this machine carries no window on purpose"
    continue
  fi
  if [ "$ACTION" = status ] || [ "${YMIR_ELECTRON_MANUAL:-0}" = 1 ]; then
    row "$s" "$state" "no runnable Electron under $app — mend with: bin/desktop/electron-ensure.sh ensure"
    FAILED=1
    continue
  fi
  if mend "$s" "$app"; then
    bin="$(electron_bin "$app" "$TREE" "$(app_pkg "$s")" 2>/dev/null || true)"
    row "$s" mended "$bin"
  else
    row "$s" FAIL "no road landed a runnable Electron under $app — npm 11 gates the postinstall; if you are behind a proxy set ELECTRON_MIRROR, and if the cache is corrupt remove ~/.cache/electron"
    FAILED=1
  fi
done <<EOF
$(surfaces)
EOF

if [ "$FAILED" = 0 ]; then
  [ "$QUIET" = 1 ] || { say "electron-ensure[1]{state}:"; say "  \"ok\",\"every installed surface resolves an Electron that answers --version\""; }
  exit 0
fi
say "electron-ensure[1]{state}:"
say "  \"FAIL\",\"a desktop surface cannot open — the row above names what to do\""
exit 1
