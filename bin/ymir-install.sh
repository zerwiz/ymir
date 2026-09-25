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
# The runtime resolver answers for every desktop surface (P1, 2026-09-24); load
# it beside app-lib so the install steps and the verifier speak its language.
if [ -z "${YMIR_ELECTRON_LIB_LOADED:-}" ] && [ -r "$SCRIPT_DIR/electron-lib.sh" ]; then
  . "$SCRIPT_DIR/electron-lib.sh"; YMIR_ELECTRON_LIB_LOADED=1
fi
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
    y|Y|yes|YES)
      # Consent must not be followed by silence: the install is minutes of work, so say
      # how much follows and let each step name itself as it runs.
      printf '\n  proceeding — %s steps. Each names itself as it runs, with its time.\n\n' "${STEP_TOTAL:-19}"
      ;;
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
  # One repo (plan 35): when the surfaces ship IN this tree there is nothing to
  # clone — the resolver's first shape (`<root>/apps/<surface>`) is already true.
  if [ -f "$ROOT/apps/hlidskjalf/package.json" ] && [ -f "$ROOT/apps/odrerir/package.json" ] \
     && [ -f "$ROOT/apps/sessrumnir/package.json" ]; then
    add apps PASS "in-tree — apps/ ships with the package (plan 35)"
    return 0
  fi
  case "$ROOT" in
    */node_modules/*)
      add apps SKIP "a package install — the surfaces are dependencies (npm i -g @zerwiz/ymir)"
      return 0 ;;
  esac
  local reg="$HOARD/identity/projects.yaml"
  if [ ! -r "$reg" ]; then
    # The fork path: no private hoard — fall back to the PUBLIC app map so a
    # fresh clone still pulls the five surfaces (config/app-repos.yaml).
    reg="$ROOT/config/app-repos.yaml"
  fi
  if [ ! -r "$reg" ]; then
    add apps SKIP "no app registry — neither the hoard's projects.yaml nor config/app-repos.yaml"
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
    # The user's OWN models, read from the ROOT pi home — never assumed. A roster can
    # name a model this machine has never seen, and nothing in the report said so.
    if [ -x "$SCRIPT_DIR/models-report.sh" ]; then
      msum="$("$SCRIPT_DIR/models-report.sh" 2>/dev/null)"
      if [ -n "$msum" ]; then
        add models-config OK "the user's models — $msum"
      else
        add models-config WARN "no models.json in the root pi home — the user's models are unread"
      fi
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
    fi
    if [ ! -f "$HOME/.pi/agent/models.json" ]; then
      "$SCRIPT_DIR/models-detect.sh" --write >/dev/null 2>&1 && add models OK "seeded ~/.pi/agent/models.json (was absent)"
    fi
  fi
  if [ -x "$SCRIPT_DIR/model-hardware.sh" ]; then
    "$SCRIPT_DIR/model-hardware.sh" >/dev/null 2>&1 && add models OK "profiled this machine (data/local-models.md; online research left for Brokk)"
  fi
}

# ── 3a3. the local model: engine, the user's model, pi, ymir ────────────────
# Installation stands a local brain up for THIS hardware (plan 57). It ADOPTS an
# existing CUDA llama.cpp engine (never rebuilds what stands), chooses the best
# model that fits the PROBED hardware, fetches it (consent first), wires pi, and
# registers the same model with Ymir in the hoard — one model road. When a local
# server already serves models, nothing is downloaded: the operator's registered
# model is adopted. Loud refusals throughout; never a silent skip.
step_local_model() {
  [ "$SKIP_ENGINES" = 1 ] && { add local-model SKIP "--skip-engines"; return; }
  [ "${YMIR_SKIP_LOCAL_MODEL:-0}" = 1 ] && { add local-model SKIP "YMIR_SKIP_LOCAL_MODEL=1"; return; }

  # 1. the engine — adopt what stands, build only when none.
  if [ ! -x "$SCRIPT_DIR/llama-ensure.sh" ]; then add local-model SKIP "no llama-ensure.sh"; return; fi
  local eng
  if eng="$("$SCRIPT_DIR/llama-ensure.sh" ensure 2>&1)"; then
    [ "$CHECK" = 1 ] && add local-model OK "engine would stand (adopt/build) CUDA llama-server" \
                     || add local-model OK "engine: $(printf '%s' "$eng" | awk -F'\",\"' '/"(adopt|built)"/{print $3; exit}')"
  else
    add local-model WARN "engine: $(printf '%s' "$eng" | tail -1)"
    return
  fi

  # 2. the model. If a local rail already serves models, ADOPT the registered one
  #    (no download); else fit one to the probed hardware and fetch it by consent.
  local provider model base url served="" key=""
  provider="$("$SCRIPT_DIR/agents-config.sh" default --provider 2>/dev/null || true)"
  model="$("$SCRIPT_DIR/agents-config.sh" default --model 2>/dev/null || true)"
  base="$([ -n "$provider" ] && "$SCRIPT_DIR/agents-config.sh" provider-url "$provider" 2>/dev/null || true)"
  [ -n "$base" ] || base="http://127.0.0.1:8080/v1"
  url="${base%/}/models"
  # The rail is keyed: read the provider's key from the operator's pi auth (a
  # reference, never a value in the tree), else the hoard env.
  key="$(python3 - "$HOME/.pi/agent/auth.json" "$provider" <<'PY' 2>/dev/null
import json, sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
p=d.get(sys.argv[2])
print((p.get("key") or p.get("apiKey")) if isinstance(p, dict) else (p if isinstance(p,str) else ""))
PY
)"
  if [ -z "$key" ]; then
    [ -r "$YMIR_ENV_FILE" ] && key="$(. "$YMIR_ENV_FILE" 2>/dev/null; printf '%s' "${LLAMA_SWAP_API_KEY:-}")"
  fi
  if have curl; then
    local -a curl_args=(-fsS --max-time 4)
    [ -n "$key" ] && curl_args+=(-H "Authorization: Bearer $key")
    curl_args+=("$url")
    served="$(curl "${curl_args[@]}" 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
ids=[m.get("id") for m in (d.get("data") or []) if m.get("id")]
print(ids[0] if ids else "")' 2>/dev/null)"
  fi

  if [ -n "$served" ]; then
    # A rail stands: register + wire the operator's model (or the first served).
    [ -n "$model" ] || model="$served"
    if [ "$CHECK" = 1 ]; then add local-model OK "rail serves models — would register ${provider}/${model}"; return; fi
    [ -x "$SCRIPT_DIR/model-register.sh" ] && "$SCRIPT_DIR/model-register.sh" --provider "$provider" --model "$model" --base-url "$base" >/dev/null 2>&1
    [ -x "$SCRIPT_DIR/pi-model-wire.sh" ] && "$SCRIPT_DIR/pi-model-wire.sh" --provider "$provider" --model "$model" --base-url "$base" --no-prove >/dev/null 2>&1
    add local-model OK "adopted rail model ${provider}/${model} (no download)"
    [ -x "$SCRIPT_DIR/model-tune.sh" ] && "$SCRIPT_DIR/model-tune.sh" --model-id "$model" --dry-run >/dev/null 2>&1 && add local-model-tune INFO "tune available: bin/model-tune.sh --model-id ${model}"
    return
  fi

  # No rail: fit a model to this hardware.
  local choice_json choice_id
  if ! choice_json="$("$SCRIPT_DIR/model-fit.sh" --json 2>/dev/null)"; then
    add local-model BLOCKED "no model fits — $( "$SCRIPT_DIR/model-fit.sh" 2>&1 | tail -1 )"
    return
  fi
  choice_id="$(printf '%s' "$choice_json" | python3 -c 'import json,sys;print(json.load(sys.stdin)["choice"]["id"])' 2>/dev/null)"
  [ -n "$choice_id" ] || { add local-model WARN "could not read the fit choice"; return; }

  if [ "$CHECK" = 1 ]; then add local-model OK "would fetch + wire '${choice_id}' for this hardware"; return; fi

  # Consent for the multi-GB download: --yes, or the explicit env door.
  if [ "$ASSUME_YES" != 1 ] && [ "${YMIR_LOCAL_MODEL_CONSENT:-0}" != 1 ]; then
    add local-model CONSENT "would download '${choice_id}' — re-run with --yes or YMIR_LOCAL_MODEL_CONSENT=1"
    return
  fi
  if ! "$SCRIPT_DIR/model-fetch.sh" "$choice_id" --consent >/dev/null 2>&1; then
    add local-model WARN "fetch failed for '${choice_id}' — see bin/model-fetch.sh ${choice_id}"
    return
  fi
  add local-model OK "fetched '${choice_id}' into the hoard models dir"
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

# ── 3b1b. Snotra, the meeting ear's engine ──────────────────────────────────
# The ear captures on the meeting seat and transcribes with whisper.cpp. The
# engine is per-OS (pacman/apt/build) and the model is fetched once; a seat that
# already carries a whisper build or voxtype is left untouched. The MCP face and
# unit ride the fleet step (bin/fleet-ensure.sh).
step_snotra() {
  [ "$SKIP_ENGINES" = 1 ] && { add snotra SKIP "--skip-engines"; return; }
  if [ ! -x "$SCRIPT_DIR/snotra-ensure.sh" ]; then add snotra SKIP "no snotra-ensure.sh"; return; fi
  if [ "$CHECK" = 1 ]; then
    if "$SCRIPT_DIR/snotra-ensure.sh" status >/dev/null 2>&1; then add snotra OK "whisper engine + model present"; else add snotra WARN "engine or model missing"; fi
    return
  fi
  if "$SCRIPT_DIR/snotra-ensure.sh" ensure --install >/dev/null 2>&1; then
    add snotra OK "whisper engine + model present"
  else
    add snotra WARN "engine or model missing (run bin/snotra-ensure.sh install)"
  fi
}

# ── 3b1c. Ratatoskr — the A2A mesh engine (a2abridge) ───────────────────────
# The mesh is the MIT engine **a2abridge**: a local directory daemon every
# agent announces to (:7777), plus the MCP bridge that gives each harness the
# a2a tools. The heart's A2A *node* (:8301) is a fleet service (step_fleet);
# THIS step seats the engine and wires it, so a fresh install is a mesh of one
# with no hand-copy — and Eir can repair it (bin/eir-doctor.sh a2abridge).
step_a2a() {
  [ "$SKIP_ENGINES" = 1 ] && { add a2a SKIP "--skip-engines"; return; }
  if [ ! -x "$SCRIPT_DIR/a2abridge-ensure.sh" ]; then add a2a SKIP "no a2abridge-ensure.sh"; return; fi
  if [ "$CHECK" = 1 ]; then
    if "$SCRIPT_DIR/a2abridge-ensure.sh" status >/dev/null 2>&1; then add a2a OK "engine + directory present"; else add a2a WARN "engine absent (run bin/a2abridge-ensure.sh ensure --install)"; fi
    return
  fi
  # The ensure's own post-start probe can race the daemon's first bind, so the
  # truth is the status check AFTER it, never its exit alone.
  "$SCRIPT_DIR/a2abridge-ensure.sh" ensure --install >/dev/null 2>&1 || true
  if "$SCRIPT_DIR/a2abridge-ensure.sh" status >/dev/null 2>&1; then
    add a2a OK "engine + directory up"
  else
    add a2a WARN "engine absent — run bin/a2abridge-ensure.sh ensure --install (offline?)"
  fi
  if [ -x "$SCRIPT_DIR/a2a-mcp.sh" ] && "$SCRIPT_DIR/a2a-mcp.sh" install >/dev/null 2>&1; then
    add a2a-mcp OK "a2abridge + engram wired into pi + opencode"
  else
    add a2a-mcp WARN "run bin/a2a-mcp.sh install to wire the mesh"
  fi
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

  # The Eindri dispatch profile (D4, 2026-09-24). A shipped template that still
  # carries unfilled model tokens must never steer dispatch, and install must
  # not leave the template to look active. Derive a REAL profile from this
  # machine (config/agents.yaml + the pi catalog) into the hoard's config dir
  # once; the private override wins over the repo file thereafter.
  if [ -x "$SCRIPT_DIR/dispatch-profile.sh" ] && [ -n "${HOARD:-}" ]; then
    local hoprofile="$HOARD/config/eindri-dispatch.json"
    if [ -f "$hoprofile" ]; then
      add dispatch-profile OK "kept (private override at $hoprofile)"
    elif [ "$CHECK" = 1 ]; then
      add dispatch-profile OK "derived at install (private override: $hoprofile)"
    elif mkdir -p "$HOARD/config" && "$SCRIPT_DIR/dispatch-profile.sh" derive --out "$hoprofile" >/dev/null 2>&1; then
      add dispatch-profile OK "derived from this machine: $hoprofile"
    else
      add dispatch-profile WARN "could not derive $hoprofile (is config/agents.yaml present and pi installed?)"
    fi
  fi

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

# ── 3c-bis. the role — what this machine IS in the fleet (plan 51) ───────────
# Role is the one fact every surface derives from: install, update, the MCP
# config, the cron set, the model rail, and dispatch. It is read from the fleet
# registry by hostname; a host that is ABSENT is registered here as `dev` — the
# safe default, because a dev body owns no record and runs no record jobs.
# `bin/role.sh set <host> heart|forge|dev|hand` changes it.
step_role() {
  if [ ! -x "$SCRIPT_DIR/role.sh" ]; then add role SKIP "no role.sh"; return 0; fi
  local host roles
  host="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
  roles="$("$SCRIPT_DIR/role.sh" show "$host" 2>/dev/null | sed -nE 's/^  "[^"]+","([^"]+)","[^"]*"$/\1/p' | head -1)"
  if [ -z "$roles" ] || [ "$roles" = "unassigned" ]; then
    if [ "$CHECK" = 1 ]; then
      add role WARN "not in the fleet registry — a real run registers '$host' as dev"
    elif "$SCRIPT_DIR/role.sh" set "$host" dev >/dev/null 2>&1; then
      add role OK "registered '$host' as dev (bin/role.sh set $host heart|forge|dev|hand)"
    else
      add role WARN "could not register '$host' in the fleet registry"
    fi
  elif [ -x "$SCRIPT_DIR/topology.sh" ]; then
    local link; link="$("$SCRIPT_DIR/topology.sh" 2>/dev/null | sed -nE 's/^  "link","([^"]+)".*/\1/p')"
    add role OK "role: $roles${link:+ (link: $link)}"
  else
    add role OK "role: $roles"
  fi
}

