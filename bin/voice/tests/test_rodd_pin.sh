#!/usr/bin/env bash
# test_rodd_pin.sh — plan 257 H7: Rödd runs the PINNED runtime, never a working tree.
#
#   1. no runtime.env → apps/rodd/start.sh refuses in one named line, exit 1
#   2. a pin elsewhere → this tree's start.sh hands over to the pin's start.sh
#   3. a pin with no start.sh → refused, named
#   4. --install-unit (run from the pin) renders ymir-rodd.service whose ExecStart names the pin,
#      the path bin/gates/guards/runtime-pinned-guard.sh reads
#   5. the Electron main resolves its UI from the pin and refuses with one line without one
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
START="$ROOT/apps/rodd/start.sh"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_CONFIG_HOME="$T/xdg" YMIR_HOME="$T/ymirhome"
unset YMIR_RUNTIME_DIR YMIR_RODD_TREE YMIR_RODD_PINNED 2>/dev/null || true
mkdir -p "$HOME" "$YMIR_HOME/config"

# 1
out="$(bash "$START" 2>&1)"; rc=$?
t "no pin: refused non-zero" [ "$rc" -eq 1 ]
t "no pin: one named line" grep -q 'Rödd refuses to start.*no pinned runtime' <<<"$out"

# 2
PIN="$T/pin"; mkdir -p "$PIN/apps/rodd"
printf '#!/usr/bin/env bash\nprintf "PINNED-RODD args=%%s pinned=%%s\\n" "$*" "${YMIR_RODD_PINNED-unset}"\n' >"$PIN/apps/rodd/start.sh"
chmod +x "$PIN/apps/rodd/start.sh"
printf 'YMIR_RUNTIME_DIR="%s"\n' "$PIN" >"$YMIR_HOME/config/runtime.env"
out="$(bash "$START" --check 2>&1)"
t "a pin: the tree's start.sh hands over to the pin's" grep -q '^PINNED-RODD args=--check pinned=1' <<<"$out"

# 3
rm -f "$PIN/apps/rodd/start.sh"
out="$(bash "$START" 2>&1)"; rc=$?
t "a pin with no start.sh: refused" [ "$rc" -eq 1 ]
t "a pin with no start.sh: named" grep -q 'no runnable apps/rodd/start.sh' <<<"$out"

# 4 — the pin IS this tree: the unit is rendered naming it
printf 'YMIR_RUNTIME_DIR="%s"\n' "$ROOT" >"$YMIR_HOME/config/runtime.env"
out="$(bash "$START" --install-unit 2>&1)"
unit="$XDG_CONFIG_HOME/systemd/user/ymir-rodd.service"
t "--install-unit renders the unit" [ -s "$unit" ]
target="$(grep -m1 '^ExecStart=' "$unit" | cut -d= -f2- | grep -oE '/[^ ]+\.(sh|py|js|mjs)' | head -1)"
t "the unit's ExecStart names the pin (what the ward reads)" [ "$target" = "$ROOT/apps/rodd/start.sh" ]

# 5 — static: the face resolves its UI from the pin and refuses without one
t "main.js resolves the UI from the pin" grep -q "path.join(PIN, 'apps', 'rodd', 'ui')" "$ROOT/apps/rodd/src/main.js"
t "main.js refuses in one line with no pin" grep -q 'Rödd refuses to start: no pinned runtime' "$ROOT/apps/rodd/src/main.js"
t "main.js parses" node --check "$ROOT/apps/rodd/src/main.js"

printf 'test_rodd_pin: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
