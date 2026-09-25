#!/usr/bin/env bash
# model-fit.sh — choose the best local model for THE USER'S hardware, probed at
# run time. Never this box: the GPU, VRAM, RAM, and free disk are read from the
# host, and the choice falls out of them and a curated candidate menu. Two
# different machines yield two different choices with the tree untouched.
#
# Usage:
#   model-fit.sh                 # probe, choose, print (TOON)
#   model-fit.sh --json          # the same as JSON
#   model-fit.sh --profile FILE  # a synthetic hardware profile (genericity test)
#   model-fit.sh --version
#
# Env (override the probe; also the synthetic-profile surface):
#   YMIR_HW_GPU        — GPU name
#   YMIR_HW_VRAM_MB    — total VRAM (MiB)
#   YMIR_HW_RAM_MB     — total RAM (MiB)
#   YMIR_HW_DISK_GB    — free disk at the models dir (GiB)
#   YMIR_FIT_CTX       — desired context (default 32768)
#
# Exit: 0 a model was chosen, 2 usage, 3 unknown hardware, 4 nothing fits.
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
hoard_settings_dir YMIR_SETTINGS_DIR
ymir_home_root YMIR_HOME
CATALOG="${YMIR_MODEL_CATALOG:-$YMIR_SETTINGS_DIR/model-catalog.yaml}"
CATALOG_TPL="$ROOT/config/model-catalog.yaml.example"
MODELS_DIR="${YMIR_MODELS_DIR:-$YMIR_HOME/models}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
JSON=0; PROFILE=""
while [ $# -gt 0 ]; do case "$1" in
  --json) JSON=1; shift ;;
  --profile) PROFILE="${2-}"; shift 2 ;;
  --profile=*) PROFILE="${1#--profile=}"; shift ;;
  *) shift ;;
esac; done

# Seed the hoard catalog from the template once, so the tree carries only a
# template and the operator's menu lives with the operator.
if [ ! -r "$CATALOG" ] && [ -r "$CATALOG_TPL" ]; then
  mkdir -p "$(dirname "$CATALOG")" 2>/dev/null || true
  cp "$CATALOG_TPL" "$CATALOG" 2>/dev/null || true
fi
[ -r "$CATALOG" ] || { printf 'error: no model catalog at %s\nhelp: install seeds it from %s\n' "$CATALOG" "$CATALOG_TPL" >&2; exit 3; }

have() { command -v "$1" >/dev/null 2>&1; }

# ── probe the host (or read a synthetic profile) ─────────────────────────────
gpu="${YMIR_HW_GPU:-}"; vram="${YMIR_HW_VRAM_MB:-}"; ram="${YMIR_HW_RAM_MB:-}"; disk="${YMIR_HW_DISK_GB:-}"

if [ -n "$PROFILE" ]; then
  [ -r "$PROFILE" ] || { printf 'error: profile not found: %s\n' "$PROFILE" >&2; exit 2; }
  eval "$(python3 - "$PROFILE" <<'PY'
import sys
try:
    import yaml
except Exception:
    sys.exit(0)
d = yaml.safe_load(open(sys.argv[1])) or {}
for k, v in d.items():
    if k in ("gpu", "vram_mb", "ram_mb", "disk_gb") and v not in (None, ""):
        print(f'export {k.upper()}={v}')
PY
)"
  gpu="${GPU:-$gpu}"; vram="${VRAM_MB:-$vram}"; ram="${RAM_MB:-$ram}"; disk="${DISK_GB:-$disk}"
fi

if [ -z "$gpu" ] && have nvidia-smi; then
  line="$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)"
  gpu="${line%%,*}"; vram="${vram:-${line##*, }}"
fi
if [ -z "$vram" ] && have rocm-smi; then
  gpu="${gpu:-AMD GPU}"; vram="${vram:-$(rocm-smi --showmeminfo vram 2>/dev/null | grep -oE '[0-9]+' | head -1)}"