# ── 3d. the warden — Heimdall's ssh-key ward ─────────────────────────────────
# The seat admits its entrant by the rune they carry on GitHub
# (github.com/<user>.keys, validated, refreshed every 15 min). One published
# key opens every warded computer, Omarchy or Ubuntu — this is Heimdall's law.
# The ensure surface carries the ward: installs the script to a stable path
# (~/.local/bin), records the operator's GitHub user, fetches + merges the
# keys, and arms the refresh timer. Idempotent; --install may add openssh
# (sudo, system package), never silently.
step_heimdall() {
  if [ ! -x "$SCRIPT_DIR/heimdall-ensure.sh" ]; then add heimdall SKIP "no heimdall-ensure.sh"; return; fi
  if [ "$CHECK" = 1 ]; then
    if "$SCRIPT_DIR/heimdall-ensure.sh" status >/dev/null 2>&1; then add heimdall OK "the ward stands — GitHub keys, 15-min refresh"
    else add heimdall WARN "the ward is not armed — a real run installs it"; fi
    return
  fi
  if "$SCRIPT_DIR/heimdall-ensure.sh" ensure --install >/dev/null 2>&1; then
    add heimdall OK "ward armed — GitHub keys admitted, refresh timer live"
  else
    add heimdall WARN "run bin/heimdall-ensure.sh ensure --install (needs sudo for openssh?); or seat keys by hand (hodd/docs/ssh)"
  fi
}

