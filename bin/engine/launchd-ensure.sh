#!/usr/bin/env bash
# launchd-ensure.sh — seat the macOS service layer: `systemctl --user` answered by launchd.
#
# WHY (2026-11-15, plan 293). Ymir's units are systemd user units, driven by `systemctl --user` from
# some sixty call sites. A Mac has no systemd, so the units were written and nothing ran them.
# bin/engine/launchd-user.py answers those verbs by rendering each unit as a launchd agent; this
# script puts it on the PATH as `systemctl`, so the core stays one core (RULES/05).
#
#   bin/engine/launchd-ensure.sh check      # is the layer seated? (exit 0 yes, 1 no)
#   bin/engine/launchd-ensure.sh ensure     # seat it (idempotent)
#   bin/engine/launchd-ensure.sh remove     # take the shim away (agents stay until disabled)
#
# Off a Mac every verb is a clean skip (exit 0). A real systemctl already on the PATH is never shadowed.
# Exit: 0 ok/skip · 1 not seated (check) or could not seat · 2 usage.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# the shim points at the PINNED runtime when one exists (RULES/02 §7), never at a working tree
PIN="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"
[ -f "$PIN/bin/engine/launchd-user.py" ] || PIN="$ROOT"
TARGET="$PIN/bin/engine/launchd-user.py"
BIN_DIR="${YMIR_SHORTCUT_BIN:-$HOME/.local/bin}"
SHIM="$BIN_DIR/systemctl"
RUN_SHIM="$BIN_DIR/systemd-run"   # the same file answers systemd-run (transient units) by its name

row() { printf '  "%s","%s","%s"\n' "$1" "$2" "$3"; }

case "$(uname -s 2>/dev/null)" in
  Darwin*) ;;
  *) printf 'launchd[1]{step,state,detail}:\n'; row launchd SKIP "not a Mac — systemd is the service manager here"; exit 0 ;;
esac

real_systemctl() {  # a systemctl on the PATH that is not ours
  local p
  p="$(command -v systemctl 2>/dev/null)" || return 1
  [ "$p" = "$SHIM" ] && return 1
  [ -L "$p" ] && [ "$(readlink "$p")" = "$TARGET" ] && return 1
  return 0
}

seated() { [ -L "$SHIM" ] && [ "$(readlink "$SHIM")" = "$TARGET" ] && [ -x "$TARGET" ]; }

cmd="${1:-check}"
printf 'launchd[1]{step,state,detail}:\n'
case "$cmd" in
  check)
    if seated; then row launchd OK "systemctl --user -> launchd ($SHIM -> $TARGET)"; exit 0; fi
    row launchd FAIL "not seated — run bin/engine/launchd-ensure.sh ensure"; exit 1 ;;
  ensure)
    if real_systemctl; then row launchd SKIP "a real systemctl is on the PATH ($(command -v systemctl)) — left alone"; exit 0; fi
    command -v python3 >/dev/null 2>&1 || { row launchd FAIL "python3 is missing — install the Xcode command line tools"; exit 1; }
    chmod +x "$TARGET" 2>/dev/null || true
    mkdir -p "$BIN_DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/ymir"
    if seated; then
      [ -e "$RUN_SHIM" ] && [ ! -L "$RUN_SHIM" ] || ln -sfn "$TARGET" "$RUN_SHIM"
      row launchd OK "already seated ($SHIM)"; exit 0
    fi
    if [ -e "$SHIM" ] && [ ! -L "$SHIM" ]; then row launchd FAIL "$SHIM exists and is not Ymir's — move it aside first"; exit 1; fi
    ln -sfn "$TARGET" "$SHIM" || { row launchd FAIL "could not link $SHIM"; exit 1; }
    [ -e "$RUN_SHIM" ] && [ ! -L "$RUN_SHIM" ] || ln -sfn "$TARGET" "$RUN_SHIM"
    case ":$PATH:" in *":$BIN_DIR:"*) ;; *) row path WARN "$BIN_DIR is not on this shell's PATH — the installer's shell step adds it" ;; esac
    row launchd OK "seated: systemctl --user -> launchd ($SHIM -> $TARGET)"; exit 0 ;;
  remove)
    if [ -L "$SHIM" ] && [ "$(readlink "$SHIM")" = "$TARGET" ]; then rm -f "$SHIM"; [ -L "$RUN_SHIM" ] && rm -f "$RUN_SHIM"; row launchd OK "removed $SHIM"; else row launchd SKIP "not seated"; fi
    exit 0 ;;
  -h|--help|help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'error: unknown command %s (check|ensure|remove)\n' "$cmd" >&2; exit 2 ;;
esac
