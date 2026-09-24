#!/usr/bin/env bash
# electron-lib.sh — is a desktop shell's runtime actually there?
#
# The trap this exists for: npm blocks a package's install scripts by default
# (npm 11.16+ warns, npm 12 refuses), and Electron's postinstall is what downloads
# its ~100 MB runtime. Without it the install still reports SUCCESS and the web app
# still builds — `node_modules/electron/dist/` is simply partial and `path.txt` is
# never written. So the shell fails to launch while every check says healthy, and
# nobody is told.
#
# The second trap (2026-09-24): the WRONG directory was probed. package.json
# declares a workspace (apps/*), so npm HOISTS each app's electron to the ymir
# ROOT — the app's own node_modules/electron is never created. Every probe that
# looked only at the app dir found nothing that could ever exist, and every guard
# that treated absence as success skipped the mend, and the launcher exec'd a path
# npm will never make. One resolver below knows every shape npm leaves behind, and
# absence is NEVER success.
#
# Ymir refuses that silence: a shell is only "ready" when the runtime verifies.
# Source-safe, functions only.
#
#   electron_bin <app-dir> [root] [pkg]      the resolved electron binary (empty + exit 1 when none)
#   electron_pkg_dir <app-dir> [root] [pkg]  the electron PACKAGE dir (path.txt, dist/) — the fetch target
#   electron_place_dir <app-dir> [root] [pkg]where a fetch must PUT the runtime when none exists
#   electron_runtime_state <app-dir> [root] [pkg]   ok | partial | absent   (exit 0 only for ok)
#   electron_root <app-dir>                  the ymir tree that owns the app (heuristic)
#   electron_is_workspace_member <app-dir> [root]  0/1 — the app is inside a workspace root
#   electron_remedy                           the exact command that mends a partial one
#   electron_fetch_runtime <app-dir> [root] [pkg]   place the runtime without npm's permission
#   fetch_electron_zip <app-dir> [root] [pkg]       the PROVEN zip road
set -u

# The ymir tree root that owns an app dir, for callers that have not resolved
# one: the nearest ancestor whose package.json declares workspaces (a clone) or
# names @zerwiz/ymir (a package). Falls back to the app's grandparent.
electron_root() {  # <app-dir>
  local a="${1-}" c
  [ -n "$a" ] || return 1
  a="$(dirname "$a")"
  while [ -n "$a" ] && [ "$a" != "/" ]; do
    if [ -f "$a/package.json" ]; then
      if grep -q '"workspaces"' "$a/package.json" 2>/dev/null \
         || grep -q '"@zerwiz/ymir"' "$a/package.json" 2>/dev/null; then
        printf '%s' "$a"; return 0
      fi
    fi
    a="$(dirname "$a")"
  done
  printf '%s' "$(dirname "$(dirname "${1-}")")"
}

# A foreign ymir root on the climb (a sibling clone, the primary checkout a
# worktree sits on) must not feed this tree's resolution — its node_modules is
# not this install's. Called before descending each ancestor.
_electron_foreign_root() {  # <ancestor> <root>
  [ -n "$2" ] || return 1
  [ "$1" = "$2" ] && return 1          # the tree itself: keep walking through
  [ -f "$1/package.json" ] || return 1
  grep -q '@zerwiz/ymir' "$1/package.json" 2>/dev/null
}

