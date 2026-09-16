#!/usr/bin/env bash
# huginn-research-worker — Apodex-powered research worker (Eindri).
# Takes a brief, recalls context from Mimirsbrunn, dispatches to the Apodex
# endpoint, and writes a structured verdict. Runs anywhere: herdr pane
# (preferred), Utgard sandbox, or host shell.
#
# Usage:
#   huginn-research-worker --brief "<task>" --output-dir <path>
#   huginn-research-worker --brief "<task>" --output-dir <path> [--model <model>]
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BRIEF="" OUTDIR="" MODEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --brief)    BRIEF="${2:-}"; shift 2 ;;
    --output-dir) OUTDIR="${2:-}"; shift 2 ;;
    --model)    MODEL="${2:-}"; shift 2 ;;
    --help|-h|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          echo "error: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$BRIEF" ]    || { echo "error: --brief required" >&2; exit 2; }
[ -n "$OUTDIR" ]   || { echo "error: --output-dir required" >&2; exit 2; }
mkdir -p "$OUTDIR"

# Resolve env — source .env.local if present.
for f in "$ROOT/.env.local" "${YMIR_HOARD:-$HOME/Documents/Ymir}/.env.local"; do
  [ -f "$f" ] && . "$f" 2>/dev/null || true
done

BASE="${APODEX_BASE_URL:-http://localhost:1234/v1}"
MODEL="${MODEL:-${APODEX_MODEL:-apodex-1.0-mini}}"
KEY="${APODEX_API_KEY:-not-needed-for-local}"

# 1. Recall context from Mimirsbrunn (boost, never blocker).
RECALL=""
if [ -x "$ROOT/bin/mimir.sh" ]; then
  RECALL=$("$ROOT/bin/mimir.sh" recall "$BRIEF" --k 3 2>/dev/null | tail -20 || true)
fi

# 2. Build the request payload.
PAYLOAD=$(python3 - "$BRIEF" "$RECALL" "$MODEL" <<'PY'
import json, sys
brief, recall, model = sys.argv[1], sys.argv[2], sys.argv[3]
msgs = [{"role": "system", "content": "You are Huginn — a research worker. Analyse the task, recall any relevant context, and produce a structured verdict. Return your findings as a structured markdown report."}]
content = f"Task: {brief}"
if recall.strip():
    content += f"\n\nRecalled context:\n{recall}"
msgs.append({"role": "user", "content": content})
print(json.dumps({"model": model, "messages": msgs, "temperature": 0.2}))
PY
)

# 3. Dispatch to Apodex endpoint.
RESP="$OUTDIR/response.json"
HTTP_CODE=$(curl -sS -w '%{http_code}' --max-time 120 \
  "$BASE/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -d "$PAYLOAD" \
  -o "$RESP" 2>/dev/null) || true

# 4. Validate response.
if ! python3 - "$RESP" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert "choices" in d and d["choices"], "no choices"
msg = d["choices"][0].get("message", {})
assert msg.get("content") or msg.get("tool_calls"), "no content/tool_calls"
PY
then
  echo "failed: no valid response from $BASE" > "$OUTDIR/status"
  echo "failed" >&2; exit 1
fi

# 5. Extract verdict into a clean summary.
python3 - "$RESP" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
msg = d["choices"][0]["message"]
verdict = msg.get("content", "")
summary = {
    "verdict": verdict,
    "model": d.get("model", ""),
    "tool_calls": bool(msg.get("tool_calls")),
    "usage": d.get("usage", {}),
}
with open(sys.argv[1], "w") as f:
    json.dump(summary, f, indent=2)
PY

# 6. Observe the verdict into Mimirsbrunn (never a blocker).
if [ -x "$ROOT/bin/mimir.sh" ]; then
  VERDICT=$(python3 -c "import json; print(json.load(open('$RESP')).get('verdict',''))" 2>/dev/null || true)
  [ -n "$VERDICT" ] && \
    "$ROOT/bin/mimir.sh" observe "$VERDICT" \
      --tags "apodex,research,verdict" \
      --source "huginn-research-worker" \
      2>/dev/null || true
fi

echo "completed" > "$OUTDIR/status"
echo "completed: verdict written to $OUTDIR/response.json" >&2
exit 0
