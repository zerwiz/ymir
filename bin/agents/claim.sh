#!/usr/bin/env bash
# claim.sh — the fleet's claims ledger: one task, one holder, visible to every seat (plan 343.12).
#
# Each machine's errand record (state/*.status) is local and ignored by the home's git, so no seat
# could see another's work, and the same PR was reworked twice. A CLAIM is a small file in the
# home's TRACKED shelf state/claims/, shipped through bin/vault/home-sync.sh in the same act that
# writes it, so `git pull` on any seat shows who holds what.
#
#   claim.sh take <key> [--role coder|judge|shipper] [--errand <id>] [--head <sha>] [--adopt-stale]
#   claim.sh show <key> [--role <r>]            # who holds it (exit 1 when nobody does)
#   claim.sh check <key> [--role <r>] [--sync]  # exit 0 free-or-mine, 1 held by another seat
#   claim.sh heartbeat <key> [--role <r>]       # keep a claim fresh (ships at most every 20 min)
#   claim.sh release <key> [--role <r>]         # the holder's seat lets go (file kept, state=released)
#   claim.sh list [--fleet] [--all]             # --fleet pulls the home first and shows every seat
#
# Keys (the one grammar):
#   pr:<owner>/<repo>#<n>         plan:<n>.<step>         branch:<owner>/<repo>:<name>
#
# Rules:
#   - A claim is per (key, role). A judge and a coder may hold the same PR; two coders may not.
#   - take refuses a key another seat holds FRESH, and names the holder (seat, errand, age).
#   - Stale = no heartbeat for CLAIM_STALE_SECONDS (default 7200, 2 h). A stale claim is OFFERED, never
#     stolen: take refuses it too, unless the caller says --adopt-stale (the old holder is recorded).
#   - A judge claim carries the PR head; a different head is a new judgement and may be taken.
#   - A claim is never deleted (Rule 11): release rewrites it as state=released; git keeps the history.
#   - Layout: <home>/state/claims/<key-name>/<role>
#
# Env: YMIR_SEAT (the seat's name; default: short hostname) · CLAIM_STALE_SECONDS · CLAIM_NOW (epoch,
#      tests) · CLAIM_NO_SYNC=1 (do not touch git; a stated skip, Rule 25) · CLAIM_SHIP_EVERY (1200)
# Exit: 0 ok · 1 refused (held by another seat) · 2 usage · 3 the home could not be reached/written
set -uo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STALE="${CLAIM_STALE_SECONDS:-7200}"
SHIP_EVERY="${CLAIM_SHIP_EVERY:-1200}"

usage() { sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; }
case "${1-}" in ""|-h|--help) usage; [ -n "${1-}" ] && exit 0; exit 2 ;; -v|-V|--version) echo "$VERSION"; exit 0 ;; esac

now() { printf '%s' "${CLAIM_NOW:-$(date +%s)}"; }
iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
epoch() { date -u -d "$1" +%s 2>/dev/null || echo 0; }
SEAT="${YMIR_SEAT:-$(hostname -s 2>/dev/null || hostname)}"

home_dir() {
  local h
  h="$(bash "$ROOT/bin/vault/hodd.sh" path 2>/dev/null || true)"
  [ -n "$h" ] || return 1
  dirname "$h"
}
HOME_DIR="$(home_dir)" || { echo "claim: no home (YMIR_HOME unresolved)" >&2; exit 3; }
CLAIMS="$HOME_DIR/state/claims"
HS="$ROOT/bin/vault/home-sync.sh"

# ── the key grammar ───────────────────────────────────────────────────────────
# normalise <key> → the canonical key on stdout, or return 2. owner/repo are lowercased (GitHub is
# case-insensitive there); a branch NAME and a plan step keep their spelling.
normalise() {
  local k="$1" kind rest o
  kind="${k%%:*}"; rest="${k#*:}"
  case "$kind" in
    pr)
      [[ "$rest" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+$ ]] || return 2
      printf 'pr:%s' "$(printf '%s' "$rest" | tr 'A-Z' 'a-z')" ;;
    plan)
      [[ "$rest" =~ ^[0-9]+(\.[0-9A-Za-z_-]+)?$ ]] || return 2
      printf 'plan:%s' "$rest" ;;
    branch)
      [[ "$rest" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+:[^[:space:]:]+$ ]] || return 2
      o="${rest%%:*}"
      printf 'branch:%s:%s' "$(printf '%s' "$o" | tr 'A-Z' 'a-z')" "${rest#*:}" ;;
    *) return 2 ;;
  esac
}
key_dir() {  # <canonical key> → a readable, collision-safe directory name
  local k="$1" safe h
  safe="$(printf '%s' "$k" | sed 's#[^A-Za-z0-9._-]#_#g' | cut -c1-80)"
  h="$(printf '%s' "$k" | cksum | cut -d' ' -f1)"
  printf '%s-%s' "$safe" "$h"
}
valid_role() { case "$1" in coder|judge|shipper) return 0 ;; *) return 1 ;; esac; }

