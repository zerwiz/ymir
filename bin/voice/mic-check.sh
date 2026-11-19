#!/usr/bin/env bash
# mic-check.sh — what the microphone gives the machine, measured, never guessed (plan 326.6).
#
#   mic-check.sh level [seconds] [--source <name>]   record the RAW source, print dBFS per second, the spread,
#                                                     the band, and the system's own input volume (default 10 s)
#   mic-check.sh trace <file.wav> [<file.wav> …]      the same per-second trace for files already recorded
#   mic-check.sh volume [--source <name>]             the system's input volume for the source, nothing recorded
#
# Bands (dBFS of one second's RMS, the scale Rödd's level line uses): under -45 silent · -45..-35 too quiet ·
# -35..-10 good · a peak at -1 or above is clipping. A steady voice stays in one band; a swing of more than 12 dB
# across voiced seconds is the "loud, then very quiet" a gain control makes.
#
# Records nothing while the desk is held (bin/desk/in-call.sh), opens no window, changes no setting, keeps no audio:
# the file lives in a temporary folder and is removed when the trace is printed.
#
# Exit: 0 ok · 1 no recorder or no source · 2 usage · 4 the desk is held.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }

default_source() { pactl get-default-source 2>/dev/null; }

volume_of() {
  pactl get-source-volume "$1" 2>/dev/null | grep -oE '[0-9]+%|-?[0-9.]+ dB' | head -2 | paste -sd' ' -
}

trace() {
  python3 - "$@" <<'PY'
import array, math, sys, wave
for path in sys.argv[1:]:
    try:
        w = wave.open(path)
    except Exception as exc:
        print(f"{path}: not a wav file ({exc})"); continue
    ch, width, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    if width != 2:
        print(f"{path}: 16-bit wav only (got {8 * width}-bit)"); continue
    data = array.array("h", w.readframes(n))
    if sys.byteorder == "big":
        data.byteswap()
    rows = []
    for sec in range(n // rate):
        seg = data[sec * rate * ch:(sec + 1) * rate * ch:ch]
        ss = sum(x * x for x in seg) / max(1, len(seg))
        pk = max((abs(x) for x in seg), default=0)
        rows.append((20 * math.log10(math.sqrt(ss) / 32768 + 1e-9), 20 * math.log10(pk / 32768 + 1e-9)))
    def band(r, p):
        return "clip" if p >= -1 else "silent" if r < -45 else "quiet" if r < -35 else "good"
    # the first second carries the stream's opening click; it is shown, never judged
    judged = rows[1:] if len(rows) > 2 else rows
    voiced = [r for r in judged if r[0] >= -45]
    bands = sorted({band(*r) for r in voiced})
    spread = (max(r[0] for r in voiced) - min(r[0] for r in voiced)) if voiced else 0.0
    print(f"trace{{file,seconds}}: {path},{len(rows)}")
    print("  rms_dbfs  " + " ".join(f"{r[0]:.0f}" for r in rows))
    print("  peak_dbfs " + " ".join(f"{r[1]:.0f}" for r in rows))
    verdict = ("no voice heard" if not voiced else
               f"steady — one band ({bands[0]})" if len(bands) == 1 and spread <= 12 else
               f"NOT steady — bands {'/'.join(bands)}")
    print(f"  voiced {len(voiced)} s · spread {spread:.0f} dB · {verdict}")
PY
}

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  -h|--help) usage; exit 0 ;;
  trace)
    [ $# -gt 0 ] || { usage >&2; exit 2; }
    trace "$@" ;;
  volume)
    src=""; [ "${1:-}" = "--source" ] && src="${2:-}"
    src="${src:-$(default_source)}"
    [ -n "$src" ] || { echo "mic-check: no input source is known to the sound server" >&2; exit 1; }
    printf 'source\t%s\nvolume\t%s\n' "$src" "$(volume_of "$src")" ;;
  level)
    secs=10; src=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --source) src="${2:-}"; shift 2 ;;
        [0-9]*) secs="$1"; shift ;;
        *) usage >&2; exit 2 ;;
      esac
    done
    if [ -x "$HERE/../desk/in-call.sh" ] && [ -n "$("$HERE/../desk/in-call.sh" holder 2>/dev/null)" ]; then
      echo "mic-check: the desk is held — nothing is recorded during a call" >&2; exit 4
    fi
    command -v pw-record >/dev/null 2>&1 || { echo "mic-check: pw-record is not installed (PipeWire)" >&2; exit 1; }
    src="${src:-$(default_source)}"
    [ -n "$src" ] || { echo "mic-check: no input source is known to the sound server" >&2; exit 1; }
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    timeout "$((secs + 1))" pw-record --target "$src" --rate 48000 --channels 1 --format s16 "$tmp/raw.wav" >/dev/null 2>&1
    [ -s "$tmp/raw.wav" ] || { echo "mic-check: nothing was recorded from $src" >&2; exit 1; }
    printf 'source\t%s\nvolume\t%s\n' "$src" "$(volume_of "$src")"
    trace "$tmp/raw.wav" | sed "s|$tmp/raw.wav|raw|" ;;
  *) usage >&2; exit 2 ;;
esac
