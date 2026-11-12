#!/usr/bin/env bash
# public-data-ward.test.sh — prove the RULES/04 ward BITES.
#
#   bin/gates/checks/public-data-ward.test.sh
#
# A ward never seen to refuse is decoration — and this one has form: until 2026-11-03 the guard that
# forbids personal data carried the operator's own name as two literal alternatives, while its third
# alternative (`$HOME`, inside a single-quoted string) never expanded and matched nothing at all. So
# this test plants one case per class and requires the refusal, and it requires the WARD ITSELF to
# carry no declared word, because RULES/04 says naming them in the guard re-creates the leak.
#
# Exit: 0 every case behaved · 1 a case did not.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GUARD="$ROOT/bin/gates/guards/public-guard.py"
WORDS=""
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
h=""; declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root h
[ -n "$h" ] && [ -r "$h/hodd/security/operator-words.txt" ] && WORDS="$h/hodd/security/operator-words.txt"

fail=0
say() { printf '%s\n' "$*"; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
plant() {  # <case> <line> <class word the finding must carry>
  printf '%s\n' "$2" >"$tmp/case.md"
  if YMIR_HOME="$tmp/nohome" python3 "$GUARD" "$tmp/case.md" 2>/dev/null | grep -q "$3"; then
    say "  ok    $1"
  else
    say "  FAIL  $1 — the ward did not refuse it"; fail=1
  fi
}

plant "a private host address" "the heart listens on 192.168.44.9"                "private address"
plant "a tailnet host"         "reach it at heartbox.tailnet.ts.net"              "tailnet host"
plant "a personal mailbox"     "write to someone.smith@gmail.com"                 "personal mailbox"
# A GUARD CONTAINS THE SHAPES IT LOOKS FOR — so the shape is BUILT here, never written: a literal
# fake token in a tracked file is refused by secret-guard (and rightly: it cannot tell mine from a
# real one), and a test that cannot be committed is a test that does not run.
fake="ghp_$(printf 'a%.0s' $(seq 1 36))"
plant "a credential shape"     "token = $fake"  "credential shape"

if [ -n "$WORDS" ]; then
  leaked=0
  while IFS= read -r w; do
    case "$w" in ''|'#'*) continue ;; esac
    if grep -qi -- "$w" "$GUARD" "$ROOT/bin/gates/guards/public-data-guard.sh" 2>/dev/null; then
      leaked=1
    fi
  done <"$WORDS"
  if [ "$leaked" = 0 ]; then say "  ok    the ward carries no declared operator word"
  else say "  FAIL  the ward names a declared operator word — that IS the leak (RULES/04)"; fail=1; fi
else
  say "  skip  no operator-words.txt on this machine — the name class was not proved here"
fi

printf 'the seat is <host>; state lives at $HOME/state; a demo address is someone@example.com\n' >"$tmp/clean.md"
if YMIR_HOME="$tmp/nohome" python3 "$GUARD" "$tmp/clean.md" >/dev/null 2>&1; then
  say "  ok    a template with placeholders passes"
else
  say "  FAIL  a clean template was refused — a ward that cries wolf gets switched off"; fail=1
fi

# ── the machine class and the scope line (plan 278) ──────────────────────────────────────────────
# A CANARY: a fake fleet registry with one fake machine and one generic name. The guard must count the
# machine where it is named AS A HOST, ignore the same word in prose (a seat may share a name with a figure
# of the lore), ignore the generic name, stay advisory by default, and refuse under --strict-names. A guard
# that passes its canary in strict mode is reporting safety that is not there.
mkdir -p "$tmp/canaryhome/hodd/data"
printf '{"hosts":{"canaryseat":{"roles":["heart"]},"localhost":{"roles":["dev"]}}}\n' >"$tmp/canaryhome/hodd/data/fleet.json"
printf 'curl -s canaryseat:4602/health\n' >"$tmp/host.md"
printf 'the canaryseat figure in the saga, and http://localhost:3888\n' >"$tmp/prose.md"
out="$(YMIR_HOME="$tmp/canaryhome" python3 "$GUARD" "$tmp/host.md" 2>/dev/null)"; rc=$?
if [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q '"machine","1","1"'; then say "  ok    a machine named as a host is counted, advisory by default"
else say "  FAIL  the machine canary was not counted as advisory (rc=$rc)"; fail=1; fi
if printf '%s\n' "$out" | grep -q canaryseat; then say "  FAIL  the guard echoed the machine name — that IS the leak"; fail=1
else say "  ok    the machine name is masked in the guard's own output"; fi
if YMIR_HOME="$tmp/canaryhome" python3 "$GUARD" --strict-names "$tmp/host.md" >/dev/null 2>&1; then
  say "  FAIL  --strict-names passed the canary — a silent guard would pass for a clean one"; fail=1
else say "  ok    --strict-names refuses the canary"; fi
if YMIR_HOME="$tmp/canaryhome" python3 "$GUARD" --strict-names "$tmp/prose.md" >/dev/null 2>&1; then
  say "  ok    the same word in prose, and a generic name, are not a machine"
else say "  FAIL  prose or a generic name was refused as a machine"; fail=1; fi
if YMIR_HOME="$tmp/canaryhome" python3 "$GUARD" "$tmp/prose.md" 2>/dev/null | grep -q '^public_guard_scope\[1\]'; then
  say "  ok    every run prints its scope (files judged, exempt, words, machines)"
else say "  FAIL  the guard printed no scope line"; fail=1; fi
# the ward ships none of THIS fleet's machine names (read from the real home, if there is one)
if [ -n "$h" ] && [ -r "$h/hodd/data/fleet.json" ]; then
  # judged by the class's own rule (a machine named AS A HOST): a seat may carry a common word or a name
  # from the lore, and a word scan would find the guard's prose, not a leak
  if YMIR_HOME="$h" python3 - "$GUARD" <<'PYX'
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("pg", sys.argv[1]); pg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pg)
shape = pg.machine_shape(pg.machine_names(Path(sys.argv[1]).resolve().parents[3]))
sys.exit(1 if shape and shape.search(open(sys.argv[1]).read()) else 0)
PYX
  then say "  ok    the ward carries none of this fleet's machine names"
  else say "  FAIL  the ward names a machine of this fleet (RULES/04)"; fail=1; fi
fi

[ "$fail" = 0 ] && say "public-data-ward: all cases behaved" || say "public-data-ward: FAILED"
exit "$fail"
