#!/usr/bin/env bash
# areas.sh — the estate door: a project's areas, their keepers, and the seam to the seat.
#
# A PROJECT divides its work into AREAS (plan 219). The canon of areas lives at
# `.agents/areas.yaml`; a project's own answers live in ITS repository at `areas/<area>.yaml`,
# because a declaration beside the work is a note and a declaration inside the work is the
# work's memory. This door is the estate manager standing between the two.
#
#   areas.sh canon                          # the canon: ids, the question each must answer
#   areas.sh init     <project|path>        # write areas/ from the canon (a real answer is never overwritten)
#   areas.sh list     <project|path>        # every area, its state, its keeper
#   areas.sh check    <project|path>        # faults named by project · area · field
#   areas.sh estate   <project|path>        # ONE line: held · unproved · waived · na · unheld
#   areas.sh brief    <project|path> <area> # the generated brief (canon questions + declaration + figure)
#   areas.sh claim    <project|path> <area> --keeper K --path P --evidence E   (or --unheld --path P)
#   areas.sh waive    <project|path> <area> --by WHO --why TEXT --until DATE
#   areas.sh call     <project|path> <area> [--headless] [--note "<what for>"]
#   areas.sh status   <project|path> [area]
#   areas.sh stop     <project|path> <area>
#
# HOW IT SEATS WITHOUT FORKING THE SEAT: `bin/agents/domain.sh` already turns a declaration into a
# brief and a pane. So this door writes the area's SEATING SHIM — a declaration in the home's own
# state (`$STATE/areas-estate/<project>/areas/<area>.yaml`) that names the house figure, the folder
# and the `may_write` read from the project's own declaration — and points domain.sh at it with
# AREAS_SCOPE=. The repository never learns a figure's name (RULES/48); the seat still works.
#
# `<project>` is a registry id from `hodd/identity/projects.yaml` (resolved through `clones:` for
# this hostname, then `local_clone`, then the repository's own git remote) or a path.
#
# Exit: 0 ok · 1 faults found / refused · 2 usage.
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"
CANON="${YMIR_AREAS_CANON:-$ROOT/.agents/areas.yaml}"
STATE="${YMIR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}/areas"

usage(){ sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }

ACTION="${1:-}"; shift || true
case "$ACTION" in
  -h|--help|"") usage; exit 0 ;;
esac
[ -r "$CANON" ] || { printf 'error: the canon is missing: %s\nhelp: it is canonical at .agents/areas.yaml\n' "$CANON" >&2; exit 1; }

case "$ACTION" in
  canon)
    exec python3 - "$CANON" <<'PY'
import sys, yaml
c = yaml.safe_load(open(sys.argv[1])) or {}
areas = c.get("areas") or []
print(f'areas[{len(areas)}]{{id,name,the question it must answer}}:')
for a in areas:
    q = (a.get("question") or "").replace('"', "'")
    print(f'  "{a["id"]}","{a.get("name","")}","{q}"')
PY
    ;;
esac

TOKEN="${1:-}"
[ -n "$TOKEN" ] || { printf 'error: %s needs a project (a registry id or a path)\n' "$ACTION" >&2; exit 2; }
shift || true

