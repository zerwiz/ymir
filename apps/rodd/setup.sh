#!/usr/bin/env bash
# setup.sh — fetch the engine's browser face at a PINNED tag and dress it as Rödd's.
#
#   apps/rodd/setup.sh
#
# The UI is fetched, not committed: upstream ships a server with addresses in it, and this
# repository carries no addresses (RULES/39). The pin is the engine release the house runs
# (`speech-to-speech` 1.1.0), whose `@openai/agents` version matches that engine's protocol —
# mixing a newer face with an older engine is what produced `Unknown or invalid event:
# conversation.item.retrieve` and every answer dying with no text and no audio.
#
# What it does:
#   1. clones the tag into ui/ (shallow)
#   2. installs the UI's own dependencies (npm ci) — the SDK bundle and the wasm live there
#   3. copies the SDK bundle and the VAD/onnx assets the page asks for
#   4. runs patch/patch-ui.py — the house's palette, brief, voices, roles and tool hook
set -uo pipefail
APP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAG="${RODD_UI_TAG:-v1.1.0}"
REPO="${RODD_UI_REPO:-https://github.com/huggingface/speech-to-speech}"
UI="$APP/ui"
say() { printf '%-42s %s\n' "$1" "$2"; }

if [ ! -d "$UI/.git" ]; then
  rm -rf "$UI"
  say "fetching the face" "$REPO @ $TAG"
  git clone --depth 1 --branch "$TAG" "$REPO" "$UI" >/dev/null 2>&1 || { say "clone failed" "$REPO"; exit 1; }
else
  say "face already fetched" "$(git -C "$UI" describe --tags 2>/dev/null || echo "$TAG")"
fi

say "installing the UI's dependencies" "(npm ci — the SDK bundle and wasm live here)"
( cd "$UI" && npm ci --silent >/dev/null 2>&1 ) || { say "npm ci failed" "run it by hand in $UI"; exit 1; }

mkdir -p "$UI/vendor"
BUNDLE="$UI/node_modules/@openai/agents-realtime/dist/bundle/openai-realtime-agents.umd.js"
[ -f "$BUNDLE" ] && cp -f "$BUNDLE" "$UI/vendor/" || say "bundle missing" "$BUNDLE"
for f in silero_vad_v6.onnx ort-wasm-simd-threaded.mjs ort-wasm-simd-threaded.wasm; do
  for src in "$UI/node_modules/@ricky0123/vad-web/dist/$f" "$UI/node_modules/onnxruntime-web/dist/$f"; do
    [ -f "$src" ] && { mkdir -p "$UI/vendor/local-vad"; cp -f "$src" "$UI/vendor/local-vad/"; break; }
  done
done

python3 "$APP/patch/patch-ui.py" "$UI" || exit 1

say "ready" "apps/rodd/start.sh  then  apps/rodd/smoke.sh"