# ── one claim file ────────────────────────────────────────────────────────────
f_get() { grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2-; }
claim_file() { printf '%s/%s/%s' "$CLAIMS" "$(key_dir "$1")" "$2"; }

# verdict <file> → free | held | stale  (a released or missing claim is free)
verdict() {
  local f="$1" st hb
  [ -f "$f" ] || { echo free; return; }
  st="$(f_get "$f" state)"
  [ "$st" = held ] || { echo free; return; }
  hb="$(epoch "$(f_get "$f" heartbeat)")"
  if [ $(( $(now) - hb )) -gt "$STALE" ]; then echo stale; else echo held; fi
}
age_h() {  # <iso> → "12m" / "3h05m"
  local s=$(( $(now) - $(epoch "$1") )); [ "$s" -ge 0 ] || s=0
  if [ "$s" -lt 3600 ]; then printf '%sm' $((s/60)); else printf '%sh%02dm' $((s/3600)) $(((s%3600)/60)); fi
}
holder_line() {  # <file>
  printf 'seat %s, errand %s, role %s, started %s, last heartbeat %s ago' \
    "$(f_get "$1" seat)" "$(f_get "$1" errand)" "$(f_get "$1" role)" "$(f_get "$1" started)" "$(age_h "$(f_get "$1" heartbeat)")"
}

# ── the home, through the one door ────────────────────────────────────────────
sync_in() {  # pull the fleet's claims before reading or taking
  [ "${CLAIM_NO_SYNC:-0}" = 1 ] && return 0
  YMIR_HOME="$HOME_DIR" bash "$HS" begin >/dev/null 2>&1
}
rel() { printf 'state/claims/%s/%s' "$(key_dir "$1")" "$2"; }
ship_claim() {  # <canonical key> <role> <message> → 0 shared · 3 the race was lost · 4 not shared
  local k="$1" role="$2" msg="$3" rc
  [ "${CLAIM_NO_SYNC:-0}" = 1 ] && return 0
  YMIR_HOME="$HOME_DIR" bash "$HS" ship "$msg" "$(rel "$k" "$role")" >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && return 0
  [ "$rc" = 3 ] && return 3
  return 4
}
undo_local() {  # <canonical key> <role> <message> — drop OUR unpushed commit and file after a lost race
  local k="$1" role="$2" msg="$3" r; r="$(rel "$k" "$role")"
  if [ "$(git -C "$HOME_DIR" log -1 --format=%s 2>/dev/null)" = "$msg" ]; then
    git -C "$HOME_DIR" reset -q --mixed HEAD~1 2>/dev/null || true
  fi
  git -C "$HOME_DIR" checkout -q -- "$r" 2>/dev/null || rm -f "$HOME_DIR/$r"
  sync_in
}

write_claim() {  # <file> <key> <role> <errand> <head> <extra-note>
  local f="$1" t; t="$(now)"
  mkdir -p "$(dirname "$f")"
  {
    printf 'key=%s\n' "$2"
    printf 'role=%s\n' "$3"
    printf 'state=held\n'
    printf 'seat=%s\n' "$SEAT"
    printf 'errand=%s\n' "$4"
    printf 'head=%s\n' "$5"
    printf 'started=%s\n' "$(iso "$t")"
    printf 'heartbeat=%s\n' "$(iso "$t")"
    [ -n "${6:-}" ] && printf 'note=%s\n' "$6"
  } >"$f"
}

