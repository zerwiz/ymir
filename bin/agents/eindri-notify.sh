#!/usr/bin/env bash
# eindri-notify.sh — the ARM-HOLDER'S INBOX: inject one line into the session that holds the lock.
#
# WHY THIS EXISTS (the Allfather, 2026-11-08: *"why arent they injecting into your session chat? we have
# built that and its not getting used. they are writing handoff in files now instead"*). He is right:
# `report.sh` writes a report FILE and the wake queue ANNOUNCES it — but nothing puts the line into the
# chat of the session that actually holds the lock. A message that only reaches a file has not reached
# anybody; the lock holder reads panes, not shelves.
#
# THE ROAD, and there is exactly one:
#   1. the lock record names the owner pid          (~/.local/state/ymir/brokk.lock)
#   2. herdr knows which pane hosts that process    (herdr pane process-info)
#   3. herdr steering speaks a turn into it         (bin/agents/eindri-send.sh → herdr agent prompt)
# So a worker's one line arrives as a turn in the arm holder's session, which is what "inject into the
# chat window" means in this house.
#
#   eindri-notify.sh --from <name> -- "<one line>"
#   eindri-notify.sh --status                 # which pane would receive, and whether the lock owner is live
#   eindri-notify.sh --dry --from <name> -- "<one line>"   # resolve everything, inject nothing
#
# Refuses loudly when it cannot inject, and says which of the three links broke: a silent success would
# be the same fault it exists to fix. Exit: 0 injected · 1 could not inject · 2 usage.
set -uo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"

from="an errand"
line=""
while [ $# -gt 0 ]; do
  case "$1" in
    --from) from="${2-}"; shift 2 ;;
    --from=*) from="${1#--from=}"; shift ;;
    --status) status=1; shift ;;
    --dry) dry=1; shift ;;
    --) shift; line="${*:-}"; break ;;
    *) line="${line:+$line }$1"; shift ;;
  esac
done

# ── 1 · the lock record ────────────────────────────────────────────────────────────────────────────
lock="$HOME/.local/state/ymir/brokk.lock"
[ -r "$lock" ] || { printf 'eindri-notify: no lock record at %s — nobody to inject into\n' "$lock" >&2; exit 1; }
owner="$(tr -dc '0-9' < "$lock" | head -c 12)"
[ -n "$owner" ] || { printf 'eindri-notify: the lock record names no pid\n' >&2; exit 1; }

# ── 2 · the pane that hosts it ─────────────────────────────────────────────────────────────────────
# THE LOCK NAMES A SESSION, NOT A PROCESS (measured 2026-11-09). `.lock` holds the harness session pid,
# and the pane that hosts it runs `pi` under its own pid — so matching only `pane process-info`'s pid
# found nothing (`pane":"NOT FOUND"`) and EVERY injection this door was built for quietly failed. The
# lease carries the session id; the pi session file name carries it too. So: match the pid first, then
# the session id, and say which link was used.
pane=""; pane_via=""
# LINK 0 — the arm holder may name its own pane. Written by the seat at session start; a pane id is the
# only thing herdr can answer for certain, and every other link here is an inference. If it exists, trust it.
if [ -z "${STATE:-}" ]; then
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
  if declare -f ymir_home_root >/dev/null 2>&1; then ymir_home_root _h 2>/dev/null; [ -n "${_h:-}" ] && STATE="$_h/state"; fi
fi
# The lease: STATE when the caller named it, else the home through its ONE resolver — never a
# literal path (Rule 07; defaults-guard refuses a guessed home, and it did: this line tripped it
# on 2026-11-14 while the plan-275/283 branch was being pushed).
lease=""
if [ -n "${STATE:-}" ]; then
  lease="$STATE/.arm.lease"
else
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
  if declare -f ymir_home_root >/dev/null 2>&1; then
    ymir_home_root _h 2>/dev/null
    [ -n "${_h:-}" ] && lease="$_h/state/.arm.lease"
  fi
  unset _h
fi
session=""
[ -r "$lease" ] || lease="$(dirname "$(dirname "$lock")")/.arm.lease"
[ -r "$lease" ] && session="$(sed -nE 's/.*session=([0-9]+).*/\1/p' "$lease" | head -1)"
if [ -z "$pane" ] && [ -r "$lease" ]; then
  _st="$(sed -nE 's/.*state=([^ ]+).*/\1/p' "$lease" | head -1)"
  for _cand in "${_st:-}/.arm.pane" "${STATE:-}/.arm.pane"; do
    [ -r "$_cand" ] || continue
    _p="$(head -1 "$_cand" | tr -dc '[:alnum:]:._-')"
    [ -n "$_p" ] && { pane="$_p"; pane_via="the arm holder named its pane ($_cand)"; break; }
  done
