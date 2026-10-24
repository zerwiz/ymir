#!/usr/bin/env bash
# place-validate.sh — validate a place.yaml against the clients register and the houses.
#
#   place-validate.sh <place.yaml-path>           # validate one place file
#   place-validate.sh --all                        # every place under hodd/identity/places/
#   place-validate.sh --self-test                  # prove this door against a throwaway home
#
# THE RULE (plan 128): a place whose `company:` is a CLIENT — an id in
# hodd/identity/clients.yaml — MUST declare `client_of: <house-id>` naming a house that
# exists in companies.yaml. Without it the place is REFUSED with a sentence naming the
# missing field. The company is the place's own id when the directory says so
# (`places/<company>[/<place>]/place.yaml`), and a written `company:` field wins.
#
# A place whose company is a HOUSE is accepted as it stands. A company that is neither is
# reported as unresolved — it may be a new one, and this door never invents a register row.
#
# Exit: 0 every place resolved (warnings allowed), 1 a place was refused, 2 usage.
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

die() { printf 'place-validate: %s\n' "$*" >&2; exit 2; }

HOARD="${YMIR_HOME:-}/hodd"
CLIENTS_FILE="$HOARD/identity/clients.yaml"
COMPANIES_FILE="$HOARD/identity/companies.yaml"
PLACES_DIR="$HOARD/identity/places"

# The one check, over one file or the whole shelf.
validate() {
  python3 - "$@" "$PLACES_DIR" "$CLIENTS_FILE" "$COMPANIES_FILE" <<'PY'
import sys, os, glob, yaml

args = sys.argv[1:]
targets_arg, places_dir, clients_file, companies_file = args[:-3], args[-3], args[-2], args[-1]

if targets_arg == ["--all"]:
    found = glob.glob(os.path.join(places_dir, '*', 'place.yaml')) \
          + glob.glob(os.path.join(places_dir, '*', '*', 'place.yaml'))
    targets = sorted(set(found))
    if not os.path.isdir(places_dir):
        print(f'OK   no places shelf at {places_dir} — nothing to resolve')
        sys.exit(0)
    if not targets:
        print(f'OK   no place.yaml under {places_dir} — nothing to resolve')
        sys.exit(0)
else:
    targets = targets_arg

clients, houses = {}, {}
if os.path.isfile(clients_file):
    cdata = yaml.safe_load(open(clients_file, encoding='utf-8')) or {}
    for c in (cdata.get('clients') or []) if isinstance(cdata, dict) else []:
        if isinstance(c, dict) and c.get('id'):
            clients[c['id']] = c
if os.path.isfile(companies_file):
    hdata = yaml.safe_load(open(companies_file, encoding='utf-8')) or {}
    for h in (hdata.get('companies') or []) if isinstance(hdata, dict) else []:
        if isinstance(h, dict) and h.get('id'):
            houses[h['id']] = h

def company_from_path(path):
    """places/<company>[/<place>]/place.yaml — the honest fallback when no field says it."""
    parts = os.path.abspath(path).split(os.sep)
    if 'places' in parts:
        i = len(parts) - 1 - parts[::-1].index('places')
        if i + 1 < len(parts) - 1:
            return parts[i + 1]
    return ''

fails = warns = oks = 0

for place_file in targets:
    if not os.path.isfile(place_file):
        print(f'FAIL {place_file}: no file at that path')
        fails += 1
        continue
    data = yaml.safe_load(open(place_file, encoding='utf-8')) or {}
    if not isinstance(data, dict):
        print(f'FAIL {place_file}: a place.yaml must be a YAML mapping')
        fails += 1
        continue
    company = str(data.get('company') or '').strip() or company_from_path(place_file)
    client_of = str(data.get('client_of') or '').strip()

    if not company:
        print(f'WARN {place_file}: names no company — set `company:` or file it under places/<company>/')
        warns += 1
        continue

    # The register itself: a place that says whose client it is, beside no register, is the
    # exact hole plan 128 closes. Absent is a refusal, never a shrug.
    if client_of and not os.path.isfile(clients_file):
        print(f'FAIL {place_file}: declares client_of: {client_of!r} but the clients register is absent '
              f'at {clients_file} — seed it (bin/engine/ymir-install.sh, or copy '
              f'registry/clients.yaml.example there) and record the client it serves')
        fails += 1
        continue

    if company in clients:
        if not client_of:
            served = ', '.join(sorted(houses)) or 'none registered yet'
            print(f'FAIL {place_file}: company {company!r} is a client in {clients_file} but this place '
                  f'declares no client_of — add `client_of: <house-id>` naming the house that serves it '
                  f'(houses: {served})')
            fails += 1
            continue
        if client_of not in houses:
            print(f'FAIL {place_file}: client_of: {client_of!r} names no house in {companies_file} '
                  f'(houses: {", ".join(sorted(houses)) or "none registered"}) — add the house, '
                  f'or name the house that serves this client')
            fails += 1
            continue
        print(f'OK   {place_file}: company {company!r} is a client, served by {client_of!r}')
        oks += 1
    elif company in houses:
        if client_of and client_of not in houses:
            print(f'FAIL {place_file}: client_of: {client_of!r} names no house in {companies_file} '
                  f'(houses: {", ".join(sorted(houses))})')
            fails += 1
            continue
        print(f'OK   {place_file}: company {company!r} is a house')
        oks += 1
    else:
        print(f'WARN {place_file}: company {company!r} is neither a house in {companies_file} nor a client '
              f'in {clients_file} — register it (a house we ARE: companies.yaml; a company we SERVE: clients.yaml)')
        warns += 1

if len(targets) != 1 or targets_arg == ['--all']:
    print(f'summary: {oks} resolved, {warns} unresolved, {fails} refused')
sys.exit(1 if fails else 0)
PY
}

