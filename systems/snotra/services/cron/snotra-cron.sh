#!/usr/bin/env bash
# systems/snotra/services/snotra-cron.sh — the door itself (plan 129). The 'RETIRED SHIM' wording below was copied in by the move and removed 2026-10-31: this file IS the door, not a shim of one.
#
# It exists so a caller nobody has repointed yet still works. It is retired by the dated follow-up in
# docs/fixes/snotra/2026-10-24-snotra-becomes-a-system.md, and .agents/paths-ledger.yaml records the move.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
HOME_DIR="${YMIR_HOME:-}"
[ -n "$HOME_DIR" ] || { . "$ROOT/bin/vault/hoard-lib.sh"; ymir_home_root HOME_DIR; }
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ymir"
mkdir -p "$STATE"
ACTION="${1:-digest}"
LOG="$STATE/snotra-cron.log"
now_iso() { "$ROOT/bin/time/sol.sh" now 2>/dev/null | sed -n 's/^  "local","\(.*\)"/\1/p' | head -1; }
log() { printf '%s %s\n' "$(now_iso)" "$*" >> "$LOG"; }

meetings() {
  find "$HOME_DIR/svartalfaheim" -type f -name record.json -printf '%h\n' 2>/dev/null | sort -u
}

sync_one() {
  local d="$1"
  [ -f "$d/signoffs.json" ] || return 0
  bash "$ROOT/bin/time/snotra/snotra-signoff.sh" sync "$d" --dry-run >/dev/null 2>&1 || true
  # live sync only when a reply exists; --dry-run would never record, so run live
  bash "$ROOT/bin/time/snotra/snotra-signoff.sh" sync "$d" >>"$LOG" 2>&1 || true
  bash "$ROOT/bin/time/snotra/snotra-trello.sh" sync "$d" >>"$LOG" 2>&1 || true
}

digest_one() {
  local d="$1" title decisions actions questions blocking pending overdue
  title="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get('meeting',d).get('title',''))" "$d/record.json" 2>/dev/null || true)"
  [ -n "$title" ] || return 0
  read -r decisions actions questions blocking overdue <<EOF
$(python3 - "$d" <<'PY'
import json,sys,datetime,os
d=sys.argv[1]; r=json.load(open(d+'/record.json'))
today=datetime.date.today()
overdue=0
for a in r.get('actions',[]):
    try:
        if a.get('due_at') and datetime.date.fromisoformat(a['due_at'][:10]) < today: overdue+=1
    except Exception: pass
print(len(r.get('decisions',[])), len(r.get('actions',[])), len(r.get('questions',[])), sum(1 for q in r.get('questions',[]) if q.get('blocking')), overdue)
PY
)
EOF
  local pending=0
  [ -f "$d/signoffs.json" ] && pending="$(python3 -c "import json;d=json.load(open('$d/signoffs.json'));print(sum(1 for p in d.get('people',[]) if p.get('status')=='pending'))" 2>/dev/null || echo 0)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$title" "$decisions" "$actions" "$questions" "$blocking" "$pending" "$overdue"
}

digest() {
  local out="$HOME_DIR/hodd/memory/snotra-digest.md"
  local tmp; tmp="$(mktemp)"
  {
    echo "# Snotra digest — $(now_iso)"
    echo
    echo "| Meeting | Decisions | Actions | Questions | Blocking | Sign-off pending | Overdue actions |"
    echo "|---|---|---|---|---|---|---|"
    while IFS= read -r d; do [ -n "$d" ] && digest_one "$d"; done < <(meetings) \
      | awk -F'\t' 'NF==7 {printf "| %s | %s | %s | %s | %s | %s | %s |\n", $1,$2,$3,$4,$5,$6,$7}'
  } > "$tmp"
  mv "$tmp" "$out"
  local summary; summary="$(tail -n +4 "$out" | wc -l)"
  log "digest written: $out"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a Snotra "Meeting digest" "$(grep -c '^|' "$out") rows · $out" 2>/dev/null || true
  fi
  printf 'digest\t%s\n' "$out"
}

friday_synch() {
  local d; d="$(meetings | head -1)"
  [ -n "$d" ] || { echo "no meetings"; exit 0; }
  bash "$ROOT/bin/time/snotra/snotra-friday-synch.sh" run "$d" >>"$LOG" 2>&1 || true
  log "friday synch complete from $d"
}

grooming() {
  local d; d="$(meetings | head -1)"
  [ -n "$d" ] || { echo "no meetings"; exit 0; }
  bash "$ROOT/bin/time/snotra/snotra-grooming.sh" run "$d" >>"$LOG" 2>&1 || true
  log "grooming card complete from $d"
}

card_moves() {
  for board in "Synteon — Meetings" "Documentation"; do
    bash "$ROOT/bin/time/snotra/snotra-card-moves.sh" watch "$board" >>"$LOG" 2>&1 || true
  done
  log "card moves complete"
}

agenda() {
  local d; d="$(meetings | head -1)"
  [ -n "$d" ] || { echo "no meetings"; exit 0; }
  if [ -f "$d/agenda-next.md" ]; then
    local op; op="$(python3 - "$HOME_DIR/hodd/identity/operator.yaml" <<'PY2'
import sys
for line in open(sys.argv[1], encoding='utf-8'):
    if line.startswith('email:'):
        print(line.split(':',1)[1].strip()); break
PY2
)"
    [ -n "${OPERATOR_EMAIL:-$op}" ] && bash "$ROOT/bin/time/snotra/mail-send.sh" draft --to "${OPERATOR_EMAIL:-$op}" \
      --subject "Agenda draft — next meeting" --body "$d/agenda-next.md" >/dev/null 2>&1 || true
    log "agenda draft prepared from $d"
  fi
}

case "$ACTION" in
  sync) while IFS= read -r d; do [ -n "$d" ] && sync_one "$d"; done < <(meetings); log "sync complete" ;;
  digest) digest ;;
  agenda) agenda ;;
  friday-synch) friday_synch ;;
  grooming) grooming ;;
  card-moves) card_moves ;;
  *) echo "usage: snotra-cron.sh sync|digest|agenda|friday-synch|grooming|card-moves" >&2; exit 2 ;;
esac
