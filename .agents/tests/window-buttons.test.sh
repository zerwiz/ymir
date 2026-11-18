#!/usr/bin/env bash
# window-buttons.test.sh — the frame's minimize/maximize/close, and who decides.
#
# The Allfather, 2026-11-14: "on Omarchy none of the _ □ × buttons should be
# visible in any app." On a tiling compositor (Hyprland, Omarchy's session) the
# compositor draws no title bar of its own and closes a window with a key, so a
# drawn _ □ × is dead weight; everywhere else the platform keeps its own frame
# (Rule 05: the layer is gated on its host, never assumed).
#
# This test holds the SHAPE of that gate, because the failure mode is silent:
# a new app, or a renamed launcher, simply forgets to ask, and the buttons come
# back on exactly one app that nobody looks at. So every Electron window in the
# house must (a) be created with a frame the platform can switch, and (b) be
# raised by a road that asks bin/host. And the menu must stay SET: the
# accelerators are the keyboard road in, and only the drawn bar goes.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

# shellcheck source=bin/desktop/app-lib.sh
. "$ROOT/bin/desktop/app-lib.sh"

# ── 1. the platform layer answers, and only in its own vocabulary ──────────────
answer="$(bash "$ROOT/bin/host/host-sense.sh" capability window-buttons 2>/dev/null)"
case "$answer" in
  yes|no) ok "host-sense answers window-buttons: $answer" ;;
  *)      bad "host-sense capability window-buttons printed '$answer' — want yes|no" ;;
esac

mapped="$(app_window_buttons 2>/dev/null)"
case "$mapped" in
  on|off) ok "app_window_buttons maps the answer to $mapped" ;;
  *)      bad "app_window_buttons printed '$mapped' — want on|off" ;;
esac
if [ "$answer" = no ] && [ "$mapped" != off ]; then bad "a platform that wants no buttons must map to off"; fi
if [ "$answer" = yes ] && [ "$mapped" != on ]; then bad "a platform that wants its frame must map to on"; fi

# The TOON block must show the fact too, or the sensor lies to the human reading it.
bash "$ROOT/bin/host/host-sense.sh" 2>/dev/null | grep -q '"window-buttons"' \
  && ok "the host report carries the window-buttons row" \
  || bad "the host report does not carry the window-buttons row"

# ── 2. every Electron window can be switched ──────────────────────────────────
# Each file that creates a BrowserWindow must set `frame:` from the platform answer.
windows=(
  "apps/hlidskjalf/electron/main.cjs"
  "apps/odrerir/electron/main.cjs"
  "apps/bilskirnir/electron/main.js"
  "apps/rodd/src/main.js"
  "apps/sessrumnir/src/main/index.ts"
)
for f in "${windows[@]}"; do
  if [ ! -f "$ROOT/$f" ]; then bad "$f is missing — the list of windows is stale"; continue; fi
  grep -q 'YMIR_WINDOW_BUTTONS' "$ROOT/$f" \
    && ok "$f reads YMIR_WINDOW_BUTTONS" \
    || bad "$f never reads YMIR_WINDOW_BUTTONS — its frame ignores the platform"
  grep -qE '(frame: *WINDOW_BUTTONS|frame: *windowButtons)' "$ROOT/$f" \
    && ok "$f builds its window with that frame" \
    || bad "$f does not pass frame: from the platform answer"
done

# Any BrowserWindow created in the house must be one of the files above: a new
# shell that silently keeps the OS frame is how one app gets left behind.
strays="$(cd "$ROOT" && grep -rln 'new BrowserWindow(' apps --include=*.js --include=*.cjs --include=*.ts --include=*.mjs 2>/dev/null \
  | grep -v node_modules | grep -v '/tests/' | grep -v '\.test\.' | sort)"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -q 'frame' "$ROOT/$f" || bad "$f creates a BrowserWindow with no frame decision"
done <<<"$strays"
[ -z "$strays" ] || ok "every BrowserWindow in apps/ carries a frame decision"

# ── 3. every road that raises a window asks the platform ──────────────────────
launchers=(
  "scripts/electron.sh"
  "apps/bilskirnir/start.sh"
  "apps/rodd/start.sh"
  "bin/desktop/sessrumnir-launch.sh"
)
for f in "${launchers[@]}"; do
  if [ ! -f "$ROOT/$f" ]; then bad "$f is missing — the list of launchers is stale"; continue; fi
  grep -q 'YMIR_WINDOW_BUTTONS' "$ROOT/$f" \
    && ok "$f carries the answer into the app" \
    || bad "$f raises a window without asking bin/host for the frame"
done

# ── 4. the keyboard road in is never removed ─────────────────────────────────
# The menu stays SET even when the drawn bar goes (Sessrúmnir's shape, now the house's).
for f in "apps/hlidskjalf/electron/main.cjs" "apps/odrerir/electron/main.cjs" "apps/sessrumnir/src/main/index.ts"; do
  grep -q 'setApplicationMenu' "$ROOT/$f" \
    && ok "$f keeps its application menu (accelerators stay)" \
    || bad "$f dropped its application menu — the shortcuts would die with the bar"
done

# ── 5. the smithy's own drawn controls obey the same answer ───────────────────
# Smíðja draws _ □ × itself when it runs in its own shell; on a tiling compositor it must not.
grep -q 'windowButtons' "$ROOT/apps/smidja-factory/apps/visualizer/desktop/preload.js" \
  && ok "Smíðja's shell hands the renderer the platform answer" \
  || bad "Smíðja's shell never tells the renderer whether to draw its controls"
grep -q 'showsWindowControls' "$ROOT/apps/smidja-factory/apps/visualizer/src/App.vue" \
  && ok "Smíðja's topbar draws its controls only when the platform wants them" \
  || bad "Smíðja's topbar still draws _ □ × unconditionally"

exit "$fail"
