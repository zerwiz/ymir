#!/usr/bin/env bash
# fleet-ensure.sh — the role-gated RAISE (plan 42's fleet services, plan 51's
# role law, and the 2026-09-24 autoboot law — one errand).
#
# The seat rises exactly what its roles owe (heart: the fleet offices;
# forge: the embedding stone; dev: the local web stack + its well door).
# Everything owed joins ONE user target (ymir.target); the install enables
# that target once, and boot pulls the whole set. The raise VERIFIES after it
# acts: a role-owed program that is not enabled or not active is a FAILURE
# with its reason — never a `say ... (warn)` the install steps past.
#
# Usage:
#   fleet-ensure.sh status              # per-role truth (delegates to the proof)
#   fleet-ensure.sh ensure              # materialize + raise + VERIFY (fails loud)
#   fleet-ensure.sh verify              # the proof alone (exit non-zero on gaps)
#   fleet-ensure.sh --well-url <url>    # the served well URL for this seat's mcp
# Env: BROKK_ROOT_OVERRIDE · BROKK_HOME · YMIR_HOST (role read) · HLIDSKJALF_PORT
#      · HLIDSKJALF_API_PORT · SMIDJA_VIZ_API_PORT · SMIDJA_DB
set -u

VERSION="2.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
. "$SCRIPT_DIR/autoboot-lib.sh"
HOME_ROOT="$AUTOBOOT_HOME_ROOT"
DST="$HOME/.fleet"
# The tree that SHIPS the templates may differ from the seat's platform root
# (an updater or installer from a source tree against a packed seat). Normally
# one and the same; the override is how a changed tree raises an existing seat.
#
# BUT A CALLER'S TREE MUST NEVER BE WRITTEN INTO THE OPERATOR'S PERMANENT UNITS.
# 2026-09-24: a smith ran an ensure from its Yggdrasil worktree and this seat's
# ~/.config/systemd/user/nornir.service came out holding
#   ExecStart=/bin/bash <main>/.yggdrasil/<id>/bin/nornir-cron-start.sh
# — a DISPOSABLE path. Pruning the worktree would have broken the seat's cron at
# boot, silently. So when no explicit override is given, resolve to the MAIN tree
# through git's common dir (the eindri-watch.sh lesson: a worktree's ensure and
# the main tree's ensure must materialize the same durable paths), and the
# materializer below refuses any unit that still carries a .yggdrasil/ path.
if [ -z "${FLEET_TEMPLATE_ROOT:-}" ]; then
  FLEET_TEMPLATE_ROOT="$ROOT"
  if command -v git >/dev/null 2>&1 && [ -e "$ROOT/.git" ]; then
    _ftr_common="$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null)"
    if [ -n "$_ftr_common" ]; then
      _ftr_main="$(cd "$ROOT" && cd "$(dirname "$_ftr_common")" 2>/dev/null && pwd)"
      # Inside a worktree this is the MAIN tree; in the main tree it is itself,
      # and the != keeps it idempotent.
      if [ -n "$_ftr_main" ] && [ "$_ftr_main" != "$ROOT" ] && [ -d "$_ftr_main/tools/mill/systemd" ]; then
        FLEET_TEMPLATE_ROOT="$_ftr_main"
      fi
    fi
    unset _ftr_common _ftr_main
  fi
fi
# A unit that names a disposable tree is a boot failure waiting to happen: refuse
# it loudly rather than seat it.
refuse_disposable_path() {  # <unit-file>
  local u="${1-}" bad
  [ -f "$u" ] || return 0
  bad="$(grep -n '\.yggdrasil/' "$u" 2>/dev/null | head -1)" || true
  if [ -n "$bad" ]; then
    say "fleet: REFUSED — $u names a disposable worktree path:" >&2
    say "fleet:   $bad" >&2
    say "fleet:   remedy: re-run from the MAIN tree, or pass FLEET_TEMPLATE_ROOT=<the durable root>" >&2
    return 1
  fi
  return 0
}
WELL_URL="${FLEET_WELL_URL:-http://127.0.0.1:8317/mcp}"
SKILLS_URL="${FLEET_SKILLS_URL:-http://127.0.0.1:8319/mcp}"
SKULD_URL="${FLEET_SKULD_URL:-http://127.0.0.1:8320}"
SNOTRA_URL="${FLEET_SNOTRA_URL:-http://127.0.0.1:8321/mcp}"
PORT_BASE="${FLEET_PORT_BASE:-8317}"
CHECK_ONLY=0
EMBED_MISSING=0
# the web-stack roots, resolved once per ensure (bin/fleet-ensure.sh sets them)
APP_DIR=""
VIZ_DIR=""
VIZ_DB=""
ENV_FILE=""
HLIDSKJALF_PORT="${HLIDSKJALF_PORT:-3888}"
HLIDSKJALF_API_PORT="${HLIDSKJALF_API_PORT:-3889}"
SMIDJA_PORT="${SMIDJA_VIZ_API_PORT:-8437}"

