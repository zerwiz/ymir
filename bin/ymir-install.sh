#!/usr/bin/env bash
# ymir-install.sh — THE FIRST SETUP. Stand the full Ymir up for the operator:
# prerequisites, the single-tenant workspace tree, the OSS engines (treehouse /
# sandcastle / no-mistakes), the sandbox image, the well (engram) + harness MCP,
# the loaders, the registries, and the runtime services. Idempotent. Galdr TOON.
#
# Usage:
#   bin/ymir-install.sh [--check] [--skip-engines] [--skip-services] [--no-desktop] [--yes]
#   bin/ymir-install.sh --plan [--json]     # the plan, computed — changes nothing
#   bin/ymir-install.sh --yes | --non-interactive | --accept-all-defaults
#   bin/ymir-install.sh --status
#   bin/ymir-install.sh --version
#
# The consent a real install asks for is not a recited paragraph: it is the PLAN
# printed by bin/ymir-plan.sh — probed on THIS host, one row per step, each with
# its state and the reason for it. A paragraph drifts behind the code; a plan is
# computed from it every run.
#
# Exit: 0 all good (or --check/--plan), 1 a step failed, 2 usage, 3 declined.
set -u

# --- portability shim: bin/ymir-platform.sh --------------------------------
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  _ymir_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  for _ymir_c in "$_ymir_dir/ymir-platform.sh" "$(dirname "$_ymir_dir")/bin/ymir-platform.sh"; do
    [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_dir _ymir_c
fi

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The operator's settings and secrets live in the home they chose, never in the
# code tree — a packaged install replaces its tree on upgrade, and a credential
# must never sit in a tree that ships (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_local_env YMIR_ENV_FILE
# The home is the OPERATOR's to choose, never ours to assume. Resolution:
# $YMIR_HOME (explicit) → the choice recorded at a previous installation →
# the one documented default. An interactive run ASKS and RECORDS the answer
# (step_home); --check never writes, --yes takes what is recorded.
# The hoard resolves through the shared lib, so the installer can never disagree
# with bin/hodd.sh about where private data lives — and never points inside the
# repo (Rule 04).
# shellcheck source=bin/hoard-lib.sh
. "$SCRIPT_DIR/hoard-lib.sh"
# shellcheck source=bin/app-lib.sh
. "$SCRIPT_DIR/app-lib.sh"
ymir_home_root YMIR_HOME
# Where the smithy's parts live: apps/smidja-factory in a clone, or the
# @zerwiz/smidja-factory package in an npm install (bin/smidja-lib.sh).
if [ -z "${YMIR_SMIDJA_LIB_LOADED:-}" ]; then
  _ys="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_ys/smidja-lib.sh" "$(dirname "$_ys")/bin/smidja-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_SMIDJA_LIB_LOADED=1; break; }
  done
  unset _ys _yc
fi
smidja_visualizer_dir SMIDJA_VIZ
smidja_factory_dir SMIDJA_FACTORY

WORKSPACE="${YMIR_WORKSPACE:-$YMIR_HOME/workspaces}"
hoard_root HOARD
DOMAINS="company marketing development life me"

CHECK=0; SKIP_ENGINES=0; SKIP_SERVICES=0; ASSUME_YES=0; NO_DESKTOP=0; PLAN_ONLY=0; PLAN_ARGS=()
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --plan|--dry-run) PLAN_ONLY=1; shift ;;
    --json|--blocked) PLAN_ARGS+=("$1"); shift ;;
    --phase) PLAN_ARGS+=("$1" "${2-}"); shift 2 ;;   # --phase carries its number
    --skip-engines) SKIP_ENGINES=1; shift ;;
    --skip-services) SKIP_SERVICES=1; shift ;;
    --no-desktop) NO_DESKTOP=1; shift ;;
    --yes|-y|--non-interactive|--accept-all-defaults) ASSUME_YES=1; shift ;;
    --status) exec "$SCRIPT_DIR/ymir-install.sh" --check ;;
    *) printf 'error: unknown flag %s\nhelp: bin/ymir-install.sh [--check|--plan|--skip-engines|--skip-services|--no-desktop|--yes]\n' "$1" >&2; exit 2 ;;
  esac
done

# The plan is a question, not a change: it prints and exits without writing.
if [ "$PLAN_ONLY" = 1 ]; then
  exec "$SCRIPT_DIR/ymir-plan.sh" ${PLAN_ARGS[@]+"${PLAN_ARGS[@]}"}
fi

# The cloth (bin/ymir-style.sh): colour, marks and spacing for the human, while
# every row of data stays TOON on stdout.
. "$SCRIPT_DIR/ymir-style.sh"
style_init

declare -a IDS STATUS DETAIL
# The code minted for this install, reported at the end so it is not lost in the
# step table. Empty on --check, and when no code could be minted.
INVITE_CODE=""
add() { IDS+=("$1"); STATUS+=("$2"); DETAIL+=("$3"); }
have() { command -v "$1" >/dev/null 2>&1; }
TOON="install[0]{step,status,detail}:"

# ── consent ──────────────────────────────────────────────────────────────
# Show exactly what will change and require explicit acceptance. A real
# install touches the machine (packages, a docker image, raised services),
# so it never proceeds on silence. The plan is COMPUTED here (bin/ymir-plan.sh
# probes this host) — never a paragraph that can drift behind the code.
confirm_install() {
  [ "$ASSUME_YES" = 1 ] && return 0
  if [ ! -t 0 ]; then
    printf 'error: refusing a non-interactive install without --yes\nhelp: re-run with --yes to accept non-interactively, or --plan / --check to preview\n' >&2
    exit 3
  fi
  style_title "Ymir first setup" "the plan below is probed on this machine, not recited"
  cat <<'PLAN'
Each row is a phase, a step, its state, and why.

  DO        a change will be made
  SKIP      already satisfied — nothing to do
  INFO      a fact about this host; no change implied
  BLOCKED   cannot run — the reason names what is missing
  CONSENT   needs your word (a credential, an invite, the desktop shells)

Nothing is deleted. Every step is idempotent.
PLAN
  printf '\n'
  # The rendering lives on stderr (the cloth); the TOON on stdout is data and is
  # dropped here. Sending BOTH to /dev/null is how the plan became invisible.
  bash "$SCRIPT_DIR/ymir-plan.sh" --colour >/dev/null || true
  printf '\nProceed with the install? [y/N] '
  read -r reply || reply=""
  case "$reply" in
    y|Y|yes|YES) ;;
    *) printf 'install declined — nothing was changed.\n'; exit 3 ;;
  esac
}

