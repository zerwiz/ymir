#!/usr/bin/env bash
# bitrate-gate.sh — a diffusion clip that "completes" is not a clip that worked.
#
# WHY THIS GATE EXISTS (measured 2026-10-05):
#   MiniMax H3 on heimdall produced a valid MP4 — right frame count, right
#   duration, right resolution, the FULL PROMPT in the metadata — of uniform RGB
#   noise. `status: completed`. Every job-level check passed. Nothing in the log
#   said otherwise.
#
#   The only tell is the file's own bitrate. Corrupted diffusion output is
#   ANOMALOUSLY HIGH: Comfy-Org/ComfyUI#15738 records ~24-47 Mbps for corrupt
#   output against ~8-10 Mbps for a correct clip of the SAME length and
#   resolution. Our corrupt render measured 26.8 Mbps against a correct clip of
#   ours at 0.47.
#
#   >>> THE BANDS ARE PER-SHAPE, NOT GLOBAL. <<<
#   0.47 Mbps is correct for a finished 832x448 assembly; 8-10 is correct for a
#   1344x768 diffusion render. **Calibrate against a known-good render of the
#   SAME shape before trusting a threshold.** A default band is offered only so
#   the gate fails loudly when nobody has calibrated one.
#
# Usage:
#   ./bitrate-gate.sh <file.mp4> [min-mbps] [max-mbps]
# Exit 1 on failure, so it sits in a pipeline like any other gate.

set -uo pipefail

F="${1:?usage: bitrate-gate.sh <file.mp4> [min-mbps] [max-mbps]}"
MIN="${2:-0}"
MAX="${3:-45}"

if [ ! -f "$F" ]; then
  printf 'bitrate-gate[1]{file,verdict}: "%s","MISSING"\n' "$F" >&2
  exit 1
fi

python3 - "$F" "$MIN" "$MAX" <<'PY'
import json, os, subprocess, sys

path, lo, hi = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
base = os.path.basename(path)

try:
    probe = json.loads(subprocess.run(
        ["ffprobe", "-v", "quiet", "-print_format", "json",
         "-show_streams", "-show_format", path],
        capture_output=True, text=True).stdout or "{}")
except Exception:
    probe = {}

duration = float((probe.get("format") or {}).get("duration") or 0) or 0.0
video = [s for s in probe.get("streams", []) if s.get("codec_type") == "video"]

bitrate = 0
for s in video:
    if s.get("bit_rate"):
        bitrate = int(s["bit_rate"])
        break
if not bitrate and duration > 0:
    bitrate = os.path.getsize(path) * 8 / duration

mbps = bitrate / 1e6
frames = next((int(s.get("nb_frames") or 0) for s in video), 0)
res = next((f'{s.get("width")}x{s.get("height")}' for s in video), "?")

print(f'bitrate-gate[4]{{file,mbps,frames,resolution}}: "{base}","{mbps:.2f}","{frames}","{res}"')

if mbps <= 0:
    print('  "verdict","UNKNOWN — ffprobe returned no bitrate; cannot judge"')
    raise SystemExit(1)

if lo <= mbps <= hi:
    print(f'  "verdict","PASS — {mbps:.2f} Mbps within {lo}-{hi}"')
    raise SystemExit(0)

print(f'  "verdict","FAIL — {mbps:.2f} Mbps outside {lo}-{hi}"')
print('  "why","corrupt diffusion output runs 2-5x a correct clip OF THE SAME SHAPE;'
      ' the band is per-shape, not global"')
print('  "next","look at a frame: ffmpeg -i FILE -ss 2 -frames:v 1 /tmp/f.jpg"')
raise SystemExit(1)
PY
