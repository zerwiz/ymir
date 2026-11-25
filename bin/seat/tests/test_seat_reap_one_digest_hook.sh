#!/usr/bin/env bash
# test_seat_reap_one_digest_hook.sh — seat-reap accepts the house's one digest hook (plan 369 item 6).
#
# harness-extensions-install.sh seats `bash "$HOME/.claude/hooks/saga-session.sh"` and prunes a
# hardcoded `<root>/bin/time/saga-session-start.sh` SessionStart hook. seat-reap.sh used to seat that
# hardcoded hook, so Eir's two mends undid each other every night and Gróa exited 4. Proved here, in a
# temporary HOME, never the operator's settings:
#   1. the house hook alone counts as seated (`--check` passes, nothing is written);
#   2. `--install` over the house hook adds no second digest hook;
#   3. with the house hook script on disk and no hook seated, `--install` seats the HOUSE hook;
#   4. with no house hook script, `--install` still seats the hardcoded door (a bare seat keeps working).
#
# Usage: test_seat_reap_one_digest_hook.sh · Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
REAP="$ROOT/bin/seat/seat-reap.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"
mkdir -p "$HOME/.claude/hooks"
S="$HOME/.claude/settings.json"
export CLAUDE_SETTINGS="$S"

count_saga() {  # how many SessionStart hooks run a digest
  python3 - "$S" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
n = 0
for g in (d.get("hooks") or {}).get("SessionStart") or []:
    for h in g.get("hooks") or []:
        c = h.get("command") or ""
        if "saga-session" in c:
            n += 1
print(n)
PY
}
cmds() { python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print([h["command"] for g in d["hooks"]["SessionStart"] for h in g["hooks"]])' "$S"; }

printf 'test_seat_reap_one_digest_hook\n'

# 1 · the house hook alone is seated
: > "$HOME/.claude/hooks/saga-session.sh"
cat > "$S" <<'EOF'
{"hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "bash \"$HOME/.claude/hooks/saga-session.sh\"", "timeout": 120}]}]}}
EOF
before=$(cat "$S")
out=$(bash "$REAP" --check 2>&1)
printf '%s\n' "$out" | grep -q '"claude","seated"' && ok "the house hook counts as seated" || bad "the house hook counts as seated" "$out"
[ "$(cat "$S")" = "$before" ] && ok "--check wrote nothing" || bad "--check wrote nothing" "$(cat "$S")"

# 2 · --install over the house hook adds no second digest
bash "$REAP" --install >/dev/null 2>&1
[ "$(count_saga)" = 1 ] && ok "--install adds no second digest hook" || bad "--install adds no second digest hook" "$(cmds)"

# 3 · house script present, nothing seated → the HOUSE hook is seated
printf '{}\n' > "$S"
bash "$REAP" --install >/dev/null 2>&1
cmds | grep -q '.claude/hooks/saga-session.sh' && ok "a bare settings file gets the house hook" || bad "a bare settings file gets the house hook" "$(cmds)"
cmds | grep -q 'bin/time/saga-session-start.sh' && bad "no hardcoded digest is seated beside it" "$(cmds)" || ok "no hardcoded digest is seated beside it"

# 4 · no house script → the hardcoded door still seats (a seat without the installer keeps a digest)
rm -f "$HOME/.claude/hooks/saga-session.sh"
printf '{}\n' > "$S"
bash "$REAP" --install >/dev/null 2>&1
cmds | grep -q 'bin/time/saga-session-start.sh' && ok "without the house script the door seats itself" || bad "without the house script the door seats itself" "$(cmds)"

printf 'test_seat_reap_one_digest_hook: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