# ── 1. prereqs ───────────────────────────────────────────────────────────────
#
# Self-healing: `bin/prereq-ensure.sh` provisions what it can in user space
# (bun, uv, mcp<2) with no sudo. Anything it cannot do is reported with an
# exact command. engram is OPTIONAL and reported honestly, never as a failure.
ENGRAM_PY=""
step_prereqs() {
  if [ "$CHECK" = 0 ] && [ -x "$SCRIPT_DIR/prereq-ensure.sh" ]; then
    "$SCRIPT_DIR/prereq-ensure.sh" bun >/dev/null 2>&1 || true
    "$SCRIPT_DIR/prereq-ensure.sh" uv  >/dev/null 2>&1 || true
    "$SCRIPT_DIR/prereq-ensure.sh" mcp >/dev/null 2>&1 || true
    # bun installs to ~/.bun/bin; adopt it for the rest of this run.
    [ -x "$HOME/.bun/bin/bun" ] && export PATH="$HOME/.bun/bin:$PATH"
    [ -x "$HOME/.local/bin/uv" ] && export PATH="$HOME/.local/bin:$PATH"
  fi
  local miss="" engine
  for c in git python3 bun; do have "$c" || miss="$miss $c"; done
  python3 -c "from mcp.server.fastmcp import FastMCP" >/dev/null 2>&1 || miss="$miss mcp<2"
  # Docker or Podman — whichever this host has; never assume the binary name.
  engine="$(ymir_container_engine_name 2>/dev/null || true)"
  [ -n "$engine" ] || miss="$miss docker/podman"
  have gh || miss="$miss gh"
  if [ -n "$miss" ]; then add prereqs WARN "missing:$miss"; else add prereqs OK "git python3 bun $engine gh mcp<2"; fi
  # The well engine: attempt to provision it rather than leaving a hint. engram
  # needs Python 3.12/3.13, so prereq-ensure installs it into a compatible
  # interpreter and records which one — the bridge then reuses it.
  if [ -x "$SCRIPT_DIR/prereq-ensure.sh" ]; then
    if "$SCRIPT_DIR/prereq-ensure.sh" engram >/dev/null 2>&1; then
      add memory-well OK "engram installed for the engine's Python"
    else
      add memory-well WARN "engram could not be installed — bin/prereq-ensure.sh engram (needs Python 3.12/3.13)"
    fi
  else
    add memory-well SKIP "no prereq-ensure.sh"
  fi
}

