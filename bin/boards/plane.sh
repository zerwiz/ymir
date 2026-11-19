#!/usr/bin/env bash
# plane.sh — THE door to Plane. No agent talks to the Plane API without passing through here.
#
# Why this file exists (RULES/41, the fault of 2026-11-01): an agent compared the project registry with
# the WayOf workspace, decided twenty projects were "missing", and created them — inside a CLIENT's
# workspace — on its own inference. Nothing stopped it, because the registry had no owner field and an
# API call is not covered by any ward. This door is that ward.
#
# THE TWO REFUSALS:
#   * a project may be created ONLY when the registry row names its `workspace:` and its `company:`;
#   * the target workspace must be the one the registry names — never one guessed from a slug.
#
# Usage:
#   plane.sh workspaces                     # what exists, and what the registry claims
#   plane.sh projects <workspace-slug>      # the workspace's projects (read-only)
#   plane.sh plan                           # the DIFF only: registry rows per workspace, and what is absent. NEVER writes.
#   plane.sh create <workspace-slug> <project-id>   # refuses unless the registry names both, and prints the object it would create
#   plane.sh probe                          # is the base Plane? refused BY NAME when it is not (plan 324 F6)
#   plane.sh status                         # up (local) · up (door) · skip <the missing value> — never a silence (F13)
#   plane.sh cards  <ws> <project>                          # the project's cards with state and people
#   plane.sh card-create <ws> <project> <title> --source <path>#<id> [--state S] [--assign who,…]
#   plane.sh card-move   <ws> <project> <card#> <state>
#   plane.sh card-assign <ws> <project> <card#> <who>[,<who>…]   # who = display name, email, or a members.yaml person
#
# The base and the token come from the environment or the vault (bin/boards/plane_base.py); nothing
# is defaulted. Every card write appends a row with WHAT changed to the boards audit (F12):
#   ${YMIR_BOARDS_AUDIT:-~/.local/state/ymir/boards-audit.jsonl}
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Rule 07: nothing about a particular installation is written here. The hoard resolver finds the
# registry; the endpoint comes from the environment. Unset means this seat has no board system, and the
# door says so and exits 0 — a clean skip is a pass (RULES/25).
REG="${YMIR_HOME:-}"
if [ -z "$REG" ]; then
  if [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
    . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
    command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root REG 2>/dev/null || true
  fi
fi
[ -n "$REG" ] && REG="$REG/hodd/identity/projects.yaml"
BASE_PY="$ROOT/bin/boards/plane_base.py"
CARDS_PY="$ROOT/bin/boards/plane_cards.py"
case "${1:-}" in
  probe) exec python3 "$BASE_PY" probe ;;
  workspaces)
    # Plane's public API answers 404 on /api/v1/workspaces/ (measured 2026-11-19); the base's own list
    # is used when it has one, else each workspace the operator names is listed by slug. No registry needed.
    exec python3 "$BASE_PY" workspaces ;;
  status)
    # F13: say which road answered. Plane is a remote service by nature, so a base that answers is
    # `up (door)` unless it is this machine's loopback.
    out="$(python3 "$BASE_PY" probe)"; rc=$?
    base="$(python3 "$BASE_PY" env | sed -n 's/^export PLANE_API_BASE=//p')"
    state="$(printf '%s\n' "$out" | sed -n '2p' | cut -d, -f2 | tr -d '"')"
    why="$(printf '%s\n' "$out" | sed -n '2p' | cut -d, -f3- | sed 's/^"//; s/"$//')"
    case "$state" in
      plane) case "$base" in *127.0.0.1*|*localhost*) road="up (local)";; *) road="up (door)";; esac
             printf 'plane[1]{door,state,detail}:\n  "plane","%s","%s"\n' "$road" "$base" ;;
      skip)  printf 'plane[1]{door,state,detail}:\n  "plane","skip","%s"\n' "$why" ;;
      *)     printf 'plane[1]{door,state,detail}:\n  "plane","refused","%s"\n' "$why"; exit 1 ;;
    esac
    exit 0 ;;
  cards|card-create|card-move|card-assign)
    exec python3 "$CARDS_PY" "$@" ;;
esac
# The registry verbs below need the base too, proven to be Plane before a single call (F6).
eval "$(python3 "$BASE_PY" env)"
API="${PLANE_API_BASE:-}"
if [ -z "$API" ]; then
  printf 'plane[1]{door,state,why}:\n  "skip","no board system","PLANE_API_BASE is unset (env or vault) — this seat has no Plane; a clean skip is a pass"\n'
  exit 0
fi
if ! verdict="$(python3 "$BASE_PY" probe)"; then
  printf '%s\n' "$verdict" >&2
  exit 1
fi
if [ -z "$REG" ] || [ ! -r "$REG" ]; then
  printf 'plane[1]{door,state,why}:\n  "skip","no registry","the hoard resolver found no hodd/identity/projects.yaml — set YMIR_HOME"\n'
  exit 0
fi

usage(){ sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'; }
tok(){ python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import plane_base; print(plane_base.resolve()["token"])' "$ROOT/bin/boards"; }

registry(){  # <project-id> → "workspace<TAB>company" (empty when unset)
  python3 - "$REG" "$1" <<'PY'
import sys, yaml
reg, want = sys.argv[1], sys.argv[2]
d = yaml.safe_load(open(reg)) or {}
rows = d.get("projects", d)
if isinstance(rows, dict): rows = [dict(id=k, **(v or {})) for k, v in rows.items()]
for r in rows or []:
    if str(r.get("id") or "") == want:
        print(f"{r.get('workspace','')}\t{r.get('company','')}")
        break
PY
}

case "${1:-}" in
  projects)
    slug="${2:?workspace slug}"; curl -s -H "X-API-Key: $(tok)" "$API/api/v1/workspaces/$slug/projects/?per_page=100" \
      | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["total_count"],"projects");[print(" ",p["identifier"],p["name"]) for p in d["results"]]' ;;
  plan)
    python3 - "$REG" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
rows = d.get("projects", d)
if isinstance(rows, dict): rows = [dict(id=k, **(v or {})) for k, v in rows.items()]
by = {}
for r in rows or []:
    ws = (r.get("workspace") or "").strip()
    by.setdefault(ws or "(unset)", []).append(str(r.get("id")))
for ws in sorted(by):
    print(f"{ws}: {len(by[ws])} project(s)")
    for pid in sorted(by[ws]): print("   ", pid)
print("\nA row with (unset) cannot be placed anywhere. Fill `workspace:` and `company:` first.")
PY
    ;;
  create)
    slug="${2:?workspace slug}"; pid="${3:?project id}"
    row="$(registry "$pid")"; ws="${row%%$'\t'*}"; co="${row#*$'\t'}"
    if [ -z "${ws// }" ] || [ "${ws}" != "$slug" ]; then
      printf 'plane[1]{refused,project,registry_workspace,asked,why}:\n  "refused","%s","%s","%s","the registry does not put this project in that workspace (RULES/41)"\n' "$pid" "${ws:-unset}" "$slug" >&2
      exit 1
    fi
    printf 'plane[1]{would_create,project,workspace,company}:\n  "%s","%s","%s","%s"\n' "$pid" "$slug" "${co:-unset}" 2>/dev/null
    printf 'plane: this door holds the REFUSAL, not the create. A create also needs the Allfather%s word naming it (RULES/41).\n' "'s" >&2
    exit 1 ;;
  *) usage; exit 2 ;;
esac
