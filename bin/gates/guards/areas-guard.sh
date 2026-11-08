#!/usr/bin/env bash
# areas-guard (tree ward) — the canon and the copy that travels must not drift.
#
# THE FAULT THIS CATCHES: `.agents/areas.yaml` is the canon — eighteen areas, the question each must
# answer, and which of our figures may keep it. `bin/collab/kit/areas/canon.yaml` is the PLAIN face of
# that canon, shipped into repositories that are not ours (RULES/48: the questions are everyone's, the
# figures are ours). Two copies of a law is exactly how the house has been burned before: sharpen a
# question in the canon, forget the kit, and every guest repository keeps answering the old one while
# the gate reports clean.
#
# It also refuses a canon that names a figure we do not have (`.agents/agents/<figure>*.md`), and an
# area missing one of its fields. A canon that cannot be honoured is not a canon.
#
# AND PART TWO — this tree's own estate, when it has adopted the shelf (`areas/*.yaml`), checked through
# the door that owns the format so there is one implementation. Deliberately NOT here: judging another
# PROJECT's declarations. That is the kit's gate, in the project's repository (RULES/18), where the
# answer lives.
#
# Exit: 0 clean · 1 a fault · 2 usage.
set -uo pipefail
_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}
ROOT="$(_root)"
CANON="$ROOT/.agents/areas.yaml"
PLAIN="$ROOT/bin/collab/kit/areas/canon.yaml"

[ -r "$CANON" ] || { printf 'areas-guard: no canon at .agents/areas.yaml — that is a fault, not a skip\n' >&2; exit 1; }
[ -r "$PLAIN" ] || { printf 'areas-guard: the kit carries no areas/canon.yaml — the questions cannot travel\n' >&2; exit 1; }

python3 -B - "$CANON" "$PLAIN" "$ROOT" <<'PY'
import glob, os, sys
import yaml

canon_path, plain_path, root = sys.argv[1], sys.argv[2], sys.argv[3]
faults = []

try:
    canon = yaml.safe_load(open(canon_path)) or {}
except Exception as e:
    print(f'areas-guard refused: the canon does not parse — {e}', file=sys.stderr)
    raise SystemExit(1)
try:
    plain = yaml.safe_load(open(plain_path)) or {}
except Exception as e:
    print(f'areas-guard refused: the kit canon does not parse — {e}', file=sys.stderr)
    raise SystemExit(1)

careas = canon.get('areas') or []
pareas = plain.get('areas') or []
if not careas:
    faults.append('the canon declares no areas')
if len(careas) != len(pareas):
    faults.append(f'the canon holds {len(careas)} areas and the kit ships {len(pareas)} — '
                  f'regen: bin/agents/areas.sh canon --kit')

REQUIRED = ('id', 'name', 'owns', 'question', 'evidence', 'figures')
seen = set()
for a in careas:
    aid = a.get('id') or '(no id)'
    for field in REQUIRED:
        if not a.get(field):
            faults.append(f'{aid}: no `{field}` — an area without it cannot be answered')
    if aid in seen:
        faults.append(f'{aid}: declared twice')
    seen.add(aid)
    for fig in a.get('figures') or []:
        if not glob.glob(os.path.join(root, '.agents', 'agents', f'{fig}*.md')):
            faults.append(f'{aid}: figure `{fig}` has no card in .agents/agents/ — a keeper that does not exist')

cby = {a.get('id'): a for a in careas}
pby = {a.get('id'): a for a in pareas}
for aid, a in cby.items():
    p = pby.get(aid)
    if not p:
        faults.append(f'{aid}: in the canon, missing from the kit — no guest repository will be asked it')
        continue
    for field in ('name', 'owns', 'question'):
        if str(a.get(field, '')).strip() != str(p.get(field, '')).strip():
            faults.append(f'{aid}: `{field}` differs between the canon and the kit copy')
    if list(a.get('evidence') or []) != list(p.get('evidence') or []):
        faults.append(f'{aid}: the evidence list differs between the canon and the kit copy')
for aid in pby:
    if aid not in cby:
        faults.append(f'{aid}: shipped in the kit but absent from the canon — a question with no owner')

if faults:
    print(f'areas-guard refused: {len(faults)} fault(s) in the canon of areas\n', file=sys.stderr)
    for f in faults:
        print(f'  {f}', file=sys.stderr)
    print('\nhelp: the canon is .agents/areas.yaml; the travelling copy is generated — '
          'bin/agents/areas.sh canon --kit', file=sys.stderr)
    raise SystemExit(1)

print(f'areas-guard: {len(careas)} areas, canon and kit agree, every named figure exists')
PY
canon_rc=$?
[ "$canon_rc" -eq 0 ] || exit "$canon_rc"

# PART TWO — this repository's own estate.
shopt -s nullglob
mine=("$ROOT"/areas/*.yaml)
shopt -u nullglob
if [ "${#mine[@]}" -eq 0 ]; then
  printf 'areas-guard: this tree carries no areas/ shelf — not adopted (bash bin/agents/areas.sh init .)\n'
  exit 0
fi
bash "$ROOT/bin/agents/areas.sh" check "$ROOT" || {
  printf '\nareas-guard refused: this repository has areas it cannot answer for. an area nobody holds\n' >&2
  printf 'is not a green area; claim it, waive it with a name, or say it does not apply.\n' >&2
  exit 1
}