self_test() {
  local t; t="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$t'" EXIT
  local h="$t/home" pass=0 fail=0
  ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
  bad() { fail=$((fail+1)); printf 'FAIL %s — %s\n' "$1" "${2-}"; }
  mkdir -p "$h/hodd/identity/places/opticat/projects" "$h/hodd/identity/places/wayof/projects"

  printf 'version: 1\ncompanies:\n  - id: wayof\n    name: WayOf\n' > "$h/hodd/identity/companies.yaml"
  printf 'version: 1\nclients:\n  - id: opticat\n    name: OptiCat\n    state: active\n    served_by: wayof\n' \
    > "$h/hodd/identity/clients.yaml"

  local place="$h/hodd/identity/places/opticat/projects/place.yaml"
  printf 'place: opticat/projects\nclient_of: wayof\n' > "$place"
  YMIR_HOME="$h" bash "$0" "$place" >/dev/null 2>&1 \
    && ok "a client place that names its serving house is accepted" \
    || bad "a client place that names its serving house is accepted"

  printf 'place: opticat/projects\n' > "$place"
  if out="$(YMIR_HOME="$h" bash "$0" "$place" 2>&1)"; then
    bad "a client place with no client_of is refused" "it was accepted"
  else
    printf '%s' "$out" | grep -q 'client_of' \
      && ok "…and the sentence names the missing field" \
      || bad "…and the sentence names the missing field" "$out"
  fi

  printf 'place: opticat/projects\nclient_of: nowhere\n' > "$place"
  YMIR_HOME="$h" bash "$0" "$place" >/dev/null 2>&1 \
    && bad "a client_of naming no house is refused" "it was accepted" \
    || ok "a client_of naming no house is refused"

  printf 'place: wayof/projects\n' > "$h/hodd/identity/places/wayof/projects/place.yaml"
  YMIR_HOME="$h" bash "$0" --all >/dev/null 2>&1 \
    && bad "--all refuses a shelf that carries one refused place" "it passed" \
    || ok "--all refuses a shelf that carries one refused place"

  printf 'place: opticat/projects\nclient_of: wayof\n' > "$place"
  YMIR_HOME="$h" bash "$0" --all >/dev/null 2>&1 \
    && ok "--all resolves a shelf whose places all resolve" \
    || bad "--all resolves a shelf whose places all resolve"

  rm -f "$h/hodd/identity/clients.yaml"
  if out="$(YMIR_HOME="$h" bash "$0" "$place" 2>&1)"; then
    bad "an absent register beside a client place is refused" "it was accepted"
  else
    printf '%s' "$out" | grep -q 'clients.yaml' \
      && ok "…and the refusal names the register file" \
      || bad "…and the refusal names the register file" "$out"
  fi
  printf 'place: wayof/projects\n' > "$h/hodd/identity/places/wayof/projects/place.yaml"
  printf 'place: opticat/projects\n' > "$place"
  YMIR_HOME="$h" bash "$0" --all >/dev/null 2>&1 \
    && ok "a shelf of houses resolves with no register at all" \
    || bad "a shelf of houses resolves with no register at all"

  printf '\nplace-validate self-test: %d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
}

case "${1-}" in
  -h|--help|"")
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  --self-test) self_test ;;
  --all) validate --all ;;
  *) [ -n "${1-}" ] || die "which place.yaml? (or --all / --self-test)"; validate "$1" ;;
esac
