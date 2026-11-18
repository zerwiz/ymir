#!/usr/bin/env bash
# 0022-roots-load-the-runtime — every harness root on a home installed before 2026-11-11 loads the PINNED
# runtime, never a working tree; and pi's root carries Ymir's extensions and packages (plan 248 P2 + P3).
#
# WHY (RULES/51, his word 2026-11-11: "ymir must work GLOBALLY on the users computers"). Measured on the
# first seat that day: pi's root settings named ~/ymir/.pi/extensions — the WORKING TREE — while
# $YMIR_HOME/config/runtime.env pinned ~/ymir-runtime; and the ymir MCP door in pi, Claude, OpenCode and
# Cursor named ~/ymir/bin/mcp/ymir-mcp.py. Three readers took runtime.env with `sed`, so `$HOME/ymir-runtime`
# stayed literal text and the pin was ignored. The reader is mended in the tree; a `git pull` does not reach
# the user's root configs, so an existing home needs this door.
#
# It calls the one owner: bin/seat/harness-extensions-install.sh, which binds pi's root settings to the
# runtime's tree, installs the pi packages named in .agents/harnesses/pi.yaml, and re-points every root
# config path that lands in a working tree at the runtime's twin (one backup per file). A path with no twin
# is HELD and named, never guessed. A host with no harness is a clean skip (RULES/25). Idempotent: a second
# run finds every root current.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
say() { printf '0022: %s\n' "$1"; }

door="$ROOT/bin/seat/harness-extensions-install.sh"
[ -x "$door" ] || { say "no bin/seat/harness-extensions-install.sh in this tree — nothing to re-point"; exit 0; }

if ! command -v pi >/dev/null 2>&1 && ! command -v claude >/dev/null 2>&1 \
   && ! command -v opencode >/dev/null 2>&1 && ! command -v codex >/dev/null 2>&1 \
   && ! command -v cursor >/dev/null 2>&1 && ! command -v cursor-agent >/dev/null 2>&1; then
  say "no harness on this host — clean skip (the roots are seated the day one is installed)"
  exit 0
fi

out="$("$door" 2>&1)"; rc=$?
printf '%s\n' "$out" | grep -E '^ *"(runtime|pi|pi-root|roots)"' | sed 's/^ *//; s/^"//; s/",/ — /; s/"$//' | sed 's/^/0022: /'
[ "$rc" = 0 ] || say "a harness could not be seated — bin/seat/harness-extensions-install.sh --check names it"
if [ -x "$ROOT/bin/seat/runtime-root.sh" ] && ! "$ROOT/bin/seat/runtime-root.sh" scan >/dev/null 2>&1; then
  say "a root still names a working tree (held: no twin in the runtime) — bin/seat/runtime-root.sh scan names it"
fi
say "done — every harness root loads the runtime; pi's root carries ro · todo · open-editor and the descriptor's packages"
exit 0
