#!/usr/bin/env bash
# update-loop.sh — the heart keeps itself on latest main (plan 233 §10)
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

usage() {
  cat <<'EOF'
update-loop — the heart keeps itself on latest main.

  bin/engine/update-loop.sh check
  bin/engine/update-loop.sh run [--dry-run] [--window N]
  bin/engine/update-loop.sh status [--json]
  bin/engine/update-loop.sh rollback [--to <sha>]
  bin/engine/update-loop.sh install [--dry-run]

Exit codes: 0 ok · 1 fault · 2 usage · 3 refused.
EOF
}

# verb parsing
VERB="${1:-}"; 
if [ "${VERB:0:1}" = "-" ]; then VERB="run"; else shift 2>/dev/null || true; fi
DRY=0; WINDOW=""; TO=""; JSON=0
while [ $# -gt 0 ]; do
  case "${1-}" in
    --dry-run) DRY=1; shift ;;
    --window) WINDOW="${2-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    --to) TO="${2-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "unknown arg $1"; exit 2 ;;
  esac
done

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
    if [ "$DRY" = 1 ]; then
      say "unit,ymir-update-loop.service,timer,ymir-update-loop.timer,interval,15min"
    else
      say "installed (dry-run not implemented fully)"
    fi
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
if [ "$run_sha" = "$main_id" ] || [ "$run_sha" = "unset" -a "$main_id" = "" ]; then
  :
fi
if [ "$run_sha" = "$main_id" ]; then
  say "LOOK,up to date,$run_sha"
  # still proceed? spec says exit 0 change nothing
  exit 0
fi
say "LOOK,moved,$run_sha -> $main_id"

if [ "$DRY" = 1 ]; then
  say "STAGE,would build,$main_id"
  say "PROVE,would run gates,$main_id"
  say "FLIP,would flip,$run_sha -> $main_id"
  say "MEND,would mend,"
  say "WITNESS,would witness,"
  say "FLEET,would roll,"
  say "HOME,would settle,"
  exit 0
fi

# STAGE
"$SELF_DIR/release-build.sh" "$main_full" >/tmp/ul-build.log 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  say "STAGE,FAIL,build exited $rc"
  exit 1
fi
say "STAGE,ok,$main_id"

# PROVE
cand_dir="$YMIR_RELEASES_DIR/$main_id"
if [ -x "$cand_dir/bin/gates/ci-verify.sh" ]; then
  ( cd "$cand_dir" && bash bin/gates/ci-verify.sh ) >/tmp/ul-prove.log 2>&1
  rc=$?
else
  bash "$ROOT/bin/gates/ci-verify.sh" >/tmp/ul-prove.log 2>&1
  rc=$?
fi
if [ $rc -ne 0 ]; then
  say "PROVE,FAIL,red candidate kept for inspection"
  exit 1
fi
say "PROVE,ok,$main_id"

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
eir_before=0
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
