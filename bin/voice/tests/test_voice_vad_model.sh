#!/usr/bin/env bash
# test_voice_vad_model.sh — the voice's detector weights: ONE answer for where they live, and a
# checksum gate that refuses to seat anything else (plan 288 step 7, plan 287 P4).
#
# The weights left the public repository on 2026-11-14. What replaces them is an install step that
# fetches the file from a pinned upstream and verifies it. That leaves two ways to be wrong, and
# this file judges both:
#
#   1. TWO ANSWERS TO ONE QUESTION. `bin/voice/voice-ensure.sh` (fetches) and `bin/voice/ymir-vad.py`
#      (loads) each resolve the weights' path. Two resolvers that drift is how an install seats a
#      file under a name the loader never looks for — green install, dead turn boundary. So the two
#      doors are asked the SAME question and their answers must be the same string.
#   2. A CHECKSUM THAT IS NOT CHECKED. A truncated or substituted download once loaded as a valid
#      session and answered noise. The fetch must refuse a mismatch, seat nothing, and leave no
#      `.part` behind.
#
# No network in this test: the fetch path is exercised against `file://` URLs, so the checksum gate
# is judged even on a machine with no route out. The real upstream is proved by hand in the fix note.
#
# Usage: test_voice_vad_model.sh   ·   Exit: 0 all pass, 1 a failure (5 skips cleanly: no python3).
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$HERE/../../.." && pwd -P)"
LIB="$ROOT/bin/voice/voice-model-lib.sh"
LOADER="$ROOT/bin/voice/ymir-vad.py"

pass=0; fail=0; skip=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
skipit(){ skip=$((skip+1)); printf '  skip %s\n' "$1"; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# ask the shell library for a path, in a fenced environment.
#   shell_path KEY=value …          sets those variables for the question
#   shell_path -u KEY KEY=value …   UNSETS the named variables first (a default must be judged too)
shell_path() {
  ( local x; while [ "$1" = "-u" ]; do unset "$2" 2>/dev/null; shift 2; done
    for x in "$@"; do export "$x"; done
    . "$LIB"; ymir_vad_model )
}
# ask the loader for the path it will read, in the same fenced environment
py_path() {
  [ -n "${PY:-}" ] || return 1
  ( local x; while [ "$1" = "-u" ]; do unset "$2" 2>/dev/null; shift 2; done
    for x in "$@"; do export "$x"; done
    "$PY" "$LOADER" path )
}

# YMIR_VAD_PYTHON lets a machine (or CI) name the interpreter that carries onnxruntime; the
# default is the system python, so the test still judges the two paths where nothing is installed.
if [ -n "${YMIR_VAD_PYTHON:-}" ] && [ -x "${YMIR_VAD_PYTHON}" ]; then PY="$YMIR_VAD_PYTHON"
elif command -v python3 >/dev/null 2>&1; then PY="$(command -v python3)"; else PY=""; fi

# ── 1. one question, one answer ───────────────────────────────────────────────────────────────
a="$(shell_path YMIR_RELEASES="$T/data" XDG_DATA_HOME="$T/xdg")"
want="$T/data/models/voice/silero_vad.onnx"
[ "$a" = "$want" ] && ok "the library seats the detector under the data root: $want" \
  || bad "library path" "got $a, want $want"

if [ -z "$PY" ]; then
  skipit "the loader's path (no python3 on PATH)"
else
  b="$(py_path YMIR_RELEASES="$T/data" XDG_DATA_HOME="$T/xdg")"
  [ "$b" = "$a" ] && ok "the loader reads the SAME file the library fetches: $b" \
    || bad "loader and library disagree" "library=$a loader=$b"

  c="$(py_path -u YMIR_RELEASES XDG_DATA_HOME="$T/xdg")"
  d="$(shell_path -u YMIR_RELEASES XDG_DATA_HOME="$T/xdg")"
  [ "$c" = "$d" ] && ok "with no YMIR_RELEASES both fall to \$XDG_DATA_HOME/ymir/models/voice: $c" \
    || bad "XDG default disagrees" "library=$d loader=$c"

  e="$(py_path YMIR_VOICE_MODELS_DIR="$T/shelf")"
  f="$(shell_path YMIR_VOICE_MODELS_DIR="$T/shelf")"
  [ "$e" = "$f" ] && [ "$e" = "$T/shelf/silero_vad.onnx" ] && ok "YMIR_VOICE_MODELS_DIR moves both doors together" \
    || bad "YMIR_VOICE_MODELS_DIR" "library=$f loader=$e"

  g="$(py_path YMIR_VAD_MODEL="$T/one.onnx")"
  h="$(shell_path YMIR_VAD_MODEL="$T/one.onnx")"
  [ "$g" = "$T/one.onnx" ] && [ "$h" = "$T/one.onnx" ] && ok "YMIR_VAD_MODEL wins outright in both doors" \
    || bad "YMIR_VAD_MODEL" "library=$h loader=$g"
fi

# ── 2. the checksum gate ──────────────────────────────────────────────────────────────────────
head -c 64 /dev/urandom > "$T/not-the-detector.onnx"
export YMIR_VOICE_MODELS_DIR="$T/shelf"

if ( . "$LIB"; ymir_vad_verify "$T/not-the-detector.onnx" ); then
  bad "verify accepted a file that is not the pinned detector"
else
  ok "verify refuses a file whose sha256 is not the pinned one"
fi

out="$( ( . "$LIB"; YMIR_VAD_URL="file://$T/not-the-detector.onnx"; ymir_vad_fetch ) 2>&1 )"; rc=$?
[ "$rc" != 0 ] && ok "fetch REFUSES a mismatched download (rc=$rc)" || bad "fetch accepted a mismatched download" "$out"
[ ! -e "$T/shelf/silero_vad.onnx" ] && ok "nothing was seated at the model path" || bad "a mismatched file was seated"
ls "$T/shelf"/silero_vad.onnx.part-* >/dev/null 2>&1 && bad "a .part file was left behind" || ok "no .part file left behind"

# ── 3. the honest path: a file that DOES match is seated, and verify then says yes ────────────
want_sha="$(sha256sum "$T/not-the-detector.onnx" | cut -d' ' -f1)"
out="$( ( . "$LIB"; YMIR_VAD_URL="file://$T/not-the-detector.onnx"; YMIR_VAD_SHA256="$want_sha"; ymir_vad_fetch ) 2>&1 )"; rc=$?
if [ "$rc" = 0 ] && [ -f "$T/shelf/silero_vad.onnx" ]; then
  ok "a matching file is fetched and seated at the data folder"
else
  bad "a matching fetch did not seat the file (rc=$rc)" "$out"
fi
( . "$LIB"; YMIR_VAD_SHA256="$want_sha"; ymir_vad_verify ) && ok "verify accepts the seated file" || bad "verify rejected the file it just seated"

# ── 4. a missing detector is LOUD, never a quiet zero ─────────────────────────────────────────
if [ -n "$PY" ]; then
  o="$(YMIR_VAD_MODEL="$T/absent.onnx" "$PY" "$LOADER" selftest 2>&1)"; rc=$?
  case "$rc:$o" in
    1:*"model missing"*) ok "selftest with no detector exits 1 and names the file" ;;
    *) bad "selftest with no detector" "rc=$rc out=$o" ;;
  esac
  case "$o" in
    *voice-ensure.sh*) ok "…and names the door that fetches it" ;;
    *) bad "the refusal does not name the fetch door" "$o" ;;
  esac
