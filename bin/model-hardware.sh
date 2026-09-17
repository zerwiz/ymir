#!/usr/bin/env bash
# model-hardware.sh — profile THIS machine for local models and record the
# baseline in data/local-models.md.
#
# Local models are hardware-bound, so the install learns the machine before it
# advises: GPU + VRAM, CPU, RAM. It states the baseline (llama.cpp — llama-server
# / llama-swap — is fastest on the GPU; coding wants >= 80000 context) and, when
# online, marks the settings section for Brokk to research the exact best
# settings for this GPU and write them here.
#
# Usage:
#   model-hardware.sh            # detect + write data/local-models.md
#   model-hardware.sh --print    # detect + print, do not write
#   model-hardware.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
OUT="${YMIR_LOCAL_MODELS_DOC:-$YMIR_DATA_DIR/local-models.md}"
PRINT_ONLY=0

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
[ "${1-}" = "--print" ] && PRINT_ONLY=1

have() { command -v "$1" >/dev/null 2>&1; }

gpu="$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1 || true)"
[ -n "$gpu" ] || gpu="$( (lspci 2>/dev/null || true) | grep -iE 'vga|3d|display' | head -1 | sed 's/^[0-9a-f:.]* //' || true)"
[ -n "$gpu" ] || gpu="none detected"
cpu="$( (grep -m1 'model name' /proc/cpuinfo 2>/dev/null || sysctl -n machdep.cpu.brand_string 2>/dev/null || true) | sed 's/^.*: //' )"
[ -n "$cpu" ] || cpu="unknown"
ram="$( (free -h 2>/dev/null | awk '/Mem:/{print $2}') || true )"
[ -n "$ram" ] || ram="unknown"

online=no
if curl -fsS --max-time 4 -o /dev/null https://github.com 2>/dev/null; then online=yes; fi

printf 'model-hardware[1]{gpu,cpu,ram,online}:\n  "%s","%s","%s","%s"\n' "$gpu" "$cpu" "$ram" "$online"

if [ "$PRINT_ONLY" = 1 ]; then exit 0; fi

mkdir -p "$(dirname "$OUT")"
# Idempotent block: replace whatever sits between the markers.
block="<!-- model-hardware:begin -->
## This machine
- **GPU:** ${gpu}
- **CPU:** ${cpu}
- **RAM:** ${ram}

## The baseline
- **llama.cpp** (llama-server / llama-swap) is the fastest local engine on the GPU —
  build/run the CUDA build; keep K and V the same KV type (q8_0).
- **Coding wants >= 80000 context.** Measure the real ceiling: load more until a
  request OOMs, then drop one step (ctx is per-model).
- **The method** — engines, wiring, and honest measurement — is the Galdr asset
  \`.agents/skills/galdr-ymirsystem/assets/local-models.md\`. Then
  \`bin/models-detect.sh --write\` registers what serves.
<!-- model-hardware:end -->"

# The researched settings are NOT in the managed block, so a re-run never clobbers
# them. Brokk fills them once, online, for this GPU.
settings_section="## Best settings for THIS hardware (researched)
<!-- Brokk: search the web for 'llama.cpp best settings <this GPU>' and record the
     exact flags (--fit / --n-gpu-layers / --n-cpu-moe / --ctx-size / kv / -fa). -->"

if [ -f "$OUT" ] && grep -q "model-hardware:begin" "$OUT"; then
  python3 - "$OUT" "$block" <<'PY'
import sys
path, block = sys.argv[1], sys.argv[2]
t = open(path).read()
a = t.index("<!-- model-hardware:begin -->")
b = t.index("<!-- model-hardware:end -->") + len("<!-- model-hardware:end -->")
open(path, "w").write(t[:a] + block + t[b:])
PY
else
  { [ -f "$OUT" ] && cat "$OUT" || printf '# Local models\n\n'; printf '\n%s\n' "$block"; } >"$OUT.tmp" && mv "$OUT.tmp" "$OUT"
fi
# The (researched) settings section is created once and never overwritten.
if ! grep -q "## Best settings for THIS hardware" "$OUT" 2>/dev/null; then
  printf '\n%s\n' "$settings_section" >>"$OUT"
fi
printf 'model-hardware: wrote %s (online=%s)\n' "$OUT" "$online"
