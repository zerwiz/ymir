#!/usr/bin/env bash
# ymir-install.sh — THE FIRST SETUP. Stand the full Ymir up for the operator:
# prerequisites, the single-tenant workspace tree, the OSS engines (worktree /
# sandcastle / no-mistakes), the sandbox image, the well (engram) + harness MCP,
# the loaders, the registries, and the runtime services. Idempotent. Galdr TOON.
#
# Usage:
#   bin/ymir-install.sh [--check] [--skip-engines] [--skip-services] [--yes]
#   bin/ymir-install.sh --status
#   bin/ymir-install.sh --version
#
# Exit: 0 all good (or --check), 1 a step failed, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE="$ROOT/workspace"
DOMAINS="company marketing development life me"

CHECK=0; SKIP_ENGINES=0; SKIP_SERVICES=0; ASSUME_YES=0
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --skip-engines) SKIP_ENGINES=1; shift ;;
    --skip-services) SKIP_SERVICES=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    --status) exec "$SCRIPT_DIR/ymir-install.sh" --check ;;
    *) printf 'error: unknown flag %s\nhelp: bin/ymir-install.sh [--check|--skip-engines|--skip-services|--yes]\n' "$1" >&2; exit 2 ;;
  esac
done

declare -a IDS STATUS DETAIL
add() { IDS+=("$1"); STATUS+=("$2"); DETAIL+=("$3"); }
have() { command -v "$1" >/dev/null 2>&1; }
TOON="install[0]{step,status,detail}:"

# ── 1. prereqs ───────────────────────────────────────────────────────────────
step_prereqs() {
  local miss=""
  for c in git python3 bun; do have "$c" || miss="$miss $c"; done
  if ! python3 -c "import engram" >/dev/null 2>&1; then miss="$miss engram"; fi
  if ! python3 -c "from mcp.server.fastmcp import FastMCP" >/dev/null 2>&1; then miss="$miss mcp<2"; fi
  have docker || miss="$miss docker"
  have gh || miss="$miss gh"
  if [ -n "$miss" ]; then add prereqs WARN "missing:$miss"; else add prereqs OK "git python3 bun docker gh engram mcp<2"; fi
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

# ── 4. sandbox image ─────────────────────────────────────────────────────────
step_sandbox() {
  if ! have docker; then add sandbox SKIP "docker absent"; return; fi
  if docker image inspect utgard-runner:latest >/dev/null 2>&1; then
    add sandbox OK "utgard-runner:latest present"
  elif [ "$CHECK" = 1 ]; then
    add sandbox WARN "utgard-runner:latest missing (run without --check)"
  else
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

step_prereqs; step_tree; step_engines; step_sandbox; step_memory; step_loaders; step_register
[ "$CHECK" = 0 ] && step_services

printf 'install[%d]{step,status,detail}:\n' "${#IDS[@]}"
for i in "${!IDS[@]}"; do printf '  "%s","%s","%s"\n' "${IDS[$i]}" "${STATUS[$i]}" "${DETAIL[$i]}"; done
printf '\nnext: gh auth login · fill workspace/projects.yaml git{} · open http://127.0.0.1:3888/\n'

for s in "${STATUS[@]}"; do [ "$s" = FAIL ] && exit 1; done
exit 0
