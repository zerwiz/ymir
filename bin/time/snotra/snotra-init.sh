#!/usr/bin/env bash
# snotra-init.sh — the first-run setup for the meeting system, agnostic by construction.
#
#   snotra-init.sh check    # what is missing (no writes)
#   snotra-init.sh apply    # create what is missing, idempotently
#
# Creates only the generic skeleton: the meetings shelf, an operator template if no
# operator exists, a confidential register template, the framework and templates, and
# the Snotra cron lines. It never writes a company, a participant or an NDA hash; those
# are the operator's.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MODE="${1:-check}"
case "$MODE" in check|apply) ;; *) echo "usage: snotra-init.sh check|apply" >&2; exit 2 ;; esac

. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
HOME_DIR="${YMIR_HOME:-}"
[ -n "$HOME_DIR" ] || command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR 2>/dev/null || true
[ -n "$HOME_DIR" ] || { echo "error: no Ymir home resolved (set YMIR_HOME or install first)" >&2; exit 1; }
[ -d "$HOME_DIR/hodd" ] || { echo "error: $HOME_DIR is not a Ymir home (no hodd/)" >&2; exit 1; }

MISSING=0
need() { MISSING=$((MISSING+1)); printf 'missing\t%s\n' "$1"; }
have() { printf 'ok\t%s\n' "$1"; }

MEETINGS="$HOME_DIR/hodd/life/meetings"
OP="$HOME_DIR/hodd/identity/operator.yaml"
CONF="$HOME_DIR/hodd/identity/confidential.yaml"
FRAME="$MEETINGS/meeting-framework.md"
TPL="$MEETINGS/templates"
CRON="$HOME_DIR/config/cron.yaml"

check() {
  [ -d "$MEETINGS" ] && have "$MEETINGS" || need "$MEETINGS"
  [ -f "$OP" ] && have "$OP" || need "$OP (operator identity)"
  [ -f "$CONF" ] && have "$CONF" || need "$CONF (confidential register)"
  [ -f "$FRAME" ] && have "$FRAME" || need "$FRAME (framework)"
  [ -d "$TPL" ] && have "$TPL" || need "$TPL (templates)"
  if [ -f "$CRON" ] && grep -q "Snotra meeting maintenance" "$CRON"; then have "cron Snotra block"; else need "cron Snotra block"; fi
  printf 'snotra-init\t%s\t%d missing\n' "$HOME_DIR" "$MISSING"
  [ "$MISSING" = 0 ]
}

apply() {
  mkdir -p "$MEETINGS" "$TPL" "$(dirname "$CRON")"
  if [ ! -f "$OP" ]; then
    cp "$ROOT/.agents/skills/snotra-meeting-outcomes/assets/templates/operator.example.yaml" "$OP"
    echo "created	$OP"
  else
    echo "kept	$OP"
  fi
  if [ ! -f "$CONF" ]; then
    cp "$ROOT/.agents/skills/snotra-meeting-outcomes/assets/templates/confidential.example.yaml" "$CONF"
    echo "created	$CONF"
  else
    echo "kept	$CONF"
  fi
  if [ ! -f "$FRAME" ]; then
    cp "$ROOT/.agents/skills/snotra-meeting-outcomes/assets/meeting-framework.example.md" "$FRAME"
    echo "created	$FRAME"
  else
    echo "kept	$FRAME"
  fi
  for f in agenda.example.md decision.example.md signoff.example.md; do
    [ -f "$ROOT/.agents/skills/snotra-meeting-outcomes/assets/templates/$f" ] || continue
    dest="$TPL/${f/.example/}"
    [ -f "$dest" ] || cp "$ROOT/.agents/skills/snotra-meeting-outcomes/assets/templates/$f" "$dest"
  done
  if ! grep -q "Snotra meeting maintenance" "$CRON" 2>/dev/null; then
    cat >> "$CRON" <<'CRON'

# — Snotra meeting maintenance (created by snotra-init) —
# Reads sign-off replies, syncs the Trello board, writes the digest.
@dev 08:05 bin/time/snotra/snotra-cron.sh sync
@dev 12:05 bin/time/snotra/snotra-cron.sh sync
@dev 16:05 bin/time/snotra/snotra-cron.sh sync
@dev 08:10 bin/time/snotra/snotra-cron.sh digest
CRON
    echo "created	$CRON (Snotra block)"
  else
    echo "kept	$CRON (Snotra block)"
  fi
  cat <<TXT

Next, the two things no installer can decide for you:
  1. Fill in $OP (name, email, organisation, partners).
  2. Connect Trello: mcp({ connect: "trello" }) and run
     bin/time/snotra/snotra-trello.sh export <meeting-dir>
     The board is created under your workspace as "Meetings" (or TRELLO_BOARD_NAME).
TXT
}

case "$MODE" in check) check ;; apply) apply ;; esac
