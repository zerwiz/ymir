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