# THE one resolver (P1, 2026-09-24). Every shape npm can leave behind, searched
# in order:
#   (1) the app-local runtime       $app/node_modules/electron
#   (2) the nearest ancestor hoist  the first node_modules/electron up the tree —
#                                   the workspace-root hoist in a clone, the
#                                   shared scope in an npm install
#   (3) the sibling package         $(dirname $root)/@zerwiz/<pkg> — the app
#                                   hoisted OUT of the ymir package to sit beside it
# No caller hardcodes an app-local electron path again: this is the only place
# that knows the shapes. Each candidate is verified executable, never assumed.
electron_bin() {  # <app-dir> [root] [pkg] → prints the binary; exit 0 found / 1 not
  local app="${1-}" root="${2-}" pkg="${3:-${app##*/}}" c
  [ -n "$app" ] && [ -d "$app" ] || return 1
  [ -z "$root" ] && root="$(electron_root "$app")"
  local a="$app"
  # (1)+(2): walk up from the app, checking node_modules/electron at each stop —
  # and when a stop IS a node_modules dir, checking electron directly inside it.
  while [ -n "$a" ] && [ "$a" != "/" ]; do
    _electron_foreign_root "$a" "$root" && break
    if [ "${a##*/}" = node_modules ]; then c="$a/electron/dist/electron"; else c="$a/node_modules/electron/dist/electron"; fi
    [ -x "$c" ] && { printf '%s' "$c"; return 0; }
    a="$(dirname "$a")"
  done
  # (3) the sibling package's own runtime
  c="$(dirname "$root")/$pkg/node_modules/electron/dist/electron"
  [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  return 1
}

# The electron PACKAGE dir (the parent of dist/, holding path.txt) — mirror of
# electron_bin's search, returning the dir instead of the binary.
electron_pkg_dir() {  # <app-dir> [root] [pkg]
  local app="${1-}" root="${2-}" pkg="${3:-${app##*/}}" c
  [ -n "$app" ] && [ -d "$app" ] || return 1
  [ -z "$root" ] && root="$(electron_root "$app")"
  local a="$app"
  while [ -n "$a" ] && [ "$a" != "/" ]; do
    _electron_foreign_root "$a" "$root" && break
    if [ "${a##*/}" = node_modules ]; then c="$a/electron"; else c="$a/node_modules/electron"; fi
    [ -d "$c" ] && { printf '%s' "$c"; return 0; }
    a="$(dirname "$a")"
  done
  c="$(dirname "$root")/$pkg/node_modules/electron"
  [ -d "$c" ] && { printf '%s' "$c"; return 0; }
  return 1
}

# Where a fetch must PUT the runtime when no electron package exists anywhere:
# the workspace root's node_modules/electron (the hoist seat npm guarantees)
# when the app is a member; the app's own node_modules only for a standalone
# app. The RUNNING search (electron_bin) already prefers the nearest installed
# one — this is only the *placement* answer for a missing runtime (P3).
electron_place_dir() {  # <app-dir> [root] [pkg]
  local app="${1-}" root="${2-}" pkg="${3:-${app##*/}}" d
  [ -n "$app" ] && [ -d "$app" ] || return 1
  [ -z "$root" ] && root="$(electron_root "$app")"
  d="$(electron_pkg_dir "$app" "$root" "$pkg")" && [ -n "$d" ] && { printf '%s' "$d"; return 0; }
  if electron_is_workspace_member "$app" "$root"; then
    printf '%s' "$root/node_modules/electron"; return 0
  fi
  printf '%s' "$app/node_modules/electron"; return 0
}

# Is the app inside a tree that declares workspaces? npm will hoist a workspace
# member's deps to that root — installing inside the member reconciles the tree
# and REMOVES the local node_modules (the 2026-09-24 deletion).
electron_is_workspace_member() {  # <app-dir> [root]
  local app="${1-}" root="${2-}"
  [ -n "$app" ] && [ -n "$root" ] || return 1
  [ -f "$root/package.json" ] || return 1
  grep -q '"workspaces"' "$root/package.json" 2>/dev/null || return 1
  case "$app" in "$root"/*) return 0 ;; *) return 1 ;; esac
}

# ok only when the resolver yields an executable binary. partial when an
# electron PACKAGE is present (npm did install it) but the binary is not there
# or not runnable — the gated-postinstall shape. absent when nothing is found.
# Absence is never 'ok'. (P2)
electron_runtime_state() {  # <app-dir> [root] [pkg] → ok | partial | absent
  local app="${1-}" root="${2-}" pkg="${3:-${app##*/}}" dir
  [ -n "$app" ] && [ -d "$app" ] || { printf 'absent'; return 1; }
  [ -z "$root" ] && root="$(electron_root "$app")"
  if electron_bin "$app" "$root" "$pkg" >/dev/null; then printf 'ok'; return 0; fi
  if dir="$(electron_pkg_dir "$app" "$root" "$pkg")" && [ -n "$dir" ]; then
    printf 'partial'; return 1
  fi
  printf 'absent'; return 1
}