fi

# ── 5. the machine's own copy, when it has one (a measured line, never an assumption) ─────────
m="$( ( unset YMIR_VOICE_MODELS_DIR YMIR_VAD_MODEL YMIR_RELEASES; . "$LIB"; ymir_vad_model ) )"
if [ -f "$m" ]; then
  if ( . "$LIB"; ymir_vad_verify "$m" ); then
    ok "the detector installed on this machine matches the pinned sha256: ${m}"
  else
    bad "the detector on this machine does NOT match the pinned sha256" "$m — re-run bin/voice/voice-ensure.sh install"
  fi
else
  skipit "no detector on this machine yet ($m) — the install door seats it"
fi

# ── 6. the loader RUNS the detector it found (only where onnxruntime lives) ────────────────────
# The file's own selftest raised NameError the first time it was ever executed (2026-11-14): a tool
# nobody ran. Where a python with onnxruntime is on the machine, this row runs it for real.
unset YMIR_VOICE_MODELS_DIR YMIR_VAD_MODEL || true   # the machine's own shelf, not this test's fake
if [ -n "$PY" ] && [ -f "$m" ] && "$PY" -c 'import onnxruntime' >/dev/null 2>&1; then
  o="$(YMIR_VAD_MODEL="$m" "$PY" "$LOADER" selftest 2>&1)"; rc=$?
  case "$rc:$o" in
    0:*PASS*) ok "the loader runs the detector and silence reads below threshold" ;;
    *) bad "selftest did not pass" "rc=$rc out=$(printf '%s' "$o" | head -2 | tr '\n' ' ')" ;;
  esac
else
  skipit "the loader's selftest (no python with onnxruntime here, or no detector yet)"
fi

printf '\ntest_voice_vad_model: %s passed, %s failed, %s skipped\n' "$pass" "$fail" "$skip"
[ "$fail" = 0 ]