# ── 3e. the fleet services (the heart's surfaces) ─────────────────────────────
# well-mcp (the served well) · ratatoskr A2A node · the mill worker · the
# embedding stone · the cards root — raised as user units from tools/, and the
# seat's pi mcp.json pointed at the served well. ROLE-GATED (plan 51): a seat
# rises exactly what its roles owe, one target (ymir.target) pulls the set at
# boot, and a program that cannot rise is a FAILURE with its reason — never a
# warn the install steps past (law, 2026-09-24).
step_fleet() {
  if [ ! -x "$SCRIPT_DIR/fleet-ensure.sh" ]; then add fleet SKIP "no fleet-ensure.sh"; return; fi
  if [ "$CHECK" = 1 ]; then
    if "$SCRIPT_DIR/fleet-ensure.sh" status >/dev/null 2>&1; then add fleet OK "services mapped — role-gated raise on a real run"
    else add fleet WARN "no user manager — a real run raises the role set"; fi
    return
  fi
  if "$SCRIPT_DIR/fleet-ensure.sh" ensure >/dev/null 2>&1; then
    add fleet OK "role-owed services raised and verified (ymir.target enabled)"
  else
    add fleet FAIL "a role-owed service could not rise — run bin/fleet-ensure.sh ensure to see the unit and the reason"
  fi
}

