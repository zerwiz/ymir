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
API="${PLANE_API_BASE:-}"
if [ -z "$API" ]; then
  printf 'plane[1]{door,state,why}:\n  "skip","no board system","PLANE_API_BASE is unset — this seat has no Plane; a clean skip is a pass"\n'
  exit 0
fi
if [ -z "$REG" ] || [ ! -r "$REG" ]; then
  printf 'plane[1]{door,state,why}:\n  "skip","no registry","the hoard resolver found no hodd/identity/projects.yaml — set YMIR_HOME"\n'
  exit 0
fi

usage(){ sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }
tok(){ bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null | sed -n 's/^export PLANE_API_TOKEN=//p' | tr -d "\"'"; }

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
  workspaces)
    curl -s -H "X-API-Key: $(tok)" "$API/api/v1/workspaces/" | head -c 600; echo ;;
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
