#!/usr/bin/env bash
# 00-lib.sh — the helpers a gate may call. Not a gate: no `gate` call is made here.
#
# It is the FIRST file the driver sources (the names are read in C order), so every gate below
# may use what it defines. A helper lives here only when two gates need the same answer; a gate
# that needs none should not read this file at all.

# nodelete_base — the ref a range gate judges. The PR's base when the host names one (a pull
# request checkout has it), else origin/main. Returns non-zero when this checkout has no base at
# all, which the caller must report as an honest SKIP, never as a green.
nodelete_base() {
  local b=""
  if [ -n "${GITHUB_BASE_REF:-}" ] && git rev-parse -q --verify "origin/${GITHUB_BASE_REF}" >/dev/null 2>&1; then
    b="origin/${GITHUB_BASE_REF}"
  elif git rev-parse -q --verify origin/main >/dev/null 2>&1; then
    b="origin/main"
  fi
  [ -n "$b" ] || return 1
  printf '%s' "$b"
}
