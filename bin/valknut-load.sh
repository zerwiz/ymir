#!/usr/bin/env bash
# valknut-load.sh — Valknut, the knot that binds the repo distro into each tool's
# load path. Galdr-style: TOON output, structured errors, no prompts, idempotent.
#
# The repo is the source of truth: agents live in `.agents/agents/`, skills in
# `.agents/skills/`, Pi extensions in `.pi/extensions/`, the backend in
# `bin/` + `.agents/backend/`. This command binds them where each harness looks.
#
# Usage:
#   bin/valknut-load.sh [--opencode] [--pi] [--global] [--status] [--all]
#   bin/valknut-load.sh --version | -v
#
# Exit: 0 ok, 1 error, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS="$ROOT/.agents/agents"
PI_LOCAL="$ROOT/.pi/agents"
PI_GLOBAL="${HOME}/.pi/agent/agents"
# Shared Pi extensions have ONE home: ${HOME}/.pi/agent/extensions/ (see
# galdr/assets/harness-integration/README.md). The repo keeps their SOURCE at
# .pi/shared/extensions/ — never at .pi/extensions/, because an extension present
# in both load paths makes pi exit with a tool-name conflict and no agent can be
# seated. This loader DEPLOYS that source into the single home.
PI_EXT_SRC="$ROOT/.pi/shared/extensions"
PI_EXT_HOME="${HOME}/.pi/agent/extensions"
OC_LOCAL="$ROOT/.opencode/agent"
SKILLS="$ROOT/.agents/skills"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

for a in "$@"; do
  case "$a" in
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
  esac
done

MODE_OPENCODE=0; MODE_PI=0; MODE_GLOBAL=0; MODE_STATUS=0
for a in "$@"; do
  case "$a" in
    --opencode) MODE_OPENCODE=1 ;;
    --pi|--agents) MODE_PI=1 ;;
    --global) MODE_GLOBAL=1 ;;
    --status) MODE_STATUS=1 ;;
    --all) MODE_OPENCODE=1; MODE_PI=1 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/valknut-load.sh [--opencode|--pi|--global|--status|--all]\n' "$a" >&2; exit 2 ;;
  esac
done
[ $((MODE_OPENCODE + MODE_PI + MODE_STATUS)) -eq 0 ] && { MODE_OPENCODE=1; MODE_PI=1; }

if [ ! -d "$AGENTS" ]; then
  printf 'error: agents dir not found: %s\nhelp: expected .agents/agents/ inside %s\n' "$AGENTS" "$ROOT"
  exit 1
fi

# ── machine config, rendered from its example ────────────────────────────────
# opencode.json and .pi/mcp.json must contain ABSOLUTE paths, so they cannot be
# tracked — a tracked copy would hand every operator the previous one's home.
# They are rendered from the shipped *.example with the real $HOME and root.
#
# TWO WRITERS touch opencode.json: this loader, and `bin/agents-config.sh apply`
# (which owns the ROSTER — providers and per-agent models, from
# config/agents.yaml). A blind render here DELETED the roster's work: the Apodex
# provider lived only in the live file and vanished on the next loader run. So
# this merges and never overwrites: missing keys are added, existing ones are
# left alone, and the skills tree is ensured. A live value is never lost, from
# either writer. Seeding happens only when the target is absent.
#
# Returns one of: seeded | merged(<what>) | unchanged | kept | absent.
config_out() {  # <rendered-json-or-text> <target>
  local ex=$1 out=$2
  [ -r "$ex" ] || { printf 'absent'; return 0; }
  python3 - "$ex" "$out" "$HOME" "$ROOT" <<'PY'
import json, os, sys

ex, out, home, root = sys.argv[1:5]
raw = open(ex).read().replace("__YMIR_HOME__", home).replace("__YMIR_ROOT__", root)

def write(text):
    with open(out, "w") as fh:
        fh.write(text)

try:
    want = json.loads(raw)
except Exception:
    # Not JSON (or not yet): seed a missing file, but never overwrite a live one.
    if os.path.exists(out):
        print("kept")
    else:
        write(raw); print("seeded")
    raise SystemExit

if not os.path.exists(out):
    write(json.dumps(want, indent=2) + "\n"); print("seeded"); raise SystemExit

cur = json.load(open(out))
added = []

def merge(cur, want, path=""):
    for k, v in want.items():
        if k not in cur:
            cur[k] = v; added.append(path + k)
        elif isinstance(v, dict) and isinstance(cur[k], dict):
            merge(cur[k], v, path + k + ".")

merge(cur, want)

# This loader's own contract: the ONE skills tree must stay reachable.
paths = cur.setdefault("skills", {}).setdefault("paths", [])
if ".agents/skills" not in paths:
    paths.append(".agents/skills"); added.append("skills.paths")

if not added:
    print("unchanged"); raise SystemExit
write(json.dumps(cur, indent=2) + "\n")
print("merged(%s)" % ",".join(added[:4]))
PY
}

declare -a T P S
add() { T+=("$1"); P+=("$2"); S+=("$3"); }

