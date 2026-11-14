#!/usr/bin/env bash
# eindri-bearings.sh — the Bearings every errand's brief carries: the fixed core, the project's
# records, and the home's document map.
#
# WHY (plan 291 part 2, the Allfather 2026-11-14: *"we need to update the endri system so they
# are allways using and updateing this when getting send out"*): measured the same day, a brief was
# exactly what the helm remembered to type. Nothing told a worker where its project's decisions,
# handoff, plans, schedule, meetings and boards live, and nothing asked it to update them. The
# "fixed core" every worker carries was a hand-kept file in the helm's scratchpad, not part of the
# system. This door makes it part of the system.
#
# It prints, in this order:
#   (a) THE FIXED CORE — the SHIPPED, AGNOSTIC template `.agents/assets/agents/eindri-core.md`,
#       followed by the home's own overlay `$YMIR_HOME/config/eindri-core.md` when it exists.
#       This fleet's names, panes, machines and standing words live in the overlay, never here.
#   (b) THE PROJECT'S RECORDS — resolved through `bin/agents/project-target.sh` from the registry
#       (`hodd/identity/projects.yaml`). A row with no `records:` block says so and names the row
#       to add; this door never invents a path.
#   (c) THE HOME'S DOCUMENT MAP — the shelves named by `.ymir-layout.yaml`, the knowledge index,
#       the plan ledger's own README, and the shelf a report goes on.
#
# ONE caller-shape, every road: `eindri-start.sh` and the engine both prepend this to the brief,
# and both skip it when the brief already carries the marker (so a brief is never doubled).
#
# Usage:
#   eindri-bearings.sh [<path|id|alias>]          # the Bearings section (markdown)
#   eindri-bearings.sh --marker                   # the marker line a brief is tested against
#   eindri-bearings.sh --check                    # the doors this section reads, and whether each answers
#
# Exit: 0 the section is printed · 1 the fixed core cannot be read (a brief without its core is a
# refusal, never a silent short brief) · 2 usage.
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"
CORE="$ROOT/.agents/assets/agents/eindri-core.md"
TARGET="$SELF/project-target.sh"
MARKER='<!-- eindri-bearings:v1 — the fixed core, your project'\''s records, and the home'\''s map -->'

if [ -z "${YMIR_HOME:-}" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  YMIR_HOME="$(bash -c '. "$1/bin/vault/hoard-lib.sh" >/dev/null 2>&1; ymir_home_root out; printf %s "$out"' _ "$ROOT" 2>/dev/null || true)"
  export YMIR_HOME
fi

usage() { sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1-}" in
  -h|--help|"") usage; exit 0 ;;
  --marker) printf '%s\n' "$MARKER"; exit 0 ;;
  --check)
    rc=0
    row() { printf '  "%s","%s","%s"\n' "$1" "$2" "$3"; }
    printf 'eindri-bearings[6]{part,door,state}:\n'
    [ -r "$CORE" ] && row core "$CORE" present || { row core "$CORE" MISSING; rc=1; }
    [ -r "${YMIR_HOME:-}/config/eindri-core.md" ] && row overlay "${YMIR_HOME:-}/config/eindri-core.md" present \
      || row overlay "${YMIR_HOME:-}/config/eindri-core.md" absent
    [ -x "$TARGET" ] && row records "$TARGET" present || { row records "$TARGET" MISSING; rc=1; }
    [ -r "${YMIR_HOME:-}/.ymir-layout.yaml" ] && row map "${YMIR_HOME:-}/.ymir-layout.yaml" present \
      || row map "${YMIR_HOME:-}/.ymir-layout.yaml" absent
    row reports "${YMIR_HOME:-}/state/eindri-reports/" "$([ -d "${YMIR_HOME:-}/state/eindri-reports" ] && echo present || echo 'absent (made by the terminal act)')"
    row home "${YMIR_HOME:-}" "$([ -n "${YMIR_HOME:-}" ] && [ -d "${YMIR_HOME:-}" ] && echo present || echo MISSING)"
    exit "$rc" ;;
  -*) printf 'error: unknown flag %s\nhelp: eindri-bearings.sh [<path|id|alias>] [--marker|--check]\n' "$1" >&2; exit 2 ;;