# ── commands ──────────────────────────────────────────────────────────────────
cmd="$1"; shift
KEY=""; ROLE="coder"; ERRAND=""; HEAD=""; ADOPT=0; FLEET=0; ALL=0; SYNC=0
while [ $# -gt 0 ]; do
  case "$1" in
    --role) ROLE="${2-}"; shift 2 ;;
    --errand) ERRAND="${2-}"; shift 2 ;;
    --head) HEAD="${2-}"; shift 2 ;;
    --adopt-stale) ADOPT=1; shift ;;
    --fleet) FLEET=1; shift ;;
    --all) ALL=1; shift ;;
    --sync) SYNC=1; shift ;;
    -*) echo "claim: unknown flag $1" >&2; exit 2 ;;
    *) [ -z "$KEY" ] && KEY="$1" || { echo "claim: one key only" >&2; exit 2; }; shift ;;
  esac
done
valid_role "$ROLE" || { echo "claim: role must be coder|judge|shipper (got $ROLE)" >&2; exit 2; }

need_key() {
  [ -n "$KEY" ] || { echo "claim: $cmd needs a key (pr:<o>/<r>#<n> | plan:<n>.<step> | branch:<o>/<r>:<name>)" >&2; exit 2; }
  KEY="$(normalise "$KEY")" || { echo "claim: bad key — use pr:<owner>/<repo>#<n>, plan:<n>.<step> or branch:<owner>/<repo>:<name>" >&2; exit 2; }
}

