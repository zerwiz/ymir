#!/usr/bin/env bash
# desk-ceiling.sh — the desk gets a ceiling, so one heavy neighbour kills a hand and not the hall.
#
# Why (plan 001 §4 F1, measured 2026-11-17): `herdr-server.service` had no `MemoryMax` at all and
# reached a 4.8 GB peak with 965 MB of swap over two days. At 07:20:59 the kernel's OOM killer took
# one `opencode` inside that unit's cgroup, systemd marked the unit `oom-kill` and RESTARTED it, and
# 27 panes came back as bare shells. One death took every hand because nothing bounded the pot.
#
# Two faults, two properties:
#
#   · the pot had no bound          → `MemoryHigh` (throttle) and `MemoryMax` (kill) and
#                                     `MemorySwapMax` (a bounded leak into swap), sized from what
#                                     THIS machine measures, never from a number in a document.
#   · a child's death stopped the   → `OOMPolicy=continue`: one process killed inside the unit no
#     whole unit (systemd's default       longer stops, and therefore no longer restarts, the desk.
#     for a service is `stop`)
#
# The sizing rule, and every number below is measured at the moment the door runs:
#
#   total   = `free -m`'s Mem total
#   high    = 30 % of total   — past this the desk is throttled, so it bleeds slowly instead of dying
#   max     = 40 % of total   — past this the kernel kills INSIDE the unit, never the machine
#   swapmax = 25 % of swap    — a desk may not eat the machine's swap either
#
# The arithmetic is printed with the numbers, because a ceiling nobody can explain is a wish.
#
# Usage:
#   desk-ceiling.sh choose           # the measurement, the arithmetic, the properties
#   desk-ceiling.sh apply            # write the drop-in, daemon-reload, and set it LIVE (no restart)
#   desk-ceiling.sh show             # what the unit reports right now
#   desk-ceiling.sh --check          # exit 0 when a ceiling and a continue-policy are in force
#
# Env (all optional):
#   YMIR_DESK_UNIT          the unit (default: herdr-server.service)
#   YMIR_DESK_HIGH_PCT      default 30
#   YMIR_DESK_MAX_PCT       default 40
#   YMIR_DESK_SWAP_PCT      default 25
#   YMIR_DESK_DROPIN_DIR    where the drop-in is written (default: the unit's own
#                           `~/.config/systemd/user/<unit>.d`), so a test never writes the real one
#   YMIR_DESK_FREE_MB       / YMIR_DESK_SWAP_MB   inject a measurement (tests, and a replay)
#
# Never restarts anything: `set-property` applies the limits to the RUNNING unit, which is the whole
# point of a failsafe — it must not need the death it prevents (the Allfather's fence, plan 001).
#
# Exit: 0 ok · 1 the ceiling is not in force (check) · 2 usage · 3 no systemd user manager here.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

UNIT="${YMIR_DESK_UNIT:-herdr-server.service}"
HIGH_PCT="${YMIR_DESK_HIGH_PCT:-30}"
MAX_PCT="${YMIR_DESK_MAX_PCT:-40}"
SWAP_PCT="${YMIR_DESK_SWAP_PCT:-25}"
DROPIN_DIR="${YMIR_DESK_DROPIN_DIR:-$HOME/.config/systemd/user/${UNIT}.d}"
DROPIN_NAME="20-desk-ceiling.conf"

usage() { sed -n '2,53p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
say()  { printf '%s\n' "$*"; }
die()  { printf 'desk-ceiling: %s\n' "$*" >&2; exit 1; }
skip() { printf 'desk-ceiling: %s\n' "$*" >&2; exit 0; }
have() { command -v "$1" >/dev/null 2>&1; }

# ── the measurement ───────────────────────────────────────────────────────────
# `free -m` is the machine's own answer and is present on every Linux seat. The swap figure matters
# as much as the memory: the death of 2026-11-17 happened with 216 kB of 4 GB left.
mem_total_mb() {
  if [ -n "${YMIR_DESK_FREE_MB:-}" ]; then printf '%s' "$YMIR_DESK_FREE_MB"; return 0; fi
  free -m 2>/dev/null | awk '/^Mem:/{print $2}' | head -1
}
swap_total_mb() {
  if [ -n "${YMIR_DESK_SWAP_MB:-}" ]; then printf '%s' "$YMIR_DESK_SWAP_MB"; return 0; fi
  free -m 2>/dev/null | awk '/^Swap:/{print $2}' | head -1
}
# The unit's own peak, so the record of what it has asked for is printed with the ceiling.
peak_mb() {
  local b
  b="$(systemctl --user show "$UNIT" -p MemoryPeak 2>/dev/null | sed -n 's/^MemoryPeak=//p')"
  case "$b" in ''|*[!0-9]*) printf '0'; return 0 ;; esac
  printf '%s' "$((b / 1024 / 1024))"
}