# THE HOARD IS RESOLVED, NEVER GUESSED (defaults-guard): the one resolver is bin/vault/hoard-lib.sh, and
# a restated home is how private work lands outside the vault.
if [ -z "${YMIR_HOME:-}" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  YMIR_HOME="$(bash -c '. "$1/bin/vault/hoard-lib.sh" >/dev/null 2>&1; ymir_home_root out; printf %s "$out"' _ "$ROOT" 2>/dev/null || true)"
  export YMIR_HOME
fi

read -r PROJECT_PATH PROJECT_ID < <(python3 - "$TOKEN" "$ROOT" <<'PY'
import os, socket, subprocess, sys
token = sys.argv[1]
tree = sys.argv[2] if len(sys.argv) > 2 else ""
home = os.environ.get("YMIR_HOME") or ""
if not home:
    sys.stderr.write("error: the hoard is unresolved\nhelp: export YMIR_HOME, or install bin/vault/hoard-lib.sh\n")
    raise SystemExit(1)
reg = os.path.join(home, "hodd/identity/projects.yaml")
host = socket.gethostname().split(".")[0]
try:
    import yaml
    data = yaml.safe_load(open(reg)) or {}
except Exception:
    data = {}
projects = data.get("projects") or []

def repo_path(entry):
    """A registry `repo` resolved to a directory on this box; `.` means THE TREE THIS DOOR LIVES IN
    (measured 2026-11-08: reading `.` as the hoard made ymir-platform's estate answer 18 unheld)."""
    repo = entry.get("repo") or ""
    if not repo:
        return ""
    if repo == ".":
        return tree
    return os.path.join(home, repo)

def by_path(path):
    """The registry id for a directory, or its basename: never a guess. A worktree's basename is an
    errand's name, so the repository's own git remote is the second voice after the registry."""
    real = os.path.realpath(path)
    for p in projects:
        for cand in (p.get("local_clone"), (p.get("clones") or {}).get(host)):
            if cand and os.path.realpath(os.path.expanduser(cand)) == real:
                return p.get("id")
        rp = repo_path(p)
        if rp and os.path.realpath(rp) == real:
            return p.get("id")
    try:
        url = subprocess.run(["git", "-C", real, "remote", "get-url", "origin"],
                             capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        url = ""
    if url:
        slug = url.rstrip("/").split(":")[-1].replace(".git", "")
        for p in projects:
            g = p.get("git") or {}
            if g.get("repo") and (g.get("owner", "") + "/" + g["repo"]) in slug:
                return p.get("id")
    return os.path.basename(real).lower()

if os.path.isdir(token):
    real = os.path.realpath(token)
    print(real, by_path(real)); raise SystemExit
for p in projects:
    if p.get("id") != token:
        continue
    clones = p.get("clones") or {}
    for key in (host, os.uname().nodename.split(".")[0]):
        if clones.get(key) and os.path.isdir(os.path.expanduser(clones[key])):
            print(os.path.realpath(os.path.expanduser(clones[key])), p["id"]); raise SystemExit
    if p.get("local_clone") and os.path.isdir(os.path.expanduser(p["local_clone"])):
        print(os.path.realpath(os.path.expanduser(p["local_clone"])), p["id"]); raise SystemExit
    rp = repo_path(p)
    if rp and os.path.isdir(rp):
        print(os.path.realpath(rp), p["id"]); raise SystemExit
    sys.stderr.write(f'error: project {token} is in the registry but has no clone here\n'
                     f'help: add clones.{host} to its projects.yaml entry, or pass the path\n')
    raise SystemExit(1)
sys.stderr.write(f'error: no such project: {token}\nhelp: an id from hodd/identity/projects.yaml, or a path\n')
raise SystemExit(1)
PY
) || exit 1
[ -n "$PROJECT_PATH" ] || exit 1
[ -d "$PROJECT_PATH" ] || { printf 'error: not a directory: %s\n' "$PROJECT_PATH" >&2; exit 1; }
PROJECT_ID="${PROJECT_ID:-$(basename "$PROJECT_PATH" | tr '[:upper:] ' '[:lower:]-')}"
mkdir -p "$STATE" 2>/dev/null || true

export YMIR_AREAS_CANON="$CANON" YMIR_AREAS_ROOT="$ROOT" YMIR_AREAS_REPO="$PROJECT_PATH" \
       YMIR_AREAS_ID="$PROJECT_ID" YMIR_AREAS_STATE="$STATE"

case "$ACTION" in
  init)
    exec python3 -B - <<'PY'
import json, os, yaml
canon = yaml.safe_load(open(os.environ["YMIR_AREAS_CANON"])) or {}
repo, pid = os.environ["YMIR_AREAS_REPO"], os.environ["YMIR_AREAS_ID"]
shelf = os.path.join(repo, "areas")
os.makedirs(shelf, exist_ok=True)
written, kept = [], []
for a in canon.get("areas") or []:
    path = os.path.join(shelf, a["id"] + ".yaml")
    if os.path.exists(path):
        kept.append(a["id"]); continue          # a real answer is never overwritten
    lines = [
        f'# areas/{a["id"]}.yaml — {a.get("name","")}',
        '#',
        '# A project answers every canon area: held · waived · na. `held` needs evidence.',
        '# `unheld` is legal in the file and is what the gate refuses once work touches the area.',
        '# This file is the project\'s own record; the canon of questions lives in Ymir.',
        '',
        'version: 1',
        f'area: {a["id"]}',
        f'project: {pid}',
        'state: unheld                 # unheld | held | waived | na',
        '',
        'keeper: unclaimed             # who holds it — a person, a role, or unclaimed',
        'lens: ""                      # what this keeper weighs, e.g. isolation, cost, correctness',
        '',
        '# the folders this keeper may write. The gate refuses a push that changes one of these',
        '# paths while the area is unheld. Empty = nothing is claimed yet.',
        'may_write: []',
        '',
        'evidence: []                  # what closes it: a test, a run, a document, a measured figure',
        '',
        '# the canon\'s questions, with this project\'s answers. An open answer is honest; a blank is not.',
        'answers:',
    ]
    for q in [a.get("question")] + list(a.get("evidence") or []):
        if not q:
            continue
        lines.append('  - q: ' + json.dumps(str(q), ensure_ascii=False))
        lines.append('    a: ""')
    lines += ['', 'closed: ""                    # the date the evidence last proved it', '']
    open(path, "w").write("\n".join(lines))
    written.append(a["id"])
plain_src = os.path.join(os.environ.get("YMIR_AREAS_ROOT", ""), "bin/collab/kit/areas/canon.yaml")
plain_dst = os.path.join(shelf, "canon.yaml")
if plain_src and os.path.exists(plain_src) and not os.path.exists(plain_dst):
    open(plain_dst, "w").write(open(plain_src).read())
    print("canon: copied the plain face of the canon into areas/canon.yaml")
readme = os.path.join(shelf, "README.md")
if not os.path.exists(readme):
    open(readme, "w").write(
        "# areas/ — what this project answers for\n\n"
        "One file per area, from the canon of eighteen. Each says who holds it, what they may write,\n"
        "and the evidence that closes it. `bash scripts/areas.sh check` names what is unanswered;\n"
        "`scripts/gates/areas-guard.sh` refuses a change to an area nobody holds.\n\n"
        "A waiver names who waived it and until when. An empty answer is honest; a silent one is not.\n")
print(f'init[{len(written)}]{{written}}:')
for w in written: print(f'  "{w}"')
if kept:
    print(f'kept[{len(kept)}]{{already answered, never overwritten}}:')
    for k in kept: print(f'  "{k}"')
PY
    ;;
  claim|waive)
    # the declaration format has ONE implementation (the kit's, which travels to repositories that
    # are not ours). This door points it at the estate instead of writing a second parser.
    AREAS_ROOT="$PROJECT_PATH" exec python3 -B "$ROOT/bin/collab/kit/scripts/areas.py" "$ACTION" "$@"
    ;;
  list|check|estate)
    if [ -x "$PROJECT_PATH/scripts/areas.sh" ] && [ "$ACTION" = check ]; then
      exec bash "$PROJECT_PATH/scripts/areas.sh" check
    fi
    exec python3 -B - "$ACTION" <<'PY'