# ── 3f. autoboot (the boot law) ──────────────────────────────────────────────
# Every Ymir program rises at boot, by itself — role-gated. This step asserts
# the two things that make that true: the ONE target is enabled (fleet-ensure
# did it) and the seat's user units survive a reboot (Linger, on a headless
# seat). The Linger value is reported here on EVERY seat — the DoD.
step_autoboot() {
  local v=""
  v="$(loginctl show-user "$USER" -p Linger 2>/dev/null | sed 's/^Linger=//')"
  case "$v" in yes) ;; *) v="no" ;; esac
  if [ "$CHECK" = 1 ]; then
    add autoboot OK "Linger=$v · would enable ymir.target + assert linger on a real run"
    return
  fi
  # A headless seat (heart/forge/server) has no login to raise its session:
  # without linger, every enabled user unit is dead until someone logs in —
  # and no surface says so. Enable it, or fail with the exact remedy.
  if [ "$v" = no ]; then
    if { [ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && [ "$(ymir_os 2>/dev/null || echo other)" != macos ]; }; then
      if loginctl enable-linger "$USER" 2>/dev/null; then
        v="$(loginctl show-user "$USER" -p Linger 2>/dev/null | sed 's/^Linger=//')"; [ "$v" = yes ] || v="no"
        if [ "$v" = yes ]; then
          add autoboot OK "Linger enabled ($USER) — headless boot services will rise"
          return
        fi
      fi
      add autoboot FAIL "Linger=no on a headless seat — boot services would never rise; remedy: sudo loginctl enable-linger $USER"
      return
    fi
  fi
  add autoboot OK "Linger=$v — boot is role-gated and proven (bin/ymir-autoboot.sh verify)"
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
  # The well is ONE memory and it lives in the hoard — always.
  if [ -n "${ENGRAM_DB:-}" ]; then
    local db="$ENGRAM_DB"
  else
    . "$SCRIPT_DIR/hoard-lib.sh" 2>/dev/null || true
    hoard_memory_store db
  fi
  local mcp=0
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
  # The answer comes from the resolver (P1): app-local, workspace-hoisted, or
  # the sibling package — never one hardcoded path.
  if [ "$(electron_runtime_state "$app" "$ROOT" "$(app_pkg hlidskjalf)" 2>/dev/null || echo absent)" = ok ]; then
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
      # Seat the post-merge rebind hook as well. Pi loads its extensions from
      # ${HOME}/.pi/agent/extensions/, so a merged extension fix stays invisible
      # to the running harness unless the bind re-runs. No install and no update
      # should leave the surfaces stale.
      "$SCRIPT_DIR/valknut-load.sh" --install >/dev/null 2>&1 \
        && add loaders OK "post-merge rebind hook seated" \
        || add loaders WARN "post-merge hook not seated"
    fi
  else add loaders SKIP "no valknut-load.sh"; fi
}

