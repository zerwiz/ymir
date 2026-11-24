#!/usr/bin/env bash
# install.sh — the one-liner. Ymir into the operator's OWN prefix, with PATH set,
# so `ymir` works in the shell they are standing in and every shell after it.
#
#   curl -fsSL https://raw.githubusercontent.com/zerwiz/ymir/main/install.sh | bash
#
# Why this exists, and why `npm install -g @zerwiz/ymir` alone is not enough: npm
# puts a global command in its global prefix's bin directory, and on an ordinary
# machine that directory is not on PATH. The command is installed and the shell
# cannot see it — the most common "it does not work" in the whole Node ecosystem.
# This script removes that class of failure:
#
#   · a prefix the user owns (no sudo, no EACCES on /usr/lib/node_modules)
#   · the export written into the shell's rc, so it survives the session
#   · and then it proves the door: `ymir --version`
#
# Env: YMIR_NPM_PREFIX (default ~/.npm-global), YMIR_PKG (default @zerwiz/ymir).
set -eu

# Android/Termux: the phone is a `hand`. Detect BEFORE PREFIX is repointed at the
# npm bin (Termux ships its own $PREFIX): the package's os gate rejects android, so
# force the install, and the first setup takes the `hand` role with no prompt.
ON_TERMUX=0
{ [ -n "${TERMUX_VERSION:-}" ] || { [ -n "${PREFIX:-}" ] && [ "${PREFIX#*com.termux}" != "$PREFIX" ]; }; } && ON_TERMUX=1

PREFIX="${YMIR_NPM_PREFIX:-$HOME/.npm-global}"
PKG="${YMIR_PKG:-@zerwiz/ymir}"

say() { printf '%s\n' "$*" >&2; }

# ── the cloth, inline ────────────────────────────────────────────────────────────────────────────────
# This script is piped from curl BEFORE the package exists, so it cannot source bin/desktop/ymir-style.sh.
# What follows is a minimal copy of that file's primitives (same palette, same rules); ymir-style.sh is the
# source of truth — change it there first. Colour and motion only for a human: a terminal on stderr, no
# NO_COLOR, no CI, no dumb TERM. A pipe or a CI log gets one plain line per step and never a control byte.
ST=0
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${CI:-}" ] && [ "${TERM:-dumb}" != dumb ] && [ "${YMIR_NO_COLOR:-0}" != 1 ]; then ST=1; fi
if [ "$ST" = 1 ]; then
  C_BR=$'\033[38;5;179m'; C_ST=$'\033[38;5;109m'; C_BL=$'\033[38;5;167m'; C_FA=$'\033[38;5;101m'; C_BO=$'\033[1m'; C_OFF=$'\033[0m'
  case "${COLORTERM:-}" in truecolor|24bit) C_BR=$'\033[38;2;201;151;79m'; C_ST=$'\033[38;2;150;160;168m'; C_BL=$'\033[38;2;194;88;74m'; C_FA=$'\033[38;2;107;98;80m' ;; esac
else C_BR=""; C_ST=""; C_BL=""; C_FA=""; C_BO=""; C_OFF=""; fi
title() { printf '%s\n%s\n\n' "${C_BR}   ᛉ  ${C_BO}$1${C_OFF}" "${C_FA}      $2${C_OFF}" >&2; }
mark()  { printf '  %s%s%s %s %s%s%s\n' "$1" "$2" "$C_OFF" "$3" "$C_FA" "${4:-}" "$C_OFF" >&2; }   # <colour> <glyph> <name> [detail]
# step "<what>" -- <command…>: a rune turns while it runs; one line at the end; the noise goes to a log. Returns the command's exit code.
step() {
  local what="$1" log rc t0 i=0 pid r; shift; [ "${1:-}" = -- ] && shift
  log="${XDG_STATE_HOME:-$HOME/.local/state}/ymir/log"; mkdir -p "$log" 2>/dev/null || log="${TMPDIR:-/tmp}"
  log="$log/install-$(date +%Y%m%d-%H%M%S)-$$.log"; t0=$SECONDS
  "$@" >"$log" 2>&1 </dev/null & pid=$!
  if [ "$ST" = 1 ]; then
    printf '\033[?25l' >&2
    while kill -0 "$pid" 2>/dev/null; do
      set -- ᛉ ᚠ ᚢ ᚦ ᚨ ᚱ; shift $((i % 6)); r="$1"; i=$((i+1))
      printf '\r\033[K  %s%s%s %s %s%ss%s' "$C_BR" "$r" "$C_OFF" "$what" "$C_FA" "$((SECONDS-t0))" "$C_OFF" >&2; sleep 0.12 2>/dev/null || sleep 1
    done
    printf '\r\033[K\033[?25h' >&2
  fi
  wait "$pid"; rc=$?
  if [ "$rc" -eq 0 ]; then mark "$C_ST" ✓ "$what" "$((SECONDS-t0))s"; rm -f "$log"
  else mark "$C_BL" ✕ "$what" "$((SECONDS-t0))s (exit $rc)"; tail -n 15 "$log" 2>/dev/null | sed "s/^/      /" >&2; printf '      %slog: %s%s\n' "$C_FA" "$log" "$C_OFF" >&2; fi
  return "$rc"
}