electron_remedy() {
  printf 'the runtime download was skipped by npm — approve and rebuild:\n'
  printf '  npm install-scripts approve electron && npm rebuild electron\n'
  printf 'yonder: bin/ymir-install.sh --no-desktop if the web surfaces are enough\n'
}


# ── the mend roads — all resolver-aware, all placing into the resolved dir ──

# npm 11+ gates postinstall scripts (allowScripts), so Electron's binary is
# often never downloaded even though the package installed. This fetches the
# release and places it, version-exact, npm-independent, into the RESOLVED
# electron dir (P3): the workspace root's hoist for a member, app-local else.
electron_fetch_runtime() {  # <app-dir> [root] [pkg]
  local app="${1-}" root="${2-}" pkg="${3:-${app##*/}}" dir v url tmp srcv
  [ -d "$app" ] || return 1
  [ -z "$root" ] && root="$(electron_root "$app")"
  dir="$(electron_place_dir "$app" "$root" "$pkg")" || return 1
  [ -d "$dir" ] || mkdir -p "$dir" || return 1
  [ -f "$dir/path.txt" ] && [ -x "$dir/dist/electron" ] && return 0
  # The exact version: the app's own manifest when it pins electron, else the
  # electron package's manifest already sitting in the place dir.
  v=""
  if [ -f "$app/package.json" ]; then
    v="$(sed -n 's/.*"electron"[[:space:]]*:[[:space:]]*"[^0-9]*\([0-9][0-9.]*\).*/\1/p' "$app/package.json" 2>/dev/null | head -1)"
  fi
  [ -n "$v" ] || v="$(node -e "console.log(require('$dir/package.json').version)" 2>/dev/null || true)"
  [ -n "$v" ] || { printf 'electron_fetch_runtime: no electron version to fetch for %s\n' "$app" >&2; return 1; }
  command -v curl >/dev/null 2>&1 || return 1
  command -v unzip >/dev/null 2>&1 || return 1
  tmp="$(mktemp -d)" || return 1
  url="https://github.com/electron/electron/releases/download/v${v}/electron-v${v}-linux-x64.zip"
  if curl -fsSL --max-time 300 -o "$tmp/e.zip" "$url"; then
    mkdir -p "$dir/dist" && unzip -q -o "$tmp/e.zip" -d "$dir/dist" && printf 'electron' >"$dir/path.txt"
  fi
  rm -rf "$tmp"
  [ -f "$dir/path.txt" ] && [ -x "$dir/dist/electron" ] && { "$dir/dist/electron" --version >/dev/null 2>&1; }
}

# fetch_electron_zip — the PROVEN road (2026-09-23): the postinstall's silent
# failures leave locales/ without the binary; the zip's direct fetch + unzip
# always lands the runtime. Now resolver-aware (P1): it fetches into the
# RESOLVED electron dir, never an app-local hardcode.
fetch_electron_zip() {  # <app-dir> [root] [pkg]
  local app="${1-}" root="${2-}" pkg="${3:-${app##*/}}"
  local dir="$app/node_modules/electron"
  [ -z "$root" ] && root="$(electron_root "$app")"
  dir="$(electron_place_dir "$app" "$root" "$pkg")" || return 1
  [ -d "$dir" ] || mkdir -p "$dir" 2>/dev/null || return 1
  local pkgj="$dir/package.json" v url tmp
  [ -f "$pkgj" ] || return 1
  v="$(node -e "console.log(require('$pkgj').version)" 2>/dev/null)" || return 1
  url="https://github.com/electron/electron/releases/download/v$v/electron-v$v-linux-x64.zip"
  tmp="$(mktemp /tmp/electron-XXXXXX.zip 2>/dev/null)" || return 1
  if command -v curl >/dev/null 2>&1 && curl -sL -m 540 -o "$tmp" "$url" && [ -s "$tmp" ]; then
    ( cd "$dir" && unzip -oq "$tmp" -d dist 2>/dev/null )
    rm -f "$tmp"
  else
    rm -f "$tmp"; return 1
  fi
  [ -x "$dir/dist/electron" ]
}