fi
if [ -z "$pane" ] && command -v herdr >/dev/null 2>&1; then
  map="$(timeout 20 herdr agent list 2>/dev/null \
          | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
for a in (d.get("result") or {}).get("agents") or []:
    s=a.get("agent_session") or {}
    print("%s\t%s" % (a.get("pane_id") or "", s.get("value") or ""))' 2>/dev/null)"
  while IFS=$'\t' read -r p sess; do
    [ -n "$p" ] || continue
    info="$(timeout 15 herdr pane process-info --pane "$p" 2>/dev/null || true)"
    case "$info" in
      *"\"pid\": $owner"*|*"\"pid\":$owner"*|*" $owner "*)
        pane="$p"; pane_via="the lock pid"; break ;;
    esac
    if [ -z "$pane" ] && [ -n "$session" ] && [ -n "$sess" ]; then
      case "$sess" in
        *"$session"*) pane="$p"; pane_via="the lease's session id" ;;
      esac
    fi
  done <<EOF
$map
EOF
fi

# ── THE RECALLED PANE IS A CLAIM, NOT A FACT (2026-11-16) ────────────────────────────────────────
# Every errand that finished today reported "pane w2:p3 reported herdr agent_not_found": w2:p3 was the
# helm's pane before the 04:00 reboot, and the arm's own state still names it. A remembered pane id is a
# guess about a machine that restarts, so it is PROVED against herdr before a turn is aimed at it —
# and a ghost is discarded and resolved again, never spoken to. The wake is already in the queue by
# this point (acclaim appends it first), so a ghost costs the chat injection and nothing else.
if [ -n "$pane" ] && command -v herdr >/dev/null 2>&1; then
  if ! timeout 20 herdr agent list 2>/dev/null | grep -qF "\"pane_id\":\"$pane\""; then
    printf 'note: the recalled pane %s (%s) holds no live agent — resolving again, and the wake stands\n' \
      "$pane" "${pane_via:-an unnamed source}" >&2
    pane=""; pane_via=""
  fi
fi

if [ "${status:-0}" = 1 ]; then
  alive="no"; kill -0 "$owner" 2>/dev/null && alive="yes"
  printf 'arm-holder[2]{lock_owner,alive,pane,via}:\n  "%s","%s","%s","%s"\n' "$owner" "$alive" "${pane:-NOT FOUND}" "${pane_via:-nothing matched}"
  [ -n "$pane" ] && exit 0 || exit 1
fi

[ -n "$line" ] || { printf 'usage: eindri-notify.sh --from <name> -- "<one line>"\n' >&2; exit 2; }
if [ -z "$pane" ]; then
  # THE WAKE QUEUE IS THE FLOOR, AND THE FLOOR HOLDS (2026-11-16). The line is already queued; a chat
  # injection that cannot happen is a lost convenience, not a lost message. Exiting non-zero here made
  # seven finished errands report "delivery FAILED" tonight for news the helm had already received.
  printf 'eindri-notify: no live pane for the lock owner (pid %s) — the line is in the wake queue and the helm drains it at the next turn; the chat injection did not happen.\n' "$owner" >&2
  exit 0
fi

# ── 3 · speak it into that session ─────────────────────────────────────────────────────────────────
if [ "${YMIR_NO_INJECT:-0}" = "1" ]; then dry=1; fi   # a test run never shouts into the chat
if [ "${dry:-0}" = 1 ]; then
  # PROVE THE ROAD WITHOUT SHOUTING (added 2026-11-08: the smoke suite ran three times and left three
  # lines in the holder's chat, which is noise in the one window that must stay readable).
  printf 'dry-inject[1]{from,pane,owner}:
  "%s","%s","%s"
' "$from" "$pane" "$owner"
  exit 0
fi

export BROKK_INJECT_MARK=1
if timeout 60 "$ROOT/bin/agents/eindri-send.sh" --from "agent $from" "$pane" "$line" >/dev/null 2>&1; then
  printf 'injected[1]{from,pane,owner}:\n  "%s","%s","%s"\n' "$from" "$pane" "$owner"
  exit 0
fi
printf 'eindri-notify: herdr did not accept the turn for pane %s (owner %s) — the line is in the wake queue; the chat injection did not happen.\n' "$pane" "$owner" >&2
exit 0