title "ymir" "the one-liner — Ymir into a prefix you own, with the command on your PATH"
command -v npm >/dev/null 2>&1 || {
  say "error: npm is not installed, and this script does not install Node."
  say "help: install Node 20+ (https://nodejs.org), then run this again."
  exit 1
}

# 1. a prefix the user owns — every later install is painless
mkdir -p "$PREFIX/bin"
npm config set prefix "$PREFIX" >/dev/null 2>&1 || true
export PATH="$PREFIX/bin:$PATH"

# 2. the PATH FIRST — so a failed install still leaves the command reachable, and
#    the user can simply run it again. (It used to be written after the install,
#    and `"${@:-}"` handed npm an EMPTY argument, so the install failed and the
#    script exited before any shell file was touched: "it never writes to .bashrc".)
rc_written=""
for rc in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile"; do
  [ -e "$rc" ] || continue
  if ! grep -q "$PREFIX/bin" "$rc" 2>/dev/null; then
    printf '\n# Ymir — the npm global bin, so `ymir` is found\ncase ":$PATH:" in *":%s/bin:"*) ;; *) export PATH="%s/bin:$PATH" ;; esac\n' "$PREFIX" "$PREFIX" >>"$rc"
    rc_written="$rc_written ${rc##*/}"
  fi
done
export PATH="$PREFIX/bin:$PATH"

# 3. the package
# `@latest` AND --prefer-online: a stale cached `latest` is how an install
# succeeds while changing nothing, and the user is left on an old build.
install_args=(-g "$PKG@latest" --prefer-online)
[ "$ON_TERMUX" = 1 ] && install_args+=(--force)
[ "$#" -gt 0 ] && install_args+=("$@")
if ! step "installing $PKG into $PREFIX" -- npm install "${install_args[@]}"; then
  say "error: the install failed — npm's own output is in the log named above."
  say "note: your PATH is already set, so a second run picks up where this left off."
  exit 1
fi


# 4. the FIRST SETUP — the whole platform, not just a command
# pi.dev and opencode finish here by running their own onboarding; an installer
# that stops at a binary leaves the user with a tool that does nothing yet, and
# with eight things still to go wrong. YMIR_SKIP_SETUP=1 installs the command only.
if [ "${YMIR_SKIP_SETUP:-0}" != 1 ]; then
  say ""
  say "${C_BO}the first setup${C_OFF} ${C_FA}— the plan, then the work. This takes a few minutes.${C_OFF}"
  setup_args=(install --yes)
  [ "$ON_TERMUX" = 1 ] && setup_args+=(--role hand)
  if ! ymir "${setup_args[@]}"; then
    say "warn: the setup did not finish cleanly — nothing is lost; run \`ymir\` again to continue."
  fi
fi

# 5. prove the doors rather than promise them
if command -v ymir >/dev/null 2>&1; then
  say ""
  mark "$C_ST" ✓ "ymir $(ymir --version 2>/dev/null || printf '?')" "installed"
  say "what stands:"
  ymir validate --quiet 2>/dev/null | grep -E "^  \"" | head -12 | sed 's/^/  /' >&2 || true
  printf '\n%s\n' "${C_BO}Where to go from here${C_OFF}" >&2
  printf '  %s%-22s%s %s%s%s\n' "$C_BR" "ymir raise" "$C_OFF" "$C_FA" "lift the hall (SPA :3888, the board :8437, the windows)" "$C_OFF" >&2
  printf '  %s%-22s%s %s%s%s\n\n' "$C_BR" "ymir --help" "$C_OFF" "$C_FA" "every door" "$C_OFF" >&2
else
  say "error: the package is installed but \`ymir\` is still not on PATH."
  say "help: export PATH=\"$PREFIX/bin:\$PATH\"   (then open a new shell)"
  exit 1
fi
[ -n "$rc_written" ] && say "PATH written into:$rc_written — open a new shell for other terminals."
