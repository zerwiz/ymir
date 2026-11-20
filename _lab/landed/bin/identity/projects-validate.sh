#!/usr/bin/env bash
# projects-validate.sh — validate projects.yaml, including the optional client field.
#
#   projects-validate.sh                           # validate the project registry
#   projects-validate.sh --check-client <project-id>  # check one project's client reference
#
# A project's `client:` field (optional) must name a client id from the clients register.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Resolve the hoard (Rule 07)
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" \
             "$SCRIPT_DIR/../../vault/hoard-lib.sh" \
             "$SCRIPT_DIR/../../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

die() { printf 'projects-validate: %s\n' "$*" >&2; exit 1; }

HOARD="${YMIR_HOME:-}/hodd"
PROJECTS_FILE="$HOARD/identity/projects.yaml"
CLIENTS_FILE="$HOARD/identity/clients.yaml"

case "${1-}" in
  -h|--help)
    sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  --check-client)
    PROJECT_ID="${2-}"
    [ -n "$PROJECT_ID" ] || die "projects-validate: --check-client requires a project id"
    [ -f "$PROJECTS_FILE" ] || die "no projects.yaml at $PROJECTS_FILE"
    python3 - "$PROJECTS_FILE" "$CLIENTS_FILE" "$PROJECT_ID" <<'PY'
import sys, yaml, os

projects_file, clients_file, project_id = sys.argv[1:4]

projects = yaml.safe_load(open(projects_file, encoding='utf-8')) or {}
projects = projects.get('projects', [])

# Find the project
proj = None
for p in projects:
    if isinstance(p, dict) and p.get('id') == project_id:
        proj = p
        break

if not proj:
    print(f"projects-validate: project {project_id!r} not found in projects.yaml", file=sys.stderr)
    sys.exit(1)

client = proj.get('client')
if not client:
    print(f"projects-validate: {project_id}: no client field (optional — nothing to check)")
    sys.exit(0)

# Load clients
clients = {}
if os.path.isfile(clients_file):
    cdata = yaml.safe_load(open(clients_file, encoding='utf-8')) or {}
    for c in (cdata.get('clients') or []):
        if isinstance(c, dict) and c.get('id'):
            clients[c['id']] = c

if client not in clients:
    print(f"projects-validate: {project_id}: client={client!r} — no client with that id "
          f"in clients.yaml (known: {sorted(clients.keys())})", file=sys.stderr)
    sys.exit(1)

print(f"projects-validate: {project_id}: client={client!r} ✓ (served by {clients[client].get('served_by','?')})")
PY
    ;;
  *)
    [ -f "$PROJECTS_FILE" ] || die "no projects.yaml at $PROJECTS_FILE"
    python3 - "$PROJECTS_FILE" "$CLIENTS_FILE" <<'PY'
import sys, yaml, os

projects_file, clients_file = sys.argv[1:3]

projects = yaml.safe_load(open(projects_file, encoding='utf-8')) or {}
projects = projects.get('projects', [])

# Load clients
clients = {}
if os.path.isfile(clients_file):
    cdata = yaml.safe_load(open(clients_file, encoding='utf-8')) or {}
    for c in (cdata.get('clients') or []):
        if isinstance(c, dict) and c.get('id'):
            clients[c['id']] = c

errors = []
ok = 0

for p in projects:
    if not isinstance(p, dict):
        continue
    pid = p.get('id', '?')
    client = p.get('client')
    if client and client not in clients:
        errors.append(f"  {pid}: client={client!r} — no client with that id in clients.yaml")
    else:
        ok += 1

if errors:
    print(f"projects-validate: {len(errors)} client reference(s) invalid:")
    for e in errors:
        print(e)
    sys.exit(1)

print(f"projects-validate: {len(projects)} project(s) validated — {ok} with valid or no client field")
PY
    ;;
esac
