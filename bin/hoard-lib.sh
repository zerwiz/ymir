#!/usr/bin/env bash
# hoard-lib.sh — where Hodd (the private hoard) lives. ONE documented default.
#
# The hoard is NEVER inside the checkout (RULES/04-hoard.md): the repo's `hodd/`
# holds only the guard, the README and `*.example` scaffolds. Private data —
# docs, secrets, identity, tenants — lives at $YMIR_HOARD, else $YMIR_HOME, else
# $HOME/Documents/Ymir. Scripts resolve it HERE so the default can never drift
# between them (Rule 07: configuration is never hardcoded; one documented
# default).
#
# Source-safe; call hoard_root <result-var>.
set -u

hoard_root() {  # <result-var> — the hoard root (may not exist yet)
  local result_var=${1-}
  [ -n "$result_var" ] || return 2
  printf -v "$result_var" '%s' "${YMIR_HOARD:-${YMIR_HOME:-$HOME/Documents/Ymir}}"
}

hoard_env() {  # <result-var> — the platform env file inside the hoard
  local result_var=${1-} root
  [ -n "$result_var" ] || return 2
  hoard_root root
  printf -v "$result_var" '%s' "$root/secrets/platform.env"
}