import glob, os, sys, yaml
action = sys.argv[1]
canon = yaml.safe_load(open(os.environ["YMIR_AREAS_CANON"])) or {}
repo, pid = os.environ["YMIR_AREAS_REPO"], os.environ["YMIR_AREAS_ID"]
shelf = os.path.join(repo, "areas")

def load(path):
    try:
        return yaml.safe_load(open(path)) or {}
    except Exception as e:
        return {"_error": str(e)}

declared = {}
for path in sorted(glob.glob(os.path.join(shelf, "*.yaml"))):
    if os.path.basename(path) == "canon.yaml":
        continue
    d = load(path)
    declared[d.get("area") or os.path.basename(path)[:-5]] = (d, os.path.basename(path))

LEGAL = {"held", "waived", "na", "unheld"}
faults, rows = [], []
counts = {"held": 0, "unproved": 0, "waived": 0, "na": 0, "unheld": 0}
for a in canon.get("areas") or []:
    aid = a["id"]
    d, fname = declared.get(aid, ({}, ""))
    if not fname:
        faults.append((aid, "no declaration", "run: bash bin/agents/areas.sh init <project>"))
        counts["unheld"] += 1
        rows.append((aid, "unheld", "-", 0)); continue
    if d.get("_error"):
        faults.append((aid, "unreadable", d["_error"])); counts["unheld"] += 1
        rows.append((aid, "unheld", "-", 0)); continue
    state = str(d.get("state") or "").strip()
    keeper = str(d.get("keeper") or "unclaimed").strip()
    ev = [x for x in (d.get("evidence") or []) if str(x).strip()]
    answers = d.get("answers") or []
    open_q = sum(1 for x in answers if isinstance(x, dict) and not str(x.get("a") or "").strip())
    if state not in LEGAL:
        faults.append((aid, "state is not one of held · waived · na · unheld", state or "(empty)"))
    if state == "held" and not ev:
        faults.append((aid, "held with no evidence", "unproved is not held — name the artefact"))
        state = "unproved"
    if state == "held" and keeper in ("", "unclaimed", "none"):
        faults.append((aid, "held with no keeper", "a claim nobody holds is a wish"))
        state = "unproved"
    if state == "waived" and not str(d.get("waived_by") or "").strip():
        faults.append((aid, "waived with nobody's name", "a waiver names who waived it and until when"))
    if state == "na" and not str(d.get("why") or "").strip():
        faults.append((aid, "na with no reason", "say why it does not apply"))
    counts[state if state in counts else "unheld"] += 1
    rows.append((aid, state if state in counts else "unheld", keeper, open_q))