say() { printf '%s\n' "$*"; }

if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  for _fec in "$SCRIPT_DIR/app-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/app-lib.sh"; do
    [ -r "$_fec" ] && { . "$_fec"; YMIR_APP_LIB_LOADED=1; break; }
  done
  unset _fec
fi
if [ -z "${YMIR_SMIDJA_LIB_LOADED:-}" ]; then
  for _fec in "$SCRIPT_DIR/smidja-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/smidja-lib.sh"; do
    [ -r "$_fec" ] && { . "$_fec"; YMIR_SMIDJA_LIB_LOADED=1; break; }
  done
  unset _fec
fi

# Which unit files the templates can materialize (all programs + the target)
PROGRAM_UNIT_SRC() {  # <program> → the template path
  case "${1-}" in
    well-mcp|ratatoskr|mill-worker|cards|skills-mcp|skuld|snotra|embed)
      printf '%s\n' "$FLEET_TEMPLATE_ROOT/tools/mill/systemd/$1.service" ;;
    hlidskjalf-spa|hlidskjalf-gate|mimir|bifrost|smidja|nornir)
      printf '%s\n' "$FLEET_TEMPLATE_ROOT/tools/web/systemd/$1.service" ;;
    ymir.target)
      printf '%s\n' "$FLEET_TEMPLATE_ROOT/tools/web/systemd/ymir.target" ;;
    *) return 1 ;;
  esac
}

# ── the role-gated tool + unit materialization ──────────────────────────────
materialize_tools() {
  # 1) the heart's tools from the repo into the seat's fleet dir (dev seats take
  #    the well door; heart/forge seats the offices) — each copy is best-effort
  #    because the artifacts' ABSENCE is verified loudly AFTER the raise.
  mkdir -p "$DST"
  for pair in "tools/well-mcp/server.ts:well-mcp-server.ts" \
              "tools/ratatoskr-node/server.ts:ratatoskr-server.ts" \
              "tools/mill/worker.sh:mill-worker.sh" \
              "tools/skills-mcp/server.mjs:skills-mcp-server.mjs" \
              "tools/tickets-mcp/server.mjs:tickets-mcp-server.mjs" \
              "tools/snotra/server.mjs:snotra-server.mjs"; do
    src="${pair%%:*}"; dstn="${pair##*:}"
    [ -f "$ROOT/$src" ] && cp -f "$ROOT/$src" "$DST/$dstn" 2>/dev/null || true
  done
  # the meeting ear's operator commands — capture, transcribe, ensure — so any
  # seat can run them from ~/.fleet without a repo checkout on its PATH
  for f in snotra-capture.sh snotra-transcribe.sh snotra-ensure.sh runes-append.sh; do
    [ -f "$ROOT/bin/$f" ] && cp -f "$ROOT/bin/$f" "$DST/$f" 2>/dev/null && chmod +x "$DST/$f" 2>/dev/null || true
  done
  # the skills mirror — the master .agents/skills tree, refreshed each ensure
  if [ -d "$ROOT/.agents/skills" ]; then
    rm -rf "$DST/skills" && cp -r "$ROOT/.agents/skills" "$DST/skills" 2>/dev/null || true
  fi
  # the cards root — the seat's own agent card under /.well-known
  mkdir -p "$DST/cards-root/.well-known"
  if [ ! -f "$DST/cards-root/.well-known/agent-card.json" ]; then
    cat > "$DST/cards-root/.well-known/agent-card.json" <<CARD
{
  "name": "$(hostname -s 2>/dev/null || echo seat)",
  "description": "Ymir body seat — A2A node (:8301) · cards (:8318)",
  "url": "http://$(hostname -I 2>/dev/null | awk '{print $1}'):8301",
  "version": "1.0"
}
CARD
  fi
  [ -f "$DST/cards-root/index.html" ] || printf '<h1>Fleet cards — %s</h1>\n' "$(hostname -s)" > "$DST/cards-root/index.html"
  # the well venv (mcp-proxy wrapping engram-mcp) — materialized HERE, so a
  # seat never inherits the heart's hand-built venv path
  VENV="$DST/well-venv"
  if [ ! -x "$VENV/bin/mcp-proxy" ]; then
    if command -v python3 >/dev/null 2>&1; then
      python3 -m venv "$VENV" 2>/dev/null && "$VENV/bin/pip" -q install mcp-proxy "mcp<2" engram-mcp >/dev/null 2>&1
    fi
  fi
}