# ── 6b. delivery gates (git hooks) ───────────────────────────────────────────
#
# Rule 08: work leaves by PR, and every push carries a fix note. The
# guards live in bin/ (branch-guard, fixes-guard, secret-guard) but git
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
      add gates WARN "hooks not installed — bin/secret-guard.sh --install && bin/fixes-guard.sh --install"
    fi
    # The home repo is where the private data lives, so its ward matters more
    # than this repo's four. Report it separately so a dormant vault is visible.
    local hh; hh="${YMIR_HOME}/.git/hooks/pre-commit"
    if [ -x "$hh" ]; then add hoard-gate OK "home pre-commit seated";
    else add hoard-gate WARN "home hooks not installed — bin/hoard-guard.sh --install"; fi
    return
  fi
  [ -x "$SCRIPT_DIR/secret-guard.sh" ] && "$SCRIPT_DIR/secret-guard.sh" --install >/dev/null 2>&1 || true
  [ -x "$SCRIPT_DIR/fixes-guard.sh" ] && "$SCRIPT_DIR/fixes-guard.sh" --install >/dev/null 2>&1 || true
  # Seat the ward on the PRIVATE home too — every install layer, every machine.
  [ -x "$SCRIPT_DIR/hoard-guard.sh" ] && "$SCRIPT_DIR/hoard-guard.sh" --install >/dev/null 2>&1 || true
  if [ -x "$pre_commit" ] && [ -x "$pre_push" ]; then add gates OK "pre-commit + pre-push installed"
  else add gates WARN "could not write .git/hooks — gates are dormant"; fi
  local hh; hh="${YMIR_HOME}/.git/hooks/pre-commit"
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
    # A check reports what is TRUE, not what reassures: count the entries really on
    # disk, and name the halls that are not.
    local cw=(hlidskjalf odrerir sessrumnir smidja) cn=0 cgone=""
    for v in "${cw[@]}"; do
      if [ -f "$HOME/.local/share/applications/ymir-$v.desktop" ]; then cn=$((cn+1)); else cgone="$cgone $v"; fi
    done
    if [ "$cn" -eq "${#cw[@]}" ]; then
      add marks OK "${cn} desktop app marks installed"
    else
      add marks WARN "${cn}/${#cw[@]} desktop app marks - missing:$cgone (run without --check to write them)"
    fi
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
    "$SCRIPT_DIR/design-icon.sh" install >/dev/null 2>&1 || true
    [ -r "$HOME/.pi/agent/AGENTS.md" ] || [ -d "$HOME/.pi/agent" ] && {
      ln -sfn "$ROOT/AGENTS.md" "$HOME/.pi/agent/AGENTS.md" 2>/dev/null || true
    }
    # VERIFY, never claim. This step once reported four marks while Smidja's entry had
    # never been written: it counted what design-icon.sh PRINTED, not what landed. A
    # mark is present when its file is on disk, executable, with an Exec that resolves
    # and an Icon the theme carries.
    local want=(hlidskjalf odrerir sessrumnir smidja) missing=0 weak=0 gone=""
    for v in "${want[@]}"; do
      f="$HOME/.local/share/applications/ymir-$v.desktop"
      if [ ! -f "$f" ]; then missing=$((missing+1)); gone="$gone $v"; continue; fi
      [ -x "$f" ] || chmod +x "$f" 2>/dev/null || true
      exe="$(sed -n 's/^Exec=//p' "$f" | head -1 | awk '{print $1}')"
      ico="$(sed -n 's/^Icon=//p' "$f" | head -1)"
      { [ -n "$exe" ] && [ -x "$exe" ]; } || weak=$((weak+1))
      [ -f "$HOME/.local/share/icons/hicolor/scalable/apps/$ico.svg" ] || weak=$((weak+1))
    done
    local total=${#want[@]}
    if [ "$missing" -gt 0 ]; then
      add marks WARN "$((total-missing))/$total marks - MISSING:$gone (checked the files, not a log line)"
    elif [ "$weak" -gt 0 ]; then
      add marks WARN "$total marks present but $weak do not resolve (Exec or Icon)"
    else
      add marks OK "$total marks verified - entry + glyph + resolvable Exec, each hall"
    fi
}

