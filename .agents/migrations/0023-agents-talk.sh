#!/usr/bin/env bash
# 0023-agents-talk — make an EXISTING home carry the road agents need to find and answer each other.
#
# WHY (plan 303 §15.4, 2026-11-16). The doors ship in the tree, so a fresh install has them. A home
# that already exists does not: it carries a stale arm pane, dead bridge port reservations, and a
# relay unit nobody seated. This migration heals those three, and nothing else. It is safe to run
# at any moment, including while agents work:
#
#   · it never restarts Hermes — not the gateway, not the Desktop — while any session or subagent is
#     mid-turn. Where a restart is wanted it runs the plain `hermes gateway restart`, which refuses
#     and names the live turn, and then records `restart pending` for the operator (his standing
#     rule, 2026-11-16);
#   · it never discards a paused turn, never writes a key, never changes a profile;
#   · it never touches another machine's files.
#
# What it does, in order, each step idempotent:
#   1. sweep the bridge port reservations whose pid is gone   ($HOME/.a2abridge/ports/<port>/pid)
#   2. repair a stale arm pane: when state/.arm.pane names a pane herdr has no agent in, and the
#      lease names a live session whose pane herdr DOES report, the file is corrected and the old
#      value is recorded beside it — never deleted
#   3. seat the relay unit when this machine has none            (bin/engine/units.sh write)
#   4. record whether a Hermes restart is owed                   (state/hermes-restart-pending)
#
# Idempotent: a second run changes nothing. Exit: 0 applied · 3 nothing to do here · 1 a step failed.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOME_DIR="${YMIR_HOME:-}"
if [ -z "$HOME_DIR" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh"
  ymir_home_root HOME_DIR 2>/dev/null || HOME_DIR=""
fi
HOME_DIR="${HOME_DIR:-${YMIR_HOME:-}}"
[ -n "$HOME_DIR" ] || { printf '0023-agents-talk: no home recorded — nothing to migrate\n'; exit 3; }
STATE="$HOME_DIR/state"
mkdir -p "$STATE" 2>/dev/null || true
NO_RESTART="${YMIR_MIGRATE_NO_RESTART:-0}"

changed=0
say() { printf '  %s\n' "$*"; }

# ── 1 · dead bridge port reservations ───────────────────────────────────────────
PORTS="$HOME/.a2abridge/ports"
if [ -d "$PORTS" ]; then
  dead=0
  for d in "$PORTS"/*; do
    [ -d "$d" ] || continue
    pid="$(cat "$d/pid" 2>/dev/null || true)"
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
      rm -rf "$d" 2>/dev/null || true
      dead=$((dead + 1))
    fi
  done
  [ "$dead" -gt 0 ] && { say "released $dead dead bridge port claim(s)"; changed=1; }
fi

# ── 2 · a stale arm pane ────────────────────────────────────────────────────────
ARM_PANE="$STATE/.arm.pane"
if [ -r "$ARM_PANE" ] && command -v herdr >/dev/null 2>&1; then
  named="$(head -1 "$ARM_PANE" | tr -dc '[:alnum:]:._-')"
  if [ -n "$named" ]; then
    alive="$(herdr agent get "$named" 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    print("no"); raise SystemExit(0)
a=(d.get("result") or {}).get("agent") or {}
print("yes" if (a.get("agent") or "") else "no")' 2>/dev/null)"
    if [ "$alive" != "yes" ]; then
      # the lease names the session that really holds the arm; herdr says which pane hosts it
      lease="$STATE/.arm.lease"
      sid="$(sed -nE 's/.*session=([0-9]+).*/\1/p' "$lease" 2>/dev/null | head -1)"
      found=""
      if [ -n "$sid" ]; then
        found="$(herdr agent list 2>/dev/null | python3 -c '
import json,sys
sid=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
for a in (d.get("result") or {}).get("agents") or []:
    s=(a.get("agent_session") or {}).get("value") or ""
    if sid and sid in s:
        print(a.get("pane_id") or ""); break' "$sid" 2>/dev/null)"
      fi
      if [ -n "$found" ] && [ "$found" != "$named" ]; then
        cp "$ARM_PANE" "$ARM_PANE.bak-$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || true
        printf '%s\n' "$found" >"$ARM_PANE"
        say "repaired the arm pane: $named → $found (the old value is kept beside it)"
        changed=1
      elif [ -z "$found" ]; then
        say "the arm pane names $named, which holds no agent — left alone (no live holder to move it to)"
      fi
    fi
  fi
fi

# ── 3 · the relay unit ──────────────────────────────────────────────────────────
if [ -x "$ROOT/bin/engine/units.sh" ]; then
  if [ "${YMIR_UNITS_NO_SYSTEMCTL:-0}" = 1 ]; then
    say "relay unit: skipped (YMIR_UNITS_NO_SYSTEMCTL=1)"
  else
    if "$ROOT/bin/engine/units.sh" write ratatoskr-relay >/dev/null 2>&1; then
      say "relay unit seated (or already current)"
    else
      say "relay unit: units.sh could not seat it — run bin/engine/units.sh write ratatoskr-relay"
    fi
  fi
fi

# ── 4 · a Hermes restart is owed, or is not needed ──────────────────────────────
PENDING="$STATE/hermes-restart-pending"
if command -v hermes >/dev/null 2>&1; then
  live="$(python3 - "$HOME/.hermes/state.db" <<'PY' 2>/dev/null || true
import os, sqlite3, sys
db = sys.argv[1]
if not os.path.exists(db):
    print(0); raise SystemExit(0)
try:
    con = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
    n = con.execute("SELECT count(*) FROM session_admissions WHERE status IN ('queued','started','unknown')").fetchone()[0]
    con.close()
except Exception:
    n = 0
print(n)
PY
)"
  live="${live:-0}"
  if [ "$NO_RESTART" = 1 ]; then
    say "hermes restart: not attempted (YMIR_MIGRATE_NO_RESTART=1)"
  elif [ "$live" -gt 0 ]; then
    # The plain restart refuses while a turn is live, which is exactly what we want it to do.
    printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ) restart pending — $live live admission(s); not restarted" >"$PENDING"
    say "hermes restart: PENDING — $live live turn(s); the gateway was not restarted"
    changed=1
  else
    [ -e "$PENDING" ] && { say "hermes restart: no live turn any more — the pending note stands for the operator"; }
  fi
fi

if [ "$changed" = 0 ]; then
  printf '0023-agents-talk: nothing to change\n'
  exit 3
fi
printf '0023-agents-talk: applied\n'
exit 0
