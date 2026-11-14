#!/usr/bin/env bash
# voice-model-lib.sh — WHERE THE VOICE'S MODEL WEIGHTS LIVE, and the one pinned upstream.
#
# WHY A LIBRARY. A weight file is not a source file. It is downloaded once per machine into the
# user's data folder, verified against a pinned checksum, and never committed: plans 288 (step 7)
# and 287 (P4) took the last tracked weights — `.fleet/voice/silero_vad.onnx`, 2,327,524 bytes —
# out of the public repository, because weights make every clone heavy and hide what is source,
# and because a public repository must carry craft, not downloads (RULES/04, 11, 25).
#
# TWO DOORS NEED THE SAME ANSWER — the install step that FETCHES the weights
# (`bin/voice/voice-ensure.sh`, run by `bin/engine/ymir-install.sh` step_voice) and the tool that
# LOADS them (`bin/voice/ymir-vad.py`, the turn boundary). So the answer is written once, here, and
# the python resolves the same three environment variables in the same order; the test
# `bin/voice/tests/test_voice_vad_model.sh` proves the two doors name one file.
#
# THE UPSTREAM IS PINNED to a commit, never to a branch: `master` moves, and a checksum pinned
# against a moving URL is a checksum that fails one morning for no reason the reader can see.
#
# Environment (RULES/07 — every value resolved, one documented default each):
#   YMIR_RELEASES            the ymir data root   ($XDG_DATA_HOME/ymir → ~/.local/share/ymir)
#   YMIR_VOICE_MODELS_DIR    the weights folder   (<data root>/models/voice)
#   YMIR_VAD_MODEL           one file override, for a machine that keeps its weights elsewhere

# Silero VAD v6.2 — the single-file ONNX detector. Apache-2.0, (c) Silero Team,
# https://github.com/snakers4/silero-vad. The same detector `pip install silero-vad` ships, without
# Torch and its CUDA bindings in the engine venv (see the note at the top of bin/voice/ymir-vad.py).
YMIR_VAD_NAME="silero_vad.onnx"
YMIR_VAD_SHA256="1a153a22f4509e292a94e67d6f9b85e8deb25b4988682b7e174c65279d8788e3"
YMIR_VAD_URL="https://raw.githubusercontent.com/snakers4/silero-vad/bfdc0193023f121ea5b3cc7b176dbed570a68a59/src/silero_vad/data/silero_vad.onnx"
YMIR_VAD_LICENSE="Apache-2.0 · silero-vad v6.2 (snakers4/silero-vad @bfdc019)"

# The ymir data root — the same default `bin/engine/release.sh` uses for releases/, so a machine has
# ONE data folder and not a second invented here.
ymir_data_root() { printf '%s' "${YMIR_RELEASES:-${XDG_DATA_HOME:-$HOME/.local/share}/ymir}"; }

# The weights folder for the voice: the detector today, and whatever the pipeline needs next.
ymir_voice_models_dir() { printf '%s' "${YMIR_VOICE_MODELS_DIR:-$(ymir_data_root)/models/voice}"; }

# The detector's own path.
ymir_vad_model() { printf '%s' "${YMIR_VAD_MODEL:-$(ymir_voice_models_dir)/$YMIR_VAD_NAME}"; }

# 0 when the file on disk IS the pinned detector; 1 when it is absent or different. A mismatch is
# never silently accepted: a truncated download once loaded as a valid session and answered noise.
ymir_vad_verify() {
  local f="${1:-$(ymir_vad_model)}"
  [ -f "$f" ] || return 1
  [ "$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)" = "$YMIR_VAD_SHA256" ]
}

# Fetch the detector into the data folder, verifying before it is allowed to land. Prints the path
# it seated. Refuses loudly — never a silent skip — when curl, the network or the checksum fails.
ymir_vad_fetch() {
  local f dir tmp; f="$(ymir_vad_model)"; dir="$(dirname "$f")"
  if ymir_vad_verify "$f"; then printf '%s' "$f"; return 0; fi
  command -v curl >/dev/null 2>&1 || { printf 'vad: curl is required to fetch %s\n' "$YMIR_VAD_NAME" >&2; return 1; }
  mkdir -p "$dir" || { printf 'vad: cannot create %s\n' "$dir" >&2; return 1; }
  tmp="$f.part-$$"
  printf 'vad: fetching %s (pinned %s) …\n' "$YMIR_VAD_NAME" "${YMIR_VAD_SHA256:0:12}" >&2
  if ! curl -fL --retry 3 -o "$tmp" "$YMIR_VAD_URL" >/dev/null 2>&1; then
    rm -f "$tmp"
    printf 'vad: fetch failed — %s\n' "$YMIR_VAD_URL" >&2
    return 1
  fi
  if [ "$(sha256sum "$tmp" | cut -d' ' -f1)" != "$YMIR_VAD_SHA256" ]; then
    local got; got="$(sha256sum "$tmp" | cut -d' ' -f1)"
    rm -f "$tmp"
    printf 'vad: checksum MISMATCH — refusing to seat it\n  want %s\n  got  %s\n' "$YMIR_VAD_SHA256" "$got" >&2
    return 1
  fi
  mv -f "$tmp" "$f" && printf '%s' "$f"
}
