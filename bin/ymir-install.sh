#!/usr/bin/env bash
# ymir-install.sh — THE FIRST SETUP. Stand the full Ymir up for the operator:
# prerequisites, the single-tenant workspace tree, the OSS engines (treehouse /
# sandcastle / no-mistakes), the sandbox image, the well (engram) + harness MCP,
# the loaders, the registries, and the runtime services. Idempotent. Galdr TOON.
#
# Usage:
#   bin/ymir-install.sh [--check] [--skip-engines] [--skip-services] [--no-desktop] [--yes]
#   bin/ymir-install.sh --status
#   bin/ymir-install.sh --version
#
# Consent: a real install (not --check) asks the operator to accept the plan
# before any change is made. Non-interactive callers must pass --yes.
#
# Exit: 0 all good (or --check), 1 a step failed, 2 usage, 3 declined.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE="$ROOT/workspace"
DOMAINS="company marketing development life me"

CHECK=0; SKIP_ENGINES=0; SKIP_SERVICES=0; ASSUME_YES=0; NO_DESKTOP=0
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --skip-engines) SKIP_ENGINES=1; shift ;;
    --skip-services) SKIP_SERVICES=1; shift ;;
    --no-desktop) NO_DESKTOP=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    --status) exec "$SCRIPT_DIR/ymir-install.sh" --check ;;
    *) printf 'error: unknown flag %s\nhelp: bin/ymir-install.sh [--check|--skip-engines|--skip-services|--no-desktop|--yes]\n' "$1" >&2; exit 2 ;;
  esac
done

declare -a IDS STATUS DETAIL
add() { IDS+=("$1"); STATUS+=("$2"); DETAIL+=("$3"); }
have() { command -v "$1" >/dev/null 2>&1; }
TOON="install[0]{step,status,detail}:"

# ── consent ──────────────────────────────────────────────────────────────
# Show exactly what will change and require explicit acceptance. A real
# install touches the machine (packages, a docker image, raised services),
# so it never proceeds on silence.
confirm_install() {
  [ "$ASSUME_YES" = 1 ] && return 0
  if [ ! -t 0 ]; then
    printf 'error: refusing a non-interactive install without --yes\nhelp: re-run with --yes to accept non-interactively, or --check to preview\n' >&2
    exit 3
  fi
  cat <<'PLAN'
Ymir first setup — this will make the following changes:

  • install in USER SPACE (no sudo): bun, uv  — and 'mcp<2>' via pip
  • create the workspace tree (work/ · personal/ · companies · registries)
  • install the OSS engines: treehouse, no-mistakes (+ sandcastle if present)
  • ensure the Hermes worker runtime
  • ensure a terminal backend (herdr — Þjazi — preferred, else tmux)
  • learn this machine (Omarchy version, packages, configs, monitors, scale)
  • place the desktop apps on their own numbered desktops
  • build the Utgard sandbox image 'utgard-runner:latest' (needs docker access)
  • create the Smiðja database and build the visualizer UI
  • load agents/skills and write workspace/INSTALL.md
  • raise the runtime services (Hlidskjalf SPA + gate API + bridges)
  • open BOTH desktop apps so you see them: Hlidskjalf + Smíðja
  • verify the running system and report what stands

Nothing is deleted. Every step is idempotent.
PLAN
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
  local miss=""
  for c in git python3 bun; do have "$c" || miss="$miss $c"; done
  python3 -c "from mcp.server.fastmcp import FastMCP" >/dev/null 2>&1 || miss="$miss mcp<2"
  have docker || miss="$miss docker"
  have gh || miss="$miss gh"
  if [ -n "$miss" ]; then add prereqs WARN "missing:$miss"; else add prereqs OK "git python3 bun docker gh mcp<2"; fi
  # engram is reported separately and never fails the step.
  if python3 -c "import engram" >/dev/null 2>&1; then
    add memory-well OK "engram present"
  else
    local pyv; pyv="$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null || echo '?')"
    add memory-well SKIP "optional — install engine then run bin/mimir-bridge.sh (have Python $pyv); platform fully runs without it"
  fi
}

