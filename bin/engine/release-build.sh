#!/usr/bin/env bash
# release-build.sh — forge an IMMUTABLE release from one commit (plan 221, P0).
#
#   bin/engine/release-build.sh HEAD              build the release for HEAD
#   bin/engine/release-build.sh <sha|branch|tag>  build the release for that commit
#   bin/engine/release-build.sh --prune-only      prune old releases and stop
#   bin/engine/release-build.sh --help | --version
#
# WHAT A RELEASE IS. `~/ymir-releases/<12-char-sha>/` — that commit's tree, its
# symlinks RESOLVED into real files, its dependencies installed INSIDE it, its
# assets built INSIDE it, a manifest that names its own sha, and links to the
# SHARED shelf for everything it must not own (state, logs, pids, the hoard).
# Nothing points at a release until `release-flip.sh` says so: build and health
# run entirely off to the side, and the flip is the LAST act (plan 221 §10 —
# "stage, then activate").
#
# THE LAW THIS SERVES, in the Allfather's words: "the apps run time must be
# locked to main. otherwise they might break if the user are switching trees" —
# and the apps must never break when the code updates.
#
# WHAT IT NEVER DOES: it never touches ~/ymir, never force/reset/stash/clean,
# never moves ~/ymir-current (that is release-flip.sh alone), never writes into
# the hoard, and never pretends a step it could not run. A missing npm, a missing
# build tool, a missing display: each is printed as a SKIP with its reason, and
# the manifest records it, so release-health.sh judges what was really built.
set -uo pipefail

RELEASE_BUILD_VERSION="1.0.0"
SELF_DIR="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SELF_DIR/../.." && pwd)"

# shellcheck source=/dev/null
. "$SELF_DIR/release-lib.sh"
# shellcheck source=/dev/null
[ -r "$ROOT/bin/fleet/ymir-platform.sh" ] && . "$ROOT/bin/fleet/ymir-platform.sh"
release_config

usage() {
  cat <<'EOF'
release-build — forge an immutable release from one commit.

  bin/engine/release-build.sh HEAD              # build the release for HEAD
  bin/engine/release-build.sh <sha|branch|tag>  # build that commit's release
  bin/engine/release-build.sh --prune-only      # retention only; build nothing
  bin/engine/release-build.sh --dry-run         # say what it would do, change nothing
  bin/engine/release-build.sh --help | --version

A release is ~/ymir-releases/<sha>/ : that commit's tree, symlinks resolved into
real files, dependencies installed inside it, assets built inside it, a manifest
naming its own sha, and links to the shared shelf (~/ymir-shared) for state, logs,
pids, the hoard and the vault. Nothing points at it until release-flip.sh.

Retention: the last three are kept, pruned BY AGE BEFORE the build, and the
current release is never a candidate.
EOF
}

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { warn "error: $*"; exit 1; }

action="build"; ref=""
while [ $# -gt 0 ]; do
  case "${1-}" in
    -h|--help)     usage; exit 0 ;;
    -v|-V|--version) printf 'release-build %s\n' "$RELEASE_BUILD_VERSION"; exit 0 ;;
    --prune-only)  action="prune"; shift ;;
    --dry-run)     action="dry"; shift ;;
    -*)            die "unknown flag $1 (help: release-build.sh --help)" ;;
    *)             ref="$1"; shift ;;
  esac
done

[ -d "$ROOT/.git" ] || [ -f "$ROOT/.git" ] || die "$ROOT is not a git checkout"

if [ "$action" = "prune" ] || [ "$action" = "dry" ]; then
  say "retention[1]{dir,keep}:"
  say "  \"$YMIR_RELEASES_DIR\",\"$YMIR_RELEASES_KEEP\""
  say "prune[1]{release,verdict,why}:"
  if [ "$action" = "dry" ]; then release_prune --dry-run; else release_prune; fi
  exit 0
fi

[ -n "$ref" ] || { usage >&2; exit 2; }

resolved="$(release_resolve "$ROOT" "$ref")" || die "$ref does not name a commit in $ROOT"
SHA="${resolved%% *}"; ID="${resolved##* }"
DEST="$(release_dir_for "$ID")"
STAGE="${DEST}.partial-$$"

say "release[1]{ref,sha,id,dir}:"
say "  \"$ref\",\"$SHA\",\"$ID\",\"$DEST\""

