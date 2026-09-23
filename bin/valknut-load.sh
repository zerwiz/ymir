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
#   bin/valknut-load.sh --install      # seat the post-merge hook (bind on merge)
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
OC_LOCAL="$ROOT/.opencode/agents"
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

MODE_OPENCODE=0; MODE_PI=0; MODE_GLOBAL=0; MODE_INSTALL=0; MODE_STATUS=0
for a in "$@"; do
  case "$a" in
    --opencode) MODE_OPENCODE=1 ;;
    --pi|--agents) MODE_PI=1 ;;
    --global) MODE_GLOBAL=1 ;;
    --status) MODE_STATUS=1 ;;
    --all) MODE_OPENCODE=1; MODE_PI=1 ;;
    --install) MODE_INSTALL=1 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/valknut-load.sh [--opencode|--pi|--global|--status|--all]\n' "$a" >&2; exit 2 ;;
  esac
done

# --install: seat the post-merge hook, so a MERGE rebinds the surfaces. A merged
# extension fix otherwise sits in the repo while the RUNNING harness keeps the
# code it loaded — which is exactly how a hand-copy became necessary 2026-09-23.
if [ "$MODE_INSTALL" = "1" ]; then
  # Ask git for the hooks dir: in a worktree `.git` is a FILE, and the shared
  # hooks live in the MAIN repo — the same reason a fix must be installed from
  # wherever git says, not from the caller's tree.
  hooksdir="$(git -C "$ROOT" rev-parse --git-path hooks 2>/dev/null)"
  case "$hooksdir" in /*) ;; "") hooksdir="" ;; *) hooksdir="$ROOT/$hooksdir" ;; esac
  if [ -n "$hooksdir" ] && [ -d "$hooksdir" ]; then
    h="$hooksdir/post-merge"
    main_root="$(cd "$(dirname "$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null)")" 2>/dev/null && pwd)"
    [ -n "$main_root" ] || main_root="$ROOT"
    cat >"$h" <<HOOK
#!/usr/bin/env bash
# post-merge — rebind the harness surfaces after a merge. Installed by
# bin/valknut-load.sh --install. A merge pulls new agents, skills and Pi
# extensions into the tree; the harnesses load them from their OWN homes, so the
# bind must run or a merged fix stays invisible to the running session.
set -u
[ -x "$main_root/bin/valknut-load.sh" ] && "$main_root/bin/valknut-load.sh" --all --global >/dev/null 2>&1 || true
HOOK
    chmod +x "$h"
    printf 'valknut-load[1]{hook,path,state}:\n  "post-merge","%s","installed"\n' "$h"
  else
    printf 'valknut-load[1]{hook,state}:\n  "post-merge","skipped — no hooks dir (not a git checkout)"\n'
  fi
  exit 0
fi

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

# ── the deployed-extension root record ───────────────────────────────────────
# The extensions are DEPLOYED into ${HOME}/.pi/agent/extensions/, and walking up
# from there reaches ${HOME}/.pi — a directory that holds no bin/. So a deployed
# copy that exec'd `${root}/bin/…` exec'd a path that does not exist, and the
# failure was silent: the Gná arm child died with 127 before its first poll, no
# state/.watch.heartbeat was ever written, and the watch was dead while every
# file listing looked correct. The root is therefore RECORDED beside the deployed
# files and read back by .pi/extensions/lib/ymir-home.ts.
#
# One absolute root per line, most recent first, deduped, capped. A root that no
# longer exists (a merged-and-removed Yggdrasil worktree, an uninstalled npm
# prefix) is skipped by the reader, so deploying from a worktree never strands a
# machine on a dead path. Prints `recorded` when the file changed, `unchanged`
# when it did not.
ymir_root_record() {
  local pointer="$PI_EXT_HOME/.ymir-root" tmp line
  [ -d "$PI_EXT_HOME" ] || return 0
  tmp="$(mktemp 2>/dev/null)" || return 0
  printf '%s\n' "$ROOT" >"$tmp"
  if [ -r "$pointer" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      [ "$line" = "$ROOT" ] && continue
      grep -qxF -- "$line" "$tmp" 2>/dev/null && continue
      printf '%s\n' "$line" >>"$tmp"
    done <"$pointer"
  fi
  if [ "$(wc -l <"$tmp" | tr -d ' ')" -gt 8 ]; then
    head -n 8 "$tmp" >"$tmp.cap" && mv "$tmp.cap" "$tmp"
  fi
  if [ -r "$pointer" ] && cmp -s "$tmp" "$pointer"; then
    rm -f "$tmp"; printf 'unchanged'; return 0
  fi
  mv "$tmp" "$pointer" && printf 'recorded'
}

# The first recorded root that really holds bin/syn-watch-arm.sh, or nothing.
ymir_root_verified() {
  local pointer="$PI_EXT_HOME/.ymir-root" line
  [ -r "$pointer" ] || return 0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ -x "$line/bin/syn-watch-arm.sh" ] && { printf '%s' "$line"; return 0; }
  done <"$pointer"
}

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
  # The root the DEPLOYED extensions read (`.ymir-root`). A stale or absent record
  # means every `${root}/bin/…` they exec is a path that does not exist: the arm
  # dies at 127 and the watch is silently dead, so this is a checked row.
  vroot="$(ymir_root_verified)"
  if [ -n "$vroot" ]; then
    add pi-ext-root "$PI_EXT_HOME/.ymir-root" "deployed extensions resolve to $vroot"
  else
    add pi-ext-root "$PI_EXT_HOME/.ymir-root" "ERROR no recorded root holds bin/syn-watch-arm.sh — deployed extensions cannot find their bin/ (run: bin/valknut-load.sh --pi)"
  fi
  for hd in .claude .codex .cursor; do
    [ -d "$ROOT/$hd" ] || continue
    [ -L "$ROOT/$hd/skills" ] && add "$hd-skills" "$ROOT/$hd/skills" linked || add "$hd-skills" "$ROOT/$hd/skills" absent
  done
fi

if [ "$MODE_OPENCODE" = 1 ]; then
  add opencode-config "$ROOT/opencode.json" "$(config_out "$ROOT/opencode.json.example" "$ROOT/opencode.json")"
  # OpenCode reads `.opencode/agents/` (PLURAL). The singular `.opencode/agent/`
  # was never read by the harness at all — twenty correct symlinks in a directory
  # no loader opens, which is why only the agents declared by hand in
  # opencode.json ever appeared. Migrate a legacy singular dir forward so an old
  # home heals instead of silently keeping its agents invisible.
  if [ -d "$ROOT/.opencode/agent" ] && [ ! -e "$ROOT/.opencode/agents" ]; then
    mv "$ROOT/.opencode/agent" "$ROOT/.opencode/agents" 2>/dev/null \
      && add opencode-migrate "$ROOT/.opencode/agents" "legacy .opencode/agent/ moved to .opencode/agents/" \
      || add opencode-migrate "$ROOT/.opencode/agents" "ERROR could not migrate"
  fi
  # Count what is bound here; the binding itself happens further down, after
  # `link_agents` is defined (this block runs before that definition).
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
  # The CONTRACT, deployed globally: pi reads an AGENTS.md from its agent home in
  # every session, whatever the workspace. Without this, Sessrumnir (or any pi
  # session) started in another project loads THAT project's rules and knows
  # nothing of Ymir - no Brokk, no laws, no lore. Symlink, so the tree stays the
  # single source and an update is picked up with no re-install.
  #
  # A Yggdrasil worktree is REMOVED by `yggdrasil.sh cleanup`, so a contract
  # symlink into one leaves every later session with no AGENTS.md at all — the
  # same transient-root failure the `.ymir-root` record exists to avoid. A deploy
  # from a worktree therefore repoints the contract only when the current target
  # is already gone.
  if [ -d "$HOME/.pi/agent" ]; then
    contract="$HOME/.pi/agent/AGENTS.md"
    if [ -e "$contract" ]; then
      case "$ROOT" in
        */.yggdrasil/*) add pi-global-contract "$contract" "kept — a worktree deploy never repoints a live contract" ;;
        *) ln -sfn "$ROOT/AGENTS.md" "$contract" 2>/dev/null \
             && add pi-global-contract "$contract" "the Ymir contract, loaded in every pi session" \
             || add pi-global-contract "$contract" "ERROR" ;;
      esac
    else
      ln -sfn "$ROOT/AGENTS.md" "$contract" 2>/dev/null \
        && add pi-global-contract "$contract" "the Ymir contract, loaded in every pi session" \
        || add pi-global-contract "$contract" "ERROR"
    fi
  fi

  if [ -d "$PI_EXT_SRC" ]; then
    mkdir -p "$PI_EXT_HOME" 2>/dev/null
    dep_n=0
    for f in "$PI_EXT_SRC"/*.ts; do
      [ -e "$f" ] || continue
      b=$(basename "$f")
      if [ -f "$PI_EXT_HOME/$b" ] && cmp -s "$f" "$PI_EXT_HOME/$b"; then continue; fi
      cp -f "$f" "$PI_EXT_HOME/$b" && dep_n=$((dep_n+1))
    done
    # Their supporting modules are one level away, under the extensions' own lib:
    # the shared extensions require sibling lib modules, and deploying the
    # top-level files ALONE ships extensions that cannot load. That is exactly
    # what pi reported: Failed to load extension, Cannot find module ./lib/....
    # A deploy that copies a file but not the module it imports is not a deploy.
    PI_EXT_LIB="$ROOT/.pi/extensions/lib"
    if [ -d "$PI_EXT_LIB" ]; then
      mkdir -p "$PI_EXT_HOME/lib" 2>/dev/null
      for f in "$PI_EXT_LIB"/*; do
        [ -e "$f" ] || continue
        b=$(basename "$f")
        if [ -f "$PI_EXT_HOME/lib/$b" ] && cmp -s "$f" "$PI_EXT_HOME/lib/$b"; then continue; fi
        cp -f "$f" "$PI_EXT_HOME/lib/$b" && dep_n=$((dep_n+1))
      done
    fi
    add pi-extensions "$PI_EXT_HOME" "$dep_n deployed (shared single home, lib included)"
    # …and record the tree that owns bin/, because the deployed copy cannot find
    # it by walking up. Read back by .pi/extensions/lib/ymir-home.ts.
    add pi-ext-root "$PI_EXT_HOME/.ymir-root" "$(ymir_root_record) → $ROOT"
  fi
fi

# Agents for every harness: `.agents/agents/` is canonical, and each harness dir
# is a directory of symlinks into it (Rule 02). Pi and opencode have their own
# bindings above; claude, codex and cursor are bound here, so no harness is left
# holding a hand-made subset. opencode names an agent by its `name:` frontmatter
# (bragi.md -> bragi-marketer.md), the others by the profile file name.
agent_name_of() {  # <profile> -> the frontmatter `name:`
  sed -n 's/^name:[[:space:]]*//p' "$1" 2>/dev/null | head -1 | tr -d '[:space:]'
}
link_agents() {  # <harness-dir> [short]
  local dir=$1 short=${2:-} made=0 f base want
  [ -d "$(dirname "$dir")" ] || return 1
  mkdir -p "$dir" || return 1
  for f in "$AGENTS"/*.md; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    if [ "$short" = "short" ]; then
      want="$(agent_name_of "$f")"; [ -n "$want" ] || continue; want="$want.md"
    else
      want="$base"
    fi
    ln -sfn "../../.agents/agents/$base" "$dir/$want" 2>/dev/null || return 1
    made=$((made + 1))
  done
  printf '%s' "$made"
}
if [ "$MODE_STATUS" = 0 ]; then
  # Skills for the CLIs whose project scope is their own directory. Pi needs no
  # link (it discovers `.agents/skills` by walking up); opencode reaches that
  # tree through `skills.paths`. claude, codex and cursor each get one link, so
  # all of them read the ONE skills tree.
  linked=""
  for hd in .claude .codex .cursor; do
    [ -d "$ROOT/$hd" ] || continue
    link_skills "$ROOT/$hd" >/dev/null 2>&1 && linked="$linked $hd"
  done
  [ -n "$linked" ] && add harness-skills "$SKILLS" "linked into:$linked"

  # …and AGENTS for the same harnesses, plus opencode, so every tool loads every
  # agent — never a hand-made subset.
  for hd in .claude .codex .cursor; do
    [ -d "$ROOT/$hd" ] || continue
    n=$(link_agents "$ROOT/$hd/agents") || n=0
    add "${hd#.}-agents" "$ROOT/$hd/agents" "bound ($n)"
  done
  if [ -d "$ROOT/.opencode" ]; then
    n=$(link_agents "$OC_LOCAL" short) || n=0
    add opencode-agents "$OC_LOCAL" "bound ($n)"
  fi
fi

printf 'loaders[%s]{tool,path,status}:\n' "${#T[@]}"
for i in "${!T[@]}"; do
  printf '  "%s","%s","%s"\n' "${T[$i]}" "${P[$i]}" "${S[$i]}"
done
printf 'help[1]: run `bin/valknut-load.sh --status` to inspect bindings\n'