# ── the embed gate (A7): the stone is heart/forge-owed; nothing on this seat
# ── writes its unit unless BOTH artifacts exist — so a missing stone FAILS
# ── loudly with the remedy, and a unit that cannot run never loops.
embed_artifacts_present() {
  [ -x "$HOME/.fleet/embed/llama-server" ] && [ -f "$HOME/Models/embed/nomic-embed-text-v1.5.Q4_K_M.gguf" ]
}

materialize_embed() {
  # The stone rides the fleet's ONE canonical engine — the rail's binary,
  # /usr/local/bin/llama-server, which every heart/forge seat hosts (and whose
  # backends live beside it; a bare copy is a torso without limbs). The unit is
  # written ONLY when both artifacts stand; otherwise the seat fails LOUDLY
  # with the remedy — never a written unit, never a restart loop.
  if [ -x /usr/local/bin/llama-server ] && [ -f "$HOME/Models/embed/nomic-embed-text-v1.5.Q4_K_M.gguf" ]; then
    cp -f "$FLEET_TEMPLATE_ROOT/tools/mill/systemd/embed.service" "$HOME/.config/systemd/user/embed.service"
    refuse_disposable_path "$HOME/.config/systemd/user/embed.service" || return 1
    return 0
  fi
  say "fleet: embed — the embedding stone is owed (heart/forge) but cannot rise:" >&2
  [ -x /usr/local/bin/llama-server ] || say "fleet:   its engine is missing: /usr/local/bin/llama-server (the fleet rail binary)" >&2
  [ -f "$HOME/Models/embed/nomic-embed-text-v1.5.Q4_K_M.gguf" ] || \
    say "fleet:   its model is missing: ~/Models/embed/nomic-embed-text-v1.5.Q4_K_M.gguf" >&2
  say "fleet:   remedy: the rail binary stands on every heart/forge seat; the gguf at ~/Models/embed/ (hf.co/nomic-ai/nomic-embed-text-v1.5)" >&2
  say "fleet:   the unit is NOT written — a stone that cannot run must not restart forever" >&2
  return 1
}

# ── the web stack (A5): dev seats owe the doors as units ────────────────────
web_app_dirs() {  # resolve the app/viz/env/db roots once, into globals
  local _db=""
  if command -v hoard_local_env >/dev/null 2>&1; then hoard_local_env ENV_FILE 2>/dev/null || true; fi
  ENV_FILE="${ENV_FILE:-$HOME_ROOT/.env.local}"
  if command -v app_dir >/dev/null 2>&1; then app_dir hlidskjalf APP_DIR 2>/dev/null || true; fi
  if command -v smidja_visualizer_dir >/dev/null 2>&1; then smidja_visualizer_dir VIZ_DIR 2>/dev/null || true; fi
  if [ -z "$VIZ_DB" ]; then
    for _db in "$HOME_ROOT/smidja/smidja.db" "$ROOT/apps/smidja/smidja_data/smidja.db"; do
      [ -f "$_db" ] && { VIZ_DB="$_db"; break; }
    done
    VIZ_DB="${VIZ_DB:-$HOME_ROOT/smidja/smidja.db}"
  fi
}

# VIZ_DB may be overridden by the environment (SMIDJA_DB) — the resolved default
# above wins only when the operator did not pin one.
VIZ_DB="${SMIDJA_DB:-}"