# ── 0. a release is a directory that already exists in full, or nothing ───────
# Building into a temp name and renaming it into place is the same "stage, then
# activate" law as the flip: a half-built directory must never be mistaken for a
# release by health, by the flip, or by a human reading the shelf.
if [ -d "$DEST" ] && [ -r "$DEST/RELEASE-MANIFEST.json" ]; then
  m_sha="$(release_manifest "$DEST" sha)"
  if [ "$m_sha" = "$SHA" ]; then
    say "state[1]{verdict,detail}:"
    say "  \"already-built\",\"$DEST names $SHA in its manifest — nothing to do (use release-health.sh to judge it)\""
    exit 0
  fi
  die "$DEST exists but its manifest names ${m_sha:-nothing}, not $SHA — refusing to overwrite a release"
fi

# ── 1. retention BEFORE the build (never after a failure) ────────────────────
say "prune[1]{release,verdict,why}:"
release_prune

mkdir -p "$YMIR_RELEASES_DIR" || die "cannot create $YMIR_RELEASES_DIR"
rm -rf -- "$STAGE"
mkdir -p "$STAGE" || die "cannot create $STAGE"

cleanup() { [ -d "$STAGE" ] && rm -rf -- "$STAGE"; }
trap cleanup EXIT INT TERM

# ── 2. export the commit (git archive | tar -x) ──────────────────────────────
say "export[1]{sha,into}:"
git -C "$ROOT" archive --format=tar "$SHA" | tar -x -C "$STAGE" \
  || die "git archive $SHA | tar -x failed"
files="$(find "$STAGE" -type f 2>/dev/null | wc -l | tr -d ' ')"
say "  \"$SHA\",\"$STAGE\",$files"

# ── 3. RESOLVE every symlink into a real file ────────────────────────────────
# A release may not depend on a link into a tree that moves. `config` is a symlink
# into `.agents/config` (plan 221 §7 names it), and the harness dirs are links into
# `.agents/`; after this pass each is the thing itself. A link whose target escapes
# the release is a REFUSAL, not a copy: a release that points outside itself is not
# a release, and a dangling link is the fault this pass exists to end.
resolved_count=0
passes=0
while [ "$passes" -lt 8 ]; do
  passes=$((passes + 1))
  links="$(find "$STAGE" -type l 2>/dev/null)"
  [ -n "$links" ] || break
  while IFS= read -r link; do
    [ -n "$link" ] || continue
    [ -L "$link" ] || continue
    tgt="$(release_real "$link")"
    if [ ! -e "$tgt" ]; then
      warn "error: $link is a DANGLING symlink (target: $(readlink "$link" 2>/dev/null))"
      die "a release may not carry a dangling link — fix the tree at $SHA"
    fi
    if ! release_under "$tgt" "$STAGE"; then
      warn "error: $link points OUTSIDE the release → $tgt"
      die "a release may not point outside itself — fix the tree at $SHA"
    fi
    case "$tgt" in "$STAGE"/*) : ;; *) die "refusing to dereference $link into the release root itself" ;; esac
    rm -f -- "$link" || die "cannot unlink $link"
    cp -a -- "$tgt" "$link" || die "cannot materialise $link from $tgt"
    resolved_count=$((resolved_count + 1))
  done <<EOF
$links
EOF
done
[ "$passes" -lt 8 ] || die "symlinks still remained after 8 passes — the tree has a link cycle"
say "symlinks[1]{resolved,passes}:"
say "  $resolved_count,$passes"

# ── 4. dependencies INSIDE the release ───────────────────────────────────────
# A release carries its own dependency closure: the whole point is that an update
# to ~/ymir cannot move the code or the modules under a running window.
deps_status="skipped"; deps_road=""; deps_reason=""
if command -v npm >/dev/null 2>&1; then
  say "deps[1]{road}:"
  if [ -f "$STAGE/package-lock.json" ] && ( cd "$STAGE" && npm ci --no-audit --no-fund --prefer-offline >/dev/null 2>&1 ); then
    deps_status="installed"; deps_road="npm ci"
  elif ( cd "$STAGE" && npm install --no-audit --no-fund --prefer-offline >/dev/null 2>&1 ); then
    deps_status="installed"; deps_road="npm install"
  else
    deps_status="failed"; deps_reason="npm could not install the dependency closure inside the release"
  fi
  say "  \"${deps_road:-none}\",\"$deps_status\""
else
  deps_reason="npm is not on this machine"
  say "deps[1]{road,status,reason}:"
  say "  \"none\",\"skipped\",\"$deps_reason\""
fi

# ── 4b. the DESKTOP runtime's own postinstall ────────────────────────────────
# npm 11+ gates install scripts, and Electron's postinstall is what downloads the
# binary — so a perfect web build can ship no window at all (the fault named in
# scripts/electron.sh). A release must carry the runtime it promises, so the
# package's own installer is run INSIDE the release, and what really happened is
# recorded. `node_modules/electron/dist/locales` alone is a 200 MB lie.
electron_status="skipped"
if [ -d "$STAGE/node_modules/electron" ]; then
  ebin="$STAGE/node_modules/electron/dist/electron"
  if [ -x "$ebin" ]; then
    electron_status="present"
  else
    ev="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$STAGE/node_modules/electron/package.json" 2>/dev/null | head -1)"
    # tier 1 — npm's own roads (they can empty dist/ when the gated download fails)
    ( cd "$STAGE" && npm rebuild electron >/dev/null 2>&1 ) || true
    if [ ! -x "$ebin" ] && [ -f "$STAGE/node_modules/electron/install.js" ] && command -v node >/dev/null 2>&1; then
      ( cd "$STAGE/node_modules/electron" && node install.js >/dev/null 2>&1 ) || true
    fi
    # tier 2 — THE ZIP ROAD, from the machine's own cache first, then the network.
    # install.js can exit 0 and leave dist/ holding only locales/; the zip road is
    # what actually lands the runtime (bin/desktop/electron-lib.sh's proven order).
    if [ ! -x "$ebin" ] && [ -n "$ev" ] && command -v unzip >/dev/null 2>&1; then
      zip=""
      for z in "$HOME/.cache/electron"/*/"electron-v$ev-linux-x64.zip"; do
        [ -s "$z" ] && { zip="$z"; break; }
      done
      if [ -z "$zip" ] && command -v curl >/dev/null 2>&1; then
        zip="$(mktemp /tmp/electron-XXXXXX.zip 2>/dev/null || true)"
        curl -sL -m 540 -o "$zip" "https://github.com/electron/electron/releases/download/v$ev/electron-v$ev-linux-x64.zip" \
          && [ -s "$zip" ] || { rm -f "$zip"; zip=""; }
      fi
      if [ -n "$zip" ]; then
        ( cd "$STAGE/node_modules/electron" && unzip -oq "$zip" -d dist >/dev/null 2>&1 ) || true
        case "$zip" in /tmp/electron-*) rm -f "$zip" ;; esac
      fi
    fi
    if [ -x "$ebin" ]; then electron_status="mended"; else electron_status="absent"; fi
  fi
