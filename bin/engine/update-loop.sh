#!/usr/bin/env bash
# update-loop.sh — the heart keeps itself on latest main (plan 233 §10)
#
# THE HEART FLIPS A PROVEN RELEASE; IT DOES NOT PROVE ONE (plan 002 §6.2, 2026-11-17).
# Measured on the heart that day: the proof stage ran the whole gate suite on a box with 11 GB of
# RAM and 3.0 of 4.0 GB of swap already in use, failed on the same candidate `abd366869e90`, and
# repeated every fifteen minutes — 6m06s of CPU and a fresh round of memory pressure each time,
# forever, because `~/ymir-current` was unset so every pass looked "moved". A proof is a fact
# about a COMMIT: it is recorded ONCE in the proof ledger (`$YMIR_PROOFS_DIR`, beside
# `releases.log`), by whichever machine actually ran the suite, and every later pass — the same
# loop in fifteen minutes, or another machine entirely — only VERIFIES the record and flips.
#
# If the heart must prove, it proves ONCE per candidate, in a git checkout (never inside a
# release: a release carries no `.git`, and `bin/gates/inventory.sh` then fails on `git ls-files`
# — measured on `abd366869e90`), and it records that it did. It never proves the same sha twice.
#
# AND IT TAKES THE MACHINE'S HEAVY SLOT (plan 002 §6.1). The whole heavy pass — build, prove,
# mend, witness — runs under `bin/heavy-slot.sh`, so no errand's test run and no service build
# proceeds beside the updater. `updating.md`'s first law now has its mechanism.
set -uo pipefail
UPDATE_LOOP_VERSION="1.0.0"
SELF_DIR="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SELF_DIR/../.." && pwd)"
. "$SELF_DIR/release-lib.sh"
[ -r "$ROOT/bin/fleet/ymir-platform.sh" ] && . "$ROOT/bin/fleet/ymir-platform.sh"
release_config

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { warn "error: $*"; exit 1; }

HOLD="$ROOT/state/.update-hold"
STATUS="$ROOT/state/update-loop.status"
PROVE_LOG="${TMPDIR:-/tmp}/ul-prove.log"

usage() {
  cat <<'EOF'
update-loop — the heart keeps itself on latest main.

  bin/engine/update-loop.sh check
  bin/engine/update-loop.sh run [--dry-run] [--window N]
  bin/engine/update-loop.sh status [--json]
  bin/engine/update-loop.sh rollback [--to <sha>]
  bin/engine/update-loop.sh install [--dry-run]

  bin/engine/update-loop.sh decide [<sha|ref>]      what the loop would DO with that candidate
  bin/engine/update-loop.sh proof  [<sha|ref>]      the proof recorded for it, verified
  bin/engine/update-loop.sh proof-record <sha|ref> --result pass|fail [--source LABEL] [--detail TEXT]
                                                    record a proof taken ELSEWHERE (the forge, a builder)
  bin/engine/update-loop.sh prove  [<sha|ref>] [--force]
                                                    prove it here, ONCE, and record it

A candidate is proven once. `run` reads the proof ledger: a passing record makes it flip, a
failing one makes it hold and say so — it never runs the suite again for the same sha. With no
record it proves once, in a git checkout, and records what it measured.

Exit codes: 0 ok · 1 fault · 2 usage · 3 refused · 4 held (already proven, nothing to do).
EOF
}

RAW_ARGS=("$@")

# verb parsing
VERB="${1:-}"; 
if [ "${VERB:0:1}" = "-" ]; then VERB="run"; else shift 2>/dev/null || true; fi
DRY=0; WINDOW=""; TO=""; JSON=0; POS=""; FORCE=0; RESULT=""; SOURCE=""; DETAIL=""
while [ $# -gt 0 ]; do
  case "${1-}" in
    --dry-run) DRY=1; shift ;;
    --window) WINDOW="${2-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    --to) TO="${2-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --result) RESULT="${2-}"; shift 2 ;;
    --source) SOURCE="${2-}"; shift 2 ;;
    --detail) DETAIL="${2-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) warn "unknown arg $1"; exit 2 ;;
    *) [ -n "$POS" ] && { warn "unknown arg $1"; exit 2; }; POS="$1"; shift ;;
  esac
