#!/usr/bin/env bash
# 0008-room — Gladsheim, the fleet room: seat its role on an existing home.
#
# The room's engine runs ONCE per operator install (plan 75 Part 9/11): here on a lone
# box, ON THE HEART in a fleet. So this migration must be ROLE-AWARE — it seats the role
# the machine's shape implies and, on a seat that is not the heart, SKIPS CLEANLY rather
# than raising a second homeserver. It asks bin/fleet/topology.sh; it never re-derives the
# shape (plan 76 — the shape law).
#
# It is IDEMPOTENT: every branch is guarded, so a second run changes nothing, and a home
# that already carries the room pays the cost of a status check.
#
# THE LAW: the home is the vault (Rule 04) and a private git repo, so nothing here deletes
# or rewrites; it only ensures. A machine the room does not apply to is told so plainly.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=bin/vault/hoard-lib.sh
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
HOME_DIR=""
command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR
[ -n "$HOME_DIR" ] || HOME_DIR="${YMIR_HOME:-}"
[ -n "$HOME_DIR" ] || { printf '0008: no home resolved — nothing touched\n'; exit 0; }
[ -f "$HOME_DIR/hodd/memory/runes_audit.md" ] || {
  printf '0008: %s is not a Ymir home (no hodd/memory/runes_audit.md) — nothing touched\n' "$HOME_DIR"
  exit 0
}

ENS="$ROOT/bin/room/gladsheim-ensure.sh"
[ -x "$ENS" ] || { printf '0008: no bin/room/gladsheim-ensure.sh — nothing touched\n'; exit 0; }

# ── seat the role the shape implies (ensure itself asks topology.sh) ─────────
_out="$(timeout 120 "$ENS" ensure 2>&1 || true)"
printf '%s\n' "$_out" | sed 's/^/0008: /'

# ── a client config, if the home has none yet (so the door can speak) ────────
CFG="$HOME_DIR/config/room.yaml"
if [ ! -r "$CFG" ]; then
  mkdir -p "$(dirname "$CFG")"
  cat > "$CFG" <<'EOF'
# Gladsheim — the fleet room's configuration (seeded by migration 0008).
# Private; belongs to the hoard, never the repo. Fill in the homeserver, the server name,
# the room, and this machine's own agent NAME (the install asks the operator for it).
homeserver: "http://127.0.0.1:8008"
server_name: "gladsheim.local"
room: ""
agents: {}
EOF
  printf '0008: seeded %s (homeserver · server_name · room · this machine’s agent name)\n' "$CFG"
else
  printf '0008: %s already present — left untouched\n' "$CFG"
fi

printf '0008: the room is seated for this machine’s role — bin/room/gladsheim.sh status\n'
exit 0
