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
# the engine checkout is a STAGING shelf, never the served face — and never inside the tree:
# a scanner that walks this repo counted its worklets as dead code (dead-code-guard, 2026-11-08)
ENGINE="${RODD_ENGINE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/ymir/rodd-engine}"   # allow-home-default: a cache, overridable
STAMP="$UI/.rodd-face"     # which tag the served face was dressed from
PATCH_STAMP="$UI/.rodd-patch"   # which patch set dressed it (plan 275: a merged patch must reach the face)
patch_hash() { cat "$APP/patch/"* 2>/dev/null | sha256sum | cut -c1-16; }
say() { printf '%-42s %s\n' "$1" "$2"; }

# `--check` is the question every installer and every updater asks: is the face present,
# and is it the face this tree pins? One word answers it, and the exit code says whether
# anything needs building.
case "${1:-}" in
  --check)
    if [ ! -f "$UI/index.html" ]; then printf 'missing\n'; exit 1; fi
    if [ "$(cat "$STAMP" 2>/dev/null)" != "$TAG" ]; then printf 'stale:%s\n' "$TAG"; exit 1; fi
    # the face is also stale when the house's patches changed since it was dressed (2026-11-12: plan 271's
    # why.js merged, but the face kept printing "[object Event]" because nothing re-ran the patcher)
    if [ "$(cat "$PATCH_STAMP" 2>/dev/null)" != "$(patch_hash)" ]; then printf 'stale:patch\n'; exit 1; fi
    printf 'present\n'; exit 0 ;;
  -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

# The engine repository is NOT the face. At the pinned tag the browser face is its own
# `demo/` directory (index.html · server.py · main.js · worklets/), and the client that
# main.js serves must be that directory's contents at `ui/`. Cloning the engine straight
# into `ui/` is what produced "patch-ui: no UI at …/ui": the face sat one level down the
# whole time, and `npm ci` ran against a root that carries no package.json.
if [ ! -f "$STAMP" ] || [ "$(cat "$STAMP" 2>/dev/null)" != "$TAG" ]; then
  rm -rf "$ENGINE"
  mkdir -p "$(dirname "$ENGINE")"
  say "fetching the face" "$REPO @ $TAG"
  git clone --depth 1 --branch "$TAG" "$REPO" "$ENGINE" >/dev/null 2>&1 || { say "clone failed" "$REPO"; exit 1; }
  [ -d "$ENGINE/demo" ] || { say "this tag carries no demo/" "$TAG"; exit 1; }
  rm -rf "$UI"
  mkdir -p "$UI"
  cp -a "$ENGINE/demo/." "$UI/"
  printf '%s\n' "$TAG" > "$STAMP"
else
  say "face already fetched" "$TAG"
fi

if [ ! -d "$UI/node_modules" ]; then
  say "installing the UI's dependencies" "(npm ci — the SDK bundle and wasm live here)"
  ( cd "$UI" && npm ci --silent >/dev/null 2>&1 ) || { say "npm ci failed" "run it by hand in $UI"; exit 1; }
else
  say "dependencies already installed" "(npm ci — skipped)"
fi

mkdir -p "$UI/vendor"
BUNDLE="$UI/node_modules/@openai/agents-realtime/dist/bundle/openai-realtime-agents.umd.js"
[ -f "$BUNDLE" ] && cp -f "$BUNDLE" "$UI/vendor/" || say "bundle missing" "$BUNDLE"
for f in silero_vad_v6.onnx ort-wasm-simd-threaded.mjs ort-wasm-simd-threaded.wasm; do
  for src in "$UI/node_modules/@ricky0123/vad-web/dist/$f" "$UI/node_modules/onnxruntime-web/dist/$f"; do
    [ -f "$src" ] && { mkdir -p "$UI/vendor/local-vad"; cp -f "$src" "$UI/vendor/local-vad/"; break; }
  done
done

python3 "$APP/patch/patch-ui.py" "$UI" || exit 1
patch_hash > "$PATCH_STAMP"

say "ready" "apps/rodd/start.sh  then  apps/rodd/smoke.sh"
