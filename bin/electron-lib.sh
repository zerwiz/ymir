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
