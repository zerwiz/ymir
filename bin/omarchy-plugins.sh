#!/usr/bin/env bash
# omarchy-plugins.sh — the Omarchy plugins Ymir suggests, and installs on consent.
#
# Ymir runs on Omarchy, and Omarchy's shell is plugin-shaped: the bar, the panels,
# the overlays are all plugins. A few of them are Ymir's own organs rendered on
# the desktop — herdr (Þjazi), Hermes (our worker runtime), and skills (the Galdr
# family). This suggests them at install, and installs only what the Allfather
# accepts.
#
# Installing is Omarchy's own verb — never a raw clone:
#   omarchy plugin add <repo> [--enable]   ·   omarchy plugin remove <id>
# (Omarchy docs: "A plugin is a git repo with a manifest.json at its root.")
#
# Usage:
#   bin/omarchy-plugins.sh list                  # what Ymir suggests
#   bin/omarchy-plugins.sh installed             # what is present now
#   bin/omarchy-plugins.sh suggest [--yes]       # offer them; install on consent
#   bin/omarchy-plugins.sh add <id>              # install one (with consent unless --yes)
#   bin/omarchy-plugins.sh --version
#
# Consent: nothing is installed without an explicit yes (or --yes). These are
# third-party plugins that run unsandboxed inside the Omarchy shell — the registry
# itself says it "validates listings, not plugin security".
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
YES=0

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-list}"; shift || true
[ "${1:-}" = "--yes" ] && YES=1
[ "${1:-}" = "-y" ] && YES=1

have() { command -v "$1" >/dev/null 2>&1; }

# id | name | why it earns a place in Ymir's suggestion list
catalog() {
  cat <<'PLUGINS'
io.github.eszanon.herdr|Herdr Watch|herdr agents in the bar, flags the ones waiting on you — Þjazi made visible
io.github.mbot11.hermes-deck|Hermes Deck|live Hermes companion: status, sessions, usage, controls — Hermes is our worker runtime
firstpick.skill-manager|Skill Manager|links local skills across Pi, OpenCode, Claude Code, Cursor, Codex — the Galdr family on every harness
io.github.fabean.herdr|Herdr|monitor herdr agent activity and status from the bar
stappmus.udder|Udder|all your herdr agents in the bar, notified when one finishes
mrpbennett.herdr-agents|Herdr Agents|every agent's state and current activity in the bar
io.github.andy-spike.herdr-theme-sync|Herdr Theme Sync|keeps herdr colors in step with the Omarchy theme
yordanbuilds.rig|Rig|project stacks for herdr — one JSON file and the workspace is up
tsouth89.omcp|OMCP|turn this desktop into an MCP server other agents can drive
PLUGINS
}

installed_plugins() {
  have omarchy || return 0
  # omarchy plugin list --json is the structured form; fall back to plain text.
  if omarchy plugin list --json >/dev/null 2>&1; then
    omarchy plugin list --json 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
    items = d.get("plugins") if isinstance(d, dict) else d
    if isinstance(items, dict): items = list(items.values())
    for it in (items or []):
        print(it.get("id") or it.get("name") or "")
except Exception:
    pass' 2>/dev/null
  else
    omarchy plugin list 2>/dev/null | awk '{print $1}'
  fi
}

is_installed() {  # <id>
  installed_plugins | grep -qxF "$1" 2>/dev/null
}

repo_for() {  # <id> — read the repo from the registry's own catalog when reachable
  local id=$1 cache="$ROOT/state/omarchy-catalog.json"
  if [ -r "$cache" ]; then
    python3 - "$cache" "$id" <<'PY' 2>/dev/null
import json,sys
try:
    d=json.load(open(sys.argv[1])); items=d.get("plugins", d)
    if isinstance(items, dict): items=list(items.values())
    for it in items:
        if it.get("id")==sys.argv[2]:
            print(it.get("repo") or ""); break
except Exception:
    pass
PY
  fi
}