pct_of() {  # <value> <percent>
  local v=$1 p=$2
  case "$v" in ''|*[!0-9]*) printf '0'; return 0 ;; esac
  printf '%s' "$((v * p / 100))"
}

# ── the choice ────────────────────────────────────────────────────────────────
choose() {
  local total swap peak high max swapmax free_now
  total="$(mem_total_mb)"; swap="$(swap_total_mb)"
  [ -n "$total" ] && [ "$total" -gt 0 ] 2>/dev/null \
    || die "this machine reports no memory total — the ceiling cannot be sized, and a guessed ceiling is a wish"
  peak="$(peak_mb)"
  high="$(pct_of "$total" "$HIGH_PCT")"
  max="$(pct_of "$total" "$MAX_PCT")"
  swapmax="$(pct_of "$swap" "$SWAP_PCT")"
  free_now="$(free -m 2>/dev/null | awk '/^Mem:/{print $7}' | head -1)"
  printf 'desk-ceiling[1]{unit,total_mb,peak_mb,free_mb,high_pct,high_mb,max_pct,max_mb,swap_total_mb,swap_pct,swap_max_mb}:\n'
  printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
    "$UNIT" "$total" "${peak:-0}" "${free_now:-?}" "$HIGH_PCT" "$high" "$MAX_PCT" "$max" "$swap" "$SWAP_PCT" "$swapmax"
  printf 'desk-ceiling-rule[3]{property,value,why}:\n'
  printf '  "MemoryHigh","%sM","%s%% of MemTotal — past this the desk is throttled, so it bleeds instead of dying"\n' "$high" "$HIGH_PCT"
  printf '  "MemoryMax","%sM","%s%% of MemTotal — past this the kernel kills inside the unit, never the machine"\n' "$max" "$MAX_PCT"
  printf '  "MemorySwapMax","%sM","%s%% of swap — the desk may not eat the machine'"'"'s swap either"\n' "$swapmax" "$SWAP_PCT"
  printf '  "OOMPolicy","continue","a child killed by the OOM killer must not stop (and so restart) the whole desk"\n'
  # A ceiling below what the desk actually uses would strangle it; say so rather than pretend.
  if [ "${peak:-0}" -gt "$max" ] 2>/dev/null; then
    printf 'disagree[1]{fact,note}:\n  "peak %s MB exceeds the %s MB ceiling — this desk has grown past the ruling; raise YMIR_DESK_MAX_PCT or find what holds it"\n' "$peak" "$max" >&2
  fi
}

# ── apply ─────────────────────────────────────────────────────────────────────
# The drop-in is the durable half: it survives a rewrite of the unit file (the seat-keeper writes that
# file, and a ceiling written INSIDE it would be lost the next time the keeper ran).
apply_dropin() {
  local high max swapmax
  high="$(pct_of "$(mem_total_mb)" "$HIGH_PCT")"
  max="$(pct_of "$(mem_total_mb)" "$MAX_PCT")"
  swapmax="$(pct_of "$(swap_total_mb)" "$SWAP_PCT")"
  mkdir -p "$DROPIN_DIR" || die "cannot create $DROPIN_DIR"
  cat >"$DROPIN_DIR/$DROPIN_NAME" <<CONF
# Written by bin/seat/desk-ceiling.sh — plan 001 §4 F1. Do not hand-edit; re-run the door.
#
# The desk is one memory pot with every agent in it. On 2026-11-17 the kernel's OOM killer took one
# process inside this unit, systemd stopped the unit with result 'oom-kill', and all 27 panes came
# back as bare shells. A ceiling makes the next death LOCAL, and OOMPolicy=continue stops systemd
# from answering a single child's death by stopping the whole desk.
[Service]
MemoryHigh=${high}M
MemoryMax=${max}M
MemorySwapMax=${swapmax}M
OOMPolicy=continue
CONF
  printf '%s/%s\n' "$DROPIN_DIR" "$DROPIN_NAME"
}

