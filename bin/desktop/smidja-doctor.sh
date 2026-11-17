#!/usr/bin/env bash
# smidja-doctor.sh — is this roster ready to run, and can this machine carry it?
#
# The books tell an operator to run `smidja doctor` before trusting a roster
# (create-new-teams §2). This tree has no `smidja` launcher, so the check had no
# door at all — a roster was only ever tested by starting a run and watching it
# fail. This is the door. It answers three questions, in one read:
#
#   1. does every agent resolve — its prompts on disk, its model in the catalog,
#      its surface available here (pi · opencode · herdr)?
#   2. can THIS machine carry the team — seats x the per-seat floor, plus one
#      resident local model, against RAM minus the estate's declared ceilings
#      (plan 003's shape) minus the desk's reserve?
#   3. what would it cost to watch — which agents get a pane, and where?
#
# It refuses nothing that a run would accept and accepts nothing a run would
# refuse: both call the same `agents.validate()` and `budget.check()`, because a
# doctor that disagrees with the engine is a second opinion nobody needs.
#
# Usage:
#   bin/desktop/smidja-doctor.sh [--config PATH] [--repo DIR] [--json]
#
#   --config PATH   the roster (default: smidja/smidja_smidja_config/smidja.config.yaml
#                   under --repo, then under the current directory)
#   --repo DIR      the tree the run would work in (default: the current directory)
#   --json          machine-readable output instead of TOON
#
# Exit: 0 the roster would run · 1 it would be refused (the reasons are printed) · 2 usage
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
CONFIG=""; REPO="$PWD"; JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    --config) CONFIG=${2-}; shift 2 ;;
    --config=*) CONFIG=${1#--config=}; shift ;;
    --repo) REPO=${2-}; shift 2 ;;
    --repo=*) REPO=${1#--repo=}; shift ;;
    --json) JSON=1; shift ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -n "$CONFIG" ] || CONFIG="$REPO/smidja/smidja_smidja_config/smidja.config.yaml"
[ -r "$CONFIG" ] || { printf 'error: no roster at %s\nhelp: --config <path>\n' "$CONFIG" >&2; exit 1; }

# The smithy's own modules live where the smithy lives (apps/smidja in a clone,
# the package's templates in a packaged install). Ask the resolver, never a path.
SMIDJA_DIR=""
for candidate in "$ROOT/apps/smidja" "$ROOT/apps/smidja-factory/templates/smidja"; do
  [ -d "$candidate/smidja_modules" ] && { SMIDJA_DIR="$candidate"; break; }
done
[ -n "$SMIDJA_DIR" ] || { printf 'error: no smidja_modules found under %s\n' "$ROOT" >&2; exit 1; }

cd "$REPO" || { printf 'error: --repo %s is not a directory\n' "$REPO" >&2; exit 1; }

SMIDJA_DIR="$SMIDJA_DIR" CONFIG="$CONFIG" REPO="$REPO" JSON="$JSON" uv run --quiet \
  --with pydantic --with pyyaml --with rich --with python-dotenv \
  python - <<'PY'
import json
import os
import sys

sys.path.insert(0, os.environ["SMIDJA_DIR"])
from smidja_modules import agents, agent_herdr, budget      # noqa: E402

config = os.environ["CONFIG"]
as_json = os.environ.get("JSON") == "1"

def emit(payload: dict) -> None:
    if as_json:
        print(json.dumps(payload, indent=2))
        return
    print("smidja-doctor[3]{roster,agents,verdict}:")
    print(f'  "{payload["config"]}",{len(payload["agents"])},"{payload["verdict"]}"')
    print("smidja-doctor[7]{agent,surface,model,prompts,seat,purpose}:")
    for a in payload["agents"]:
        print(f'  "{a["name"]}","{a["coding_agent"]}","{a["model"]}","{a["prompts"]}",'
              f'"{a["seat"]}","{(a["purpose"] or "")[:60]}"')
    b = payload["budget"]
    print("smidja-doctor[8]{term,mb,why}:")
    print(f'  "ram",{b["ram_mb"]},"physical memory"')
    print(f'  "estate",{b["estate_mb"]},"declared by {b["estate_services"]} service(s)"')
    print(f'  "desk_reserve",{b["desk_reserve_mb"]},"kept for the desk"')
    print(f'  "available",{b["available_mb"]},"left for agents"')
    print(f'  "seat_floor",{b["seat_floor_mb"]},"per seated agent"')
    print(f'  "team_needs",{b["needed_mb"]},"{b["members"]} seat(s)"')
    print(f'  "seats_fit",{b["seats_fit"]},"what this machine can carry"')
    print(f'  "local_resident",{b["local_resident_mb"]},"one resident local model"')
    if payload["problems"]:
        print("smidja-doctor[2]{refusal,why}:")
        for problem in payload["problems"]:
            print(f'  "refused","{problem}"')
    print(f'  "estate_source","{b["estate_source"]}"')
    print(f'smidja-doctor[1]{{verdict}}:\n  "{payload["verdict"]}"')

problems: list[str] = []
payload_agents: list[dict] = []
cfg = None
try:
    cfg = agents.load_config(config)
except Exception as error:                                   # noqa: BLE001
    problems.append(f"the roster does not parse: {error}")

if cfg is not None:
    try:
        agents.validate(cfg, [a.name for a in cfg.agents])
    except SystemExit as error:
        problems.extend(str(error).splitlines()[1:])
    herdr_ok, herdr_why = agent_herdr.available()
    for agent in cfg.agents:
        seat = ("a pane" if agent.coding_agent == "herdr" and herdr_ok
                else f"no pane — {herdr_why}" if agent.coding_agent == "herdr"
                else "a process")
        payload_agents.append({
            "name": agent.name,
            "coding_agent": agent.coding_agent,
            "model": agent.model,
            "purpose": agent.purpose,
            "seat": seat,
            "prompts": "ok" if all(os.path.isfile(p) for p in
                                   (agent.prompt_engineering.system,
                                    agent.prompt_engineering.user)) else "MISSING",
        })
    verdict_budget = budget.check(cfg)
else:
    verdict_budget = budget.check(type("Empty", (), {"agents": []})())

verdict = "green — this roster would run" if not problems else "refused"
emit({
    "config": config,
    "agents": payload_agents,
    "budget": verdict_budget,
    "problems": problems,
    "verdict": verdict,
})
sys.exit(0 if not problems else 1)
PY
