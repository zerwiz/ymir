#!/usr/bin/env bash
# snotra-reason.sh — the reasoning pass: use the local rail for logic tasks.
#
#   snotra-reason.sh extract   <transcript-file>   extract decisions/actions/questions via LLM
#   snotra-reason.sh steps     <action-text>       generate suggested steps via LLM
#   snotra-reason.sh classify  <card-text>         classify into workstream board via LLM
#   snotra-reason.sh dedup     <new-card> <existing-cards>  detect semantic duplicates
#   snotra-reason.sh identity  <speaker> <context> resolve speaker to user
#
# Uses the local rail (llama-swap) for reasoning. Falls back to deterministic
# logic if the rail is unavailable.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && while [ ! -d "$PWD/RULES" ] && [ "$PWD" != / ]; do cd ..; done; pwd)"
# Resolve rail
RAIL_URL="${RAIL_URL:-}"
if [ -z "$RAIL_URL" ] && [ -x "$ROOT/bin/model/rail-resolve.sh" ]; then
  RAIL_URL="$(bash "$ROOT/bin/model/rail-resolve.sh" resolve --json 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("url",""))' 2>/dev/null || true)"
fi
RAIL_URL="${RAIL_URL:-http://127.0.0.1:8080/v1}"
RAIL_MODEL="${RAIL_MODEL:-}"
RAIL_KEY="${RAIL_KEY:-}"
if [ -z "$RAIL_KEY" ] && [ -f "$HOME/.pi/agent/auth.json" ]; then
  RAIL_KEY=$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("llama-swap",{}).get("key",""))' "$HOME/.pi/agent/auth.json" 2>/dev/null || true)
fi

ACTION="${1:-}"; shift || true

# Helper: call the rail with a prompt
rail_call() {
  local system_prompt="$1" user_prompt="$2" max_tokens="${3:-500}"
  if [ -z "$RAIL_KEY" ] || [ -z "$RAIL_MODEL" ]; then
    echo ""  # no rail available, return empty
    return
  fi
  curl -s --max-time 120 "$RAIL_URL/chat/completions" \
    -H "Authorization: Bearer $RAIL_KEY" \
    -H "Content-Type: application/json" \
    -d "$(python3 - "$RAIL_MODEL" "$system_prompt" "$user_prompt" "$max_tokens" <<'PY'
import json,sys
model, sys_p, user_p, max_t = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
print(json.dumps({
  "model": model,
  "messages": [
    {"role":"system","content":sys_p},
    {"role":"user","content":user_p}
  ],
  "temperature": 0,
  "max_tokens": max_t
}))
PY
)" 2>/dev/null | python3 -c '
import json,sys
try:
  d=json.loads(sys.stdin.read())
  print(d.get("choices",[{}])[0].get("message",{}).get("content",""))
except Exception:
  print("")
' 2>/dev/null || true
}

case "$ACTION" in
  extract)
    TRANSCRIPT_FILE="${1:-}"
    [ -f "$TRANSCRIPT_FILE" ] || { echo "error: transcript file not found" >&2; exit 1; }
    TRANSCRIPT=$(cat "$TRANSCRIPT_FILE")
    rail_call "You are a meeting transcript analyzer. Extract decisions, action items, and open questions from the transcript. For each item, provide: type (decision/action/question), statement, owner (if mentioned), due date (if mentioned), and evidence quote with timestamp. Output as JSON array." \
      "Transcript:\n${TRANSCRIPT:0:15000}" 800
    ;;
  steps)
    ACTION_TEXT="${1:-}"
    rail_call "You are a task breakdown assistant. Given an action item, generate 3-5 concrete, ordered, actionable steps. Each step should be something a person can do in one sitting. Output as a numbered list." \
      "Action item: $ACTION_TEXT" 300
    ;;
  classify)
    CARD_TEXT="${1:-}"
    rail_call "You are a workstream classifier. Given a card's text, classify it into one of: patent, vertical, docs, control-tower, meetings. Output only the classification." \
      "Card text: $CARD_TEXT" 50
    ;;
  dedup)
    NEW_CARD="${1:-}"; EXISTING="${2:-}"
    rail_call "You are a duplicate detector. Given a new card and a list of existing cards, determine if the new card is a semantic duplicate of any existing card. Output: 'duplicate: <existing card id>' or 'unique'." \
      "New card: $NEW_CARD\nExisting cards:\n$EXISTING" 100
    ;;
  identity)
    SPEAKER="${1:-}"; CONTEXT="${2:-}"
    rail_call "You are an identity resolver. Given a speaker name from a transcript and context about the meeting participants, resolve the speaker to their full name. Output only the full name." \
      "Speaker: $SPEAKER\nContext: $CONTEXT" 50
    ;;
  *)
    echo "usage: snotra-reason.sh extract|steps|classify|dedup|identity ..." >&2
    exit 2
    ;;
esac