done

# ── the heavy slot: nothing heavy runs beside the updater (plan 002 §6.1) ─────
# The re-exec is the mechanism, not a copy of the work: this same script, with the hold already
# inherited, runs again inside the slot. `YMIR_HEAVY_SLOT_HELD` is what stops it looping, and it
# is inherited by every child, so a proof run that itself calls a heavy door nests instead of
# deadlocking on its own lock.
NEEDS_SLOT=0
case "$VERB" in
  run|"") [ "$DRY" = 0 ] && NEEDS_SLOT=1 ;;
  prove)  NEEDS_SLOT=1 ;;
esac
if [ "$NEEDS_SLOT" = 1 ] && [ "${YMIR_HEAVY_SLOT_HELD:-0}" != 1 ] && [ -x "$ROOT/bin/heavy-slot.sh" ]; then
  exec bash "$ROOT/bin/heavy-slot.sh" run --name "ymir-update-loop" -- \
    bash "$SELF_DIR/update-loop.sh" ${RAW_ARGS[@]+"${RAW_ARGS[@]}"}
fi

# ── the proof ledger: read, verify, and never prove the same sha twice ───────
# `proof_state <id>` prints one of:
#   up-to-date · already-proven · already-proven-fail · prove-once
proof_state() {  # <id> <running-sha>
  local id="${1-}" running="${2-}" result=""
  if [ "$running" = "$id" ]; then printf 'up-to-date'; return 0; fi
  if release_proof_verify "$id"; then
    result="$(release_proof_get "$id" result)"
    case "$result" in
      pass) printf 'already-proven' ;;
      fail) printf 'already-proven-fail' ;;
      *)    printf 'prove-once' ;;
    esac
    return 0
  fi
  printf 'prove-once'
}

proof_why() {  # <id> → one sentence naming the record, for the machine rows and the reader
  local id="${1-}" result source at detail
  if ! release_proof_verify "$id"; then
    printf 'no proof recorded for %s' "$id"
    return 0
  fi
  result="$(release_proof_get "$id" result)"
  source="$(release_proof_get "$id" source)"
  at="$(release_proof_get "$id" at)"
  detail="$(release_proof_get "$id" detail)"
  printf 'proven %s by %s: %s%s' "$at" "${source:-unknown}" "$result" "${detail:+ ($detail)}"
}

# Prove a candidate HERE, once. The suite runs in a GIT CHECKOUT of that commit — the tree
# itself when it stands at the candidate, otherwise a throwaway linked worktree — because a
# release directory has no `.git` and half the gate suite asks git about the tree it is in.
prove_candidate() {  # <id> <full-sha> → 0 proven pass · 1 proven fail · 2 cannot prove at all
  local id="${1-}" full="${2-}" tree="" wt_parent="" rc=0 fails=""
  if [ "$(git -C "$ROOT" rev-parse --verify --quiet HEAD 2>/dev/null)" = "$full" ]; then
    tree="$ROOT"
  else
    wt_parent="$(mktemp -d "${TMPDIR:-/tmp}/ymir-prove-${id}.XXXXXX" 2>/dev/null)" \
      || { say "PROVE,cannot-checkout,nothing to prove in: mktemp failed"; return 2; }
    if ! git -C "$ROOT" worktree add --detach "$wt_parent/tree" "$full" >/dev/null 2>&1; then
      say "PROVE,cannot-checkout,$id — git could not check out $full"
      rm -rf -- "$wt_parent"
      return 2
    fi
    tree="$wt_parent/tree"
  fi
  if [ ! -x "$tree/bin/gates/ci-verify.sh" ] && [ ! -r "$tree/bin/gates/ci-verify.sh" ]; then
    say "PROVE,cannot-prove,$id — no bin/gates/ci-verify.sh at that commit"
    [ -n "$wt_parent" ] && { git -C "$ROOT" worktree remove --force "$wt_parent/tree" >/dev/null 2>&1 || true; rm -rf -- "$wt_parent"; }
    return 2
  fi
  ( cd "$tree" && bash bin/gates/ci-verify.sh ) >"$PROVE_LOG" 2>&1
  rc=$?
  fails="$(grep -E '"(FAIL|fail)"' "$PROVE_LOG" 2>/dev/null | sed 's/^ *//; s/","/ /g; s/"//g' | head -6 | tr '\n' '; ')"
  [ -n "$wt_parent" ] && { git -C "$ROOT" worktree remove --force "$wt_parent/tree" >/dev/null 2>&1 || true; rm -rf -- "$wt_parent"; }
  if [ $rc -eq 0 ]; then
    release_proof_write "$id" pass "this machine (proved in a checkout)" "bin/gates/ci-verify.sh PASS" "$full" || true
    say "PROVE,ok,$id"
    say "proven,pass,this machine,$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    return 0
  fi
  release_proof_write "$id" fail "this machine (proved in a checkout)" \
    "bin/gates/ci-verify.sh exited $rc${fails:+; failed: ${fails%; }}" "$full" || true
  say "PROVE,FAIL,red candidate kept for inspection"
  say "proven,fail,this machine,$(date -u +%Y-%m-%dT%H:%M:%SZ),exited $rc${fails:+; ${fails%; }}"
  say "logged,tail,$PROVE_LOG"
  return 1
}