link_agent_dir() {  # <target-dir> <rel-prefix>
  local target=$1 prefix=$2 made=0
  mkdir -p "$target" || return 1
  local f base
  for f in "$AGENTS"/*.md; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    ln -sfn "${prefix}/${base}" "$target/$base" 2>/dev/null || return 1
    made=$((made + 1))
  done
  printf '%s' "$made"
}

# Skills are ONE tree (`.agents/skills/`). Each harness reaches it its own way:
#   opencode — `skills.paths: [".agents/skills"]` in opencode.json (rendered below)
#   pi       — discovery, natively: it walks up from the cwd looking for
#              `.agents/skills` (and `~/.agents/skills`), so it needs NO link,
#              and a second root under `.pi/` would only invite double-loading
#   claude · codex · cursor — project skills live under the harness dir, so each
#              gets `<harness>/skills -> ../.agents/skills`
link_skills() {  # <harness-dir>  → binds <harness-dir>/skills
  local dir=$1
  [ -d "$dir" ] || return 1
  ln -sfn ../.agents/skills "$dir/skills" 2>/dev/null || return 1
  printf 'bound'
}

if [ "$MODE_STATUS" = 1 ]; then
  [ -d "$OC_LOCAL" ] && add opencode "$OC_LOCAL" "$(ls "$OC_LOCAL"/*.md 2>/dev/null | wc -l | tr -d ' ') files" || add opencode "$OC_LOCAL" absent
  [ -d "$PI_LOCAL" ] && add pi-local "$PI_LOCAL" "$(ls "$PI_LOCAL"/*.md 2>/dev/null | wc -l | tr -d ' ') links" || add pi-local "$PI_LOCAL" absent
  [ -d "$PI_GLOBAL" ] && add pi-global "$PI_GLOBAL" "$(ls "$PI_GLOBAL"/*.md 2>/dev/null | wc -l | tr -d ' ') links" || add pi-global "$PI_GLOBAL" absent
  add agents-source "$AGENTS" "$(ls "$AGENTS"/*.md 2>/dev/null | wc -l | tr -d ' ') files"
  add opencode-skills "$SKILLS" "$(grep -q '\.agents/skills' "$ROOT/opencode.json" 2>/dev/null && printf 'via skills.paths' || printf 'absent')"
  add pi-skills "$SKILLS" "native discovery (walks up to .agents/skills)"
  for hd in .claude .codex .cursor; do
    [ -d "$ROOT/$hd" ] || continue
    [ -L "$ROOT/$hd/skills" ] && add "$hd-skills" "$ROOT/$hd/skills" linked || add "$hd-skills" "$ROOT/$hd/skills" absent
  done
fi

if [ "$MODE_OPENCODE" = 1 ]; then
  add opencode-config "$ROOT/opencode.json" "$(config_out "$ROOT/opencode.json.example" "$ROOT/opencode.json")"
  if [ -d "$OC_LOCAL" ]; then
    n=$(ls "$OC_LOCAL"/*.md 2>/dev/null | wc -l | tr -d ' ')
    add opencode "$OC_LOCAL" "native ($n agents)"
  else
    add opencode "$OC_LOCAL" "ERROR absent"
  fi
  # The skills tree reaches opencode through its config, not a link.
  if [ -f "$ROOT/opencode.json" ] && grep -q '\.agents/skills' "$ROOT/opencode.json"; then
    add opencode-skills "$SKILLS" "via skills.paths"
  else
    add opencode-skills "$SKILLS" "ERROR not in opencode.json"
  fi
fi

if [ "$MODE_PI" = 1 ]; then
  add pi-mcp "$ROOT/.pi/mcp.json" "$(config_out "$ROOT/.pi/mcp.json.example" "$ROOT/.pi/mcp.json")"
  n=$(link_agent_dir "$PI_LOCAL" "../../.agents/agents") && add pi-local "$PI_LOCAL" "bound ($n links)" || add pi-local "$PI_LOCAL" "ERROR"
  if [ "$MODE_GLOBAL" = 1 ]; then
    g=$(link_agent_dir "$PI_GLOBAL" "$AGENTS") && add pi-global "$PI_GLOBAL" "bound ($g links)" || add pi-global "$PI_GLOBAL" "ERROR"
  fi
  # Deploy the shared extensions into their single home. Copy, not link: a
  # broken link would silently disable a tool, and pi reads the file directly.
  # Idempotent — identical files are left untouched.
  if [ -d "$PI_EXT_SRC" ]; then
    mkdir -p "$PI_EXT_HOME" 2>/dev/null
    dep_n=0
    for f in "$PI_EXT_SRC"/*.ts; do
      [ -e "$f" ] || continue
      b=$(basename "$f")
      if [ -f "$PI_EXT_HOME/$b" ] && cmp -s "$f" "$PI_EXT_HOME/$b"; then continue; fi
      cp -f "$f" "$PI_EXT_HOME/$b" && dep_n=$((dep_n+1))
    done
    add pi-extensions "$PI_EXT_HOME" "$dep_n deployed (shared single home)"
  fi
fi

# Skills for the CLIs whose project scope is their own directory. Pi needs no
# link (it discovers `.agents/skills` by walking up); opencode reaches the tree
# through `skills.paths`. claude, codex and cursor each get one link, so all of
# them read the ONE skills tree.
if [ "$MODE_STATUS" = 0 ]; then
  linked=""
  for hd in .claude .codex .cursor; do
    [ -d "$ROOT/$hd" ] || continue
    link_skills "$ROOT/$hd" >/dev/null 2>&1 && linked="$linked $hd"
  done
  [ -n "$linked" ] && add harness-skills "$SKILLS" "linked into:$linked"
fi

printf 'loaders[%s]{tool,path,status}:\n' "${#T[@]}"
for i in "${!T[@]}"; do
  printf '  "%s","%s","%s"\n' "${T[$i]}" "${P[$i]}" "${S[$i]}"
done
printf 'help[1]: run `bin/valknut-load.sh --status` to inspect bindings\n'