if action == "estate":
    total = sum(counts.values())
    print(f'estate[1]{{project,areas,held,unproved,waived,na,unheld}}:')
    print(f'  "{pid}",{total},{counts["held"]},{counts["unproved"]},{counts["waived"]},{counts["na"]},{counts["unheld"]}')
    raise SystemExit(0)

print(f'areas[{len(rows)}]{{area,state,keeper,open_questions}}:')
for aid, state, keeper, oq in rows:
    print(f'  "{aid}","{state}","{keeper}",{oq}')
if action == "list":
    raise SystemExit(0)
if faults:
    print(f'\nfaults[{len(faults)}]{{area,fault,what to do}}:')
    for aid, what, how in faults:
        print(f'  "{aid}","{what}","{how}"')
    print(f'\n{pid}: {counts["unheld"]} unheld · {counts["unproved"]} unproved · {counts["held"]} held '
          f'— an area nobody holds is not a green area')
    raise SystemExit(1)
print(f'\n{pid}: every canon area is answered ({counts["held"]} held · {counts["unproved"]} unproved · '
      f'{counts["waived"]} waived · {counts["na"]} na)')
PY
    ;;
  brief)
    AREA="${1:-}"; shift || true
    [ -n "$AREA" ] || { printf 'error: brief needs an area\nhelp: bin/agents/areas.sh list <project>\n' >&2; exit 2; }
    export YMIR_AREAS_AREA="$AREA"
    exec python3 -B - <<'PY'
import os, yaml
canon = yaml.safe_load(open(os.environ["YMIR_AREAS_CANON"])) or {}
area = os.environ["YMIR_AREAS_AREA"]
repo, pid = os.environ["YMIR_AREAS_REPO"], os.environ["YMIR_AREAS_ID"]
spec = next((a for a in canon.get("areas") or [] if a["id"] == area), None)
if not spec:
    print(f'error: no such area: {area}\nhelp: bash bin/agents/areas.sh canon'); raise SystemExit(2)