case "$ACTION" in
  list)
    printf 'omarchy-plugins[%d]{id,name,why}:\n' "$(catalog | grep -c .)"
    while IFS='|' read -r id name why; do
      [ -n "$id" ] || continue
      printf '  "%s","%s","%s"\n' "$id" "$name" "$why"
    done < <(catalog)
    printf 'install: bin/omarchy-plugins.sh add <id>   (Omarchy installs via `omarchy plugin add`)\n'
    ;;
  installed)
    if ! have omarchy; then printf 'omarchy-plugins[1]{state}:\n  "not an Omarchy host"\n'; exit 0; fi
    mapfile -t have_ids < <(installed_plugins)
    printf 'omarchy-plugins[%d]{id,present}:\n' "${#have_ids[@]}"
    for id in "${have_ids[@]}"; do [ -n "$id" ] && printf '  "%s","yes"\n' "$id"; done
    ;;
  suggest)
    if ! have omarchy; then printf 'omarchy-plugins[1]{state}:\n  "skipped — not an Omarchy host"\n'; exit 0; fi
    printf 'Ymir suggests these Omarchy plugins — third-party code that runs inside your shell:\n\n'
    while IFS='|' read -r id name why; do
      [ -n "$id" ] || continue
      if is_installed "$id"; then printf '  [have] %-32s %s\n' "$name" "$why"
      else printf '  [ -- ] %-32s %s\n' "$name" "$why"; fi
    done < <(catalog)
    printf '\nEach is Omarchy-verified as a listing, not audited for safety. Install one at a time:\n'
    printf '  bin/omarchy-plugins.sh add <id>\n'
    if [ "$YES" = 1 ]; then
      while IFS='|' read -r id name why; do
        [ -n "$id" ] || continue
        is_installed "$id" && continue
        "$SCRIPT_DIR/omarchy-plugins.sh" add "$id" --yes || true
      done < <(catalog)
    fi
    ;;
  add)
    id="${1:-}"; shift || true
    [ -n "$id" ] || { printf 'error: add needs a plugin id\nhelp: bin/omarchy-plugins.sh list\n' >&2; exit 2; }
    [ "${1:-}" = "--yes" ] && YES=1
    have omarchy || { printf 'error: not an Omarchy host (no `omarchy` command)\n' >&2; exit 1; }
    if is_installed "$id"; then
      printf 'omarchy-plugins[1]{id,state}:\n  "%s","already installed"\n' "$id"; exit 0
    fi
    # Resolve the repo from the registry catalog; refresh it if absent.
    cache="$ROOT/state/omarchy-catalog.json"
    if [ ! -r "$cache" ] && have curl; then
      mkdir -p "$(dirname "$cache")"
      curl -fsS --max-time 25 https://plugins.omarchy.org/catalog.json -o "$cache" 2>/dev/null || true
    fi
    repo="$(repo_for "$id")"
    if [ -z "$repo" ]; then
      printf 'error: cannot resolve the repository for %s\nhelp: check the id (bin/omarchy-plugins.sh list), or install by repo:\n' "$id" >&2
      printf '      omarchy plugin add <git-url> --enable\n' >&2
      exit 1
    fi
    if [ "$YES" != 1 ]; then
      if [ ! -t 0 ]; then
        printf 'error: refusing to install %s without --yes\nhelp: bin/omarchy-plugins.sh add %s --yes\n' "$id" "$id" >&2
        exit 3
      fi
      printf 'Install %s from %s? It runs unsandboxed inside your Omarchy shell. [y/N] ' "$id" "$repo"
      read -r reply || reply=""
      case "$reply" in y|Y|yes|YES) ;; *) printf 'skipped.\n'; exit 0 ;; esac
    fi
    if omarchy plugin add "$repo" --enable >/dev/null 2>&1; then
      printf 'omarchy-plugins[1]{id,state,repo}:\n  "%s","installed","%s"\n' "$id" "$repo"
    else
      printf 'omarchy-plugins[1]{id,state}:\n  "%s","install failed"\n' "$id"
      printf 'help: run manually: omarchy plugin add %s --enable\n' "$repo" >&2
      exit 1
    fi
    ;;
  *) printf 'error: unknown action %s\nhelp: bin/omarchy-plugins.sh [list|installed|suggest|add]\n' "$ACTION" >&2; exit 2 ;;
esac
