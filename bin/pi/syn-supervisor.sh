#!/usr/bin/env bash
# syn-supervisor.sh — Sýn's MIND: the supervisor loop, measure → judge → act → prove → record.
#
# Sýn's arm (bin/pi/syn-watch.sh) keeps the standing watch: it knows whether the
# session is alive and raises the line that needs the helm. It cannot decide what
# to do about what it sees. This is the door to the supervisor that can — plan
# 004, the Allfather's correction (2026-11-17): *"the supervisor must work for the
# intended outcome … and an agent must be involved in the loop."*
#
# The behaviour lives ONCE in the engine (`src/ymir_runtime/supervisor.py`); this
# file is the interpreter, the argv, and nothing that could drift.
#
#   syn-supervisor.sh --once                 one pass: measure, judge, act, prove, record
#   syn-supervisor.sh --every 60             the standing loop (the unit's ExecStart)
#   syn-supervisor.sh --once --dry-run       measure and judge, act on nothing
#   syn-supervisor.sh --once --toon          agent-facing rows
#
#   --registry PATH        the services registry (default: <home>/hodd/identity/services.yaml)
#   --judge PATH           the judge door (default: bin/agents/syn-judge.sh)
#   --runbook-index PATH   the situation → page index (default: <home>/hodd/docs/runbooks/README.md)
#   --host NAME            the seat whose registry rows are this loop's (default: this hostname)
#   --fixes PATH           where the record goes (default: <home>/hodd/machines/<host>/fixes.md)
#   --any-host             measure every row, whatever host it names (a probe; never a default)
#
# The five steps and the gates they keep are the module's, not this file's:
#   measure  memory, swap, load, the registry's own audit, one line per surface
#   judge    ONE verb from a runbook, chosen by a model turn — never a threshold
#   act      one verb only, and only while the arm is held (`bin/voice/rodd-arm.sh who`)
#   prove    the same measurement runs again; a surface still down is recorded FAILED
#   record   one line in the machine's fixes.md and one rune
#
# Exit: 0 a pass that acted and proved (or had nothing to do) · 1 an act that did not hold
#       · 2 usage · 3 refused (no arm, a verb outside the vocabulary, a target not ours).
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

# The engine door owns the interpreter, PYTHONPATH, and the venv choice. This
# door hands the verb over and keeps none of the judgement.
exec "$SCRIPT_DIR/../engine/ymir-engine.sh" supervise "$@"