fi
if [ -z "$gpu" ] && [ -d /sys/class/drm ]; then
  gpu="$( (lspci 2>/dev/null || true) | grep -iE 'vga|3d|display' | head -1 | sed 's/^[0-9a-f:.]* //' )"
fi
if [ -z "$ram" ]; then
  if [ -r /proc/meminfo ]; then ram="$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 ))"
  elif have sysctl; then ram="$(( $(sysctl -n hw.memsize 2>/dev/null || printf 0) / 1048576 ))"; fi
fi
if [ -z "$disk" ]; then
  mkdir -p "$MODELS_DIR" 2>/dev/null || true
  disk="$(df -BG "$MODELS_DIR" 2>/dev/null | awk 'NR==2{gsub("G","",$4); print $4}')"
fi

# Unknown hardware is a LOUD refusal, never a guess.
if [ -z "$gpu" ] || [ -z "$vram" ] || [ -z "$ram" ]; then
  printf 'error: hardware could not be probed (gpu=%s vram=%s ram=%s)\n' "${gpu:-?}" "${vram:-?}" "${ram:-?}" >&2
  printf 'help: provide a profile (--profile FILE) or set YMIR_HW_GPU/VRAM_MB/RAM_MB.\n' >&2
  exit 3
fi

export YMIR_FIT_CTX="${YMIR_FIT_CTX:-32768}"

# ── choose: the largest candidate that fits ──────────────────────────────────
python3 - "$CATALOG" "$gpu" "$vram" "${ram:-0}" "${disk:-0}" "$JSON" "$YMIR_FIT_CTX" <<'PY'
import sys, json
catalog_path, gpu, vram, ram, disk, as_json, want_ctx = sys.argv[1:8]
try:
    import yaml
except Exception:
    print("error: python3 has no PyYAML"); sys.exit(3)
vram = int(float(vram)); ram = int(float(ram or 0)); disk = int(float(disk or 0))
want_ctx = int(float(want_ctx or 32768))
cfg = yaml.safe_load(open(catalog_path)) or {}
cands = cfg.get("candidates") or []
if not cands:
    print("error: the model catalog has no candidates"); sys.exit(3)

usable_vram = int(vram * 0.90)          # keep headroom for context + overhead
usable_ram  = int(ram * 0.80) if ram else 0

def fits(c):
    if int(c.get("min_vram_mb") or 0) > usable_vram:
        return False
    if disk and float(c.get("size_gb") or 0) > disk:
        return False
    return True

ordered = sorted(cands, key=lambda c: (float(c.get("params_b") or 0), float(c.get("size_gb") or 0)), reverse=True)
choice = next((c for c in ordered if fits(c)), None)
if choice is None:
    print(f"error: no candidate fits — vram={vram}MiB ram={ram}MiB disk={disk}GiB", file=sys.stderr)
    print("help: add a smaller candidate to the catalog, or raise the disk/VRAM.", file=sys.stderr)
    sys.exit(4)

ctx = min(int(choice.get("context") or want_ctx), want_ctx) if want_ctx else int(choice.get("context") or 0)
reason = (f"largest of {len(cands)} candidates that fits "
          f"{usable_vram}MiB usable VRAM and {disk}GiB free disk"
          if disk else f"largest of {len(cands)} candidates that fits {usable_vram}MiB usable VRAM")

if as_json == "1":
    print(json.dumps({"gpu": gpu, "vram_mb": vram, "ram_mb": ram, "disk_gb": disk,
                      "choice": choice, "ctx": ctx, "reason": reason}))
else:
    print("model-fit[1]{gpu,vram_mb,ram_mb,disk_gb,ctx,id,quant,size_gb,reason}:")
    print(f'  "{gpu}","{vram}","{ram}","{disk}","{ctx}","{choice.get("id")}",'
          f'"{choice.get("quant")}","{choice.get("size_gb")}","{reason}"')
PY