materialize_web_unit() {  # <program> — substitute the per-seat roots into the template
  local p="$1" template dst
  template="$(PROGRAM_UNIT_SRC "$p")"
  dst="$HOME/.config/systemd/user/$p.service"
  sed -e "s|__YMIR_APP_DIR__|$APP_DIR|g" \
      -e "s|__YMIR_VIZ_DIR__|$VIZ_DIR|g" \
      -e "s|__YMIR_VIZ_DB__|$VIZ_DB|g" \
      -e "s|__YMIR_ENV_FILE__|$ENV_FILE|g" \
      -e "s|__YMIR_BIN_DIR__|$FLEET_TEMPLATE_ROOT/bin|g" \
      -e "s|__YMIR_OPERATOR_STATE__|$HOME_ROOT/state|g" \
      -e "s|__YMIR_OPERATOR_CONFIG__|$HOME_ROOT/config|g" \
      -e "s|__YMIR_HLIDSKJALF_PORT__|$HLIDSKJALF_PORT|g" \
      -e "s|__YMIR_HLIDSKJALF_API_PORT__|$HLIDSKJALF_API_PORT|g" \
      -e "s|__YMIR_SMIDJA_PORT__|$SMIDJA_PORT|g" \
      "$template" > "$dst"
  refuse_disposable_path "$dst" || return 1
}

materialize_units() {  # <owed...> — every owed unit + the target; purge the stale
  local owed="$1" p="" i=0
  # the ONE target, every seat
  cp -f "$FLEET_TEMPLATE_ROOT/tools/web/systemd/ymir.target" "$HOME/.config/systemd/user/ymir.target"
  refuse_disposable_path "$HOME/.config/systemd/user/ymir.target" || return 1
  mkdir -p "$HOME/.config/systemd/user"
  for p in $owed; do
    case "$p" in
      embed)
        case " $AUTOBOOT_HOST_ROLES " in *heart*|*forge*) ;;
          *) say "fleet: embed not owed here (roles: $AUTOBOOT_HOST_ROLES)" ;; esac
        materialize_embed || EMBED_MISSING=1
        ;;
      hlidskjalf-spa|hlidskjalf-gate|mimir|bifrost|smidja|nornir)
        materialize_web_unit "$p"
        ;;
      *)  # the mill/offices — %h-native templates, copied as they ship
        if [ -f "$(PROGRAM_UNIT_SRC "$p")" ]; then
          cp -f "$(PROGRAM_UNIT_SRC "$p")" "$HOME/.config/systemd/user/$p.service"
          refuse_disposable_path "$HOME/.config/systemd/user/$p.service" || return 1
        else
          say "fleet: $p — no unit template (tools/mill/systemd/$p.service missing)" >&2
          EMBED_MISSING=1  # any missing template is a loud gap, not a skip
        fi
        ;;
    esac
  done
}

purge_stale_units() {  # <owed...> — units NOT owed must not stand (a stale unit
  # is how the old lie survived: enabled by an earlier hand, looping forever).
  # ymir.target is OWED BY EVERY SEAT — never a purge candidate.
  local owed="$1" p=""
  for p in $AUTOBOOT_PROGRAMS; do
    case " $owed " in *" $p "*) continue ;; esac
    if [ -f "$HOME/.config/systemd/user/$p.service" ] || \
       systemctl --user is-enabled --quiet "$p.service" 2>/dev/null || \
       [ -e "$HOME/.config/systemd/user/ymir.target.wants/$p.service" ] || \
       [ -e "$HOME/.config/systemd/user/default.target.wants/$p.service" ]; then
      systemctl --user stop "$p.service" 2>/dev/null || true
      systemctl --user disable "$p.service" 2>/dev/null || true
      rm -f "$HOME/.config/systemd/user/$p.service" "$HOME/.config/systemd/user/"*.target.wants/"$p.service" 2>/dev/null || true
      systemctl --user reset-failed "$p.service" 2>/dev/null || true
      say "fleet: purged stale unit $p.service (not owed by roles: $AUTOBOOT_HOST_ROLES)"
    fi
  done
}

# ── linger (A4): a headless seat's boot needs it, or nothing rises ──────────
linger_assert() {  # exit 0 on ok; prints the value and the remedy when it fails
  local v
  v="$(autoboot_linger)"
  say "fleet: Linger=$v (loginctl show-user $USER -p Linger)"
  if [ "$v" = "yes" ]; then return 0; fi
  if ! autoboot_is_headless; then
    say "fleet: display seat — units rise with the login session; linger left as-is"
    return 0
  fi
  if loginctl enable-linger "$USER" 2>/dev/null; then
    v="$(autoboot_linger)"
    say "fleet: Linger enabled -> $v"
    [ "$v" = "yes" ] && return 0
  fi
  say "fleet: FAIL — Linger=no on a headless seat means NOTHING rises at boot" >&2
  say "fleet:   remedy: sudo loginctl enable-linger $USER   (run by the seat's admin)" >&2
  return 1
}