apply_live() {
  # No restart: `set-property` moves the limits of the RUNNING unit. OOMPolicy is not a settable
  # property at runtime, so the drop-in carries it for the next start and this line reports that.
  local high max swapmax rc=0 out
  high="$(pct_of "$(mem_total_mb)" "$HIGH_PCT")"
  max="$(pct_of "$(mem_total_mb)" "$MAX_PCT")"
  swapmax="$(pct_of "$(swap_total_mb)" "$SWAP_PCT")"
  out="$(systemctl --user set-property "$UNIT" "MemoryHigh=${high}M" "MemoryMax=${max}M" "MemorySwapMax=${swapmax}M" 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'desk-ceiling: the live limits were NOT moved on %s — %s\n' "$UNIT" "$(printf '%s' "$out" | head -1)" >&2
    return 1
  fi
  printf 'set-property: MemoryHigh=%sM MemoryMax=%sM MemorySwapMax=%sM on %s (no restart)\n' "$high" "$max" "$swapmax" "$UNIT"
}

show() {
  systemctl --user show "$UNIT" -p MemoryHigh -p MemoryMax -p MemorySwapMax -p MemoryPeak -p MemoryCurrent -p OOMPolicy 2>/dev/null \
    || die "the user manager did not answer for $UNIT"
}

check() {
  local out max oom rc=0
  out="$(systemctl --user show "$UNIT" -p MemoryMax -p OOMPolicy 2>/dev/null)"
  max="$(printf '%s\n' "$out" | sed -n 's/^MemoryMax=//p')"
  oom="$(printf '%s\n' "$out" | sed -n 's/^OOMPolicy=//p')"
  printf 'desk-ceiling-check[1]{unit,memory_max,oom_policy,verdict}:\n'
  case "$max" in
    ''|infinity|0)
      printf '  "%s","%s","%s","NO CEILING — run: bin/seat/desk-ceiling.sh apply"\n' "$UNIT" "${max:-absent}" "${oom:-?}"
      rc=1 ;;
    *)
      if [ "${oom:-}" != "continue" ]; then
        printf '  "%s","%s","%s","ceiling set, but a child killed by the OOM killer still stops the desk — apply the drop-in"\n' "$UNIT" "$max" "${oom:-?}"
        rc=1
      else
        printf '  "%s","%s","%s","ceiling in force, and a killed child no longer stops the desk"\n' "$UNIT" "$max" "$oom"
      fi ;;
  esac
  return "$rc"
}

# ── main ──────────────────────────────────────────────────────────────────────
ACTION="${1:-choose}"
case "$ACTION" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) usage 0 ;;
  choose) choose ;;
  apply)
    have systemctl || skip "no systemctl on this machine — the desk has no cgroup ceiling to set here (clean skip)"
    systemctl --user show "$UNIT" >/dev/null 2>&1 || die "$UNIT is not a unit of this user's manager"
    f="$(apply_dropin)" && printf 'drop-in: %s\n' "$f"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    apply_live || exit 1
    printf 'note: OOMPolicy=continue is carried by the drop-in and lands at the unit'"'"'s next start (never restarted by this door)\n'
    show
    ;;
  show)
    have systemctl || skip "no systemctl on this machine (clean skip)"
    show ;;
  --check|check)
    have systemctl || skip "no systemctl on this machine (clean skip)"
    check ;;
  dropin)
    # The durable half alone: write the drop-in and nothing else. Used by a test (a temp dir) and by a
    # seat that must not touch a running manager.
    apply_dropin ;;
  *) usage 2 ;;
esac