# ── 7. services ──────────────────────────────────────────────────────────────
step_services() {
  [ "$SKIP_SERVICES" = 1 ] && { add services SKIP "--skip-services"; return; }
  if [ "$CHECK" = 1 ]; then
    local up=0
    for p in 3888 3889 4602 4603; do (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null && up=$((up+1)); done
    add services OK "$up/4 ports up (3888/3889/4602/4603)"; return
  fi
  # The web stack is SEATED as user units on dev seats (hlidskjalf-spa · gate ·
  # mimir · bifrost · smidja, all joined to ymir.target and raised by the fleet
  # step above) — the old "run scripts/start.sh and hope" road is retired. This
  # step PROVES the raise: the boot proof reads systemd directly and exits
  # non-zero when a role-owed program is not enabled. Desktop windows stay on
  # demand; the services are what boot owes.
  if out="$("$SCRIPT_DIR/ymir-autoboot.sh" verify 2>&1)"; then
    add services OK "autoboot verified — every dev-seat service is enabled and standing"
  else
    local nbad; nbad="$(printf '%s' "$out" | grep -cE '"disabled"|"failed"|"inactive"' || true)"
    add services FAIL "boot proof failed ($nbad program(s)) — bin/ymir-autoboot.sh verify names them"
  fi
}

# ── 7b. desktop (both Electron apps) ──────────────────────────
# The operator should SEE the applications when the install finishes, so we
# raise both desktop shells (Hlidskjalf + Smíðja) as separate processes.
step_desktop() {
  if [ "$NO_DESKTOP" = 1 ]; then add desktop SKIP "--no-desktop"; return; fi
  if [ ! -x "$ROOT/scripts/electron.sh" ]; then add desktop SKIP "no scripts/electron.sh"; return; fi
  if [ "$CHECK" = 1 ]; then
    # A check probes: every surface must RESOLVE an executable runtime and be
    # routed by the right class (bin/desktop-verify.sh — read-only, few
    # seconds). Fails loudly, naming the surface and the resolved path.
    if [ -x "$ROOT/bin/desktop-verify.sh" ]; then
      if out="$("$ROOT/bin/desktop-verify.sh" 2>&1)"; then
        add desktop OK "verified: every surface resolves a runnable Electron and is routed right"
      else
        add desktop FAIL "$(printf '%s' "$out" | grep -m1 'FAIL' | sed 's/^  //')"
      fi
    else
      add desktop OK "would verify + launch the desktop shells"
    fi
    return
  fi
  # A headless host has no display; launching a window would only fail.
  # DISPLAY/WAYLAND_DISPLAY are X11/Wayland variables — macOS has a display and
  # neither of them, so testing only those would wrongly skip every Mac.
  if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && [ "$(ymir_os)" != macos ]; then
    add desktop SKIP "no display (headless) — run scripts/electron.sh start --both"; return
  fi
  # P4 (2026-09-24): the INSTALL-TIME guarantee — before any window is claimed,
  # every surface must resolve an executable runtime that ANSWERS --version and
  # is routed by the right class. A runtime that is merely absent is a FAILURE,
  # never the old silent SKIP: the launcher must not proceed into a path that
  # npm will never make.
  if [ -x "$ROOT/bin/desktop-verify.sh" ]; then
    local vout vrc
    vout="$("$ROOT/bin/desktop-verify.sh" 2>&1)"
    vrc=$?
    if [ "$vrc" != 0 ]; then
      add desktop FAIL "$(printf '%s' "$vout" | grep -m1 'FAIL' | sed 's/^  //')"
      return 0
    fi
  fi
  # One window per surface that is here: the halls are not one app.
  raised=0
  for _v in hlidskjalf smidja odrerir; do
    "$ROOT/scripts/electron.sh" start --view "$_v" >/dev/null 2>&1 && raised=$((raised+1))
  done
  [ -x "$ROOT/bin/sessrumnir.sh" ] && "$ROOT/bin/sessrumnir.sh" start >/dev/null 2>&1 && raised=$((raised+1))
  if [ "$raised" -ge 2 ]; then
    add desktop OK "verified + raised $raised window(s) — Hlidskjalf · Smíðja · Óðrerir · Sessrúmnir"
  else
    add desktop WARN "could not raise every desktop app — ymir hlidskjalf | smidja | sessrumnir"
  fi
  # The routing is then proven LIVE (P5): with the windows up, the compositor
  # must actually hold each surface's class. One retry lets a slow map settle.
  if [ -x "$ROOT/bin/desktop-verify.sh" ] && command -v hyprctl >/dev/null 2>&1; then
    local t=0
    while [ "$t" -lt 2 ] && ! "$ROOT/bin/desktop-verify.sh" --live >/dev/null 2>&1; do
      t=$((t+1)); sleep 3
    done
    if ! "$ROOT/bin/desktop-verify.sh" --live >/dev/null 2>&1; then
      add desktop FAIL "a raised surface's window is missing its class on the compositor — bin/desktop-verify.sh --live names it"
    fi
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
    printf '3. The services rise at boot (role-gated; `bin/ymir-autoboot.sh status` shows them).\n'
    printf '   `scripts/start.sh` remains the manual raise when a window is wanted.\n'
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
  # The final gate proves the BOOT as well as the running system: ymir-validate
  # checks live ports/stores; the autoboot proof checks that every role-owed
  # program would RISE at boot (enabled + standing). Both must pass for the
  # install to claim "it stands".
  if [ ! -x "$SCRIPT_DIR/ymir-validate.sh" ] || [ ! -x "$SCRIPT_DIR/ymir-autoboot.sh" ]; then
    add validate SKIP "no ymir-validate.sh / ymir-autoboot.sh"; return
  fi
  if [ "$CHECK" = 1 ]; then add validate OK "would verify the running system and the boot proof"; return; fi
  local boot_ok=1 live_ok=0 out nf
  if "$SCRIPT_DIR/ymir-autoboot.sh" verify --quiet >/dev/null 2>&1; then boot_ok=0; fi
  if out="$("$SCRIPT_DIR/ymir-validate.sh" --quiet 2>&1)"; then live_ok=1; else nf="$(printf '%s' "$out" | grep -oE '[0-9]+ required check\(s\) failed' | head -1)"; fi
  if [ "$boot_ok" = 0 ] && [ "$live_ok" = 1 ]; then
    add validate OK "all checks pass — the roll is verified (bin/ymir-autoboot.sh verify)"
  else
    local why=""
    [ "$boot_ok" = 1 ] && why="boot proof failed — bin/ymir-autoboot.sh verify"
    [ -n "$why" ] && [ "$live_ok" = 0 ] && why="$why; "
    [ "$live_ok" = 0 ] && why="${why}${nf:-some live checks} failed — bin/ymir-validate.sh"
    add validate WARN "$why"
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

# ── progress ─────────────────────────────────────────────────────────────────
# The install takes minutes; a user must SEE work rather than silence. Each step
# announces itself before it runs and reports its elapsed time after, so a slow step
# reads as work and a hung one is obvious. Progress goes to stderr: the TOON report
# on stdout stays clean for anything that parses it.
STEP_TOTAL=24
STEP_N=0
run_step() {  # <runner-function> <label spoken to the user>
  STEP_N=$((STEP_N + 1))
  local t0=$SECONDS
  if [ -t 2 ]; then
    # A terminal: rewrite one line in place, so the list stays short and alive.
    printf '\r\033[K  [%2d/%2d] %s …' "$STEP_N" "$STEP_TOTAL" "$2" >&2
    "$1"
    printf '\r\033[K  [%2d/%2d] %s — %ss\n' "$STEP_N" "$STEP_TOTAL" "$2" "$((SECONDS - t0))" >&2
  else
    # Piped or logged: one plain line each, no escapes, so a log reads clean.
    printf '  [%2d/%2d] %s …\n' "$STEP_N" "$STEP_TOTAL" "$2" >&2
    "$1"
    printf '  [%2d/%2d] %s — %ss\n' "$STEP_N" "$STEP_TOTAL" "$2" "$((SECONDS - t0))" >&2
  fi
}

run_step step_panes "panes"
run_step step_prereqs "prerequisites"
run_step step_home "home"
run_step step_tree "workspace tree"
run_step step_apps "apps"
run_step step_engines "engines"
run_step step_models "models"
run_step step_local_model "the local model"
run_step step_hermes "hermes"
run_step step_snotra "the meeting ear"
run_step step_a2a "the A2A mesh"
run_step step_sessrumnir "the seat"
run_step step_backend "backend"
run_step step_host "host"
run_step step_role "role"
run_step step_heimdall "the warden"
run_step step_fleet "fleet services"
run_step step_autoboot "autoboot"
run_step step_sandbox "sandbox"
run_step step_memory "memory"
run_step step_smidja "the smithy"
run_step step_spa "the spa"
run_step step_omarchy "omarchy layer"
run_step step_loaders "loaders"
run_step step_gates "gates"
run_step step_marks "marks"
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