esac

PROJECT="${1:-$PWD}"
[ -r "$CORE" ] || { printf 'error: the shipped core is missing: %s\nhelp: it ships with the repository — a brief without its core is refused\n' "$CORE" >&2; exit 1; }

# ---- (0) where this errand works ------------------------------------------------------------
PATH_=""; PID=""; KIND="unregistered"; HOW="an unregistered path"; CLONE=""; REALM=""
if [ -x "$TARGET" ]; then
  while IFS=$'\t' read -r k v; do
    case "$k" in
      path) PATH_="$v" ;; id) PID="$v" ;; kind) KIND="$v" ;; how) HOW="$v" ;; clone) CLONE="$v" ;; realm) REALM="$v" ;;
    esac
  done < <("$TARGET" resolve "$PROJECT" 2>/dev/null)
fi
[ -n "$PATH_" ] || PATH_="$PROJECT"

printf '%s\n' "$MARKER"
printf '## Bearings — read this before the errand\n\n'
printf 'This section is generated (`bin/agents/eindri-bearings.sh`) and travels with every brief.\n'
printf 'It carries the fixed core you work by, the records of the project you were sent to, and the\n'
printf 'map of where documents live in the home. Read it first; the errand follows below.\n\n'

printf '**Where you work.** project `%s` — %s (%s), at `%s`.\n\n' "${PID:-unregistered}" "${KIND}" "${HOW}" "$PATH_"

# ---- (a) the fixed core ---------------------------------------------------------------------
printf '### (a) The fixed core\n\n'
awk 'NR==1 && /^<!--/ {skip=1; next} skip && /-->/ {skip=0; next} skip {next} /^# / {next} {print}' "$CORE"
printf '\n'
OVERLAY="${YMIR_HOME:-}/config/eindri-core.md"
if [ -r "$OVERLAY" ]; then
  printf '### (a2) This fleet'"'"'s overlay\n\n'
  printf '_The home'"'"'s own word on top of the shipped core (`config/eindri-core.md`) — names, panes, machines and standing words._\n\n'
  awk 'NR==1 && /^<!--/ {skip=1; next} skip && /-->/ {skip=0; next} skip {next} /^# / {next} {print}' "$OVERLAY"
  printf '\n'
else
  printf '> [!NOTE]\n> No home overlay at `%s` — the shipped core above is all this errand carries. A fleet that\n> has its own names, panes and machines writes them there, never in the public repository.\n\n' "$OVERLAY"
fi

# ---- (b) the project's records --------------------------------------------------------------
printf '### (b) The records of this project — read before you write, update before your report\n\n'
records="$("$TARGET" records "$PROJECT" 2>/dev/null)"; rec_rc=$?
if [ "$rec_rc" -eq 0 ] && [ -n "$records" ]; then
  printf '| where | what | path or door | your duty |\n|---|---|---|---|\n'
  while IFS=$'\t' read -r place key value duty; do
    [ -n "$place" ] || continue
    case "$place" in
      in_repo) where="the project's repo" ;;
      in_home) where="the home" ;;
      boards) where="the board" ;;
      merges) where="who merges" ;;
      *) where="$place" ;;
    esac
    printf '| %s | %s | `%s` | %s |\n' "$where" "$key" "$value" "$duty"
  done <<<"$records"
  printf '\n**The duty, in one line:** read the records above before you write, update the ones your work\nchanges before your report, and name every path you touched under `records updated` (below).\n\n'
else
  printf '> [!IMPORTANT]\n> **This project has no `records:` block in the registry.** Nothing here is guessed: this door\n'
  printf '> will not invent a decisions file or a board. The registry keeps it at\n'
  printf '> `%s/hodd/identity/projects.yaml`; add the block to the row `- id: %s` —\n' "${YMIR_HOME:-$YMIR_HOME}" "${PID:-<project>}"
  printf '> `in_repo` (decisions, handoff, schedule, plans, plan_status, docs_index), `in_home` (meetings,\n'
  printf '> seat), `boards`, and `merges`.\n\n'
