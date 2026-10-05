#!/usr/bin/env bash
# valknut-load.sh — Valknut, the knot that binds the repo distro into each tool's
# load path. Galdr-style: TOON output, structured errors, no prompts, idempotent.
#
# The repo is the source of truth: agents live in `.agents/agents/`, skills in
# `.agents/skills/`, Pi extensions in `.pi/extensions/`, the backend in
# `bin/` + `.agents/backend/`. This command binds them where each harness looks.
#
# Usage:
#   bin/seat/valknut-load.sh [--opencode] [--pi] [--global] [--status] [--all]
#   bin/seat/valknut-load.sh --install      # seat the post-merge hook (bind on merge)
#   bin/seat/valknut-load.sh --version | -v
#
# Exit: 0 ok, 1 error, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
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
# The helper modules the shared extensions import. Still sourced from the OLD flat
# tree (`.pi/extensions/lib`) because plan 29 built them there and the single-home
# migration moved the extensions but not their internals — see the harness-integration
# asset. Named separately so --check can see it without running a deploy.
PI_EXT_LIB_SRC="$ROOT/.pi/extensions/lib"
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

MODE_OPENCODE=0; MODE_PI=0; MODE_GLOBAL=0; MODE_INSTALL=0; MODE_STATUS=0; MODE_CHECK=0
for a in "$@"; do
  case "$a" in
    --opencode) MODE_OPENCODE=1 ;;
    --pi|--agents) MODE_PI=1 ;;
    --global) MODE_GLOBAL=1 ;;
    --status) MODE_STATUS=1 ;;
    --check) MODE_CHECK=1 ;;
    --all) MODE_OPENCODE=1; MODE_PI=1 ;;
    --install) MODE_INSTALL=1 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/seat/valknut-load.sh [--opencode|--pi|--global|--status|--check|--all]\n' "$a" >&2; exit 2 ;;
  esac
done