case "$cmd" in
  take)
    need_key; [ -n "$ERRAND" ] || ERRAND="${YMIR_ERRAND:-$ROLE-$$}"
    sync_in || echo "claim: the home could not be pulled — taking on the local view (UNVERIFIED)" >&2
    f="$(claim_file "$KEY" "$ROLE")"; v="$(verdict "$f")"; note=""
    if [ "$v" != free ]; then
      hseat="$(f_get "$f" seat)"; herr="$(f_get "$f" errand)"
      if [ "$hseat" = "$SEAT" ] && { [ "$herr" = "$ERRAND" ] || [ "$v" = stale ]; }; then
        :  # this seat's own claim, same errand (or its own stale one): refresh it
      elif [ "$ROLE" = judge ] && [ -n "$HEAD" ] && [ -n "$(f_get "$f" head)" ] && [ "$(f_get "$f" head)" != "$HEAD" ]; then
        note="a new head ($HEAD): the earlier judgement was for $(f_get "$f" head)"
      elif [ "$v" = stale ] && [ "$ADOPT" = 1 ]; then
        note="adopted from $hseat/$herr after $(age_h "$(f_get "$f" heartbeat)") without a heartbeat"
      else
        if [ "$v" = stale ]; then
          printf 'claim: %s (%s) is STALE and offered, not taken — %s\n' "$KEY" "$ROLE" "$(holder_line "$f")" >&2
          printf 'help: if that errand is dead, take it deliberately: claim.sh take %s --role %s --errand %s --adopt-stale\n' "$KEY" "$ROLE" "$ERRAND" >&2
        else
          printf 'claim: %s is held — %s\n' "$KEY" "$(holder_line "$f")" >&2
          printf 'help: pick another task, or wait for seat %s (claim.sh show %s --role %s)\n' "$hseat" "$KEY" "$ROLE" >&2
        fi
        exit 1
      fi
    fi
    write_claim "$f" "$KEY" "$ROLE" "$ERRAND" "$HEAD" "$note"
    msg="claims: $SEAT takes $KEY as $ROLE ($ERRAND)"
    ship_claim "$KEY" "$ROLE" "$msg"; rc=$?
    if [ "$rc" = 3 ]; then
      undo_local "$KEY" "$ROLE" "$msg"
      f2="$(claim_file "$KEY" "$ROLE")"
      printf 'claim: lost the race for %s — %s\n' "$KEY" "$( [ -f "$f2" ] && holder_line "$f2" || echo 'another seat took it first')" >&2
      exit 1
    fi
    [ "$rc" = 4 ] && echo "claim: $KEY is claimed here but NOT shared — the home could not be pushed; other seats cannot see it yet" >&2
    printf 'claim[1]{key,role,seat,errand,state}:\n  "%s","%s","%s","%s","%s"\n' "$KEY" "$ROLE" "$SEAT" "$ERRAND" "$([ "$rc" = 0 ] && echo shared || echo local-only)"
    ;;

  show)
    need_key; sync_in || true
    f="$(claim_file "$KEY" "$ROLE")"; v="$(verdict "$f")"
    if [ "$v" = free ]; then printf 'claim[1]{key,role,state}:\n  "%s","%s","free"\n' "$KEY" "$ROLE"; exit 1; fi
    printf 'claim[1]{key,role,state,seat,errand,started,heartbeat_age}:\n  "%s","%s","%s","%s","%s","%s","%s"\n' \
      "$KEY" "$ROLE" "$v" "$(f_get "$f" seat)" "$(f_get "$f" errand)" "$(f_get "$f" started)" "$(age_h "$(f_get "$f" heartbeat)")"
    ;;

  check)
    need_key; [ "$SYNC" = 1 ] && { sync_in || echo "claim: the home could not be pulled — checking the local view" >&2; }
    f="$(claim_file "$KEY" "$ROLE")"; v="$(verdict "$f")"
    if [ "$v" = held ] && [ "$(f_get "$f" seat)" != "$SEAT" ]; then
      printf 'claim: %s is held by another seat — %s\n' "$KEY" "$(holder_line "$f")" >&2; exit 1
    fi
    printf 'claim[1]{key,role,verdict}:\n  "%s","%s","%s"\n' "$KEY" "$ROLE" "$([ "$v" = held ] && echo mine || echo "$v")"
    ;;

  heartbeat)
    need_key; f="$(claim_file "$KEY" "$ROLE")"
    [ -f "$f" ] && [ "$(f_get "$f" state)" = held ] && [ "$(f_get "$f" seat)" = "$SEAT" ] \
      || { echo "claim: $KEY ($ROLE) is not held by this seat ($SEAT) — nothing to refresh" >&2; exit 1; }
    prev="$(epoch "$(f_get "$f" heartbeat)")"
    sed -i "s/^heartbeat=.*/heartbeat=$(iso "$(now)")/" "$f"
    # Rewriting is free; committing every beat would flood the home. Ship only when the shared
    # copy has aged past CLAIM_SHIP_EVERY — far inside the 2 h stale line.
    if [ $(( $(now) - prev )) -ge "$SHIP_EVERY" ]; then
      ship_claim "$KEY" "$ROLE" "claims: $SEAT keeps $KEY as $ROLE" || echo "claim: heartbeat kept locally, not shared" >&2
    fi
    printf 'claim[1]{key,role,heartbeat}:\n  "%s","%s","%s"\n' "$KEY" "$ROLE" "$(f_get "$f" heartbeat)"
    ;;

  release)
    need_key; sync_in || true
    f="$(claim_file "$KEY" "$ROLE")"
    [ -f "$f" ] || { printf 'claim[1]{key,role,state}:\n  "%s","%s","free"\n' "$KEY" "$ROLE"; exit 0; }
    if [ "$(f_get "$f" state)" = held ] && [ "$(f_get "$f" seat)" != "$SEAT" ]; then
      printf 'claim: %s is held by another seat — only its holder releases it: %s\n' "$KEY" "$(holder_line "$f")" >&2; exit 1
    fi
    sed -i 's/^state=.*/state=released/' "$f"; printf 'released=%s\n' "$(iso "$(now)")" >>"$f"
    ship_claim "$KEY" "$ROLE" "claims: $SEAT releases $KEY as $ROLE" || echo "claim: release kept locally, not shared" >&2
    printf 'claim[1]{key,role,state}:\n  "%s","%s","released"\n' "$KEY" "$ROLE"
    ;;

  list)
    [ "$FLEET" = 1 ] && { sync_in || echo "claim: the home could not be pulled — this is the LOCAL view" >&2; }
    printf 'claims[]{key,role,seat,errand,state,heartbeat_age}:\n'
    n=0
    if [ -d "$CLAIMS" ]; then
      while IFS= read -r f; do
        v="$(verdict "$f")"
        [ "$v" = free ] && [ "$ALL" = 0 ] && continue
        [ "$FLEET" = 0 ] && [ "$(f_get "$f" seat)" != "$SEAT" ] && continue
        [ "$v" = free ] && v=released
        printf '  "%s","%s","%s","%s","%s","%s"\n' "$(f_get "$f" key)" "$(f_get "$f" role)" "$(f_get "$f" seat)" \
          "$(f_get "$f" errand)" "$v" "$(age_h "$(f_get "$f" heartbeat)")"
        n=$((n+1))
      done < <(find "$CLAIMS" -mindepth 2 -maxdepth 2 -type f | sort)
    fi
    [ "$n" -gt 0 ] || printf '  # nothing is claimed%s\n' "$([ "$FLEET" = 1 ] && echo ' by any seat' || echo " by seat $SEAT")"
    ;;

  *) echo "claim: unknown command $cmd" >&2; usage >&2; exit 2 ;;
esac