fi

printf 'Write your report with one line that answers it, and `none: <reason>` when the errand changed no record:\n\n'
printf '```\nrecords updated: <path> · <path>   |   none: <why no record changed>\n```\n\n'

# ---- (c) the home's document map ------------------------------------------------------------
printf '### (c) The home'"'"'s document map\n\n'
if [ -r "${YMIR_HOME:-}/.ymir-layout.yaml" ]; then
  python3 - "${YMIR_HOME}/.ymir-layout.yaml" <<'PY'
import sys
try:
    import yaml
except Exception:
    print("- the layout map exists but its reader (PyYAML) is absent on this machine\n")
    raise SystemExit(0)
try:
    data = yaml.safe_load(open(sys.argv[1], encoding="utf-8")) or {}
except Exception as e:  # noqa: BLE001 - a broken map is said, never hidden
    print(f"- the layout map could not be read: {e}\n")
    raise SystemExit(0)
layout = data.get("layout") or {}
if layout:
    print("| shelf | where |")
    print("|---|---|")
    for key in sorted(layout):
        print(f"| {key} | `{layout[key]}` |")
    print()
PY
else
  printf '- no `.ymir-layout.yaml` in the home (the shape ships at `hodd/.ymir-layout.yaml.example`)\n'
fi
[ -r "${YMIR_HOME:-}/hodd/docs/INDEX.md" ] && printf -- '- **the knowledge shelf**: `%s/hodd/docs/INDEX.md` — the index before the shelf\n' "$YMIR_HOME"
[ -r "${YMIR_HOME:-}/hodd/ATLAS.md" ] && printf -- '- **the atlas**: `%s/hodd/ATLAS.md` — every realm, project and shelf in one map\n' "$YMIR_HOME"
if [ -d "${YMIR_HOME:-}/svartalfaheim" ]; then
  ledgers=( "${YMIR_HOME}"/svartalfaheim/*/projects/*/plans/README.md )
  [ -e "${ledgers[0]:-}" ] || ledgers=()
  own=""
  if [ -n "$PID" ]; then
    own="$(ls -1 "${YMIR_HOME}"/svartalfaheim/*/projects/"$PID"/plans/README.md 2>/dev/null | head -1 || true)"
  fi
  if [ -n "$own" ]; then
    printf -- "- **your project owns a plan ledger**: \`%s\` — its README is the index and the conventions\n" "${own#"$YMIR_HOME"/}"
  fi
  realm_n=0
  if [ -n "$REALM" ] && [ -d "${YMIR_HOME}/svartalfaheim/$REALM" ]; then
    while IFS= read -r readme; do
      [ -n "$readme" ] || continue
      realm_n=$((realm_n + 1))
      [ "$realm_n" -le 3 ] && printf -- "- **a plan ledger in this project realm** (\`%s\`): \`%s\`\n" "$REALM" "${readme#"$YMIR_HOME"/}"
    done < <(ls -1 "${YMIR_HOME}/svartalfaheim/$REALM"/projects/*/plans/README.md 2>/dev/null)
  fi
  if [ "${#ledgers[@]}" -gt 0 ]; then
    printf -- "- **the plan ledgers** (one per project, %s in the home): \`svartalfaheim/*/projects/*/plans/README.md\` — each README is its own index and conventions\n" "${#ledgers[@]}"
  else
    printf -- '- no plan-ledger README found under `svartalfaheim/*/projects/*/plans/`\n'
  fi
fi
printf -- '- **your report**: `%s/state/eindri-reports/<errand>.md`, written by your terminal act; a question only the operator can answer goes to `%s/state/eindri-questions/<errand>.md`\n' "$YMIR_HOME" "$YMIR_HOME"
printf -- '- **the law**: `docs/fixes/<component>/` for what changed and why, `RULES/` for what is law\n'
printf '\n'