# ── retire the manual stack (A5) ─────────────────────────────────────────────
# The web stack used to be "run scripts/start.sh and hope" — pid-file daemons
# nothing at boot called. The units now own those ports, so the old daemons
# must retire or the unit's first start collides with a process the platform
# no longer supervises. The pid files and the bridge scripts know their own;
# the raise only takes over what the unit set is about to own.
retire_manual_stack() {
  # A pid file names the daemon it launched — but start.sh's wrappers fork
  # children (npm → vite, bun) that hold the port after the parent dies, so a
  # pid-file kill leaves a ghost on the very port the unit must bind. Kill by
  # PORT: what listens is what the unit will fight.
  retire_port() {  # <port>
    local port="$1" pid=""
    pid="$(ss -tlnpH 2>/dev/null | awk -v p=":$port" '$4 ~ p { gsub(/.*pid=/,"",$6); gsub(/,.*/,"",$6); print $6; exit }')"
    [ -n "$pid" ] || pid="$(lsof -ti tcp:"$port" 2>/dev/null | head -1 || true)"
    case "$pid" in
      ''|*[!0-9]*) return 0 ;;
    esac
    kill "$pid" 2>/dev/null && say "fleet: retired the listener on :$port (pid $pid)" || true
    wait 2>/dev/null || true
  }
  retire_port "${HLIDSKJALF_PORT:-3888}"
  retire_port "${HLIDSKJALF_API_PORT:-3889}"
  retire_port "${SMIDJA_VIZ_API_PORT:-8437}"
  local f
  for f in "$ROOT/.run/hlidskjalf.pid" "$ROOT/.run/hlidskjalf-api.pid" "$ROOT/.run/smidja-viz-api.pid"; do
    rm -f "$f"
  done
  if [ -x "$ROOT/bin/mimir-bridge.sh" ]; then
    "$ROOT/bin/mimir-bridge.sh" --stop >/dev/null 2>&1 && say "fleet: retired the manual well bridge" || true
  fi
  if [ -x "$ROOT/bin/bifrost-bridge.sh" ]; then
    "$ROOT/bin/bifrost-bridge.sh" --stop >/dev/null 2>&1 && say "fleet: retired the manual model bridge" || true
  fi
}

# ── the raise: enable THE target, enable+start every owed unit, then VERIFY ──
raise_units() {  # <owed...>
  local owed="$1" p="" fail=0
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  if systemctl --user enable ymir.target >/dev/null 2>&1; then
    say "fleet: ymir.target enabled (the one object boot pulls)"
  else
    say "fleet: FAIL — could not enable ymir.target" >&2; fail=1
  fi
  for p in $owed; do
    case "$p" in
      embed) [ "${EMBED_MISSING:-0}" = 1 ] && continue ;;
    esac
    if systemctl --user enable --now "$p.service" >/dev/null 2>&1; then
      say "fleet: $p.service enabled + started"
    else
      say "fleet: FAIL — could not raise $p.service (systemctl --user enable --now $p.service)" >&2
      fail=1
    fi
  done
  return "$fail"
}

# ── the whole truth, after the raise ────────────────────────────────────────
raise_verify() {  # <owed...>
  # A verify raced against the first boot reads "activating"/"inactive" for a
  # unit that IS rising — a race the platform calls a lie worth removing. Wait
  # for the just-started units to settle (bounded), then prove them.
  local owed="$1" p="" settle=$((SECONDS+30))
  while [ "$SECONDS" -lt "$settle" ]; do
    local settled=1
    for p in $owed; do
      autoboot_is_unit_active "$p" || { settled=0; break; }
    done
    [ "$settled" = 1 ] && break
    sleep 1
  done
  local ver
  if [ -x "$SCRIPT_DIR/ymir-autoboot.sh" ]; then
    "$SCRIPT_DIR/ymir-autoboot.sh" verify --quiet
    ver=$?
  else
    ver=1
  fi
  if [ "$ver" = 0 ]; then
    say "fleet: verified — every role-owed program is enabled and standing"
  else
    say "fleet: FAIL — a role-owed program is not rising; the rows above name them" >&2
  fi
  return "$ver"
}

