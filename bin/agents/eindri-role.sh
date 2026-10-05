#!/usr/bin/env bash
# eindri-role.sh — the right smith for the right metal.
#
# An Eindri is a delegated hand (see AGENTS.md / docs/lore.md §II). Choosing the
# wrong smith for a task is like handing a skald a hammer: the work gets done
# badly, or not at all. This maps a task to the agent whose craft matches it.
#
# The DECISION TABLE is data: `.agents/roles.yaml` (role → figure → tools). This
# door only reads it — it declares no role in code (plan 58 Phase 4). The figure
# cards in `.agents/agents/*.md` carry the prose and the frontmatter; the ROSTER
# (`bin/fleet/agents-config.sh roster`) joins this table to the hoard's model choice.
#
# Usage:
#   bin/agents/eindri-role.sh list
#   bin/agents/eindri-role.sh choose "<task text>"        # the smith whose craft fits
#   bin/agents/eindri-role.sh for <role|figure>           # exact role or figure lookup
#   bin/agents/eindri-role.sh --version
#
# Output: Galdr TOON.
set -u

VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
ROLES="${YMIR_ROLES_YAML:-$ROOT/.agents/roles.yaml}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-list}"; shift || true

[ -r "$ROLES" ] || { printf 'error: roles table not found: %s\nhelp: it is canonical at .agents/roles.yaml\n' "$ROLES" >&2; exit 1; }

ROLES="$ROLES" ACTION="$ACTION" python3 - "$@" <<'PY'
import os, re, sys
try:
    import yaml
except Exception:
    print('error: python3 has no PyYAML'); sys.exit(1)

roles_path = os.environ["ROLES"]
action = os.environ.get("ACTION", "list")
args = sys.argv[1:]
doc = yaml.safe_load(open(roles_path)) or {}
roles = doc.get("roles") or {}

def craft_of(spec):
    return spec.get("craft") or ""

def rows():
    """(role_key, spec) in file order — the table's own order is the tie-break."""
    for key, spec in roles.items():
        if isinstance(spec, dict):
            yield key, spec

def dispatch_rows():
    for key, spec in rows():
        if spec.get("dispatch"):
            yield key, spec

def find(term):
    """A role by its key, else by its figure — the two names a caller speaks."""
    for key, spec in rows():
        if key == term:
            return key, spec
    for key, spec in rows():
        if spec.get("figure") == term:
            return key, spec
    return None, None

if action == "list":
    rs = list(dispatch_rows())
    print(f'eindri-roles[{len(rs)}]{{role,craft}}:')
    for _key, spec in rs:
        print(f'  "{spec.get("figure")}","{craft_of(spec)}"')
    sys.exit(0)

if action == "for":
    want = args[0] if args else ""
    if not want:
        print('error: for needs a role or figure name', file=sys.stderr); sys.exit(2)
    key, spec = find(want)
    if spec is None:
        print(f'eindri-role[1]{{role,known}}:\n  "{want}","no"')
        print('help: bin/agents/eindri-role.sh list', file=sys.stderr)
        sys.exit(1)
    print(f'eindri-role[1]{{role,craft}}:\n  "{spec.get("figure")}","{craft_of(spec)}"')
    sys.exit(0)

if action == "choose":
    text = " ".join(args).lower()
    if not text:
        print('error: choose needs task text', file=sys.stderr); sys.exit(2)
    best = None; bestscore = 0
    for key, spec in dispatch_rows():
        s = 0
        for word in (spec.get("keywords") or []):
            word = str(word)
            if not word or word in ("of", "the", "and", "a", "to"):
                continue
            if re.search(r"(?<![A-Za-z0-9_])" + re.escape(word) + r"(?![A-Za-z0-9_])", text):
                s += 1
        if s > bestscore:
            bestscore = s; best = (key, spec)
    if best is None:
        # No craft word matched: the smith of first resort for general work.
        best = ("developer", roles.get("developer") or {"figure": "sindri", "craft": "code — build, refactor, fix, test"})
    spec = best[1]
    print(f'eindri-choice[1]{{role,craft,score}}:\n  "{spec.get("figure")}","{craft_of(spec)}",{bestscore}')
    sys.exit(0)

print(f'error: unknown action {action}\nhelp: bin/agents/eindri-role.sh [list|choose|for]', file=sys.stderr)
sys.exit(2)
PY
