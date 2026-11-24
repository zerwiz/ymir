#!/usr/bin/env bash
# test_weave_needed.sh — the hook weaves only when a register's input is staged (plan 369 item 9).
# Usage: test_weave_needed.sh · Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/records/weave-needed.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

judge() {  # <want yes|no> <label> <name-status lines…>
  local want=$1 label=$2; shift 2
  printf '%s\n' "$@" > "$T/list"
  local out rc; out="$(env -u YMIR_WEAVE -u YMIR_SKIP_WEAVE YMIR_WEAVE_TEST_HEADER="${HDR:-}" bash "$DOOR" --list "$T/list")"; rc=$?
  if { [ "$want" = yes ] && [ "$rc" = 0 ]; } || { [ "$want" = no ] && [ "$rc" = 1 ]; }; then ok "$label"; else bad "$label" "rc=$rc $out"; fi
}

printf 'test_weave_needed\n'
judge no  "a fix note alone skips"                       "A	docs/fixes/voice/2026-11-24-x.md"
judge no  "a door's body edit skips"                     "M	bin/voice/rodd-helm.sh"
judge no  "an app edit skips"                            "M	apps/hlidskjalf/src/gates/Well.tsx"
judge yes "a new door weaves"                            "A	bin/voice/hermes-arm-wake.sh"
judge yes "a deleted door weaves"                        "D	bin/voice/old.sh"
judge yes "a renamed door weaves"                        "R100	bin/a/x.sh	bin/b/x.sh"
judge yes "a test edit weaves (it can flip a verdict)"   "M	bin/voice/tests/test_rodd_helm.sh"
judge yes "a skill page weaves (it names doors)"         "M	.agents/skills/ymir/SKILL.md"
judge yes "AGENTS.md weaves"                             "M	AGENTS.md"
judge yes "a feature page weaves"                        "M	docs/features/projects-panel.md"
judge yes "a register input weaves"                      "M	bin/gates/registers/folders.tsv"
HDR="bin/voice/rodd-helm.sh" judge yes "a door's header edit weaves" "M	bin/voice/rodd-helm.sh"
judge no  "an empty commit skips"                        ""

out="$(YMIR_WEAVE=1 bash "$DOOR" --list "$T/list")"; [ $? = 0 ] && ok "YMIR_WEAVE=1 forces a weave" || bad "YMIR_WEAVE=1 forces a weave" "$out"
printf 'A\tbin/x.sh\n' > "$T/list"
out="$(YMIR_SKIP_WEAVE=1 bash "$DOOR" --list "$T/list")"; [ $? = 1 ] && ok "YMIR_SKIP_WEAVE=1 skips" || bad "YMIR_SKIP_WEAVE=1 skips" "$out"

printf 'test_weave_needed: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