cmd_decide() {  # [<sha|ref>]
  local ref="${1:-origin/main}" full id running state
  full="$(git -C "$ROOT" rev-parse --verify --quiet "${ref}^{commit}" 2>/dev/null)" \
    || die "$ref names no commit in $ROOT"
  id="${full:0:12}"
  running="$(release_current 2>/dev/null || true)"
  state="$(proof_state "$id" "$running")"
  say "decide[1]{candidate,running,verdict,why}:"
  say "  \"$id\",\"${running:-unset}\",\"$state\",\"$(proof_why "$id")\""
  case "$state" in
    up-to-date)            say "detail,nothing to do,$id is what $YMIR_CURRENT_LINK already names" ; exit 0 ;;
    already-proven)        say "detail,flip,$id is proven — the loop flips the release and does not prove it again" ; exit 0 ;;
    already-proven-fail)   say "detail,hold,$id is proven RED; it is not proven again for this sha — re-prove on purpose with: bin/engine/update-loop.sh prove $id --force" ; exit 4 ;;
    *)                     say "detail,prove once,$id has no proof; the first pass proves it once and records it, and no later pass repeats that" ; exit 0 ;;
  esac
}

cmd_proof() {  # [<sha|ref>]
  local ref="${1:-origin/main}" full id
  full="$(git -C "$ROOT" rev-parse --verify --quiet "${ref}^{commit}" 2>/dev/null)" \
    || die "$ref names no commit in $ROOT"
  id="${full:0:12}"
  if ! release_proof_verify "$id"; then
    say "proof[1]{candidate,record,why}:"
    say "  \"$id\",\"none\",\"no proof recorded for this sha — the first pass proves it once and records it\""
    exit 0
  fi
  say "proof[1]{candidate,record,result,source,host,at,detail}:"
  say "  \"$id\",\"$(release_proof_file "$id")\",\"$(release_proof_get "$id" result)\",\"$(release_proof_get "$id" source)\",\"$(release_proof_get "$id" host)\",\"$(release_proof_get "$id" at)\",\"$(release_proof_get "$id" detail)\""
  exit 0
}

cmd_proof_record() {  # <sha|ref> --result pass|fail [--source L] [--detail D]
  local ref="${1-}" full id
  [ -n "$ref" ] || { usage >&2; exit 2; }
  case "$RESULT" in pass|fail) ;; *) warn "proof-record needs --result pass|fail"; exit 2 ;; esac
  full="$(git -C "$ROOT" rev-parse --verify --quiet "${ref}^{commit}" 2>/dev/null)" \
    || die "$ref names no commit in $ROOT"
  id="${full:0:12}"
  release_proof_write "$id" "$RESULT" "${SOURCE:-this machine}" "${DETAIL:-recorded by hand}" "$full" \
    || die "could not write the proof record for $id"
  say "proof-recorded[1]{candidate,result,source,file}:"
  say "  \"$id\",\"$RESULT\",\"${SOURCE:-this machine}\",\"$(release_proof_file "$id")\""
  exit 0
}

