#!/usr/bin/env bash
# test_claude_global_arm_opt_in.sh — the global Claude arm is seated only when the operator asks (2026-11-12).
#
# ymir-arm.sh is an asyncRewake Stop hook that wakes every Claude session on the machine, in every
# repository, to act on the wake queue — and Gná writes lines derived from inbound mail into that queue.
#
#   · default                         → the AGENTS.md loader and the Eindri ward are seated; the arm is NOT
#   · default, --check                → the absent arm is reported `opt-in`, never `stale` (Eir stays green)
#   · YMIR_CLAUDE_GLOBAL_ARM=1         → the arm is seated
#   · config/claude-global-arm = on   → the arm is seated
#   · an entry the operator already has is left alone
#
# Runs in a throwaway HOME. Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
DOOR="$ROOT/bin/seat/harness-extensions-install.sh"
command -v claude >/dev/null 2>&1 || { printf 'skip  no claude on this host — the door skips Claude wiring cleanly\n'; exit 0; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-arm-opt.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }
stops() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(sum(1 for e in d.get("hooks",{}).get("Stop",[]) for h in e.get("hooks",[]) if "ymir-arm.sh" in (h.get("command") or "")))' "$1"; }
fresh() { rm -rf "$TMP/h"; mkdir -p "$TMP/h/.claude" "$TMP/h/ymirhome/config"; printf '{}\n' > "$TMP/h/.claude/settings.json"; }
run() { HOME="$TMP/h" YMIR_HOME="$TMP/h/ymirhome" bash "$DOOR" "$@" 2>&1; }

fresh; out="$(run)"
[ "$(stops "$TMP/h/.claude/settings.json")" = 0 ] && ok "default: the global arm is not seated" || bad "default: the global arm was seated"
printf '%s' "$out" | grep -q '"claude-agents-md","synced"' && ok "default: the AGENTS.md loader is seated" || bad "default: the AGENTS.md loader is missing"
out="$(run --check)"
printf '%s' "$out" | grep -q '"claude-ymir-arm","opt-in"' && ok "check: the absent arm reads opt-in" || bad "check: the absent arm is not reported opt-in"
printf '%s' "$out" | grep -q '"claude-ymir-arm","stale"' && bad "check: the absent arm reads stale" || ok "check: the absent arm is never stale"

fresh; HOME="$TMP/h" YMIR_HOME="$TMP/h/ymirhome" YMIR_CLAUDE_GLOBAL_ARM=1 bash "$DOOR" >/dev/null 2>&1
[ "$(stops "$TMP/h/.claude/settings.json")" = 1 ] && ok "env opt-in: the arm is seated" || bad "env opt-in: the arm was not seated"

fresh; printf 'on\n' > "$TMP/h/ymirhome/config/claude-global-arm"; run >/dev/null
[ "$(stops "$TMP/h/.claude/settings.json")" = 1 ] && ok "config opt-in: the arm is seated" || bad "config opt-in: the arm was not seated"

fresh; python3 - "$TMP/h/.claude/settings.json" <<'PY'
import json, sys
json.dump({"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "bash \"$HOME/.claude/hooks/ymir-arm.sh\""}]}]}}, open(sys.argv[1], "w"))
PY
run >/dev/null
[ "$(stops "$TMP/h/.claude/settings.json")" = 1 ] && ok "an existing entry is left alone" || bad "an existing entry was changed"

exit "$fail"
