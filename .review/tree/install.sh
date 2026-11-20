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

PREFIX="${YMIR_NPM_PREFIX:-$HOME/.npm-global}"
PKG="${YMIR_PKG:-@zerwiz/ymir}"

say() { printf '%s\n' "$*" >&2; }

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
say "installing $PKG into $PREFIX …"
# `@latest` AND --prefer-online: a stale cached `latest` is how an install
# succeeds while changing nothing, and the user is left on an old build.
install_args=(-g "$PKG@latest" --prefer-online)
[ "$#" -gt 0 ] && install_args+=("$@")
if ! npm install "${install_args[@]}"; then
  say "error: the install failed — see npm's output above."
  say "note: your PATH is already set, so a second run picks up where this left off."
  exit 1
fi


# 4. the FIRST SETUP — the whole platform, not just a command
# pi.dev and opencode finish here by running their own onboarding; an installer
# that stops at a binary leaves the user with a tool that does nothing yet, and
# with eight things still to go wrong. YMIR_SKIP_SETUP=1 installs the command only.
if [ "${YMIR_SKIP_SETUP:-0}" != 1 ]; then
  say ""
  say "the first setup — the plan, then the work. This takes a few minutes."
  if ! ymir install --yes; then
    say "warn: the setup did not finish cleanly — nothing is lost; run \`ymir\` again to continue."
  fi
fi

# 5. prove the doors rather than promise them
if command -v ymir >/dev/null 2>&1; then
  say ""
  say "ymir $(ymir --version 2>/dev/null || printf '?') — installed."
  say "what stands:"
  ymir validate --quiet 2>/dev/null | grep -E "^  \"" | head -12 | sed 's/^/  /' >&2 || true
  say "next:  ymir raise      # lift the hall (SPA :3888, the board :8437, the windows)"
  say "       ymir --help     # every door"
else
  say "error: the package is installed but \`ymir\` is still not on PATH."
  say "help: export PATH=\"$PREFIX/bin:\$PATH\"   (then open a new shell)"
  exit 1
fi
[ -n "$rc_written" ] && say "PATH written into:$rc_written — open a new shell for other terminals."
