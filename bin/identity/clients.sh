#!/usr/bin/env bash
# clients.sh — the clients register: load, validate, and check.
#
#   clients.sh load                              # read hodd/identity/clients.yaml, print shape
#   clients.sh validate                          # fail loudly on a bad shape
#   clients.sh check                             # verify every client references existing entities
#
# The register lives in the hoard (private). This script resolves it through
# hoard-lib.sh (Rule 07). A fresh home gets it from the template (Phase 3).
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

die() { printf 'clients: %s\n' "$*" >&2; exit 1; }

CLIENTS_FILE="${YMIR_HOME:-}/hodd/identity/clients.yaml"

case "${1-}" in
  -h|--help|"")
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  load)
    [ -f "$CLIENTS_FILE" ] || die "no clients register at $CLIENTS_FILE"
    python3 -c "
import yaml, sys
data = yaml.safe_load(open(sys.argv[1], encoding='utf-8')) or {}
clients = data.get('clients', [])
print('clients[%d]{id,name,state,served_by}:' % len(clients))
for c in clients:
    print('  \"%s\",\"%s\",\"%s\",\"%s\"' % (
        c.get('id','?'), c.get('name','?'), c.get('state','?'), c.get('served_by','?')))
" "$CLIENTS_FILE"
    ;;
  validate)
    [ -f "$CLIENTS_FILE" ] || die "no clients register at $CLIENTS_FILE — seed it first"
    python3 - "$CLIENTS_FILE" <<'PY'
import sys, yaml

clients_file = sys.argv[1]
data = yaml.safe_load(open(clients_file, encoding='utf-8')) or {}

if not isinstance(data, dict):
    print(f"clients: the register must be a YAML mapping (got {type(data).__name__})", file=sys.stderr)
    sys.exit(1)

clients = data.get('clients')
if clients is None:
    print(f"clients: the register has no 'clients' key", file=sys.stderr)
    sys.exit(1)
if not isinstance(clients, list):
    print(f"clients: 'clients' must be a list (got {type(clients).__name__})", file=sys.stderr)
    sys.exit(1)

valid_states = {'lead', 'prospect', 'active', 'paused', 'ended'}
errors = []

for i, c in enumerate(clients):
    prefix = f"clients[{i}]"
    if not isinstance(c, dict):
        errors.append(f"{prefix}: must be a mapping (got {type(c).__name__})")
        continue
    cid = c.get('id')
    if not cid or not isinstance(cid, str):
        errors.append(f"{prefix}: missing or invalid 'id' (must be a non-empty string)")
        continue
    if not c.get('name'):
        errors.append(f"{prefix}({cid}): missing 'name'")
    state = c.get('state')
    if state not in valid_states:
        errors.append(f"{prefix}({cid}): 'state' must be one of {sorted(valid_states)} (got {state!r})")
    if not c.get('served_by'):
        errors.append(f"{prefix}({cid}): missing 'served_by' (must name a house id from companies.yaml)")
    owner = c.get('owner')
    if owner and not isinstance(owner, str):
        errors.append(f"{prefix}({cid}): 'owner' must be a string (person id)")
    projects = c.get('projects')
    if projects is not None and not isinstance(projects, list):
        errors.append(f"{prefix}({cid}): 'projects' must be a list")

if errors:
    for e in errors:
        print(f"clients: {e}", file=sys.stderr)
    sys.exit(1)

print(f"clients: validated {len(clients)} client(s) — shape is correct")
PY
    ;;
  check)
    # Verify every client references existing entities:
    #   served_by → a house id in companies.yaml
    #   owner    → a person id in collaborators.yaml
    #   realm    → a directory under svartalfaheim/
    #   place    → a place.yaml under hodd/identity/places/
    #   projects → project ids in projects.yaml
    [ -f "$CLIENTS_FILE" ] || die "no clients register at $CLIENTS_FILE"

    # Resolve the hoard paths
    HOARD="${YMIR_HOME:-}/hodd"
    COMPANIES_FILE="$HOARD/identity/companies.yaml"
    COLLABS_FILE="$HOARD/identity/collaborators.yaml"
    PROJECTS_FILE="$HOARD/identity/projects.yaml"

    python3 - "$CLIENTS_FILE" "$COMPANIES_FILE" "$COLLABS_FILE" "$PROJECTS_FILE" "$HOARD" <<'PY'
import sys, yaml, os, re

clients_file, companies_file, collabs_file, projects_file, hoard = sys.argv[1:6]

clients = yaml.safe_load(open(clients_file, encoding='utf-8')) or {}
clients = clients.get('clients', [])

# Load companies
companies = {}
if os.path.isfile(companies_file):
    data = yaml.safe_load(open(companies_file, encoding='utf-8')) or {}
    for c in (data.get('companies') or []):
        if isinstance(c, dict) and c.get('id'):
            companies[c['id']] = c.get('name', '?')

# Load collaborators (people)
people = set()
if os.path.isfile(collabs_file):
    data = yaml.safe_load(open(collabs_file, encoding='utf-8')) or {}
    for p in (data.get('collaborators') or data.get('people') or []):
        if isinstance(p, dict) and p.get('id'):
            people.add(p['id'])

# Load projects
project_ids = set()
if os.path.isfile(projects_file):
    data = yaml.safe_load(open(projects_file, encoding='utf-8')) or {}
    for p in (data.get('projects') or []):
        if isinstance(p, dict) and p.get('id'):
            project_ids.add(p['id'])

errors = []
ok = 0

for c in clients:
    cid = c.get('id', '?')
    # served_by must be a known house
    sb = c.get('served_by')
    if sb and sb not in companies:
        errors.append(f"  {cid}: served_by={sb!r} — no house with that id in companies.yaml (known: {sorted(companies.keys())})")
    # owner must be a known person
    owner = c.get('owner')
    if owner and owner not in people:
        errors.append(f"  {cid}: owner={owner!r} — no person with that id in collaborators.yaml")
    # realm must exist as a directory
    realm = c.get('realm')
    if realm:
        realm_path = os.path.join(hoard, realm)
        if not os.path.isdir(realm_path):
            errors.append(f"  {cid}: realm={realm!r} — directory not found at {realm_path}")
    # place must exist as a place.yaml
    place = c.get('place')
    if place:
        place_path = os.path.join(hoard, 'hodd', 'identity', 'places', place, 'place.yaml')
        if not os.path.isfile(place_path):
            errors.append(f"  {cid}: place={place!r} — no place.yaml at {place_path}")
    # projects must be known project ids
    for pid in (c.get('projects') or []):
        if pid not in project_ids:
            errors.append(f"  {cid}: project={pid!r} — no project with that id in projects.yaml")

if errors:
    print(f"clients: {len(errors)} issue(s) found:")
    for e in errors:
        print(e)
    sys.exit(1)

print(f"clients: all {len(clients)} client(s) resolved — served_by, owner, realm, place, projects are valid")
PY
    ;;
  *)
    die "unknown action '${1-}' — load | validate | check"
    ;;
esac
