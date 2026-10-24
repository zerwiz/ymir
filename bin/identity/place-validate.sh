#!/usr/bin/env bash
# place-validate.sh — validate a place.yaml against the clients register and companies.
#
#   place-validate.sh <place.yaml-path>          # validate one place file
#   place-validate.sh --all                       # validate every place.yaml under hodd/identity/places/
#
# A place whose `company:` is a client id MUST declare `client_of:` naming a house
# that exists in companies.yaml. Without that declaration the place is refused.
#
# A place whose `company:` is a house id is accepted as-is (no client_of needed).
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

die() { printf 'place-validate: %s\n' "$*" >&2; exit 1; }

HOARD="${YMIR_HOME:-}/hodd"
CLIENTS_FILE="$HOARD/identity/clients.yaml"
COMPANIES_FILE="$HOARD/identity/companies.yaml"
PLACES_DIR="$HOARD/identity/places"

case "${1-}" in
  -h|--help|"")
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  --all)
    [ -d "$PLACES_DIR" ] || { echo "place-validate: no places directory at $PLACES_DIR"; exit 0; }
    found=0
    for pf in "$PLACES_DIR"/*/; do
      [ -f "$pf/place.yaml" ] || continue
      found=$((found + 1))
      bash "$0" "$pf/place.yaml" || true
    done
    [ "$found" -gt 0 ] || echo "place-validate: no place.yaml files found"
    ;;
  *)
    PLACE_FILE="${1-}"
    [ -f "$PLACE_FILE" ] || die "no file at $PLACE_FILE"
    python3 - "$PLACE_FILE" "$CLIENTS_FILE" "$COMPANIES_FILE" <<'PY'
import sys, yaml, os

place_file = sys.argv[1]
clients_file = sys.argv[2]
companies_file = sys.argv[3]

data = yaml.safe_load(open(place_file, encoding='utf-8')) or {}
company = (data.get('company') or '').strip()
client_of = (data.get('client_of') or '').strip()

# If company is absent but client_of is present, infer company from the place path.
# A place at places/<company>/<place>/place.yaml uses <company> as its company.
if not company and client_of:
    parts = place_file.rstrip('/').split('/')
    places_idx = parts.index('places') if 'places' in parts else -1
    if places_idx >= 0 and len(parts) > places_idx + 1:
        company = parts[places_idx + 1]
        print(f"place-validate: {place_file}: inferred company={company!r} from path (client_of={client_of!r})")

if not company:
    print(f"place-validate: {place_file}: no 'company' field and no 'client_of' — cannot validate")
    sys.exit(0)

# Load clients register
clients = {}
if os.path.isfile(clients_file):
    cdata = yaml.safe_load(open(clients_file, encoding='utf-8')) or {}
    for c in (cdata.get('clients') or []):
        if isinstance(c, dict) and c.get('id'):
            clients[c['id']] = c

# Load companies
houses = set()
if os.path.isfile(companies_file):
    hdata = yaml.safe_load(open(companies_file, encoding='utf-8')) or {}
    for h in (hdata.get('companies') or []):
        if isinstance(h, dict) and h.get('id'):
            houses.add(h['id'])

# Is this company a client?
if company in clients:
    # It IS a client — client_of is REQUIRED
    client_of = (data.get('client_of') or '').strip()
    if not client_of:
        print(f"place-validate: {place_file}: company={company!r} is a client in the register "
              f"but this place has no 'client_of' field — add 'client_of: <house-id>' "
              f"(the house that serves this client)", file=sys.stderr)
        sys.exit(1)
    if client_of not in houses:
        print(f"place-validate: {place_file}: client_of={client_of!r} — no house with that id "
              f"in companies.yaml (known: {sorted(houses)})", file=sys.stderr)
        sys.exit(1)
    print(f"place-validate: {place_file}: company={company!r} is a client, served by {client_of!r} ✓")
else:
    # It's a house (or unknown) — no client_of needed
    if company in houses:
        print(f"place-validate: {place_file}: company={company!r} is a house ✓")
    else:
        print(f"place-validate: {place_file}: company={company!r} — not found in companies.yaml "
              f"or clients.yaml (may be a new entity)", file=sys.stderr)
        sys.exit(1)
PY
    ;;
esac
