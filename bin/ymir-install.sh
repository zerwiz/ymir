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
      # A check reports what is TRUE, not what reassures: count the entries that are
      # really on disk, and name the halls that are not.
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
