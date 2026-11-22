#!/usr/bin/env bash
# skill-smoke.sh — a skill whose commands no longer exist is a hallucination waiting for its reader (plan 350 D).
#
# Every SKILL.md on the shelves names the commands an agent is to run. When a verb is renamed (`smidja teams` →
# `smidja team list`, measured 2026-11-21) or a door moves, the skill still teaches the old one, and the next agent
# follows it. This door reads every skill and checks each command it names:
#
#   a path       `bin/…/x.sh`, `scripts/x`, `.agents/…/x.py`   → it exists in this tree (and a .sh is executable)
#   a verb       `<cli> <verb>` for a CLI on PATH (SKILL_SMOKE_CLIS, default "smidja herdr")
#                                                             → `<cli> --help` names the verb
#
# Nothing a skill names is RUN: the smoke reads help and the tree only, so it is safe on the clock.
#
#   skill-smoke.sh [--shelf DIR]... [--json] [--notify]
#
# A skill that names no command at all is listed as `none` (a note, not a fault). A skill naming a command that is
# gone is `GONE`, with the command. --notify hands the GONE list to the arm holder through the Veil.
# Exit: 0 every named command is there · 1 one or more are gone · 2 usage.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SHELVES=(); JSON=0; NOTIFY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --shelf) SHELVES+=("$2"); shift 2 ;;
    --json) JSON=1; shift ;;
    --notify) NOTIFY=1; shift ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'skill-smoke: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ "${#SHELVES[@]}" -gt 0 ] || SHELVES=("$ROOT/.agents/skills")
export SKILL_SMOKE_ROOT="$ROOT" SKILL_SMOKE_CLIS="${SKILL_SMOKE_CLIS:-smidja herdr}"
out="$(python3 - "$JSON" "${SHELVES[@]}" <<'PY'
import json, os, re, shutil, subprocess, sys
root = os.environ["SKILL_SMOKE_ROOT"]
clis = os.environ["SKILL_SMOKE_CLIS"].split()
as_json, shelves = sys.argv[1] == "1", sys.argv[2:]
helps = {}
def help_of(cli):
    if cli not in helps:
        try:
            helps[cli] = subprocess.run([cli, "--help"], capture_output=True, text=True, timeout=20).stdout
        except Exception:
            helps[cli] = None
    return helps[cli]
PATH_RE = re.compile(r"`(?:bash |python3 )?((?:bin|scripts|\.agents|apps|tools|systems)/[A-Za-z0-9_./-]+\.(?:sh|py|mjs|ts))")
rows = []
for shelf in shelves:
    if not os.path.isdir(shelf):
        continue
    for name in sorted(os.listdir(shelf)):
        f = os.path.join(shelf, name, "SKILL.md")
        if not os.path.isfile(f):
            continue
        text = open(f, encoding="utf-8", errors="replace").read()
        named, gone = set(), []
        for p in PATH_RE.findall(text):
            named.add(p)
            full = os.path.join(root, p)
            if not os.path.exists(full):
                gone.append(p)
            elif p.endswith(".sh") and not os.access(full, os.X_OK):
                gone.append(p + " (not executable)")
        for cli in clis:
            if not shutil.which(cli):
                continue
            for verb in sorted(set(re.findall(r"`" + re.escape(cli) + r" ([a-z][a-z-]+)", text))):
                named.add(f"{cli} {verb}")
                h = help_of(cli)
                if h is not None and not re.search(r"(^|[\s|,])" + re.escape(verb) + r"([\s|,]|$)", h, re.M):
                    gone.append(f"{cli} {verb}")
        gone = list(dict.fromkeys(gone))
        state = "GONE" if gone else ("ok" if named else "none")
        rows.append({"skill": name, "shelf": shelf, "state": state, "named": len(named), "gone": gone})
if as_json:
    print(json.dumps(rows))
else:
    print(f"skill-smoke[{len(rows)}]{{skill,state,named,gone}}:")
    for r in rows:
        print(f'  "{r["skill"]}","{r["state"]}",{r["named"]},"{"; ".join(r["gone"])}"')
bad = [r for r in rows if r["state"] == "GONE"]
print(f"skill-smoke: {len(bad)} skill(s) name a command that is gone", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
)"; rc=$?
printf '%s\n' "$out"
if [ "$rc" = 1 ] && [ "$NOTIFY" = 1 ] && [ -x "$ROOT/bin/agents/veil.sh" ]; then
  gone="$(printf '%s\n' "$out" | sed -n 's/^  "\([^"]*\)","GONE",[0-9]*,"\(.*\)"$/\1: \2/p' | tr '\n' ';')"
  timeout 120 bash "$ROOT/bin/agents/veil.sh" send --from "script the skill smoke" --kind finding \
    "skills teach commands that are gone — $gone" >/dev/null 2>&1 || true
fi
exit "$rc"
