#!/usr/bin/env bash
# prereq-ensure.sh — self-healing prerequisite engine for Ymir.
#
# The installer should not leave the operator to fix prerequisites by hand.
# This helper provisions what it can, in USER SPACE (no sudo), and reports
# clearly what it could not do. Every action is idempotent.
#
# Engine:
#   bun       — installs via the official installer, then ~/.bun/bin on PATH
#   uv        — installs via the official installer (used for Python provisioning)
#   pip       — reported with a per-manager hint (needs a system package)
#   mcp<2     — pip-installed into the user site
#   pythonX.Y — fetched by uv in user space when a package needs another Python
#
# Usage:
#   bin/prereq-ensure.sh bun | uv | mcp | python <X.Y> | all
#   bin/prereq-ensure.sh status
#   bin/prereq-ensure.sh --version
#
# Output: Galdr TOON. Exit 0 when the target is present afterwards, 1 otherwise.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUN_HOME="${BUN_INSTALL:-$HOME/.bun}"

add_path() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }
have() { command -v "$1" >/dev/null 2>&1; }
say()  { printf 'prereq[1]{name,state,detail}:\n  "%s","%s","%s"\n' "$1" "$2" "$3"; }

# ── the memory engine (engram) ───────────────────────────────────────────────
# engram needs Python >=3.12,<3.14. A modern distro may ship something newer
# (this box: 3.14), so the engine is installed into a COMPATIBLE interpreter and
# that interpreter is recorded for the bridge to reuse. uv can supply one.
ENGRAM_PY_FILE="${YMIR_ENGRAM_PY:-$HOME/.config/ymir/engram-python}"

engram_python() {  # echo an interpreter that can (or could) run engram
  local p
  for p in "${YMIR_ENGRAM_PYTHON:-}" python3.12 python3.13; do
    [ -n "$p" ] || continue
    command -v "$p" >/dev/null 2>&1 && { printf '%s' "$p"; return 0; }
  done
  if command -v uv >/dev/null 2>&1; then
    p="$(uv python find 3.12 2>/dev/null || uv python find 3.13 2>/dev/null || true)"
    [ -n "$p" ] && { printf '%s' "$p"; return 0; }
  fi
  printf 'python3'
}

ensure_engram() {
  local py; py="$(engram_python)"
  if "$py" -c 'import engram' >/dev/null 2>&1; then
    mkdir -p "$(dirname "$ENGRAM_PY_FILE")" 2>/dev/null
    printf '%s\n' "$py" >"$ENGRAM_PY_FILE" 2>/dev/null
    say engram present "importable under $py"
    return 0
  fi
  # is the chosen interpreter even in engram's supported range?
  if ! "$py" -c 'import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)' >/dev/null 2>&1; then
    if command -v uv >/dev/null 2>&1 && uv python install 3.12 >/dev/null 2>&1; then
      py="$(uv python find 3.12 2>/dev/null || printf '%s' "$py")"
    fi
  fi
  if "$py" -c 'import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)' >/dev/null 2>&1 \
     && "$py" -m pip install --user --break-system-packages -q engdbram >/dev/null 2>&1 \
     && "$py" -c 'import engram' >/dev/null 2>&1; then
    mkdir -p "$(dirname "$ENGRAM_PY_FILE")" 2>/dev/null
    printf '%s\n' "$(command -v "$py" 2>/dev/null || printf '%s' "$py")" >"$ENGRAM_PY_FILE" 2>/dev/null
    say engram installed "$py"
    return 0
  fi
  say engram absent "install failed (engdbram needs Python >=3.11) — try: uv python install 3.12"
  return 1
}

ensure_bun() {
  add_path "$BUN_HOME/bin"
  if have bun; then say bun present "$(bun --version 2>/dev/null)"; return 0; fi
  if curl -fsSL https://bun.sh/install 2>/dev/null | bash >/dev/null 2>&1; then
    add_path "$BUN_HOME/bin"
    if have bun; then say bun installed "$(bun --version 2>/dev/null)"; return 0; fi
  fi
  say bun absent "install manually: https://bun.sh (or your package manager)"
  return 1
}

ensure_uv() {
  add_path "$HOME/.local/bin"
  if have uv; then say uv present "$(uv --version 2>/dev/null | awk '{print $2}')"; return 0; fi
  if curl -fsSL https://astral.sh/uv/install.sh 2>/dev/null | sh >/dev/null 2>&1; then
    add_path "$HOME/.local/bin"
    if have uv; then say uv installed "$(uv --version 2>/dev/null | awk '{print $2}')"; return 0; fi
  fi
  say uv absent "install manually: https://astral.sh/uv"
  return 1
}

# Fetch a Python interpreter in user space via uv. Prints its path on success.
ensure_python() {
  local want="$1"
  if have "python$want"; then
    say "python$want" present "$(command -v "python$want")"
    command -v "python$want"
    return 0
  fi
  ensure_uv >/dev/null 2>&1 || true
  if have uv; then
    if uv python install "$want" >/dev/null 2>&1; then
      local p
      p="$(uv python find "$want" 2>/dev/null || true)"
      if [ -n "$p" ]; then say "python$want" installed "$p"; printf '%s\n' "$p"; return 0; fi
    fi
  fi
  say "python$want" absent "uv could not fetch it (offline?)"
  return 1
}

ensure_mcp() {
  if python3 -c "from mcp.server.fastmcp import FastMCP" >/dev/null 2>&1; then
    say "mcp<2" present "importable"
    return 0
  fi
  if python3 -m pip --version >/dev/null 2>&1; then
    if python3 -m pip install --user --break-system-packages -q 'mcp<2' >/dev/null 2>&1 \
       && python3 -c "from mcp.server.fastmcp import FastMCP" >/dev/null 2>&1; then
      say "mcp<2" installed "user site"
      return 0
    fi
  fi
  say "mcp<2" absent "needs pip (a system package on this distro)"
  return 1
}

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

case "$1" in
  bun)    ensure_bun ;;
  uv)     ensure_uv ;;
  mcp)    ensure_mcp ;;
  engram) ensure_engram ;;
  python) ensure_python "${2:?usage: prereq-ensure.sh python <X.Y>}" ;;
  status)
    printf 'prereq[5]{name,state,detail}:\n'
    for c in git python3 bun docker gh uv; do
      if have "$c"; then printf '  "%s","present","%s"\n' "$c" "$(command -v "$c")"
      else printf '  "%s","absent","-"\n' "$c"; fi
    done
    ;;
  all)
    rc=0
    ensure_bun || rc=1
    ensure_uv  || rc=1
    ensure_mcp || rc=1
    exit $rc ;;
  *) printf 'error: unknown target %s\nhelp: bin/prereq-ensure.sh [bun|uv|mcp|engram|python X.Y|status|all]\n' "$1" >&2; exit 2 ;;
esac
