#!/usr/bin/env bash
# valknut-load.sh — Valknut, the knot that binds the repo distro into each tool's
# load path. Galdr-style: TOON output, structured errors, no prompts, idempotent.
#
# The repo is the source of truth: agents live in `.agents/agents/`, skills in
# `.agents/skills/`, Pi extensions in `.pi/extensions/`, the backend in
# `bin/` + `.agents/backend/`. This command binds them where each harness looks.
#
# Usage:
#   bin/valknut-load.sh [--opencode] [--pi] [--global] [--status] [--all]
#   bin/valknut-load.sh --version | -v
#
# Exit: 0 ok, 1 error, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS="$ROOT/.agents/agents"
PI_LOCAL="$ROOT/.pi/agents"
PI_GLOBAL="${HOME}/.pi/agent/agents"
# Shared Pi extensions have ONE home: ${HOME}/.pi/agent/extensions/ (see
# galdr/assets/harness-integration/README.md). The repo keeps their SOURCE at
# .pi/shared/extensions/ — never at .pi/extensions/, because an extension present
# in both load paths makes pi exit with a tool-name conflict and no agent can be
# seated. This loader DEPLOYS that source into the single home.
PI_EXT_SRC="$ROOT/.pi/shared/extensions"
PI_EXT_HOME="${HOME}/.pi/agent/extensions"
OC_LOCAL="$ROOT/.opencode/agent"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

for a in "$@"; do
  case "$a" in
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
  esac
done

MODE_OPENCODE=0; MODE_PI=0; MODE_GLOBAL=0; MODE_STATUS=0
for a in "$@"; do
  case "$a" in
    --opencode) MODE_OPENCODE=1 ;;
    --pi|--agents) MODE_PI=1 ;;
    --global) MODE_GLOBAL=1 ;;
    --status) MODE_STATUS=1 ;;
    --all) MODE_OPENCODE=1; MODE_PI=1 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/valknut-load.sh [--opencode|--pi|--global|--status|--all]\n' "$a" >&2; exit 2 ;;
  esac
done
[ $((MODE_OPENCODE + MODE_PI + MODE_STATUS)) -eq 0 ] && { MODE_OPENCODE=1; MODE_PI=1; }

if [ ! -d "$AGENTS" ]; then
  printf 'error: agents dir not found: %s\nhelp: expected .agents/agents/ inside %s\n' "$AGENTS" "$ROOT"
  exit 1
fi

declare -a T P S
add() { T+=("$1"); P+=("$2"); S+=("$3"); }

link_agent_dir() {  # <target-dir> <rel-prefix>
  local target=$1 prefix=$2 made=0
  mkdir -p "$target" || return 1
  local f base
  for f in "$AGENTS"/*.md; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    ln -sfn "${prefix}/${base}" "$target/$base" 2>/dev/null || return 1
    made=$((made + 1))
  done
  printf '%s' "$made"
}

if [ "$MODE_STATUS" = 1 ]; then
  printf 'loaders[4]{tool,path,status}:\n'
  [ -d "$OC_LOCAL" ] && printf '  "opencode","%s","%s files"\n' "$OC_LOCAL" "$(ls "$OC_LOCAL"/*.md 2>/dev/null | wc -l | tr -d ' ')" || printf '  "opencode","%s","absent"\n' "$OC_LOCAL"
  [ -d "$PI_LOCAL" ] && printf '  "pi-local","%s","%s links"\n' "$PI_LOCAL" "$(ls "$PI_LOCAL"/*.md 2>/dev/null | wc -l | tr -d ' ')" || printf '  "pi-local","%s","absent"\n' "$PI_LOCAL"
  [ -d "$PI_GLOBAL" ] && printf '  "pi-global","%s","%s links"\n' "$PI_GLOBAL" "$(ls "$PI_GLOBAL"/*.md 2>/dev/null | wc -l | tr -d ' ')" || printf '  "pi-global","%s","absent"\n' "$PI_GLOBAL"
  printf '  "agents-source","%s","%s files"\n' "$AGENTS" "$(ls "$AGENTS"/*.md 2>/dev/null | wc -l | tr -d ' ')"
  exit 0
fi

if [ "$MODE_OPENCODE" = 1 ]; then
  if [ -d "$OC_LOCAL" ]; then
    n=$(ls "$OC_LOCAL"/*.md 2>/dev/null | wc -l | tr -d ' ')
    add opencode "$OC_LOCAL" "native ($n agents)"
  else
    add opencode "$OC_LOCAL" "ERROR absent"
  fi
fi

if [ "$MODE_PI" = 1 ]; then
  n=$(link_agent_dir "$PI_LOCAL" "../../.agents/agents") && add pi-local "$PI_LOCAL" "bound ($n links)" || add pi-local "$PI_LOCAL" "ERROR"
  if [ "$MODE_GLOBAL" = 1 ]; then
    g=$(link_agent_dir "$PI_GLOBAL" "$AGENTS") && add pi-global "$PI_GLOBAL" "bound ($g links)" || add pi-global "$PI_GLOBAL" "ERROR"
  fi
  # Deploy the shared extensions into their single home. Copy, not link: a
  # broken link would silently disable a tool, and pi reads the file directly.
  # Idempotent — identical files are left untouched.
  if [ -d "$PI_EXT_SRC" ]; then
    mkdir -p "$PI_EXT_HOME" 2>/dev/null
    dep_n=0
    for f in "$PI_EXT_SRC"/*.ts; do
      [ -e "$f" ] || continue
      b=$(basename "$f")
      if [ -f "$PI_EXT_HOME/$b" ] && cmp -s "$f" "$PI_EXT_HOME/$b"; then continue; fi
      cp -f "$f" "$PI_EXT_HOME/$b" && dep_n=$((dep_n+1))
    done
    add pi-extensions "$PI_EXT_HOME" "$dep_n deployed (shared single home)"
  fi
fi

printf 'loaders[%s]{tool,path,status}:\n' "${#T[@]}"
for i in "${!T[@]}"; do
  printf '  "%s","%s","%s"\n' "${T[$i]}" "${P[$i]}" "${S[$i]}"
done
printf 'help[1]: run `bin/valknut-load.sh --status` to inspect bindings\n'