fi
say "electron[1]{status}:"
say "  \"$electron_status\""

# ── 5. assets built INSIDE the release ───────────────────────────────────────
# The SPA is served from ./dist when a build exists and from a dev server when it
# does not — a release must serve, so the build is attempted here and what really
# happened is recorded (never assumed).
assets_built=""; assets_skipped=""
build_asset() {  # <label> <dir> <command...>
  local label="$1" dir="$2"; shift 2
  [ -d "$STAGE/$dir" ] || { assets_skipped="$assets_skipped $label(absent)"; return 0; }
  if [ "$deps_status" != "installed" ]; then
    assets_skipped="$assets_skipped $label(no dependencies)"; return 0
  fi
  if ( cd "$STAGE/$dir" && "$@" >/dev/null 2>&1 ); then
    assets_built="$assets_built $label"
  else
    assets_skipped="$assets_skipped $label(build failed)"
  fi
}
build_asset hlidskjalf apps/hlidskjalf npx --no-install vite build
build_asset odrerir apps/odrerir npx --no-install vite build
if command -v bun >/dev/null 2>&1; then
  build_asset smidja-visualizer apps/smidja-factory/apps/visualizer bunx vite build
else
  assets_skipped="$assets_skipped smidja-visualizer(no bun)"
fi
assets_built="${assets_built# }"; assets_skipped="${assets_skipped# }"
say "assets[1]{built,skipped}:"
say "  \"${assets_built:-none}\",\"${assets_skipped:-none}\""

# ── 6. the SHARED shelf, materialised once and linked by every release ───────
# Capistrano's shared/ + linked_dirs, and plan 221 §10's fifth correction: state
# must SURVIVE a release, so a release that writes into itself cannot be rolled
# back cleanly. The shelf is created once; every release points at it and writes
# nothing of its own.
seat_state=""; hoard=""; vault=""
declare -f hoard_state_dir >/dev/null 2>&1 && hoard_state_dir seat_state
declare -f hoard_root     >/dev/null 2>&1 && hoard_root hoard
[ -n "${hoard:-}" ] && vault="$hoard/secrets"

