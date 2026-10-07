#!/usr/bin/env bash
# syn-watch-arm.sh — the ARM as a SERVICE, and this is its thin client.
#
# Sýn ("the one who sees") watches the runtime state and raises an actionable
# `signal:`/`stale:`/`check:`/`heartbeat:` line when the primary is needed. The
# Pi/OpenCode extensions (gna-pi-watch, syn-watch-arm.js) own the session side:
# they spawn this client, relay whatever it prints, deliver the wake, and spawn
# the next one.
#
# What changed, and why (plan 58, Phase 2 — 2026-09-27): the WATCH LOOP used to
# live in this file, so it lived and died with the session. When the session's
# lock owner went away the loop printed `watcher: retired - session lock is no
# longer held` and exited 0 in silence — a silent close the harness reads as
# "ended without an actionable reason", then retries and flaps. On 2026-09-27 it
# flapped all day and needed three hand re-arms.
#
# Now the loop is bin/pi/syn-watch.sh run — a standing service with its own lease
# that IDLES (never retires) when no session is seated and is restarted when it
# dies — and THIS file is the thin client:
#
#   · it enters a vacant helm (bin/vault/gleipnir-lock-lib.sh) exactly as before;
#   · it seats/attaches to the arm service for this home;
#   · it prints the same lines, in the same grammar, and exits when one is raised;
#   · the session's death no longer kills the watch.
#
# CLI (unchanged, so every harness adapter works as it stands):
#   syn-watch-arm.sh --restart
#   syn-watch-arm.sh --handling-delivered <generation> --watcher-pid <pid>
#
# `BROKK_WATCH_INLINE=1` keeps the watch loop in this process — the pre-service
# shape, for a probe or a host with no way to seat a daemon.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
# The wake queue is written by the Eindri handoff (bin/agents/eindri-acclaim.sh) into the
# OPERATOR'S HOME state — never the code tree. Both sides resolve it the same way,
# through bin/vault/hoard-lib.sh. The watcher must read the SAME queue: it once defaulted
# to the tree's state dir, so the handoff filled one queue and the watcher watched
# another, and no wake ever surfaced (2026-09-23). Same order of authority as the lib.
_STATE_GIVEN="${BROKK_STATE_OVERRIDE:-}"
if [ -z "${BROKK_STATE_OVERRIDE:-}" ]; then
  if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
    for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
      [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
    done
    unset _c
  fi
  hoard_state_dir _HS 2>/dev/null && BROKK_STATE_OVERRIDE="$_HS"
  unset _HS
fi
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
# shellcheck source=bin/vault/gleipnir-lock-lib.sh
. "$SCRIPT_DIR/../vault/gleipnir-lock-lib.sh"

WATCH="$SCRIPT_DIR/syn-watch.sh"
POLL_SECONDS="${BROKK_WATCH_POLL_SECONDS:-5}"
DAEMON_GRACE_SECONDS="${BROKK_WATCH_DAEMON_GRACE_SECONDS:-15}"

EVENT="$STATE/.arm.event"
LEASE="$STATE/.arm.lease"

# The delivery confirmation the extension sends back once the wake it relayed has
# been handled and a successor is ready. It carries the generation this client
# printed, so the record names what was handled.
if [ "${1-}" = "--handling-delivered" ]; then
  generation=${2-}
  watcher_pid=${4-}
  mkdir -p "$STATE" 2>/dev/null || true
  [ -n "$generation" ] && printf '%s\n' "$generation" >"$STATE/.arm.handled" 2>/dev/null || true
  printf 'watcher: handling delivered generation=%s watcher-pid=%s\n' "$generation" "$watcher_pid"
  exit 0
fi

mkdir -p "$STATE"

# CATCH-UP ON RE-ARM (plan 58 Phase 3). The moment this arm recovers — the Pi
# extension's re-arm after a flap, a repair, or session start — reconcile what
# the dead window missed: sweep the handoff shelves into the durable wake queue
# BEFORE the lock and the poll loop, so recovery is never blind and an arm that
# is refused read-only has still reconciled. Idempotent via the shared ledger
# (bin/agents/eindri-wake-lib.sh); the cycle sweep below is the steady-state form.
CATCH_UP=0
if [ -x "$SCRIPT_DIR/../agents/eindri-handoff.sh" ]; then
  _handoff_out="$(BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/../agents/eindri-handoff.sh" sweep 2>/dev/null)" || true
  CATCH_UP="$(printf '%s\n' "$_handoff_out" | sed -n 's/.*"sweep",\([0-9][0-9]*\),.*/\1/p' | head -n1)"
  [ -n "$CATCH_UP" ] || CATCH_UP=0
  printf 'watcher: catch-up sweep delivered=%s\n' "$CATCH_UP"
  unset _handoff_out
fi