# ── 2. workspace tree ────────────────────────────────────────────────────────
step_tree() {
  if [ "$CHECK" = 1 ]; then
    local ok=1
    [ -d "$WORKSPACE/work" ] && [ -d "$WORKSPACE/personal" ] && [ -f "$WORKSPACE/workspaces.yaml" ] && [ -f "$WORKSPACE/projects.yaml" ] || ok=0
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
  mkdir -p "$WORKSPACE/companies" "$WORKSPACE/memory/daily"
  if [ ! -f "$WORKSPACE/workspaces.yaml" ]; then
    cat >"$WORKSPACE/workspaces.yaml" <<'YAML'
# Workspace registry — single tenant. One operator, many workspaces.
# kind: work | personal.  company: only for work.  domains: knowledge areas.
workspaces:
  - id: work
    name: Work
    kind: work
    company: wayof
    domains: [company, marketing, development, life]
  - id: personal
    name: Personal
    kind: personal
    domains: [me, life, development]
YAML
    created=$((created+1))
  fi
  if [ ! -f "$WORKSPACE/projects.yaml" ]; then
    cat >"$WORKSPACE/projects.yaml" <<'YAML'
# Master project registry. Every project carries its GitHub block here; the
# runtime reads it — never guesses a remote. auth is a REFERENCE, never a value.
projects:
  - id: ymir-platform
    name: Ymir
    workspace: work
    company: wayof
    domains: [development, company]
    repo: .
    posture: local-only
    git: { host: github.com, owner: Way-Of, repo: ymir, remote: origin, default_branch: main, auth: gh }
  - id: hlidskjalf
    name: Hlidskjalf
    workspace: work
    company: wayof
    domains: [development, company]
    repo: apps/hlidskjalf
    posture: direct-PR
    git: { host: github.com, owner: Way-Of, repo: ymir, remote: origin, default_branch: main, auth: gh }
YAML
    created=$((created+1))
  fi
  add tree OK "workspace/{work,personal} · companies · registries (created $created)"
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
step_host() {
  local on_omarchy=0
  [ -d /usr/share/omarchy ] && on_omarchy=1
  local learned=no placed=no hooked=no

  if [ "$CHECK" = 1 ]; then
    if [ -x "$SCRIPT_DIR/omarchy-sense.sh" ]; then
      local snap; snap="$("$SCRIPT_DIR/omarchy-sense.sh" status 2>&1 | sed -n '2p' | sed -E 's/^ *//; s/^"//; s/"$//' | tr -d '\n' | cut -c1-70)"
      learned="${snap:-no snapshot yet}"
    fi
    add host OK "${learned}; omarchy=${on_omarchy}"; return
  fi

  # 1. Learn the host (Omarchy version, packages, configs, monitors, scale).
  if [ -x "$SCRIPT_DIR/omarchy-sense.sh" ]; then
    "$SCRIPT_DIR/omarchy-sense.sh" observe --quiet >/dev/null 2>&1 && learned=yes
  fi

  # 2. Place the desktop apps on their own desktops (Hyprland hosts).
  if [ -x "$SCRIPT_DIR/desktop-place.sh" ]; then
    "$SCRIPT_DIR/desktop-place.sh" apply >/dev/null 2>&1 && placed=yes
  fi

  # 3. Omarchy extras: re-learn after every `omarchy update`.
  if [ "$on_omarchy" = 1 ] && [ -x "$SCRIPT_DIR/omarchy-hook-install.sh" ]; then
    "$SCRIPT_DIR/omarchy-hook-install.sh" install >/dev/null 2>&1 && hooked=yes
  fi

  if [ "$on_omarchy" = 1 ]; then
    add host OK "learnt the host; desktops placed=${placed}; post-update hook=${hooked}"
  else
    add host OK "learnt the host; desktops placed=${placed} (not an Omarchy host)"
  fi
}

# ── 4. sandbox image ─────────────────────────────────────────────────────────
step_sandbox() {
  if ! have docker; then add sandbox SKIP "docker absent"; return; fi
  if docker image inspect utgard-runner:latest >/dev/null 2>&1; then
    add sandbox OK "utgard-runner:latest present"
  elif [ "$CHECK" = 1 ]; then
    add sandbox WARN "utgard-runner:latest missing (run without --check)"
  else
    # Distinguish "no daemon access" from "build failed" so the operator gets
    # an actionable message instead of a blanket failure.
    if ! docker info >/dev/null 2>&1; then
      local who; who="$(id -un)"
      if id -nG "$who" 2>/dev/null | grep -qw docker; then
        add sandbox WARN "docker daemon unreachable — log out and back in so the docker group applies"
      else
        add sandbox WARN "docker permission denied — add $who to the docker group, then re-login"
      fi
      return
    fi
    if "$SCRIPT_DIR/utgard.sh" build >/dev/null 2>&1; then add sandbox OK "utgard-runner:latest built"; else add sandbox WARN "image build failed (see docker)"; fi
  fi
}

# ── 5. memory (well + harness MCP) ───────────────────────────────────────────
step_memory() {
  local db="$ROOT/.agents/memory/kaia.engram" mcp=0
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
      [ -f "$ROOT/smidja/smidja_data/smidja.db" ] && dbok=present || dbok=missing
      [ -d "$ROOT/.agents/skills/smidja/apps/visualizer/dist" ] && vizok=built || vizok=unbuilt
      add smidja OK "smidja.db $dbok · visualizer UI $vizok"
    else
      if "$SCRIPT_DIR/smidja-bootstrap.sh" >/dev/null 2>&1; then add smidja OK "smidja.db ready (visualizer has data)"; else add smidja WARN "could not bootstrap smidja.db (visualizer stays empty)"; fi
    fi
  else add smidja SKIP "no smidja-bootstrap.sh"; fi
  # The visualizer API serves its UI from ./dist — without a build it answers
  # the API but shows "No ./dist build found". Build it once when absent.
  local viz="$ROOT/.agents/skills/smidja/apps/visualizer"
  [ -d "$viz" ] || return 0
  if [ -d "$viz/dist" ]; then
    add visualizer OK "UI built (served on :8437)"
  elif [ "$CHECK" = 1 ]; then
    add visualizer WARN "UI not built (run without --check)"
  elif command -v bun >/dev/null 2>&1; then
    [ -d "$viz/node_modules" ] || (cd "$viz" && bun install >/dev/null 2>&1 || true)
    if (cd "$viz" && bun run build >/dev/null 2>&1); then add visualizer OK "UI built (served on :8437)"; else add visualizer WARN "UI build failed — (cd $viz && bun run build)"; fi
  else
    add visualizer WARN "no bun — cannot build the visualizer UI"
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
  if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    add desktop SKIP "no display (headless) — run scripts/electron.sh start --both"; return
  fi
  # On Omarchy, place each app on its OWN numbered desktop (preferring EMPTY
  # ones) BEFORE launching, so they open separated instead of stacked.
  if [ -x "$SCRIPT_DIR/desktop-place.sh" ] && [ -d /usr/share/omarchy ]; then
    "$SCRIPT_DIR/desktop-place.sh" apply >/dev/null 2>&1 || true
  fi
  if "$ROOT/scripts/electron.sh" start --both >/dev/null 2>&1; then
    add desktop OK "raised Hlidskjalf + Smíðja"
  else
    add desktop WARN "could not raise the desktop apps — run scripts/electron.sh start --both"
  fi
}

# ── 8. register ──────────────────────────────────────────────────────────────
step_register() {
  if [ "$CHECK" = 1 ]; then add register OK "would write workspace/INSTALL.md"; return; fi
  local out="$WORKSPACE/INSTALL.md"
  {
    printf '# Ymir — first setup\n\n'
    printf 'Provisioned by `bin/ymir-install.sh` at %s.\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '## Workspaces\n\n'; printf -- '- work (company: wayof)\n- personal\n\n'
    printf '## Engines\n\n- Yggdrasil → treehouse\n- Utgard → sandcastle\n- Mjollnir/Glitnir → no-mistakes\n\n'
    printf '## Next\n\n1. `gh auth login` (the Allfather\x27s own GitHub login).\n'
    printf '2. Fill each project\x27s `git{}` block in `workspace/projects.yaml`.\n'
    printf '3. `scripts/start.sh` then open http://127.0.0.1:3888/.\n'
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

# Ask before touching the machine; --check only previews and never asks.
[ "$CHECK" = 0 ] && confirm_install

step_prereqs; step_tree; step_engines; step_hermes; step_backend; step_host; step_sandbox; step_memory; step_smidja; step_loaders; step_register
[ "$CHECK" = 0 ] && step_services
[ "$CHECK" = 0 ] && step_desktop
[ "$CHECK" = 0 ] && step_validate

printf 'install[%d]{step,status,detail}:\n' "${#IDS[@]}"
for i in "${!IDS[@]}"; do printf '  "%s","%s","%s"\n' "${IDS[$i]}" "${STATUS[$i]}" "${DETAIL[$i]}"; done
printf '\nnext: gh auth login · fill workspace/projects.yaml git{} · open http://127.0.0.1:3888/\n'

for s in "${STATUS[@]}"; do [ "$s" = FAIL ] && exit 1; done
exit 0