mkdir -p "$YMIR_SHARED_DIR/logs" "$YMIR_SHARED_DIR/run" "$YMIR_SHARED_DIR/cache" 2>/dev/null \
  || die "cannot create the shared shelf at $YMIR_SHARED_DIR"

shared_link() {  # <name> <real-dir> — borrow the real thing, or keep a local shelf
  local name="$1" real="$2" dest="$YMIR_SHARED_DIR/$1"
  if [ -n "$real" ] && [ -d "$real" ]; then
    if [ -L "$dest" ]; then
      [ "$(release_real "$dest")" = "$(release_real "$real")" ] || ln -sfn "$real" "$dest"
    elif [ -d "$dest" ]; then
      say "  \"$name\",\"local\",\"$dest already holds its own directory — left alone\""
      return 0
    else
      ln -s "$real" "$dest" || { say "  \"$name\",\"FAIL\",\"cannot link $dest → $real\""; return 1; }
    fi
    say "  \"$name\",\"linked\",\"$real\""
  else
    mkdir -p "$dest" 2>/dev/null
    say "  \"$name\",\"local\",\"no real $name on this machine — a local shelf was made\""
  fi
}
say "shared[1]{name,state,where}:"
say "  \"shelf\",\"ready\",\"$YMIR_SHARED_DIR\""
shared_link state "$seat_state"
shared_link hoard "$hoard"
shared_link vault "$vault"
shared_link logs  ""
shared_link run   ""
shared_link cache ""

# The release points at the shelf — absolute targets, because a release must not
# depend on the caller's working directory.
for pair in "shared:$YMIR_SHARED_DIR" ".run:$YMIR_SHARED_DIR/run" "state:$YMIR_SHARED_DIR/state" "logs:$YMIR_SHARED_DIR/logs"; do
  name="${pair%%:*}"; target="${pair#*:}"
  [ -e "$STAGE/$name" ] && [ ! -L "$STAGE/$name" ] && { warn "note: $name exists in the tree; the shared link is skipped"; continue; }
  ln -sfn "$target" "$STAGE/$name" || die "cannot link $STAGE/$name → $target"
done
say "links[1]{release,shared}:"
say "  \"$STAGE\",\"$YMIR_SHARED_DIR\""

# ── 7. the manifest: the release's own claim about itself ────────────────────
size="$(release_size "$STAGE")"
built_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'detached')"
cat >"$STAGE/RELEASE-MANIFEST.json" <<EOF
{
  "release": "$ID",
  "sha": "$SHA",
  "short": "$ID",
  "built_at": "$built_at",
  "source_root": "$ROOT",
  "source_branch": "$branch",
  "size_bytes": $size,
  "files": $files,
  "symlinks_resolved": $resolved_count,
  "deps": {"status": "$deps_status", "road": "$deps_road", "reason": "$deps_reason"},
  "electron": "$electron_status",
  "assets": {"built": "${assets_built:-none}", "skipped": "${assets_skipped:-none}"},
  "shared": {"dir": "$YMIR_SHARED_DIR", "links": ["shared", ".run", "state", "logs"]},
  "services": "gate 3889 · spa 3888 · visualizer 8437 · hall 4322"
}
EOF

# ── 8. activate the DIRECTORY (the flip activates the link, later) ───────────
[ -d "$DEST" ] && rm -rf -- "$DEST"          # an incomplete leftover, never a release
mv -- "$STAGE" "$DEST" || die "cannot move the staged release into $DEST"
trap - EXIT INT TERM

# The release must answer for itself before we call it built.
own="$(bash "$DEST/scripts/electron.sh" --root 2>/dev/null || true)"
say "release-built[1]{sha,dir,size,files,deps,electron,assets,symlinks,own_root}:"
say "  \"$ID\",\"$DEST\",\"$(release_human "$size")\",$files,\"$deps_status${deps_road:+ via $deps_road}\",\"$electron_status\",\"${assets_built:-none}\",$resolved_count,\"${own:-unresolved}\""
if [ "$(release_real "$own")" != "$(release_real "$DEST")" ]; then
  warn "error: $DEST/scripts/electron.sh resolves its root to '${own:-nothing}', not to the release"
  warn "help: the release is built but NOT trustworthy — release-health.sh will refuse it"
  exit 1
fi
say "next[1]{door}:"
say "  \"release-health.sh\",\"$DEST\""
exit 0