[ -x "$WATCH" ] || { printf 'watcher: FAILED - the arm service door is missing: %s\n' "$WATCH" >&2; exit 1; }

# ── the helm ────────────────────────────────────────────────────────────────
# A live-session contract: enter a VACANT helm (no owner, or an owner verifiably
# gone) through the lib's acquire; only a genuinely live other session is refused.

lock_owner=$(gleipnir_lock_owner _lo 2>/dev/null; printf '%s' "${_lo:-}")
if [ -z "$lock_owner" ] || ! gleipnir_pid_alive "$lock_owner"; then
  if ! gleipnir_lock_acquire; then
    printf 'watcher: read-only - the session helm is held by another live session\n' >&2
    exit 0
  fi
fi

lease_alive() {
  local pid st state
  [ -r "$LEASE" ] || return 1
  pid=$(sed -n 's/^pid=\([^ ]*\).*/\1/p' "$LEASE" | head -1)
  st=$(sed -n 's/.*starttime=\([^ ]*\).*/\1/p' "$LEASE" | head -1)
  state=$(sed -n 's/.* state=//p' "$LEASE" | head -1)
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  [ "$state" = "$STATE" ] || return 1
  gleipnir_pid_alive "$pid" "$st"
}

lease_part() {  # <key> — one field of the live lease
  [ -r "$LEASE" ] || return 0
  awk -v k="$1=" '{ for (i = 1; i <= NF; i++) if (index($i, k) == 1) { print substr($i, length(k) + 1); exit } }' "$LEASE" 2>/dev/null || true
}

# ── the inline shape (pre-service; opt-in only) ─────────────────────────────
if [ "${BROKK_WATCH_INLINE:-0}" = 1 ]; then
  printf 'watcher: started pid=%s recovery-generation=inline-%s\n' "$$" "$$"
  printf 'watcher: attached - inline watch loop (BROKK_WATCH_INLINE=1) state=%s\n' "$STATE"
  exec "$WATCH" run --emit
fi

# ── the service ─────────────────────────────────────────────────────────────
next_gen="$(cat "$STATE/.arm.gen" 2>/dev/null || true)"
case "$next_gen" in ''|*[!0-9]*) next_gen=0 ;; esac
# Readiness is declared BEFORE the seat is proven, so a seat that cannot rise is
# relayed as an actionable line rather than a silent close the harness retries.
printf 'watcher: started pid=%s recovery-generation=svc.0.%s\n' "$$" "$((next_gen + 1))"

lease_alive || "$WATCH" start >/dev/null 2>&1 || true
if ! lease_alive; then
  printf 'stale: arm service is down - no live lease for %s (remedy: bin/pi/syn-watch.sh start)\n' "$STATE"
  exit 0
fi
svc_pid="$(lease_part pid)"
svc_gen="$(lease_part gen)"
svc_mode="$(lease_part mode)"
printf 'watcher: attached - arm service up pid=%s mode=%s gen=%s recovery-generation=svc.%s.%s state=%s\n' \
  "${svc_pid:-none}" "${svc_mode:-unknown}" "${svc_gen:-0}" "${svc_pid:-0}" "${svc_gen:-0}" "$STATE"

# ── relay ───────────────────────────────────────────────────────────────────
# The service raises ONE line into .arm.event; this client carries it out and
# exits, exactly as the old loop did when it ended on an actionable line.
deliver_pending() {
  local line
  [ -s "$EVENT" ] || return 1
  line="$(head -n1 "$EVENT" 2>/dev/null || true)"
  [ -n "$line" ] || return 1
  # A line raised between the read and the removal must not be swallowed.
  [ "$(head -n1 "$EVENT" 2>/dev/null || true)" = "$line" ] || return 1
  rm -f "$EVENT" 2>/dev/null || true
  printf '%s\n' "$line"
}

if deliver_pending; then exit 0; fi

down_since=0
while :; do
  sleep "$POLL_SECONDS"
  if deliver_pending; then exit 0; fi
  if ! lease_alive; then
    # A systemd restart is invisible here: it is back inside the grace window.
    # Past the grace the client re-seats the service itself — a dead arm that can
    # be raised again is not news the model needs; one that cannot is.
    [ "$down_since" = 0 ] && down_since="$(date -u +%s)"
    if [ "$(( $(date -u +%s) - down_since ))" -ge "$DAEMON_GRACE_SECONDS" ]; then
      "$WATCH" start >/dev/null 2>&1 || true
      if lease_alive; then
        printf 'watcher: re-seated the arm service pid=%s state=%s\n' "$(lease_part pid)" "$STATE" >&2
        down_since=0
      else
        printf 'stale: arm service is down - the watch could not be re-seated (remedy: bin/pi/syn-watch.sh status)\n'
        exit 0
      fi
    fi
  else
    down_since=0
  fi
done
