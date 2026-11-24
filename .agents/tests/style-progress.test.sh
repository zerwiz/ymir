#!/usr/bin/env bash
# style-progress.test.sh — the progress primitives of bin/desktop/ymir-style.sh keep their promises.
#
# The four claims:
#   1. off a TTY (a pipe) the output is plain: no escape byte, no carriage return, one line per step;
#   2. NO_COLOR is plain even when a terminal is present;
#   3. a failing step returns the command's own exit code and prints the log's tail and the log path;
#   4. a passing step prints exactly one line and leaves no log behind.
# Plus: a step counted with style_steps says [i/n], and --data replays stdout untouched.
# Hermetic: a temp log dir, no network, no model.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STYLE="$ROOT/bin/desktop/ymir-style.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export YMIR_LOG_DIR="$T/log"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

# run <snippet> → stdout in $OUT, stderr in $ERR, status in $RC (stderr is a file: not a TTY)
run() {
  OUT="$(bash -c ". '$STYLE'; style_init; $1" 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
}

run 'style_step "plain pass" -- true'
[ "$RC" = 0 ] && ok "a passing step returns 0" || bad "a passing step returned $RC"
[ "$(printf '%s\n' "$ERR" | wc -l)" = 1 ] && ok "a passing step prints exactly one line" || bad "a passing step printed: $ERR"
case "$ERR" in *$'\033'*|*$'\r'*) bad "a pipe got control bytes" ;; *) ok "off a TTY there is no escape byte and no carriage return" ;; esac
case "$ERR" in *"plain pass"*) ok "the line names the step" ;; *) bad "the line lost the name: $ERR" ;; esac
[ -z "$(ls "$T/log" 2>/dev/null)" ] && ok "a passing step leaves no log" || bad "a passing step left a log"

run 'style_step "loud failure" -- bash -c "for i in \$(seq 1 30); do echo noise \$i; done; exit 7"'
[ "$RC" = 7 ] && ok "a failing step returns the command's own exit code (7)" || bad "exit code was $RC, not 7"
case "$ERR" in *"noise 30"*) ok "the failure prints the log's tail" ;; *) bad "no tail: $ERR" ;; esac
case "$ERR" in *"noise 15"$'\n'*|*"noise 15") bad "the tail is longer than 15 lines" ;; *) ok "the tail is cut to the last 15 lines" ;; esac
case "$ERR" in *"log: $T/log/"*) ok "the failure names its log" ;; *) bad "no log path: $ERR" ;; esac
ls "$T/log"/*.log >/dev/null 2>&1 && ok "the failed step's log is kept" || bad "no log kept"

# a real pty via script(1): NO_COLOR and CI must stay plain, a bare terminal must move
if command -v script >/dev/null 2>&1; then
  pty() { env "$@" TERM=xterm-256color script -qc "bash -c \". '$STYLE'; style_init; style_step 'pty step' -- sleep 1\"" /dev/null 2>&1; }
  RAW="$(pty NO_COLOR=1 | tr -d '\r')"
  case "$RAW" in *$'\033'*) bad "NO_COLOR still produced escapes" ;; *) ok "NO_COLOR is plain even on a terminal" ;; esac
  case "$RAW" in *"pty step"*) ok "NO_COLOR still says the step" ;; *) bad "NO_COLOR run said nothing: $RAW" ;; esac
  RAWC="$(pty CI=1)"
  case "$RAWC" in *$'\033'*) bad "CI still produced escapes" ;; *) ok "CI is plain even on a terminal" ;; esac
  RAWT="$(pty X=1)"
  case "$RAWT" in *$'\033['*) ok "on a real terminal the cloth moves" ;; *) bad "no motion on a TTY" ;; esac
else
  ok "script(1) absent — the terminal claims are skipped (clean skip)"
fi

run 'style_steps 2; style_step "one" -- true; style_step "two" -- true'
case "$ERR" in *"[1/2] one"*"[2/2] two"*) ok "counted steps say [1/2] [2/2]" ;; *) bad "count wrong: $ERR" ;; esac

run 'style_step --data "wrapped data" -- bash -c "echo TOON-ROW"'
[ "$OUT" = "TOON-ROW" ] && ok "--data replays the command's stdout on stdout" || bad "data lost: [$OUT]"
case "$ERR" in *TOON-ROW*) bad "data leaked into the decoration" ;; *) ok "--data keeps data out of stderr" ;; esac

run 'style_step "no command"'
[ "$RC" = 2 ] && ok "a step with no command is a usage error (2)" || bad "no-command rc=$RC"

exit "$fail"
