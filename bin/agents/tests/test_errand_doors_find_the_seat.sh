#!/usr/bin/env bash
# test_errand_doors_find_the_seat.sh — an errand is found by the RECORD, not by a guess.
#
# Why this test exists (measured 2026-11-20): two doors could not find a LIVE errand.
#
#   · `ymir_errand read <id>` answered "NOTHING RECORDED — no state/<id>.meta" while
#     `state/<id>.meta` and `state/<id>.status` both stood in the HOME — the reader looked in the
#     checkout's `state/`, which is not where the helm writes.
#   · `bin/agents/eindri-send.sh <id> "…"` refused "no agent stands in <id>" (herdr:
#     agent_not_found) while the pane its own meta named (`seat_pane=w1D:p1`) held the agent.
#
# `ymir_errand close` always worked, because it goes through `eindri-acclaim.sh`, which resolves the
# HOME's state. These cases pin the same resolution on the reading doors:
#
#   1 · the pi reader finds a record in the home (and names its seat)
#   2 · the helm's own override (BROKK_HELM_STATE) wins over the home
#   3 · a record that is NOT anywhere is refused with every dir it looked in
#   4 · the opencode reader names the same dirs and no longer reads `<root>/state/<id>` alone
#
# The pi reader is called for real through bun. A machine with no bun runs cases 3 and 4 only and
# says so by name — a clean skip, never a silent pass (RULES/25).
#
#   bash bin/agents/tests/test_errand_doors_find_the_seat.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EXT="$ROOT/.pi/extensions/eindri.ts"
PLUGIN="$ROOT/.agents/harness/opencode/plugins/ymir-tools.ts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ok=0; fail=0
good() { ok=$((ok+1)); printf 'ok   %s\n' "$*"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n     %s\n' "$1" "${2-}"; }

# A Yggdrasil worktree EXCLUDES `.pi/extensions/` on purpose (Rule 13: pi loads both the project tree
# and the seat's home, so a second tree collides every tool name). The source is read from git when it
# is not in the working tree, and the copy is imported by absolute path — it needs nothing but node
# builtins, and ROOT comes from YMIR_ROOT.
if [ ! -f "$EXT" ]; then
  if git -C "$ROOT" cat-file -e "HEAD:.pi/extensions/eindri.ts" 2>/dev/null; then
    git -C "$ROOT" show "HEAD:.pi/extensions/eindri.ts" > "$T/eindri.ts"
    EXT="$T/eindri.ts"
    printf 'note: .pi/extensions/ is not checked out here (a sparse worktree, Rule 13) — reading it from HEAD\n'
  else
    printf 'FAIL the pi extension is missing: .pi/extensions/eindri.ts (not in the tree, not in HEAD)\n'; exit 1
  fi
fi
[ -f "$PLUGIN" ] || { printf 'FAIL the opencode plugin is missing: %s\n' "$PLUGIN"; exit 1; }

mkdir -p "$T/home/state"
printf 'id=a-live-errand\nwindow=w4:p2\nseat_pane=w4:p2\nbackend=herdr\nharness=pi\n' > "$T/home/state/a-live-errand.meta"
printf 'working: carving the door\n' > "$T/home/state/a-live-errand.status"

read_errand() {  # read_errand <id> [extra env assignments…] — the pi reader, through bun
  local id="$1"; shift
  ( cd "$ROOT" && env YMIR_ROOT="$ROOT" YMIR_HOME="$T/home" "$@" \
      bun -e 'const m = await import(process.argv[2]); console.log(m.readErrand(process.argv[1]))' "$id" "$EXT" 2>&1 )
}

if command -v bun >/dev/null 2>&1; then
  out="$(read_errand a-live-errand)"
  case "$out" in
    *'"a-live-errand","working: carving the door"'*) good 'the pi reader finds a record that lives in the HOME' ;;
    *) bad 'the pi reader finds a record that lives in the HOME' "$out" ;;
  esac
  case "$out" in
    *"seat: w4:p2"*) good 'and it names the seat the record holds' ;;
    *) bad 'and it names the seat the record holds' "$out" ;;
  esac

  mkdir -p "$T/helm-state"
  printf 'id=only-in-the-helm\nwindow=w8:p5\nseat_pane=w8:p5\n' > "$T/helm-state/only-in-the-helm.meta"
  out="$(read_errand only-in-the-helm BROKK_HELM_STATE="$T/helm-state")"
  case "$out" in
    *"seat: w8:p5"*) good 'the helm override wins over the home, as the shell doors do' ;;
    *) bad 'the helm override wins over the home, as the shell doors do' "$out" ;;
  esac
else
  printf 'skip the pi reader cases — no bun on this machine (the extension is TypeScript)\n'
fi

out="$(read_errand no-such-errand 2>/dev/null || true)"
case "$out" in
  *"NOTHING RECORDED"*) good 'a record that is nowhere is refused' ;;
  *"skip"*|"") printf 'skip the refusal case — the pi reader could not run\n' ;;
  *) bad 'a record that is nowhere is refused' "$out" ;;
esac
case "$out" in
  *"$T/home/state"*) good 'and the refusal names every dir it looked in' ;;
  *"skip"*|"") ;;  # the skip above already said why
  *) bad 'and the refusal names every dir it looked in' "$out" ;;
esac

# ── the opencode reader: a shape assertion, and it says so ────────────────────────────────────────
# The plugin is a bun/effect module that needs the opencode runtime to load, so it cannot be called
# here. What is asserted is the shape the fault was made of: the read arm names the state dirs and
# takes the base from them, instead of reading the checkout's `state/` by itself.
if grep -q 'stateDirs' "$PLUGIN" && grep -q 'BROKK_HELM_STATE' "$PLUGIN"; then
  good 'the opencode reader resolves the same state dirs (helm, home, in-tree)'
else
  bad 'the opencode reader resolves the same state dirs (helm, home, in-tree)' "no stateDirs/BROKK_HELM_STATE in $PLUGIN"
fi
if grep -q 'const statusFile = `${root}/state/${id}.status`' "$PLUGIN"; then
  bad 'the opencode reader no longer reads the checkout state by itself' 'it still does'
else
  good 'the opencode reader no longer reads the checkout state by itself'
fi

printf '\nerrand doors: %s ok, %s failed\n' "$ok" "$fail"
[ "$fail" = 0 ]