path = os.path.join(repo, "areas", area + ".yaml")
decl = (yaml.safe_load(open(path)) if os.path.exists(path) else {}) or {}
print(f'# Brief — you keep the {area} area of {pid}\n')
print(f'## What this area owns\n\n{spec.get("owns","")}\n')
print(f'## The question you must be able to answer\n\n{spec.get("question","")}\n')
print('## The evidence that closes it\n')
for e in spec.get("evidence") or []:
    print(f'- {e}')
print(f'\n## This project\'s declaration (`areas/{area}.yaml`)\n')
try:
    print(open(path).read())
except Exception:
    print(f'    NONE — no areas/{area}.yaml in {repo}. Say so before you act.\n')
mw = [str(x) for x in (decl.get("may_write") or [])]
print('## What you may write\n')
if mw:
    for m in mw:
        print(f'- `{repo}/{m}`')
else:
    print('- NOTHING is claimed for this area yet. Write nothing; say what must be claimed first.')
print('\n## What you may never do\n')
print('- write outside the folders above')
print('- call an answer closed while a question in the declaration is still open')
print('- merge, or claim an evidence you did not run')
print('\n## How to report\n')
print(f'    one line: what you forged, what stands unmade, what you need — then the artefact\n'
      f'    set `evidence:` and `closed:` in areas/{area}.yaml, and name `keeper:` if you are taking it on\n')
PY
    ;;
  call|status|stop)
    AREA="${1:-}"; shift || true
    [ -n "$AREA" ] || { printf 'error: %s needs an area\n' "$ACTION" >&2; exit 2; }
    SHIM="$STATE/estate/$PROJECT_ID"
    mkdir -p "$SHIM/areas" || exit 1
    YMIR_AREAS_AREA="$AREA" YMIR_AREAS_SHIM="$SHIM" python3 -B - <<'PY' || exit 1
import os, yaml
canon = yaml.safe_load(open(os.environ["YMIR_AREAS_CANON"])) or {}
area = os.environ["YMIR_AREAS_AREA"]; repo = os.environ["YMIR_AREAS_REPO"]
pid = os.environ["YMIR_AREAS_ID"]; shim = os.environ["YMIR_AREAS_SHIM"]
spec = next((a for a in canon.get("areas") or [] if a["id"] == area), None)
if not spec:
    print(f'error: no such area: {area}'); raise SystemExit(2)
decl = {}
p = os.path.join(repo, "areas", area + ".yaml")
if os.path.exists(p):
    decl = yaml.safe_load(open(p)) or {}
figures = spec.get("figures") or ["sindri"]
figure = figures[0]
mw = [str(x) for x in (decl.get("may_write") or [])]
lines = [
    f'# {shim}/areas/{area}.yaml — the seating shim, generated by bin/agents/areas.sh',
    '# OURS, NOT THEIRS: the project declares the area; this file names which of our figures keeps it.',
    '',
    'version: 1',
    f'domain: {area}',
    f'name: {area}',
    f'figure: {spec.get("name","")}',
    'kind: area',
    f'keeper: {figure}',
    'stateful: true',
    f'folder: {repo}',
    'may_write: [' + ', '.join('"' + m + '"' for m in mw) + ']' if mw else 'may_write: []',
    f'board: {pid}/{area}',
    f'memory: well namespace domain:{pid}/{area}',
    'called_by:',
    f'  - "bin/agents/areas.sh call {pid} {area}"',
    'never:',
    '  - "write outside may_write"',
    '  - "merge"',
]
os.makedirs(os.path.join(shim, "areas"), exist_ok=True)
open(os.path.join(shim, "areas", area + ".yaml"), "w").write("\n".join(lines) + "\n")
PY
    export AREAS_SCOPE="$SHIM"
    args=("$AREA")
    for a in "$@"; do args+=("$a"); done
    exec bash "$ROOT/bin/agents/domain.sh" "$ACTION" "${args[@]}"
    ;;
  *) usage; exit 2 ;;
esac