# ── the seat's pi mcp.json wiring (the doors the harness drinks from) ──────
wire_mcp() {  # role-aware: the well door is local (every seat hosts its own);
  # bolthorn (:8319) and skuld (:8320) live on the HEART — a dev seat drinks
  # them over the tailnet, and the heart drinks its own. The old "write
  # localhost to every seat" line is how the Allfather's doors pointed at
  # ghosts on a seat that never hosted them.
  mkdir -p "$HOME/.pi/agent"
  python3 - "$WELL_URL" "$SKILLS_URL" "$SKULD_URL" "$SNOTRA_URL" "$AUTOBOOT_HOST_ROLES" "$AUTOBOOT_FLEET_REGISTRY" "$HOME" <<'PY'
import json, os, sys
well, skills, skuld, snotra, roles, reg, home = sys.argv[1:8]
if "heart" not in (roles or "").split():
    # a dev/forge/hand seat drinks the heart's doors; resolve the heart's base
    # from the fleet registry (tailnet MagicDNS preferred, LAN fallback)
    try:
        doc = json.load(open(reg))
        heart = (doc.get("heart") or "")
        row = (doc.get("hosts") or {}).get(heart, {})
        base = (row.get("tailnet") or row.get("lan") or "").split("://")[-1]
        if base:
            skills = "http://%s:8319/mcp" % base
            skuld = "http://%s:8320" % base
            snotra = "http://%s:8321/mcp" % base
    except Exception:
        pass
p = os.path.join(home, ".pi/agent/mcp.json")
try: d = json.load(open(p))
except Exception: d = {}
d.setdefault("mcpServers", {})
d["mcpServers"]["well"] = {"url": well}
d["mcpServers"]["bolthorn"] = {"url": skills}
d.setdefault("mcpServers", {})["skuld"] = {"url": skuld}
d.setdefault("mcpServers", {})["snotra"] = {"url": snotra}
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump(d, open(p, "w"), indent=2)

# OpenCode's GLOBAL config too: it is project-scoped, so a seat's own well door
# must live here or a run outside this checkout loses the well. The URL is this
# seat's door (loopback), never a LAN IP of another host (Rule 07).
ocp = os.path.join(home, ".config/opencode/opencode.json")
try: oc = json.load(open(ocp))
except Exception: oc = {}
oc.setdefault("mcp", {})
oc["mcp"]["well"] = {"type": "remote", "url": well}
os.makedirs(os.path.dirname(ocp), exist_ok=True)
json.dump(oc, open(ocp, "w"), indent=2)
PY
}

status() {
  if [ -x "$SCRIPT_DIR/ymir-autoboot.sh" ]; then
    "$SCRIPT_DIR/ymir-autoboot.sh" status
  else
    say "error: no ymir-autoboot.sh — the proof is missing" >&2
    return 1
  fi
}

ensure() {
  local owed="" roles=""
  EMBED_MISSING=0
  autoboot_owed_roles AUTOBOOT_HOST_ROLES
  autoboot_owed owed
  say "fleet: $AUTOBOOT_HOST owes (${AUTOBOOT_HOST_ROLES}): $owed"
  mkdir -p "$HOME/.config/systemd/user"
  materialize_tools
  web_app_dirs
  if [ "$CHECK_ONLY" = 1 ]; then
    say "fleet: (check) would materialize + raise: $owed"
    return 0
  fi
  materialize_units "$owed"
  purge_stale_units "$owed"
  linger_assert || return 1
  retire_manual_stack
  wire_mcp
  raise_units "$owed" || return 1
  raise_verify "$owed"
}

case "${1-}" in
  status) status ;;
  verify)
    if [ -x "$SCRIPT_DIR/ymir-autoboot.sh" ]; then
      shift; "$SCRIPT_DIR/ymir-autoboot.sh" verify "${1-}"
    else
      say "error: no ymir-autoboot.sh — the proof is missing" >&2
      exit 1
    fi
    ;;
  ensure) shift; while [ $# -gt 0 ]; do
      case "$1" in
        --well-url) WELL_URL="${2-}"; shift 2 ;;
        --check) CHECK_ONLY=1; shift ;;
        *) say "error: unknown flag $1" >&2; exit 2 ;;
      esac
    done; ensure ;;
  *) say "error: unknown command (status|ensure|verify)" >&2; exit 2 ;;
esac