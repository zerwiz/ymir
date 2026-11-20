#!/usr/bin/env bash
# realm-lib.sh — resolve the ACTIVE realm (tenant) without assuming the company's.
#
# A fresh Ymir is a distro, not the company that built it: nothing may default to
# a company slug. Resolution order:
#   1. data/realm.md (first line) — the operator's chosen realm, if set;
#   2. the first shipped realm scaffold under svartalfaheim/ (examples/ excluded);
#   3. "default".
# Source-safe. Usage: ymir_active_realm <root> [result-var]
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "${ROOT:-}/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/hoard-lib.sh"; do
    [ -n "$_yc" ] && [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

ymir_active_realm() {  # <root> [result-var]
  local root="${1-}" result_var="${2-}" realm
  if [ -z "$root" ]; then
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
  # The operator's root is $YMIR_HOME (default $HOME/Documents/ymirhome) — never the
  # checkout, so a realm can never be resolved inside the repo. The realm marker
  # lives in the hoard; the realms themselves live beside it under svartalfaheim/.
  root="${YMIR_HOME}"
  realm="$(head -n1 "$root/hodd/data/realm.md" 2>/dev/null | tr -d '[:space:]')"
  if [ -z "$realm" ] && [ -d "$root/svartalfaheim" ]; then
    realm="$(find "$root/svartalfaheim" -mindepth 1 -maxdepth 1 -type d \
      ! -name 'examples' ! -name '.*' -printf '%f\n' 2>/dev/null | sort | head -n1)"
  fi
  realm="${realm:-default}"
  if [ -n "$result_var" ]; then
    printf -v "$result_var" '%s' "$realm"
  else
    printf '%s' "$realm"
  fi
}
