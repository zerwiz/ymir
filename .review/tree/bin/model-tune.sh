#!/usr/bin/env bash
# model-tune.sh — tune the chosen model for THIS host, with measured numbers.
#
# Drives the modeltesting skill's own bench (bench-one.sh / bench-ctx.sh) — it
# does NOT reconfigure the serving stack; the bench starts a throwaway server and
# kills it. The measured settings REPLACE the placeholder in the seat's
# data/local-models.md, so the record says what was measured, not researched.
#
# Usage:
#   model-tune.sh --model-id <registry-id> [--max-tokens N]
#   model-tune.sh --gguf PATH --ctx N --ncmoe N --ctk q8_0 --ctv q8_0
#   model-tune.sh --dry-run ...        # print the bench command, run nothing
#   model-tune.sh --version
#
# Env:
#   YMIR_MODELTESTING_DIR   — the modeltesting skill dir
#                             (default ~/.agents/skills/modeltesting)
#   YMIR_LOCAL_MODELS_DOC   — the record to write (default $YMIR_DATA_DIR/local-models.md)
#
# Exit: 0 tuned, 2 usage, 3 bench/skill absent, 4 the bench failed.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
hoard_data_dir YMIR_DATA_DIR
BENCH_DIR="${YMIR_MODELTESTING_DIR:-$HOME/.agents/skills/modeltesting}/scripts"
OUT="${YMIR_LOCAL_MODELS_DOC:-$YMIR_DATA_DIR/local-models.md}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

MODEL_ID=""; GGUF=""; CTX=""; NCMOE=""; CTK=""; CTV=""; MAX_TOKENS="256"; DRY=0
while [ $# -gt 0 ]; do case "$1" in
  --model-id) MODEL_ID="${2-}"; shift 2 ;;
  --model-id=*) MODEL_ID="${1#--model-id=}"; shift ;;
  --gguf) GGUF="${2-}"; shift 2 ;;
  --gguf=*) GGUF="${1#--gguf=}"; shift ;;
  --ctx) CTX="${2-}"; shift 2 ;;
  --ctx=*) CTX="${1#--ctx=}"; shift ;;
  --ncmoe) NCMOE="${2-}"; shift 2 ;;
  --ncmoe=*) NCMOE="${1#--ncmoe=}"; shift ;;
  --ctk) CTK="${2-}"; shift 2 ;;
  --ctk=*) CTK="${1#--ctk=}"; shift ;;
  --ctv) CTV="${2-}"; shift 2 ;;
  --ctv=*) CTV="${1#--ctv=}"; shift ;;
  --max-tokens) MAX_TOKENS="${2-}"; shift 2 ;;
  --max-tokens=*) MAX_TOKENS="${1#--max-tokens=}"; shift ;;
  --dry-run) DRY=1; shift ;;
  *) shift ;;
esac; done

have() { command -v "$1" >/dev/null 2>&1; }

# A CUDA engine must stand — a CPU bench measures nothing.
CUDA_BIN=""
for c in "${LLAMA_SERVER_CUDA:-}" llama-server-cuda "$(command -v llama-server 2>/dev/null || true)"; do
  [ -n "$c" ] && [ -x "$c" ] && { CUDA_BIN="$c"; break; }
done
if [ -z "$CUDA_BIN" ]; then
  printf 'error: no llama-server found — a CPU bench would measure a lie\nhelp: bin/llama-ensure.sh ensure\n' >&2
  exit 3
fi
if ! timeout 25 "$CUDA_BIN" --list-devices 2>&1 | grep -q 'CUDA[0-9]'; then
  printf 'error: the llama-server at %s reports no CUDA device\nhelp: bin/llama-ensure.sh status\n' "$CUDA_BIN" >&2
  exit 3
fi

# Choose the bench and build its command.
if [ -n "$GGUF" ]; then
  BENCH="$BENCH_DIR/bench-ctx.sh"
  [ -x "$BENCH" ] || [ -f "$BENCH" ] || { printf 'error: bench-ctx.sh not found at %s\nhelp: set YMIR_MODELTESTING_DIR\n' "$BENCH" >&2; exit 3; }
  [ "$DRY" = 1 ] || [ -f "$GGUF" ] || { printf 'error: gguf not found: %s\n' "$GGUF" >&2; exit 2; }
  CMD=(bash "$BENCH" "tune-$(basename "$GGUF" .gguf)" "$GGUF" "${CTX:-32768}" "${NCMOE:-0}" "${CTK:-q8_0}" "${CTV:-q8_0}")
elif [ -n "$MODEL_ID" ]; then
  BENCH="$BENCH_DIR/bench-one.sh"
  [ -x "$BENCH" ] || [ -f "$BENCH" ] || { printf 'error: bench-one.sh not found at %s\nhelp: set YMIR_MODELTESTING_DIR\n' "$BENCH" >&2; exit 3; }
  CMD=(bash "$BENCH" "$MODEL_ID" "" "$MAX_TOKENS")
else
  printf 'error: usage: model-tune.sh --model-id ID | --gguf PATH [--ctx N --ncmoe N --ctk T --ctv T]\n' >&2
  exit 2
fi

if [ "$DRY" = 1 ]; then
  printf 'model-tune[1]{state,cmd}:\n  "would-run","%s"\n' "${CMD[*]}"
  exit 0
fi

printf 'model-tune[1]{state,bench}:\n  "running","%s"\n' "${CMD[*]}" >&2
LOG="$(mktemp /tmp/model-tune-XXXXXX.log)"
if ! "${CMD[@]}" >"$LOG" 2>&1; then
  printf 'error: the bench failed — see %s\n' "$LOG" >&2
  tail -12 "$LOG" >&2 || true
  exit 4
fi

# Extract the measured result lines (RESULT / tokens/s / VRAM) and write them.
RESULT="$(grep -iE 'RESULT|tokens/s|prefill|decode|VRAM|n_ctx' "$LOG" | tail -20 || true)"
[ -n "$RESULT" ] || { printf 'error: the bench produced no measurable result line\nhelp: see %s\n' "$LOG" >&2; exit 4; }

mkdir -p "$(dirname "$OUT")"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BLOCK="## Best settings for THIS hardware (measured)
<!-- model-tune:begin -->
- **Tuned:** ${STAMP}
- **Engine:** ${CUDA_BIN}
- **Bench:** ${CMD[*]}
- **Measured:**
\`\`\`
${RESULT}
\`\`\`
<!-- model-tune:end -->"

python3 - "$OUT" "$BLOCK" <<'PY'
import sys
path, block = sys.argv[1], sys.argv[2]
try:
    t = open(path).read()
except FileNotFoundError:
    t = "# Local models\n"
begin, end = "<!-- model-tune:begin -->", "<!-- model-tune:end -->"
if begin in t and end in t:
    a = t.index(begin)
    # include the heading line above the marker when present
    head = "## Best settings for THIS hardware (measured)\n"
    if head in t[:a]:
        a = t.rindex(head)
    b = t.index(end) + len(end)
    t = t[:a] + block + t[b:]
else:
    # replace the researched placeholder section if it is there, else append.
    ph = "## Best settings for THIS hardware (researched)"
    if ph in t:
        a = t.index(ph)
        t = t[:a] + block + "\n"
    else:
        t = t.rstrip() + "\n\n" + block + "\n"
open(path, "w").write(t)
print(f"model-tune: measured settings written to {path}")
PY
