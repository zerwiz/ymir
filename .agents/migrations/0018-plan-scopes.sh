#!/usr/bin/env bash
# 0018-plan-scopes — a plan belongs to whoever owns the work (plan 240).
#
# The law this migration serves: the plan ledger resolved only ONE shape —
# svartalfaheim/<realm>/projects/<project>/plans/ — so a machine, a company (realm) and the
# Allfather's own work had nowhere to file a plan, and a machine's repair was numbered among
# the ymir project's 240. This creates the three missing shelves and their indexes, and
# touches NO existing plan: nothing is moved, nothing is renumbered, nothing is rewritten.
#
#   shelf            where                         who files there
#   -------------    ---------------------------   --------------------------------
#   realm/company    svartalfaheim/<realm>/plans/  the house itself: strategy, money
#   machine          hodd/machines/<host>/plans/   a computer: hardware, rail, repairs
#   personal         hodd/plans/                   the Allfather's own work
#
# Idempotent: an existing shelf and an existing index are left exactly as they are; a
# second run reports nothing to do. Never overwrites a README.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
hoard="$(bash "$ROOT/bin/vault/hodd.sh" path 2>/dev/null || true)"
[ -n "$hoard" ] || { printf '0018-plan-scopes: no home — nothing to do\n'; exit 0; }
HOME_DIR="$(dirname "$hoard")"

made=0; kept=0

seed_index() {   # seed_index <dir> <scope> <owner>
  local dir="$1" scope="$2" owner="$3" f="$1/README.md"
  mkdir -p "$dir" || return 1
  if [ -f "$f" ]; then kept=$((kept + 1)); return 0; fi
  {
    case "$scope" in
      machine)
        printf '# %s'"'"'s plans — the machine'"'"'s own ledger\n\n' "$owner"
        printf '**A machine plans for itself here** — its power, its thermals, its fans, its rail, its repairs.\n'
        printf 'A plan belongs to whoever owns the work, so this is deliberately *not* a project'"'"'s ledger (plan 240).\n\n' ;;
      realm)
        printf '# %s — the realm'"'"'s plans\n\n' "$owner"
        printf '**A company (realm) plans for itself here** — strategy, money, the house'"'"'s own work —\n'
        printf 'deliberately *not* a project'"'"'s ledger (plan 240).\n\n' ;;
      personal)
        printf '# The Allfather'"'"'s plans\n\n'
        printf '**His own working plans** — personal work, schedules, errands that belong to no project and no\n'
        printf 'machine (plan 240).\n\n' ;;
    esac
    printf '```\nplan[3]{rule,why}:\n'
    printf '  "numbering is per shelf","001 is this shelf'"'"'s first plan; no number is reused within a shelf"\n'
    printf '  "one index: this file","every plan gets a row here, in the same change that creates it"\n'
    printf '  "the owner is in the plan header","owner · owner_name, so a plan keeps its provenance if it ever moves"\n'
    printf '```\n\n## The plans\n'
  } > "$f"
  made=$((made + 1))
}

# ── realm (company) shelves — every realm that already exists ────────────────
for r in "$HOME_DIR"/svartalfaheim/*/; do
  [ -d "$r" ] || continue
  name="$(basename "$r")"
  [ "$name" = "README.md" ] && continue
  seed_index "$HOME_DIR/svartalfaheim/$name/plans" realm "$name"
done

# ── the Allfather's own shelf ────────────────────────────────────────────────
seed_index "$HOME_DIR/hodd/plans" personal "the Allfather"

# ── this machine's shelf — and every machine the fleet registry knows ───────
host="${HOSTNAME%%.*}"
[ -n "$host" ] && seed_index "$HOME_DIR/hodd/machines/$host/plans" machine "$host"
fleet="$HOME_DIR/hodd/data/fleet.json"
if [ -f "$fleet" ] && command -v python3 >/dev/null 2>&1; then
  while IFS= read -r h; do
    [ -n "$h" ] && seed_index "$HOME_DIR/hodd/machines/$h/plans" machine "$h"
  done < <(python3 - "$fleet" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(0)
hosts = d.get("machines") or d.get("hosts") or []
if isinstance(hosts, dict):
    hosts = list(hosts)
for h in hosts:
    name = h.get("name") if isinstance(h, dict) else h
    host = (h.get("host") or h.get("hostname")) if isinstance(h, dict) else None
    if isinstance(name, str) and name:
        print(name.split(".")[0])
    elif isinstance(host, str) and host:
        print(host.split(".")[0])
PY
)
fi

printf '0018-plan-scopes: shelves created %s · indices kept %s\n' "$made" "$kept"
printf '0018-plan-scopes: a plan now belongs to whoever owns the work (project · realm · machine · personal)\n'
exit 0