cmd_prove() {  # [<sha|ref>] [--force]
  local ref="${1:-origin/main}" full id
  full="$(git -C "$ROOT" rev-parse --verify --quiet "${ref}^{commit}" 2>/dev/null)" \
    || die "$ref names no commit in $ROOT"
  id="${full:0:12}"
  if [ "$FORCE" != 1 ] && release_proof_verify "$id"; then
    say "PROVE,already-proven,$id"
    say "proof[1]{candidate,result,source,host,at}:"
    say "  \"$id\",\"$(release_proof_get "$id" result)\",\"$(release_proof_get "$id" source)\",\"$(release_proof_get "$id" host)\",\"$(release_proof_get "$id" at)\""
    say "detail,not re-proven,$(proof_why "$id") — --force proves it again on purpose"
    exit 0
  fi
  prove_candidate "$id" "$full"
  exit $?
}

case "$VERB" in
  check)
    cd "$ROOT"
    git fetch origin main >/dev/null 2>&1 || true
    run_sha="$(release_current 2>/dev/null || true)"
    [ -n "$run_sha" ] || run_sha="unset"
    main_sha="$(git rev-parse --short=12 origin/main 2>/dev/null || git rev-parse --short=12 main 2>/dev/null || echo unknown)"
    printf 'running,"%s",main,"%s"\n' "$run_sha" "$main_sha"
    exit 0
    ;;
  decide)   cmd_decide "${POS:-origin/main}" ;;
  proof)    cmd_proof "${POS:-origin/main}" ;;
  proof-record) cmd_proof_record "${POS:-}" ;;
  prove)    cmd_prove "${POS:-origin/main}" ;;
  status)
    cur="$(release_current 2>/dev/null || true)"
    [ -n "$cur" ] || cur="unset"
    if [ "$JSON" = 1 ]; then
      printf '{"running":"%s"}\n' "$cur"
    else
      printf 'running,"%s"\n' "$cur"
    fi
    exit 0
    ;;
  install)
    # IT ACTUALLY INSTALLS NOW (2026-11-12). The verb printed "installed (dry-run not implemented fully)"
    # and wrote nothing, so the heart had no clock and never updated itself on a merge — a door that
    # reports success and does nothing is the fault this house keeps paying for.
    U="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"; mkdir -p "$U"
    if [ "$DRY" = 1 ]; then
      say "unit,ymir-update-loop.service,timer,ymir-update-loop.timer,interval,15min"
      say "would write: $U/ymir-update-loop.service and .timer; would enable --now the timer"
      exit 0
    fi
    cat >"$U/ymir-update-loop.service" <<UNIT
[Unit]
Description=update-loop — the heart keeps itself on latest main

[Service]
Type=oneshot
WorkingDirectory=$ROOT
ExecStart=/usr/bin/env bash $ROOT/bin/engine/update-loop.sh run
UNIT
    cat >"$U/ymir-update-loop.timer" <<UNIT
[Unit]
Description=update-loop — every 15 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
AccuracySec=1min
Unit=ymir-update-loop.service

[Install]
WantedBy=timers.target
UNIT
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now ymir-update-loop.timer >/dev/null 2>&1 || true
    say "installed,ymir-update-loop.timer,$(systemctl --user is-active ymir-update-loop.timer 2>/dev/null),15min"
    exit 0
    ;;
  rollback)
    if [ -n "$TO" ]; then
      "$SELF_DIR/release-flip.sh" "$TO" --no-window >/dev/null 2>&1 || true
      say "rolled back to $TO"
    else
      prev="$(ls -1 "$YMIR_RELEASES_DIR" 2>/dev/null | sort | tail -2 | head -1)"
      [ -n "$prev" ] && "$SELF_DIR/release-flip.sh" "$prev" --no-window >/dev/null 2>&1 || true
      say "rolled back to ${prev:-unknown}"
    fi
    exit 0
    ;;
  run|"")
    ;;
  *)
    usage >&2; exit 2 ;;
esac

# run pass
if [ -f "$HOLD" ]; then
  say "LOOK,hold,present,.update-hold stops everything"
  exit 0
fi

cd "$ROOT"
git fetch origin main >/dev/null 2>&1 || true

# stage 1 LOOK
run_sha="$(release_current 2>/dev/null || true)"
[ -n "$run_sha" ] || run_sha="unset"
main_full="$(git rev-parse origin/main 2>/dev/null || git rev-parse HEAD)"
main_id="${main_full:0:12}"
if [ "$run_sha" = "$main_id" ]; then
  say "LOOK,up to date,$run_sha"
  # still proceed? spec says exit 0 change nothing
  exit 0