# --check: is the DEPLOYED extension tree what the repo says it is?
#
# This gate exists because of four defects that every other check missed (2026-10-04):
#   1. the deployed ymir-subagents.ts was 12,991 B against a 13,748 B source, so the
#      RUNNING harness was missing the fix that stops a figure being seated with an
#      unfilled brief — and every file listing looked correct
#   2. `constellation-load.test.ts` and `constellation-registry.test.ts` were copied
#      into the live tree on every deploy, because nothing excluded them
#   3. an extension present in BOTH `~/.pi/agent/extensions/` and the project
#      `.pi/extensions/` registers its tools twice; pi refuses the duplicate and no
#      agent can be seated. The no-op stubs exist to prevent exactly this
#   4. the governing doc pointed at both paths at once, so a grep for a module's
#      home returned two answers
#
# A deploy is a COPY. Nothing re-runs the loader on its own, so the only thing that
# can catch a stale deploy is a check that asks. Exit 1 on any failure, so it can sit
# in CI and in the post-merge hook rather than in someone's memory.
if [ "$MODE_CHECK" = "1" ]; then
  fails=0
  printf 'check{pi-extensions-deployed}:\n'
  if [ ! -d "$PI_EXT_HOME" ]; then
    printf '  %-46s %s\n' "deployed tree" "MISSING — run: bin/seat/valknut-load.sh --pi"
    exit 1
  fi

  # 1. every deployed extension must be byte-identical to its source
  stale=0
  for f in "$PI_EXT_SRC"/*.ts "$PI_EXT_SRC"/*.js; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    if [ ! -f "$PI_EXT_HOME/$b" ]; then
      printf '  %-46s %s\n' "$b" "NOT DEPLOYED"
      stale=$((stale+1))
    elif ! cmp -s "$f" "$PI_EXT_HOME/$b"; then
      printf '  %-46s %s\n' "$b" "STALE — deployed differs from source"
      stale=$((stale+1))
    fi
  done
  [ "$stale" -eq 0 ] && printf '  %-46s %s\n' "all extensions byte-identical to source" "PASS" \
                     || { printf '  %-46s %s\n' "stale or undeployed extensions" "FAIL ($stale)"; fails=$((fails+1)); }

  # 2. the helper modules the shared set imports must be deployed too — deploying
  #    the top-level files ALONE ships extensions that cannot load
  if [ -d "$PI_EXT_LIB_SRC" ]; then
    miss=0
    for f in "$PI_EXT_LIB_SRC"/*; do
      [ -e "$f" ] || continue
      b=$(basename "$f")
      case "$b" in *.test.*|*.spec.*) continue ;; esac
      if [ ! -f "$PI_EXT_HOME/lib/$b" ]; then
        printf '  %-46s %s\n' "lib/$b" "NOT DEPLOYED"
        miss=$((miss+1))
      elif ! cmp -s "$f" "$PI_EXT_HOME/lib/$b"; then
        printf '  %-46s %s\n' "lib/$b" "STALE"
        miss=$((miss+1))
      fi
    done
    [ "$miss" -eq 0 ] && printf '  %-46s %s\n' "all helper modules byte-identical" "PASS" \
                      || { printf '  %-46s %s\n' "helper modules" "FAIL ($miss)"; fails=$((fails+1)); }
  fi

  # 3. nothing that is not a test may live in the live tree
  leaked=0
  for f in "$PI_EXT_HOME"/lib/*.test.* "$PI_EXT_HOME"/*.test.*; do
    [ -e "$f" ] || continue
    printf '  %-46s %s\n' "$(basename "$f")" "LEAKED — a test is in the live tree"
    leaked=$((leaked+1))
  done
  [ "$leaked" -eq 0 ] && printf '  %-46s %s\n' "no test files in the deployed tree" "PASS" \
                      || { printf '  %-46s %s\n' "test files deployed" "FAIL ($leaked)"; fails=$((fails+1)); }

  # 4. no extension may exist in BOTH load paths. This is the collision that makes
  #    pi exit with a tool-name conflict, and no agent can be seated.
  #
  #    Tested by fault injection, and the first version of this check was WRONG: it
  #    skipped any project-local file byte-identical to the source, on the theory that
  #    only a *different* file collides. A file copied VERBATIM from the source
  #    collides just as hard — it registers the same tools from a second directory pi
  #    already scanned. So the rule is the plain one: a project-local extension file
  #    must either not exist, or register nothing at all.
  dupes=0
  for f in "$ROOT/.pi/extensions"/*.ts "$ROOT/.pi/extensions"/*.js; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    sz=$(stat -c%s "$f")
    if [ "$sz" -gt 1024 ]; then
      printf '  %-46s %s\n' "$b" "DUPLICATE — ${sz}B in the project tree registers tools pi already loaded"
      dupes=$((dupes+1))
    elif [ -f "$PI_EXT_SRC/$b" ] && cmp -s "$f" "$PI_EXT_SRC/$b"; then
      printf '  %-46s %s\n' "$b" "DUPLICATE — byte-identical to the deployed source"
      dupes=$((dupes+1))
    fi
  done
  [ "$dupes" -eq 0 ] && printf '  %-46s %s\n' "no extension in two load paths" "PASS" \
                     || { printf '  %-46s %s\n' "double-registered extensions" "FAIL ($dupes)"; fails=$((fails+1)); }

  # 5. A no-op stub is allowed only while it stays a no-op. List them, so the
  #    eventual deletion of this tree is a decision rather than a surprise.
  stubs=0
  for f in "$ROOT/.pi/extensions"/*.ts; do
    [ -e "$f" ] || continue
    stubs=$((stubs+1))
  done
  printf '  %-46s %s\n' "project-local no-op stubs" "$stubs present (each must register nothing)"

  printf 'check{pi-extension-check}:\n'
  if [ "$fails" -eq 0 ]; then
    printf '  %-46s %s\n' "valknut-load --check" "PASS"
    exit 0
  fi
  printf '  %-46s %s\n' "valknut-load --check" "FAIL ($fails) — run: bin/seat/valknut-load.sh --pi"
  exit 1
fi

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
# bin/seat/valknut-load.sh --install. A merge pulls new agents, skills and Pi
# extensions into the tree; the harnesses load them from their OWN homes, so the
# bind must run or a merged fix stays invisible to the running session.
set -u
[ -x "$main_root/bin/seat/valknut-load.sh" ] && "$main_root/bin/seat/valknut-load.sh" --all --global >/dev/null 2>&1 || true
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
# opencode.json and .pi/mcp-adapter.json must contain ABSOLUTE paths, so they cannot be
# tracked — a tracked copy would hand every operator the previous one's home.
# They are rendered from the shipped *.example with the real $HOME and root.
#
# TWO WRITERS touch opencode.json: this loader, and `bin/fleet/agents-config.sh apply`
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
  # PRUNE DEAD ROOTS. Measured 2026-10-04: `.ymir-root` carried FOUR roots and TWO of them were
  # `.yggdrasil/` worktrees that no longer exist. Every resolver that reads this file asks "the
  # first recorded root that really holds bin/pi/syn-watch-arm.sh", so a worktree that survives here
  # after it is deleted from disk will eventually be picked — and every door an extension calls
  # through it fails at 127. This list is a cache of places that USED to be real; a cache of dead
  # places is worse than no cache.
  if [ -r "$pointer" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      [ "$line" = "$ROOT" ] && continue
      grep -qxF -- "$line" "$tmp" 2>/dev/null && continue
      # keep a root only while it still IS a root
      [ -x "$line/bin/pi/syn-watch-arm.sh" ] || continue
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

# The first recorded root that really holds bin/pi/syn-watch-arm.sh, or nothing.
ymir_root_verified() {
  local pointer="$PI_EXT_HOME/.ymir-root" line
  [ -r "$pointer" ] || return 0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ -x "$line/bin/pi/syn-watch-arm.sh" ] && { printf '%s' "$line"; return 0; }
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
    add pi-ext-root "$PI_EXT_HOME/.ymir-root" "ERROR no recorded root holds bin/pi/syn-watch-arm.sh — deployed extensions cannot find their bin/ (run: bin/seat/valknut-load.sh --pi)"
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
  add pi-mcp "$ROOT/.pi/mcp-adapter.json" "$(config_out "$ROOT/.pi/mcp-adapter.json.example" "$ROOT/.pi/mcp-adapter.json")"
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
    # The source is ONE tree (Rule 13): top-level single-file extensions, plus one
    # directory per multi-file extension (pi loads a subdirectory only when it has
    # an index.ts), plus lib/ for what is genuinely shared. The deploy MIRRORS that
    # tree — copying the top-level files alone ships extensions that cannot load,
    # which is exactly the "Cannot find module ./lib/..." pi reported.
    #
    # Tests never deploy. A *.test.ts is not a discoverable entry point, so it is
    # harmless in the live tree — but it would be copied on every run and then read
    # as part of the shipped extension set. The repo keeps its tests; the deploy
    # does not.
    deploy_ext_tree() {
      local src="$1" dst="$2" rel f b
      for f in "$src"/*; do
        [ -e "$f" ] || continue
        b=$(basename "$f")
        if [ -d "$f" ]; then
          [ "$b" = "node_modules" ] && continue
          mkdir -p "$dst/$b" 2>/dev/null
          deploy_ext_tree "$f" "$dst/$b" && true
          continue
        fi
        case "$b" in
          *.test.ts|*.test.js|*.test.mjs|*.spec.ts|*.spec.js) continue ;;
        esac
        rel="${f#$src/}"
        mkdir -p "$(dirname "$dst/$rel")" 2>/dev/null
        if [ -f "$dst/$rel" ] && cmp -s "$f" "$dst/$rel"; then continue; fi
        cp -f "$f" "$dst/$rel" && dep_n=$((dep_n+1))
      done
    }
    deploy_ext_tree "$PI_EXT_SRC" "$PI_EXT_HOME"

    # PRUNE. A deploy only ever ADDS, so a restructure leaves the old file beside
    # the new directory — and that is the collision Rule 13 §1 exists to prevent:
    # `ro.ts` and `ro/index.ts` both load, both register Ro's tools, and pi exits
    # with a tool-name conflict so no agent can be seated.
    #
    # The rule is EXACT: remove a deployed file only when the source has no file
    # at the same relative path. An earlier version of this block removed
    # everything not named `.ymir-root` and wiped the live tree — 43 files — which
    # is what a prune must never do.
    pruned=0
    for stale in "$PI_EXT_HOME"/*.ts "$PI_EXT_HOME"/*.js "$PI_EXT_HOME"/*.mjs; do
      [ -e "$stale" ] || continue
      b=$(basename "$stale")
      [ -e "$PI_EXT_SRC/$b" ] || { rm -f "$stale" && pruned=$((pruned+1)); }
    done
    if [ -d "$PI_EXT_HOME/lib" ]; then
      for stale in "$PI_EXT_HOME"/lib/*; do
        [ -e "$stale" ] || continue
        b=$(basename "$stale")
        [ -e "$PI_EXT_SRC/lib/$b" ] || { rm -f "$stale" && pruned=$((pruned+1)); }
      done
    fi
    for d in "$PI_EXT_HOME"/*/; do
      [ -d "$d" ] || continue
      b=$(basename "$d")
      [ -d "$PI_EXT_SRC/$b" ] || { rm -rf "$d" && pruned=$((pruned+1)); }
    done
    [ "$pruned" -gt 0 ] && add pi-ext-prune "$PI_EXT_HOME" "$pruned removed (source no longer has them — a leftover would double-register)"
    add pi-extensions "$PI_EXT_HOME" "$dep_n deployed (one tree mirrored: files, extension folders, lib)"
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
printf 'help[1]: run `bin/seat/valknut-load.sh --status` to inspect bindings\n'
