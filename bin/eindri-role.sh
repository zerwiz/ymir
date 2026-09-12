#!/usr/bin/env bash
# eindri-role.sh — the right smith for the right metal.
#
# An Eindri is a delegated hand (see AGENTS.md / docs/lore.md §II). Choosing the
# wrong smith for a task is like handing a skald a hammer: the work gets done
# badly, or not at all. This maps a task to the agent whose craft matches it.
#
# The roster is the source of truth (.agents/agents/*.md). This is the chooser.
#
# Usage:
#   bin/eindri-role.sh list
#   bin/eindri-role.sh choose "<task text>"        # the smith whose craft fits
#   bin/eindri-role.sh for <keyword>               # exact role lookup
#   bin/eindri-role.sh --version
#
# Output: Galdr TOON.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-list}"; shift || true

# role | craft | the words that call it
roles() {
  cat <<'ROLES'
sindri|code — build, refactor, fix, test|code build refactor fix bug implement feature test compile script forge api backend frontend function class module
bragi|content — marketing, SEO, social|content write copy marketing seo social post article blog campaign brand announcement newsletter
huginn|research — search, analyse, discover|research search analyse analyze investigate find discover compare benchmark source docs look up
kvasir|scout — recon a codebase before work|scout recon survey map explore inventory reconnaissance lay of the land
hnoss|design — UI/UX, prototypes, decks, dashboards|design ui ux prototype landing dashboard deck slide visual layout figma design-system
mimir|plan — design the approach|plan design architect approach strategy spec breakdown sequence decompose
snotra|document — prose, guides, references|document docs guide reference readme manual explain describe prose
forseti|review — judge the work|review judge audit critique verify assess check inspect quality gate
galdr|runtime — the Ymir distro itself|galdr runtime distro install skill toon cli agent-facing extension
ROLES
}

case "$ACTION" in
  list)
    printf 'eindri-roles[8]{role,craft}:\n'
    while IFS='|' read -r r c _; do
      printf '  "%s","%s"\n' "$r" "$c"
    done < <(roles)
    ;;
  for)
    want="${1:-}"
    [ -n "$want" ] || { printf 'error: for needs a role name\n' >&2; exit 2; }
    hit="$(roles | awk -F'|' -v w="$want" '$1==w {print}')"
    if [ -n "$hit" ]; then
      printf 'eindri-role[1]{role,craft}:\n  "%s","%s"\n' "$(printf '%s' "$hit" | cut -d'|' -f1)" "$(printf '%s' "$hit" | cut -d'|' -f2)"
    else
      printf 'eindri-role[1]{role,known}:\n  "%s","no"\n' "$want"
      printf 'help: bin/eindri-role.sh list\n' >&2
      exit 1
    fi
    ;;
  choose)
    text="$(printf '%s' "${*:-}" | tr '[:upper:]' '[:lower:]')"
    [ -n "$text" ] || { printf 'error: choose needs task text\n' >&2; exit 2; }
    best=""; bestscore=0
    while IFS='|' read -r r craft words; do
      s=0
      for w in $words; do
        case "$text" in *"$w"*) s=$((s+1));; esac
      done
      if [ "$s" -gt "$bestscore" ]; then bestscore=$s; best="$r"; bestcraft="$craft"; fi
    done < <(roles)
    if [ -z "$best" ]; then
      # No craft word matched: the smith of first resort for general work.
      best="sindri"; bestcraft="code — build, refactor, fix, test"
    fi
    printf 'eindri-choice[1]{role,craft,score}:\n  "%s","%s",%s\n' "$best" "$bestcraft" "$bestscore"
    ;;
  *) printf 'error: unknown action %s\nhelp: bin/eindri-role.sh [list|choose|for]\n' "$ACTION" >&2; exit 2 ;;
esac