# ── 2. workspace tree ────────────────────────────────────────────────────────
step_tree() {
  if [ "$CHECK" = 1 ]; then
    local ok=1
    [ -d "$WORKSPACE/work" ] && [ -d "$WORKSPACE/personal" ] && [ -f "$HOARD/identity/workspaces.yaml" ] && [ -f "$HOARD/identity/projects.yaml" ] || ok=0
    if [ "$ok" = 1 ]; then add tree OK "workspace tree present"; else add tree WARN "workspace tree incomplete"; fi
    return
  fi
  local created=0
  for ws in work:company,marketing,development,life personal:me,life,development; do
    local name="${ws%%:*}" domains="${ws#*:}"
    for d in ${domains//,/ }; do
      [ -d "$WORKSPACE/$name/$d" ] || { mkdir -p "$WORKSPACE/$name/$d"; created=$((created+1)); }
    done
  done
  mkdir -p "$WORKSPACE/companies" "$WORKSPACE/memory/daily" "$HOARD/identity"
  # The hoard is OUTSIDE the repo (Rule 04): this creates its layout at the
  # resolved root, never in the checkout. Idempotent.
  "$SCRIPT_DIR/hodd.sh" init >/dev/null 2>&1 || true
  # A missing platform env makes `bin/hodd.sh emit secrets/platform.env` fail on a
  # fresh machine; seed an empty one (0600) so the reference always resolves.
  if [ ! -f "$HOARD/secrets/platform.env" ]; then
    mkdir -p "$HOARD/secrets"
    ( umask 077; : >"$HOARD/secrets/platform.env" )
    created=$((created+1))
  fi
  if [ ! -f "$HOARD/identity/workspaces.yaml" ]; then
    cat >"$HOARD/identity/workspaces.yaml" <<'YAML'
# Workspace registry — single tenant. One operator, many workspaces.
# kind: work | personal.  company: only for work.  domains: knowledge areas.
# Add a work workspace of your own, e.g.:
#   - id: work
#     name: Work
#     kind: work
#     company: your-company
#     domains: [company, development]
workspaces:
  - id: personal
    name: Personal
    kind: personal
    domains: [me, life, development]
YAML
    created=$((created+1))
  fi
  if [ ! -f "$HOARD/identity/projects.yaml" ]; then
    cat >"$HOARD/identity/projects.yaml" <<'YAML'
# Master project registry. Every project carries its GitHub block here; the
# runtime reads it — never guesses a remote. auth is a REFERENCE, never a value.
# Register your own projects, e.g.:
#   - id: my-project
#     name: My Project
#     workspace: personal
#     domains: [development]
#     repo: projects/my-project
#     posture: local-only
#     git: { host: github.com, owner: <you>, repo: my-project, remote: origin, default_branch: main, auth: gh }
projects: []
YAML
    created=$((created+1))
  fi
  add tree OK "workspace/{personal} · companies · registries · hoard (outside the repo) (created $created)"
}

# ── 2a. the home the operator chooses ────────────────────────────────────────
# Everything private — docs, secrets, identity, projects, workspaces, memory —
# lives in ONE place the operator owns, and it is the operator's to name. A real
# interactive run asks once and records the answer under ~/.config/ymir/home, so
# every later script resolves the same home without being told again. --check
# never writes; --yes takes what is already recorded (or the documented default).
step_home() {
  local rec="" chosen=""
  ymir_home_record rec
  if [ -n "${YMIR_HOME:-}" ] && [ "$CHECK" = 1 ]; then add home OK "home: $YMIR_HOME"; return; fi
  if [ -n "$rec" ]; then
    add home OK "home: $YMIR_HOME (the choice recorded at installation)"
    return
  fi
  if [ "$ASSUME_YES" = 1 ] || [ ! -t 0 ]; then
    if ymir_home_record_set "$YMIR_HOME" 2>/dev/null; then
      add home OK "home: $YMIR_HOME (default recorded — change it any time with YMIR_HOME=<path> bin/ymir-install.sh)"
    else
      add home WARN "home: $YMIR_HOME (could not record the choice under $YMIR_CONFIG_DIR — pass YMIR_HOME=<path> to every run)"
    fi
    return
  fi
  printf '\nWhere shall your home live?\n'
  printf 'Everything private is kept there — docs, secrets, identity, projects,\n'
  printf 'workspaces, memory — never in the code tree, never in this package.\n'
  printf 'Home [%s]: ' "$YMIR_HOME"
  IFS= read -r chosen || true
  [ -n "$chosen" ] && YMIR_HOME="${chosen/#\~/$HOME}"
  if [ -e "$YMIR_HOME" ]; then
    printf 'using %s — what is already there is kept; nothing is deleted.\n' "$YMIR_HOME"
  fi
  # Re-resolve the roots the choice moved: the hoard within the home, and the
  # workspace tree beneath it. A second run finds the record and never asks again.
  hoard_root HOARD
  WORKSPACE="${YMIR_WORKSPACE:-$YMIR_HOME/workspaces}"
  if ymir_home_record_set "$YMIR_HOME"; then
    add home OK "home: $YMIR_HOME (recorded — later runs need not ask)"
  else
    add home WARN "home: $YMIR_HOME (could not record the choice; pass YMIR_HOME=<path> to every run)"
  fi
}

# ── 2b. app repos (the app split) ────────────────────────────────────────────
# The apps live in their OWN repos (zerwiz/hlidskjalf · hlidskjalf-mobile ·
# odrerir · sessrumnir · smidja), registered in the home registry with a
# `repo: apps/<path>` block. The monorepo never tracks them; installation
# clones each into the tree — never guessing a remote, always reading the
# registry. A present repo is fast-forwarded; a missing one cloned. The smithy
# engine (apps/smidja) is stamped from the cloned factory's templates, exactly
# as install.py does for a target repo.
step_apps() {
  # A packaged install has no apps/ of its own on purpose: the surfaces arrive as
  # dependencies. Cloning the repos into node_modules/@zerwiz/ymir/apps/ is how a
  # hollow directory shadowed a real package, so a package tree clones nothing.
  # A CLONE still clones — that is the shape this step exists for.
  case "$ROOT" in
    */node_modules/*)
      add apps SKIP "a package install — the surfaces are dependencies (npm i -g @zerwiz/ymir)"
      return 0 ;;
  esac
  local reg="$HOARD/identity/projects.yaml"
  if [ ! -r "$reg" ]; then
    add apps SKIP "no registry — no app repos to pull ($reg)"
    return 0
  fi
  # Parse blocks that carry `repo: apps/<path>` and a `git:` inline dict.
  local entries
  entries=$(awk '
    /^  - id:/ { repo="" }
    /^    repo: apps\// { repo=substr($2, 6) }
    /^    git: / {
      line=$0; host=""; owner=""; grepo=""
      if (match(line, /host: [A-Za-z0-9._-]+/)) host=substr(line, RSTART+6, RLENGTH-6)
      if (match(line, /owner: [A-Za-z0-9_-]+/)) owner=substr(line, RSTART+7, RLENGTH-7)
      if (match(line, /repo: [A-Za-z0-9._-]+/)) grepo=substr(line, RSTART+6, RLENGTH-6)
      if (repo != "" && owner != "" && grepo != "") print repo "|" host "|" owner "|" grepo
      repo=""
    }' "$reg")
  if [ -z "$entries" ]; then
    add apps OK "no apps/ projects registered — nothing to pull"
    return 0
  fi
  local ok=0 skip=0 fail=0 missing=0
  while IFS='|' read -r rel host owner grepo; do
    [ -n "$rel" ] || continue
    local path="$ROOT/apps/$rel"
    if [ "$CHECK" = 1 ]; then
      if [ -d "$path/.git" ]; then add apps OK "$rel present ($owner/$grepo)"; ok=$((ok+1));
      elif [ -d "$path" ]; then add apps WARN "$rel present but not a git clone — re-install to replace"; skip=$((skip+1));
      else add apps WARN "$rel absent — a full run clones $owner/$grepo"; missing=$((missing+1)); fi
      continue
    fi
    if [ -d "$path/.git" ]; then
      if (cd "$path" && git fetch origin 2>/dev/null && git merge --ff-only origin/main >/dev/null 2>&1); then add apps OK "$rel up to date ($owner/$grepo)"; ok=$((ok+1));
      else add apps OK "$rel present ($owner/$grepo; pull refused — local changes?)"; skip=$((skip+1)); fi
    elif [ -d "$path" ]; then
      add apps WARN "$rel present but not a git clone — move $path aside and re-run"; skip=$((skip+1))
    else
      local url="https://github.com/$owner/$grepo.git"
      if git clone -q "$url" "$path" 2>/dev/null; then add apps OK "$rel cloned ($owner/$grepo)"; ok=$((ok+1));
      else add apps WARN "$rel clone failed — run: git clone $url $path"; fail=$((fail+1)); fi
    fi
  done <<< "$entries"
  # The smithy engine: apps/smidja is stamped from the cloned factory's
  # templates (the monorepo tracks neither). The config template follows.
  local factory="$ROOT/apps/smidja-factory" eng="$ROOT/apps/smidja"
  if [ "$CHECK" = 0 ] && [ -d "$factory/templates/smidja" ] && [ ! -e "$eng/smidja_modules" ]; then
    mkdir -p "$eng"
    cp -rn "$factory/templates/smidja/." "$eng/" 2>/dev/null
    [ -f "$factory/templates/smidja.config.yaml" ] && { mkdir -p "$eng/smidja_smidja_config"; cp -n "$factory/templates/smidja.config.yaml" "$eng/smidja_smidja_config/smidja.config.yaml" 2>/dev/null; }
    add apps OK "smidja engine stamped into apps/smidja"
  fi
  if [ "$fail" -gt 0 ]; then add apps WARN "$fail app clone(s) failed (offline?)"; fi
}

# ── 3. engines ───────────────────────────────────────────────────────────────
step_engines() {
  [ "$SKIP_ENGINES" = 1 ] && { add engines SKIP "--skip-engines"; return; }
  if [ "$CHECK" = 1 ]; then
    local has=""
    have treehouse && has="$has treehouse"
    have no-mistakes && has="$has no-mistakes"
    { [ -d "$ROOT/node_modules/@ai-hero/sandcastle" ] || have sandcastle; } && has="$has sandcastle"
    if [ -n "$has" ]; then add engines OK "present:$has"; else add engines WARN "none present"; fi
    return
  fi
  local got=""
  if have treehouse; then got="$got treehouse"; else
    if curl -fsSL https://kunchenguid.github.io/treehouse/install.sh 2>/dev/null | sh >/dev/null 2>&1 && have treehouse; then got="$got treehouse"; fi
  fi
  if have no-mistakes; then got="$got no-mistakes"; else
    if curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh 2>/dev/null | sh >/dev/null 2>&1 && have no-mistakes; then got="$got no-mistakes"; fi
  fi
  if [ -d "$ROOT/node_modules/@ai-hero/sandcastle" ] || have sandcastle; then got="$got sandcastle"; fi
  if [ -z "$got" ]; then add engines WARN "none installed (offline?) — install manually"; else add engines OK "installed:$got"; fi
}

# ── 3a2. the Pi agent + local models ────────────────────────────────────────
# Ensure pi and the Pi packages Ymir needs (pi-mcp-adapter, pi-web-access,
# pi-lmstudio — Pi has no native MCP/web/local-model support), detect the LOCAL
# model runtimes actually here (never assume llama.cpp), and seed
# ~/.pi/agent/models.json only when the operator has none.
step_models() {
  [ "$SKIP_ENGINES" = 1 ] && { add models SKIP "--skip-engines"; return; }
  if [ "$CHECK" = 1 ]; then add models OK "would ensure pi + packages and detect local models"; return; fi
  if [ -x "$SCRIPT_DIR/pi-ensure.sh" ]; then
    if "$SCRIPT_DIR/pi-ensure.sh" ensure --install >/dev/null 2>&1; then add models OK "pi + packages present";
    else add models WARN "pi or a Pi package missing — run bin/pi-ensure.sh install"; fi
  else
    add models SKIP "no pi-ensure.sh"
  fi
  if [ -x "$SCRIPT_DIR/models-detect.sh" ]; then
    local detected
    detected="$("$SCRIPT_DIR/models-detect.sh" --json 2>/dev/null | python3 -c 'import json,sys;print(",".join(json.load(sys.stdin).get("providers",{}).keys()))' 2>/dev/null)"
    add models OK "local runtimes: ${detected:-none}"
    if [ ! -f "$HOME/.pi/agent/models.json" ]; then
      "$SCRIPT_DIR/models-detect.sh" --write >/dev/null 2>&1 && add models OK "seeded ~/.pi/agent/models.json (was absent)"
    fi
  fi
  if [ -x "$SCRIPT_DIR/model-hardware.sh" ]; then
    "$SCRIPT_DIR/model-hardware.sh" >/dev/null 2>&1 && add models OK "profiled this machine (data/local-models.md; online research left for Brokk)"
  fi
}

# ── 3b. hermes runtime ───────────────────────────────────────────────────────
step_hermes() {
  [ "$SKIP_ENGINES" = 1 ] && { add hermes SKIP "--skip-engines"; return; }
  if [ -x "$SCRIPT_DIR/hermes-ensure.sh" ]; then
    if [ "$CHECK" = 1 ]; then
      if "$SCRIPT_DIR/hermes-ensure.sh" status >/dev/null 2>&1; then add hermes OK "present"; else add hermes WARN "absent"; fi
    else
      if "$SCRIPT_DIR/hermes-ensure.sh" ensure --install >/dev/null 2>&1; then add hermes OK "present"; else add hermes WARN "not installed (run bin/hermes-ensure.sh install)"; fi
    fi
  else add hermes SKIP "no hermes-ensure.sh"; fi
}

# ── 3b2. Sessrúmnir desktop GUI ──────────────────────────────────────────────
# The seat-hall: a vendored, re-themed fork of pi-desktop (Apache-2.0) at
# apps/sessrumnir. Deps are never committed; the ensure step installs them on
# first run, exactly as scripts/electron.sh does for the other desktop apps.
step_sessrumnir() {
  [ "$SKIP_ENGINES" = 1 ] && { add sessrumnir SKIP "--skip-engines"; return; }
  if [ -x "$SCRIPT_DIR/sessrumnir-ensure.sh" ]; then
    if [ "$CHECK" = 1 ]; then
      if "$SCRIPT_DIR/sessrumnir-ensure.sh" status >/dev/null 2>&1; then add sessrumnir OK "ready"; else add sessrumnir WARN "not ready (run bin/sessrumnir-ensure.sh install)"; fi
    else
      if "$SCRIPT_DIR/sessrumnir-ensure.sh" ensure --install >/dev/null 2>&1; then add sessrumnir OK "ready"; else add sessrumnir WARN "not ready — run bin/sessrumnir-ensure.sh install"; fi
    fi
  else add sessrumnir SKIP "no sessrumnir-ensure.sh"; fi
}

# ── 3c. Þjazi backend (herdr-first) ──────────────────────────────────────────
# Ymir spawns agents into terminal panes, so a backend must exist. herdr is
# preferred (protocol 14+, presentation spaces at 0.8.0+); tmux is an accepted
# reference backend. Never a silent fallback — a missing backend is reported.
step_backend() {
  if [ ! -x "$SCRIPT_DIR/herdr-ensure.sh" ]; then add backend SKIP "no herdr-ensure.sh"; return; fi
  if [ "$CHECK" = 1 ]; then
    if out="$("$SCRIPT_DIR/herdr-ensure.sh" status 2>&1)"; then
      local b; b="$(printf '%s' "$out" | grep -oE '"(herdr|tmux|none)"' | head -1 | tr -d '"')"
      add backend OK "$b"
    else
      add backend WARN "no terminal backend (install herdr or tmux)"
    fi
  else
    if "$SCRIPT_DIR/herdr-ensure.sh" ensure --install >/dev/null 2>&1; then
      local b; b="$( "$SCRIPT_DIR/herdr-ensure.sh" status 2>&1 | grep -oE '"(herdr|tmux|none)"' | head -1 | tr -d '"' )"
      add backend OK "$b"
    else
      add backend WARN "no terminal backend — install herdr or tmux"
    fi
  fi
}

# ── 3d. host integration ─────────────────────────────────────────────────
# Learn the machine and place the desktop apps on EVERY host; the Omarchy-specific
# extras (the post-update hook) apply only when Omarchy is present. A non-Omarchy
# host still gets host learning and desktop placement — this is not a bonus for
# Omarchy, it is part of a normal install.
# ── 3b. the Omarchy installation layer (Rule 05) ─────────────────────────────
# Ymir is Omarchy-first: the desktop integration is a LAYER beside the portable
# core, and it owns its own installer. The core calls it here and reports one
# line; everything inside is the layer's business.
step_omarchy() {
  if [ ! -x "$SCRIPT_DIR/omarchy-install.sh" ]; then add omarchy SKIP "no omarchy-install.sh"; return 0; fi
  if [ "$CHECK" = 1 ]; then
    "$SCRIPT_DIR/omarchy-install.sh" --check >/dev/null 2>&1
  else
    "$SCRIPT_DIR/omarchy-install.sh" >/dev/null 2>&1
  fi
  rc=$?
  if [ "$rc" = 0 ]; then
    if [ -d /usr/share/omarchy ]; then add omarchy OK "layer applied (sense · hook · plugins · desktops · editor · alarm · backend)"
    else add omarchy SKIP "not an Omarchy host — the core runs without this layer"; fi
  else
    add omarchy WARN "layer reported a failing step — run bin/omarchy-install.sh to see which"
  fi
}

step_host() {
  # Core host learning: sense THIS machine on EVERY host with the portable
  # sensor (Rule 05). The Omarchy-specific RECORDING (omarchy-sense observe), the
  # post-update hook, desktop placement, the plugin offer, and the desktop alarm
  # channel belong to the Omarchy layer and are applied by step_omarchy; nothing
  # here assumes Omarchy.
  local seen="unknown"
  if [ -x "$SCRIPT_DIR/host-sense.sh" ]; then
    # host-sense TOON row 2 is: os, id, family, session, desktop
    local row; row="$("$SCRIPT_DIR/host-sense.sh" 2>/dev/null | sed -n '2p')"
    [ -n "$row" ] && seen="$(printf '%s' "$row" | sed -E 's/^[[:space:]]*"//; s/"[[:space:]]*$//; s/","/ \/ /g')"
  fi
  add host OK "host sensed: ${seen}"

  # The operator's own agent setup, seeded from the tracked template into the
  # home's settings dir — settings are the operator's, never the package's.
  # Idempotent: the seeded file is private and is never overwritten once set.
  # --check writes nothing, so it only reports. The template is code, so it is
  # read from wherever the tree keeps it: `config/` in a clone (a symlink the
  # npm tarball cannot carry), else `.agents/config/`.
  if [ -e "$YMIR_SETTINGS_DIR/agents.yaml" ]; then
    add agents-config OK "kept (private, never overwritten)"
    return 0
  fi
  local tpl="$ROOT/config/agents.yaml.example"
  [ -r "$tpl" ] || tpl="$ROOT/.agents/config/agents.yaml.example"
  if [ "$CHECK" = 1 ]; then
    add agents-config WARN "not seeded yet — a real run writes $YMIR_SETTINGS_DIR/agents.yaml"
  elif [ -r "$tpl" ] && mkdir -p "$YMIR_SETTINGS_DIR" && cp "$tpl" "$YMIR_SETTINGS_DIR/agents.yaml" 2>/dev/null; then
    add agents-config OK "seeded $YMIR_SETTINGS_DIR/agents.yaml from the template"
  else
    add agents-config WARN "could not seed $YMIR_SETTINGS_DIR/agents.yaml"
  fi
}

# ── 4. sandbox image ─────────────────────────────────────────────────────────
step_sandbox() {
  local engine; engine="$(ymir_container_engine_name 2>/dev/null || true)"
  if [ -z "$engine" ]; then add sandbox SKIP "no container engine (docker/podman)"; return; fi
  if "$engine" image inspect utgard-runner:latest >/dev/null 2>&1; then
    add sandbox OK "utgard-runner:latest present ($engine)"
  elif [ "$CHECK" = 1 ]; then
    add sandbox WARN "utgard-runner:latest missing (run without --check)"
  else
    # Distinguish "engine not reachable" from "build failed" so the operator gets
    # an actionable message instead of a blanket failure.
    if ! "$engine" info >/dev/null 2>&1; then
      local who; who="$(id -un)"
      if ymir_engine_is_podman 2>/dev/null; then
        add sandbox WARN "rootless podman unreachable — ensure a login session (loginctl enable-linger) and XDG_RUNTIME_DIR are set"
      elif id -nG "$who" 2>/dev/null | grep -qw docker; then
        add sandbox WARN "docker daemon unreachable — log out and back in so the docker group applies"
      else
        add sandbox WARN "docker permission denied — add $who to the docker group, then re-login"
      fi
      return
    fi
    if "$SCRIPT_DIR/utgard.sh" build >/dev/null 2>&1; then add sandbox OK "utgard-runner:latest built ($engine)"; else add sandbox WARN "image build failed (see $engine)"; fi
  fi
}

# ── 5. memory (well + harness MCP) ───────────────────────────────────────────
step_memory() {
  local db="$YMIR_HOME/memory/kaia.engram" mcp=0
  [ "$CHECK" = 0 ] && "$SCRIPT_DIR/mimir-bridge.sh" --start >/dev/null 2>&1 || true
  for f in "$ROOT/opencode.json" "$HOME/.config/opencode/opencode.json" "$HOME/.pi/agent/settings.json" "$HOME/.claude.json" "$HOME/.cursor/mcp.json"; do
    [ -f "$f" ] && grep -q '"engram"' "$f" 2>/dev/null && mcp=$((mcp+1))
  done
  local store="absent"; [ -f "$db" ] && store="present"
  add memory OK "engram store $store · MCP in $mcp harness configs"
}

# ── 5b. smidja db (visualizer readiness) ─────────────────────────────
step_smidja() {
  if [ -x "$SCRIPT_DIR/smidja-bootstrap.sh" ]; then
    if [ "$CHECK" = 1 ]; then
      local dbok vizok
      [ -f "$YMIR_HOME/smidja/smidja.db" ] && dbok=present || dbok=missing
      [ -n "${SMIDJA_VIZ:-}" ] && [ -d "$SMIDJA_VIZ/dist" ] && vizok=built || vizok=unbuilt
      if [ "$dbok" = missing ]; then
        add smidja WARN "smidja.db missing — a full run (without --check) creates it and seeds one bootstrap session"
      else
        add smidja OK "smidja.db $dbok · visualizer UI $vizok"
      fi
    elif ! have uv; then
      # The bootstrap creates the schema through the tracer, run under uv so the
      # smidja deps resolve without a system install.
      add smidja WARN "needs uv — bin/prereq-ensure.sh uv (the visualizer stays empty without it)"
    else
      if "$SCRIPT_DIR/smidja-bootstrap.sh" >/dev/null 2>&1; then add smidja OK "smidja.db ready (visualizer has data)"; else add smidja WARN "could not bootstrap smidja.db — run bin/smidja-bootstrap.sh to see why"; fi
    fi
  else add smidja SKIP "no smidja-bootstrap.sh"; fi
  # The visualizer API serves its UI from ./dist — without a build it answers
  # the API but shows "No ./dist build found". Build it once when absent.
  local viz="${SMIDJA_VIZ:-}"; [ -n "$viz" ] || return 0
  [ -d "$viz" ] || return 0
  if [ -d "$viz/dist" ]; then
    add visualizer OK "UI built (served on :8437)"
  elif [ "$CHECK" = 1 ]; then
    add visualizer WARN "UI not built (run without --check)"
  elif command -v bun >/dev/null 2>&1; then
    if [ ! -d "$viz/node_modules" ] && ! (cd "$viz" && bun install >/dev/null 2>&1); then
      add visualizer WARN "bun install failed — (cd $viz && bun install)"
    elif (cd "$viz" && bun run build >/dev/null 2>&1); then
      add visualizer OK "UI built (served on :8437)"
    else
      add visualizer WARN "UI build failed — (cd $viz && bun run build)"
    fi
  else
    add visualizer WARN "no bun — cannot build the visualizer UI"
  fi
}

# ── 5c. the SPA ──────────────────────────────────────────────────────────────
# Hlidskjalf installs with npm (its own lockfile), not bun, and its API serves the
# UI from ./dist. Without this step a fresh clone has no SPA and no build.
step_spa() {
  local app; app_dir hlidskjalf app || app=""
  local app_ok="$app"
  [ -d "$app" ] || { add hlidskjalf SKIP "no apps/hlidskjalf"; return 0; }
  if [ "$CHECK" = 0 ]; then
    if ! have npm; then
      add hlidskjalf WARN "no npm — cannot install the SPA"; return 0
    fi
    if [ ! -d "$app/node_modules" ] && ! (cd "$app" && npm install --no-audit --no-fund >/dev/null 2>&1); then
      add hlidskjalf WARN "npm install failed — (cd $app && npm install --no-audit --no-fund)"; return 0
    fi
    if [ ! -d "$app/dist" ] && ! (cd "$app" && npm run build >/dev/null 2>&1); then
      add hlidskjalf WARN "installed, build failed — (cd $app && npm run build)"; return 0
    fi
  fi
  if [ ! -d "$app/node_modules" ] || [ ! -d "$app/dist" ]; then
    add hlidskjalf WARN "not installed (run without --check)"; return 0
  fi
  # Electron's runtime comes from a gated postinstall. package.json pins the
  # approval, but verify the binary so the desktop shell never fails silently.
  if [ -x "$app/node_modules/electron/dist/electron" ] || [ ! -d "$app/electron" ]; then
    add hlidskjalf OK "installed + built + electron (served on :3888)"
  else
    add hlidskjalf WARN "installed + built, but electron has no binary — npm rebuild electron"
  fi
}

# ── 6. loaders ───────────────────────────────────────────────────────────────
step_loaders() {
  if [ -x "$SCRIPT_DIR/valknut-load.sh" ]; then
    if [ "$CHECK" = 1 ]; then add loaders OK "valknut-load.sh present"; else
      "$SCRIPT_DIR/valknut-load.sh" >/dev/null 2>&1 && add loaders OK "agents/skills loaded" || add loaders WARN "loader reported errors"
    fi
  else add loaders SKIP "no valknut-load.sh"; fi
}

# ── 6b. delivery gates (git hooks) ───────────────────────────────────────────
#
# Rule 08: work leaves by PR, and every push carries a CHANGELOG entry. The
# guards live in bin/ (branch-guard, changelog-guard, secret-guard) but git
# only reads .git/hooks, so the install seats them there — the gate is live
# from the first commit of a fresh clone. Idempotent: each --install rewrites
# its own hook.
step_gates() {
  local hooks="$ROOT/.git/hooks" pre_commit="$ROOT/.git/hooks/pre-commit" pre_push="$ROOT/.git/hooks/pre-push"
  if [ ! -d "$hooks" ]; then add gates SKIP "not a git checkout"; return; fi
  if [ "$CHECK" = 1 ]; then
    if [ -x "$pre_commit" ] && [ -x "$pre_push" ]; then
      add gates OK "pre-commit + pre-push installed"
    else
      add gates WARN "hooks not installed — bin/secret-guard.sh --install && bin/changelog-guard.sh --install"
    fi
    # The home repo is where the private data lives, so its ward matters more
    # than this repo's four. Report it separately so a dormant vault is visible.
    local hh; hh="${YMIR_HOME:-$HOME/Documents/Ymir}/.git/hooks/pre-commit"
    if [ -x "$hh" ]; then add hoard-gate OK "home pre-commit seated";
    else add hoard-gate WARN "home hooks not installed — bin/hoard-guard.sh --install"; fi
    return
  fi
  [ -x "$SCRIPT_DIR/secret-guard.sh" ] && "$SCRIPT_DIR/secret-guard.sh" --install >/dev/null 2>&1 || true
  [ -x "$SCRIPT_DIR/changelog-guard.sh" ] && "$SCRIPT_DIR/changelog-guard.sh" --install >/dev/null 2>&1 || true
  # Seat the ward on the PRIVATE home too — every install layer, every machine.
  [ -x "$SCRIPT_DIR/hoard-guard.sh" ] && "$SCRIPT_DIR/hoard-guard.sh" --install >/dev/null 2>&1 || true
  if [ -x "$pre_commit" ] && [ -x "$pre_push" ]; then add gates OK "pre-commit + pre-push installed"
  else add gates WARN "could not write .git/hooks — gates are dormant"; fi
  local hh; hh="${YMIR_HOME:-$HOME/Documents/Ymir}/.git/hooks/pre-commit"
  if [ -x "$hh" ]; then add hoard-gate OK "home pre-commit seated";
  else add hoard-gate WARN "home hooks not seated — bin/hoard-guard.sh --install"; fi
}

# ── 6c. desktop marks (the rune, the entry, the contract) ────────────────────
#
# Every app wears its OWN rune in the operator's desktop: the icon into the icon
# theme, the .desktop entry into their applications dir (so every app is
# dockable and pinnable), and the Ymir contract deployed into pi's agent home so
# every session - in ANY folder - loads Brokk. Idempotent, and it writes to the
# operator's real data dir, never a sandbox one.
step_marks() {
  if [ ! -x "$SCRIPT_DIR/design-icon.sh" ]; then add marks SKIP "no design-icon.sh"; return; fi
  if [ "$CHECK" = 1 ]; then
    n=$(ls "$HOME/.local/share"/applications/ymir-*.desktop 2>/dev/null | wc -l | tr -d ' ')
    add marks OK "$n desktop app marks installed"
    return
  fi
  # The apps' own launcher templates land first (the freedesktop half of desktop
  # integration, for ANY Linux desktop), and the rune marks are minted and
  # installed over them — so the themed rune name wins for the surfaces that have
  # one, instead of a template's absolute .png.
  if [ -x "$SCRIPT_DIR/desktop-place.sh" ]; then
    "$SCRIPT_DIR/desktop-place.sh" entries >/dev/null 2>&1 || true
  fi
  "$SCRIPT_DIR/design-icon.sh" mint --all >/dev/null 2>&1 || true
  n=$("$SCRIPT_DIR/design-icon.sh" install 2>/dev/null | grep -c '"ymir-') || n=0
  [ -r "$HOME/.pi/agent/AGENTS.md" ] || [ -d "$HOME/.pi/agent" ] && {
    ln -sfn "$ROOT/AGENTS.md" "$HOME/.pi/agent/AGENTS.md" 2>/dev/null || true
  }
  add marks OK "$n app marks (rune icon + entry) · Ymir contract in the pi agent home"
}

# ── 7. services ──────────────────────────────────────────────────────────────
step_services() {
  [ "$SKIP_SERVICES" = 1 ] && { add services SKIP "--skip-services"; return; }
  if [ "$CHECK" = 1 ]; then
    local up=0
    for p in 3888 3889 4602 4603; do (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null && up=$((up+1)); done
    add services OK "$up/4 ports up (3888/3889/4602/4603)"; return
  fi
  if "$ROOT/scripts/start.sh" >/dev/null 2>&1; then add services OK "runtime raised"; else add services WARN "start.sh reported errors"; fi
}

# ── 7b. desktop (both Electron apps) ──────────────────────────
# The operator should SEE the applications when the install finishes, so we
# raise both desktop shells (Hlidskjalf + Smíðja) as separate processes.
step_desktop() {
  if [ "$NO_DESKTOP" = 1 ]; then add desktop SKIP "--no-desktop"; return; fi
  if [ ! -x "$ROOT/scripts/electron.sh" ]; then add desktop SKIP "no scripts/electron.sh"; return; fi
  if [ "$CHECK" = 1 ]; then add desktop OK "would launch Hlidskjalf + Smíðja"; return; fi
  # A headless host has no display; launching a window would only fail.
  # DISPLAY/WAYLAND_DISPLAY are X11/Wayland variables — macOS has a display and
  # neither of them, so testing only those would wrongly skip every Mac.
  if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && [ "$(ymir_os)" != macos ]; then
    add desktop SKIP "no display (headless) — run scripts/electron.sh start --both"; return
  fi
  # Placement is the Omarchy layer's job and has already run (step_omarchy runs
  # before this step), so here we only launch.
  # Verify the runtime before claiming anything: a skipped Electron postinstall
  # leaves a partial runtime that fails to launch while every build still passes.
  if [ -z "${YMIR_ELECTRON_LIB_LOADED:-}" ] && [ -r "$SCRIPT_DIR/electron-lib.sh" ]; then
    . "$SCRIPT_DIR/electron-lib.sh"; YMIR_ELECTRON_LIB_LOADED=1
  fi
  local shell partial=""
  for shell in hlidskjalf odrerir sessrumnir; do
    local dir d
    app_dir "$shell" dir || continue
    d="$(electron_runtime_state "$dir" 2>/dev/null || true)"
    [ "$d" = partial ] && partial="$partial $shell"
  done
  if [ -n "$partial" ]; then
    add desktop WARN "the Electron runtime is PARTIAL for:$partial — the web surfaces stand; approve and rebuild to launch the shells"
    return 0
  fi
  # One window per surface that is here: the halls are not one app.
  raised=0
  for _v in hlidskjalf smidja odrerir; do
    "$ROOT/scripts/electron.sh" start --view "$_v" >/dev/null 2>&1 && raised=$((raised+1))
  done
  [ -x "$ROOT/bin/sessrumnir.sh" ] && "$ROOT/bin/sessrumnir.sh" start >/dev/null 2>&1 && raised=$((raised+1))
  if [ "$raised" -ge 2 ]; then
    add desktop OK "raised $raised window(s) — Hlidskjalf · Smíðja · Óðrerir · Sessrúmnir"
  else
    add desktop WARN "could not raise the desktop apps — ymir hlidskjalf | smidja | sessrumnir"
  fi
}

# ── 8. register ──────────────────────────────────────────────────────────────
# ── 8b. the way in ────────────────────────────────
# One operator owns the instance; an invite code is how someone *else* is let in
# to try it. Registration stays closed until a live code exists, so the gate is
# never open by accident.
step_invite() {
  if [ "$CHECK" = 1 ]; then add invite OK "would mint an invite code"; return; fi
  if [ ! -x "$ROOT/bin/ymir-invite.sh" ]; then add invite SKIP "bin/ymir-invite.sh not executable"; return; fi
  if ! command -v bun >/dev/null 2>&1; then add invite SKIP "bun missing — no account store"; return; fi
  local out
  if ! out=$(bash "$ROOT/bin/ymir-invite.sh" ensure 2>&1); then add invite WARN "could not mint a code"; return; fi
  INVITE_CODE=$(printf '%s\n' "$out" | sed -n '2p' | tr -d ' "' | cut -d, -f1)
  if [ -n "$INVITE_CODE" ]; then add invite OK "invite ${INVITE_CODE} — share it to let someone register"; else add invite WARN "no code found"; fi
}

# ── 8a. the operator's way in ────────────────────────────────────────────────
# The gate has two doors — a local password (HLIDSKJALF_AUTH) or GitHub sign-in
# (a GitHub OAuth app). Neither is seeded by a checkout, so a fresh instance has
# no way in until the operator sets one. Interactive installs prompt; --yes and
# non-tty leave it to bin/ymir-setup-auth.sh.
step_auth() {
  if [ ! -x "$ROOT/bin/ymir-setup-auth.sh" ]; then add auth SKIP "bin/ymir-setup-auth.sh not executable"; return; fi
  local door
  door=$(bash "$ROOT/bin/ymir-setup-auth.sh" status 2>/dev/null | sed -n '2p' | cut -d, -f1 | tr -d ' "')
  if [ -n "$door" ] && [ "$door" != none ]; then add auth OK "operator credential present ($door)"; return; fi
  if [ "$CHECK" = 1 ]; then add auth WARN "no operator credential — run bin/ymir-setup-auth.sh set|github"; return; fi
  if [ "$ASSUME_YES" = 1 ] || [ ! -t 0 ]; then
    add auth WARN "no operator credential — set one: bin/ymir-setup-auth.sh set (or github)"
    return
  fi
  printf '\nSet the operator credential now? [p]assword / [g]ithub / [s]kip: '
  local choice; IFS= read -r choice || true
  case "${choice:-s}" in
    p|P) bash "$ROOT/bin/ymir-setup-auth.sh" set && add auth OK "operator password set" || add auth WARN "password setup failed" ;;
    g|G) bash "$ROOT/bin/ymir-setup-auth.sh" github && add auth OK "GitHub sign-in configured" || add auth WARN "GitHub setup failed" ;;
    *)   add auth SKIP "left unset — run bin/ymir-setup-auth.sh set|github later" ;;
  esac
}

step_register() {
  if [ "$CHECK" = 1 ]; then add register OK "would write workspace/INSTALL.md"; return; fi
  local out="$WORKSPACE/INSTALL.md"
  {
    printf '# Ymir — first setup\n\n'
    printf 'Provisioned by `bin/ymir-install.sh` at %s.\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '## Workspaces\n\n'; printf -- '- personal\n\n'
    printf '## Engines\n\n- Yggdrasil → treehouse\n- Utgard → sandcastle\n- Mjollnir/Glitnir → no-mistakes\n- Hermes → hermes-agent (worker runtime)\n- Sessrúmnir → pi-desktop (desktop GUI, vendored at apps/sessrumnir)\n\n'
    printf '## Next\n\n1. `gh auth login` (your own GitHub login).\n'
    printf '2. Register your projects and their `git{}` blocks in `hoard/identity/projects.yaml`.\n'
    printf '3. `scripts/start.sh` then open http://127.0.0.1:3888/.\n'
    printf '4. To let someone else try it, share the invite code printed above\n'
    printf '   (or mint another: `bin/ymir-invite.sh mint <n>`). They register at the\n'
    printf '   login screen; `bin/ymir-invite.sh list` shows what is spent.\n'
  } >"$out"
  add register OK "wrote workspace/INSTALL.md"
}

# ── 9. validate ───────────────────────────────────
# Prove the installation actually works: live ports, readable stores, running
# processes. The installer says what it did; this observes the result.
step_validate() {
  if [ ! -x "$SCRIPT_DIR/ymir-validate.sh" ]; then add validate SKIP "no ymir-validate.sh"; return; fi
  if [ "$CHECK" = 1 ]; then add validate OK "would verify the running system"; return; fi
  if out="$("$SCRIPT_DIR/ymir-validate.sh" --quiet 2>&1)"; then
    add validate OK "all required checks pass"
  else
    local nf; nf="$(printf '%s' "$out" | grep -oE '[0-9]+ required check\(s\) failed' | head -1)"
    add validate WARN "${nf:-some checks} failed — run bin/ymir-validate.sh for detail"
  fi
}

# ── 0. herdr panes (visible when inside herdr) ──────────────
# When the Allfather sits within herdr, the install should be SEEN: a pane is
# raised for the run and the steps are executed within it. Outside herdr this is
# a clean fall-through — the same steps, no panes. Nothing here can lose work:
# if a pane cannot be made, the caller runs its command inline.
step_panes() {
  local runner="$SCRIPT_DIR/herdr-run.sh"
  if [ ! -x "$runner" ]; then add panes SKIP "no herdr-run.sh"; return; fi
  if ! "$runner" available >/dev/null 2>&1; then
    add panes SKIP "no herdr session — steps run inline"
    return
  fi
  if [ "$CHECK" = 1 ]; then
    add panes OK "herdr present — steps would run in visible panes"
    return
  fi
  # Keep the panes the run makes, so the Allfather can read them afterwards.
  YMIR_HERDR_KEEP=1 "$runner" run "install" -- bash -c \
    'echo "Ymir first setup begins $(date -u +%H:%M:%SZ)"; echo "the steps follow in this pane"; echo "repo: $PWD"' \
    >/dev/null 2>&1 && add panes OK "run shown in a herdr pane" || add panes WARN "could not raise a herdr pane"
}

# Ask before touching the machine; --check only previews and never asks.
[ "$CHECK" = 0 ] && confirm_install
[ "$CHECK" = 0 ] && style_patience "the halls are being stood up for the first time"

step_panes; step_prereqs; step_home; step_tree; step_apps; step_engines; step_models; step_hermes; step_sessrumnir; step_backend; step_host; step_sandbox; step_memory; step_smidja; step_spa; step_omarchy; step_loaders; step_gates; step_marks
# Migrations MOVE private data — that is a write, and `--check` promises none.
# Only a real run heals the home forward; the preview leaves it untouched.
if [ "$CHECK" = 0 ]; then bin/ymir-migrate.sh apply >/dev/null 2>&1 || true; fi
step_auth; step_invite; step_register
[ "$CHECK" = 0 ] && step_services
[ "$CHECK" = 0 ] && step_desktop
[ "$CHECK" = 0 ] && step_validate

# The panes were raised for the Allfather to read; leave them standing when we
# made them, and close them only when the operator asks (herdr-run close-all).

printf 'install[%d]{step,status,detail}:\n' "${#IDS[@]}"
for i in "${!IDS[@]}"; do printf '  "%s","%s","%s"\n' "${IDS[$i]}" "${STATUS[$i]}" "${DETAIL[$i]}"; done
# The same rows, rendered for the eye (stderr) — the TOON above is the data a
# script reads, this is what a person gets. An install that ends in a raw table
# has no design, and design here is not decoration: it is whether a reader can
# see, at a glance, what stands, what warned, and what was skipped and why.
if [ "${STYLE_ON:-0}" = 1 ]; then
  ok=0; warn=0; skip=0; fail=0
  for s_ in "${STATUS[@]}"; do
    case "$s_" in OK) ok=$((ok+1)) ;; WARN) warn=$((warn+1)) ;; SKIP) skip=$((skip+1)) ;; FAIL) fail=$((fail+1)) ;; esac
  done
  style_rule 56
  if [ "$fail" -gt 0 ]; then
    style_line FAIL "not usable" "$fail step(s) failed — nothing below it can be trusted"
  elif [ "$warn" -gt 0 ]; then
    style_line OK   "it stands" "$ok steps done · $warn warned · $skip skipped"
  else
    style_line OK   "it stands" "$ok steps done · $skip skipped — nothing warned"
  fi
  # the warnings carry the why; they are the rows a person must read
  for i in "${!IDS[@]}"; do
    [ "${STATUS[$i]}" = WARN ] && style_line WARN "${IDS[$i]}" "${DETAIL[$i]}"
    [ "${STATUS[$i]}" = FAIL ] && style_line FAIL "${IDS[$i]}" "${DETAIL[$i]}"
  done
  # and the skips as one line, with their reasons, since they are decisions not faults
  skips=""
  for i in "${!IDS[@]}"; do [ "${STATUS[$i]}" = SKIP ] && skips="$skips ${IDS[$i]}"; done
  [ -n "$skips" ] && style_hint "skipped:$skips — each with its reason in the table above"
fi
printf '\nnext: gh auth login · register your projects in hoard/identity/projects.yaml · open http://127.0.0.1:3888/\n'
[ -n "$INVITE_CODE" ] && printf 'invite: %s — share it to let someone register (bin/ymir-invite.sh list shows what is spent)\n' "$INVITE_CODE"

for s in "${STATUS[@]}"; do [ "$s" = FAIL ] && exit 1; done
exit 0