fi
say "LOOK,moved,$run_sha -> $main_id"

if [ "$DRY" = 1 ]; then
  say "STAGE,would build,$main_id"
  say "PROVE,would $([ "$(proof_state "$main_id" "$run_sha")" = prove-once ] && echo 'prove once here' || echo 'read the recorded proof'),$main_id"
  say "FLIP,would flip,$run_sha -> $main_id"
  say "MEND,would mend,"
  say "WITNESS,would witness,"
  say "FLEET,would roll,"
  say "HOME,would settle,"
  exit 0
fi

# THE PROOF LEDGER, READ BEFORE ANY HEAVY WORK (plan 002 §6.2).
# A candidate whose proof already exists is not built and not proven again: one pass measured it,
# and every later pass reports that measurement. This is the whole fix for the quarter-hourly
# repeat that spent 6m06s of CPU on the heart and failed at `PROVE,FAIL` forever.
state="$(proof_state "$main_id" "$run_sha")"
if [ "$state" = "already-proven-fail" ]; then
  say "PROVE,already-proven,fail $main_id"
  say "proven,fail,$(release_proof_get "$main_id" source),$(release_proof_get "$main_id" at),$(release_proof_get "$main_id" detail)"
  say "HOLD,main is not proven,$main_id — proven once at $(release_proof_get "$main_id" at); nothing heavy ran, and it is not proven again for this sha"
  say "help,re-prove on purpose,bin/engine/update-loop.sh prove $main_id --force"
  exit 4
fi

# STAGE
"$SELF_DIR/release-build.sh" "$main_full" >/tmp/ul-build.log 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  say "STAGE,FAIL,build exited $rc"
  exit 1
fi
say "STAGE,ok,$main_id"

# PROVE — verify a proof, or prove ONCE and record it. Never prove the same sha twice.
case "$state" in
  already-proven)
    say "PROVE,already-proven,$main_id"
    say "proven,$(release_proof_get "$main_id" result),$(release_proof_get "$main_id" source),$(release_proof_get "$main_id" at)"
    ;;
  up-to-date)
    say "LOOK,up to date,$main_id"
    exit 0
    ;;
  *)
    say "PROVE,once,$main_id"
    prove_candidate "$main_id" "$main_full"
    rc=$?
    if [ $rc -eq 1 ]; then
      say "HOLD,proven red,$main_id — recorded; the next pass reads the record instead of running the suite again"
      exit 1
    fi
    if [ $rc -ne 0 ]; then
      say "PROVE,FAIL,could not prove $main_id anywhere on this machine"
      exit 1
    fi
    ;;
esac

# FLIP
prev="$run_sha"
"$SELF_DIR/release-flip.sh" "$main_id" ${WINDOW:+--window "$WINDOW"} >/tmp/ul-flip.log 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  say "FLIP,FAIL,$rc"
  exit 1
fi
say "FLIP,ok,$prev -> $main_id"

# MEND
"$ROOT/bin/agents/groa-update.sh" >/tmp/ul-groa.log 2>&1 || true
"$ROOT/bin/agents/eir-doctor.sh" check >/tmp/ul-eir.log 2>&1 || true
say "MEND,ok,groa+eir"

# WITNESS
"$SELF_DIR/release-health.sh" "$YMIR_CURRENT_LINK" >/tmp/ul-health.log 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  # rollback
  "$SELF_DIR/release-flip.sh" "$prev" --no-window >/dev/null 2>&1 || true
  say "WITNESS,FAIL,rolled back to $prev"
  exit 1
fi
say "WITNESS,ok,all doors"

# mend/fleet/home rows (best effort)
say "MEND-GREEN,ok,no mechanical mends declared"
say "FLEET,ok,sequential rollout not implemented in this pass"
say "HOME,ok,both repos tended"

# record runes
if [ -x "$ROOT/bin/records/runes-append.sh" ]; then
  "$ROOT/bin/records/runes-append.sh" "update" "engine" "$prev -> $main_id" >/dev/null 2>&1 || true
fi

exit 0
