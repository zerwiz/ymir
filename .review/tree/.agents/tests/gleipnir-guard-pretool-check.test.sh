#!/usr/bin/env bash
# Unit tests for the Sýn PreToolUse seatbelts:
#   bin/syn-arm-pretool-check.sh   - the watcher arm is never backgrounded
#   bin/syn-guard-pretool-check.sh - load-bearing invariants stay untouched
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARM="$ROOT/bin/syn-arm-pretool-check.sh"
GUARD="$ROOT/bin/syn-guard-pretool-check.sh"
fail=0

allows() {  # <script> <command>
  if "$1" --command "$2" >/dev/null 2>&1; then :
  else printf 'not ok - should allow: %s\n' "$2" >&2; fail=1; fi
}
denies() {  # <script> <command>
  if "$1" --command "$2" >/dev/null 2>&1; then
    printf 'not ok - should deny: %s\n' "$2" >&2; fail=1
  fi
}

# --- arm seatbelt: real backgrounding vs chaining and syntax checks ----------

allows "$ARM" 'bash -n bin/syn-watch-arm.sh && echo "syntax OK"'
allows "$ARM" 'cat bin/syn-watch-arm.sh'
allows "$ARM" 'echo "chained" && ls'
denies "$ARM" 'bin/syn-watch-arm.sh --restart &'
denies "$ARM" 'nohup bin/syn-watch-arm.sh --restart'
denies "$ARM" 'setsid bin/syn-watch-arm.sh --restart'
denies "$ARM" 'disown; bin/syn-watch-arm.sh --restart'

# --- invariant seatbelt: destructive shapes are denied -----------------------

denies "$GUARD" 'rm -f state/.lock'
denies "$GUARD" 'echo 123 > state/.supervision-armed'
denies "$GUARD" 'sed -i s/x/y/ workspace/memory/runes_audit.md'
denies "$GUARD" 'rm -f bin/syn-watch-arm.sh'
denies "$GUARD" 'cat .env.local'
denies "$GUARD" 'git add .env.realm'
denies "$GUARD" 'echo x > config/cron.yaml'

# --- invariant seatbelt: reads and ordinary work are allowed -----------------

allows "$GUARD" 'cat state/.lock'
allows "$GUARD" 'rg wake state/.wake-queue'
allows "$GUARD" 'git status'
allows "$GUARD" 'bin/runes-append.sh brokk test --message hi'
allows "$GUARD" 'bash -n bin/syn-guard-pretool-check.sh'

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
