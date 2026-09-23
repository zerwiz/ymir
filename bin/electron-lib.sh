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
# Ymir refuses that silence: a shell is only "ready" when the runtime verifies.
# Source-safe, functions only.
#
#   electron_runtime_state <app-dir>   ok | partial | absent   (exit 0 only for ok)
#   electron_remedy                    the exact command that mends a partial one
set -u

electron_runtime_state() {  # <app-dir>
  local dir="${1-}"
  [ -n "$dir" ] && [ -d "$dir" ] || { printf 'absent'; return 1; }
  [ -d "$dir/node_modules/electron" ] || { printf 'absent'; return 1; }
  # path.txt is written by the postinstall; dist/electron is what it points at.
  if [ -f "$dir/node_modules/electron/path.txt" ] \
     && [ -x "$dir/node_modules/electron/dist/electron" ]; then
    printf 'ok'; return 0
  fi
  printf 'partial'; return 1
}

electron_remedy() {
  printf 'the runtime download was skipped by npm — approve and rebuild:\n'
  printf '  npm install-scripts approve electron && npm rebuild electron\n'
  printf 'yonder: bin/ymir-install.sh --no-desktop if the web surfaces are enough'
}


electron_fetch_runtime() {  # <app-dir> — place the runtime without npm's permission
  # npm gates package install scripts by default, so Electron's postinstall never
  # runs and the desktop windows cannot open — a fresh install of the whole platform
  # with no windows, and no error a user could act on. `npm rebuild` reports success
  # and changes nothing; `npm install-scripts approve` does not exist in every npm.
  # What works, everywhere, is what the postinstall itself does: fetch the release
  # and place it. Version-exact, npm-independent, and proven on this machine.
  local dir="${1-}" app v url tmp
  [ -d "$dir" ] || return 1
  app="$dir/node_modules/electron"
  [ -f "$app/path.txt" ] && [ -x "$app/dist/electron" ] && return 0
  v="$(sed -n 's/.*"electron"[[:space:]]*:[[:space:]]*"[^0-9]*\([0-9][0-9.]*\).*/\1/p' "$dir/package.json" 2>/dev/null | head -1)"
  [ -n "$v" ] || return 1
  command -v curl >/dev/null 2>&1 || return 1
  command -v unzip >/dev/null 2>&1 || return 1
  tmp="$(mktemp -d)" || return 1
  url="https://github.com/electron/electron/releases/download/v${v}/electron-v${v}-linux-x64.zip"
  if curl -fsSL --max-time 300 -o "$tmp/e.zip" "$url"; then
    mkdir -p "$app/dist" && unzip -q -o "$tmp/e.zip" -d "$app/dist" && printf 'electron' >"$app/path.txt"
  fi
  rm -rf "$tmp"
  [ -f "$app/path.txt" ] && [ -x "$app/dist/electron" ] && { "$app/dist/electron" --version >/dev/null 2>&1; }
}

# fetch_electron_zip — the PROVEN road (2026-09-23): the postinstall's silent
# failures leave locales/ without the binary; the zip's direct fetch + unzip
# always lands the runtime. The mend's final tier.
fetch_electron_zip() {  # <app-dir> — the app whose node_modules/electron needs dist/electron
  local dir="$1" pkg v url tmp
  pkg="$dir/node_modules/electron/package.json"
  [ -f "$pkg" ] || return 1
  v="$(node -e "console.log(require('$pkg').version)" 2>/dev/null)" || return 1
  url="https://github.com/electron/electron/releases/download/v$v/electron-v$v-linux-x64.zip"
  tmp="$(mktemp /tmp/electron-XXXXXX.zip 2>/dev/null)" || return 1
  if command -v curl >/dev/null 2>&1 && curl -sL -m 540 -o "$tmp" "$url" && [ -s "$tmp" ]; then
    ( cd "$dir/node_modules/electron" && unzip -oq "$tmp" -d dist 2>/dev/null )
    rm -f "$tmp"
  else
    rm -f "$tmp"; return 1
  fi
  [ -x "$dir/node_modules/electron/dist/electron" ]
}

# electron_find — the SHARED runtime: any app's electron in this tree (the
# never-happen law: one fetch seats every view; a view without its own dep runs
# the found one). Returns the app dir containing the binary, "" when none.
electron_find() {  # <root> — the ymir root (repo or npm package)
  local root="$1" d
  for d in "$root"/apps/*/node_modules/electron; do
    [ -x "$d/dist/electron" ] && { printf '%s' "$(dirname "$d")"; return 0; }
  done
  return 1
}

# seat_app_runtime — the install-time runtime seating (the never-happen law):
# the app's deps, then the electron (the PROVEN zip road, or the found seat's
# symlink — ONE fetch for the whole tree).
seat_app_runtime() {  # <app-dir> <fetched-app-dir-or-"">
  local dir="$1" shared="$2" pkg
  [ -d "$dir/node_modules/electron/dist" ] && return 0
  command -v npm >/dev/null 2>&1 || return 1
  ( cd "$dir" && npm install --include=dev >/dev/null 2>&1 )
  if [ -d "$dir/node_modules/electron" ] && [ ! -x "$dir/node_modules/electron/dist/electron" ]; then
    if [ -n "$shared" ] && [ -x "$shared/node_modules/electron/dist/electron" ]; then
      rm -rf "$dir/node_modules/electron"
      ln -s "$shared/node_modules/electron" "$dir/node_modules/electron" 2>/dev/null
    else
      fetch_electron_zip "$dir" >/dev/null 2>&1 || true
    fi
  fi
  [ -x "$dir/node_modules/electron/dist/electron" ]
}
