#!/usr/bin/env bash
# private-guard-variable.test.sh — a VARIABLE is the design; a RESOLVED path or a real name is a leak.
#
# Plan 293 part 8 (2026-11-14). The public docs say where a thing lives as
# `$YMIR_HOME/hodd/...` — Rule 07's shape, one variable with one documented default — and
# `bin/gates/guards/private-guard.py` read every one of those mentions as a "private hoard
# path" (measured by the helm's audit of 36 agent panes, 2026-11-14: 277 tracked files carry
# the form). A ward that refuses the design is a ward the house routes around.
#
# So this test proves BOTH directions, and it must be able to fail on the leak:
#   the variable form passes, and the resolved path, a `~/` path and a real name are refused.
#
# Everything is fenced: a throwaway home (YMIR_HOME) with its own confidential.yaml, and
# files written in a temp directory — no real home, no real name, no tracked file touched.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$ROOT/bin/gates/guards/private-guard.sh"
[ -x "$GUARD" ] || { printf 'FAIL no %s\n' "$GUARD"; exit 1; }

ok=0; fail=0
good() { ok=$((ok+1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ -n "${2-}" ] && printf '     %s\n' "$2"; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
HOME_DIR="$T/home"
mkdir -p "$HOME_DIR/hodd/identity"

# The home the guard resolves: an invented one, so the "resolved path" rule is proven against
# a path that exists only in this test. The marker below is invented too — the ward reads its
# names from the home at run time, never from the code (RULES/04).
printf 'markers:\n  - "Vardrland"\n' >"$HOME_DIR/hodd/identity/confidential.yaml"

# judge <file> → sets GUARD_RC and GUARD_OUT (both streams, so the reason is readable)
judge() {
  GUARD_OUT="$(YMIR_HOME="$HOME_DIR" bash "$GUARD" check --surface public "$1" 2>&1)"
  GUARD_RC=$?
}

# ── 1. the variable form is the design, and it passes ─────────────────────────────────
printf '%s\n' \
  'The hoard answers through one variable: `$YMIR_HOME/hodd/docs/INDEX.md` is the index,' \
  'and the plans live at `$YMIR_HOME/svartalfaheim/<realm>/projects/<project>/plans/`.' \
  'Run it as $YMIR_HOME."' >"$T/variable.md"
judge "$T/variable.md"
if [ "$GUARD_RC" = 0 ]; then good 'passes a public doc naming $YMIR_HOME/... (a variable is not a path)'
else bad 'passes a public doc naming $YMIR_HOME/...' "$(printf '%s' "$GUARD_OUT" | head -3)"; fi

# ── 2. a bare $YMIR_HOME passes too (it is the same variable, with no path behind it) ──
printf '%s\n' 'Private data lives at $YMIR_HOME and nowhere else (Rule 04).' >"$T/bare.md"
judge "$T/bare.md"
if [ "$GUARD_RC" = 0 ]; then good 'passes a bare $YMIR_HOME mention'
else bad 'passes a bare $YMIR_HOME mention' "$(printf '%s' "$GUARD_OUT" | head -3)"; fi

# ── 3. the RESOLVED home is a leak, and it is refused ─────────────────────────────────
# $T/home is this test's invented home: a real, expanded path to a private shelf.
printf '%s\n' "the record is at $HOME_DIR/hodd/docs/INDEX.md" >"$T/resolved.md"
judge "$T/resolved.md"
case "$GUARD_OUT" in
  *"private hoard path"*) good 'refuses the RESOLVED home path' ;;
  *) bad 'refuses the RESOLVED home path' "$(printf '%s' "$GUARD_OUT" | head -3)" ;;
esac
[ "$GUARD_RC" != 0 ] || bad 'the resolved path exits non-zero'

# ── 4. a `~/` path is a resolved path written with a shell variable the guard cannot see ─
printf '%s\n' 'the record is at ~/Documents/ymirhome/hodd/docs/INDEX.md' >"$T/tilde.md"
judge "$T/tilde.md"
case "$GUARD_OUT" in
  *"private hoard path"*) good 'refuses a ~/Documents/... path' ;;
  *) bad 'refuses a ~/Documents/... path' "$(printf '%s' "$GUARD_OUT" | head -3)" ;;
esac

# ── 5. a real NAME still bites: the marker is read from the home, never written in code ─
printf '%s\n' 'notes from the Vardrland call' >"$T/name.md"
judge "$T/name.md"
case "$GUARD_OUT" in
  *classified*) good 'refuses a home-declared name' ;;
  *) bad 'refuses a home-declared name' "$(printf '%s' "$GUARD_OUT" | head -3)" ;;
esac

# ── 6. a secret shape still bites (this arm is old behaviour, kept proved) ────────────
printf '%s\n' 'token: sk-abcdefghijklmnop' >"$T/secret.md"
judge "$T/secret.md"
case "$GUARD_OUT" in
  *"secret shape"*) good 'refuses a secret shape' ;;
  *) bad 'refuses a secret shape' "$(printf '%s' "$GUARD_OUT" | head -3)" ;;
esac

# ── 7. the two live together: a variable and a resolved path in ONE file still refuses ─
printf '%s\n' 'the index is `$YMIR_HOME/hodd/docs/INDEX.md`' "but here it is expanded: $HOME_DIR/hodd/docs/INDEX.md" >"$T/both.md"
judge "$T/both.md"
if [ "$GUARD_RC" != 0 ]; then good 'a resolved path beside a variable still refuses (the variable never shields it)'
else bad 'a resolved path beside a variable still refuses'; fi

# ── 8. a REAL realm on the private shelf refuses; the repo's own shaped shelf does not ─
# The realm's name is invented in this test and declared by the temp home's own shelf, so the
# ward reads it at run time (nothing private is written here). `docs/examples` stands for a
# shelf the repository itself ships, which is a path in the tree, not in the hoard.
mkdir -p "$HOME_DIR/svartalfaheim/Vardrheim"
printf '%s\n' 'the ledger is at $YMIR_HOME/svartalfaheim/Vardrheim/projects/x/plans/01-a.md' >"$T/realm.md"
judge "$T/realm.md"
case "$GUARD_OUT" in
  *"real realm"*) good 'refuses a REAL realm named on the private shelf' ;;
  *) bad 'refuses a REAL realm named on the private shelf' "$(printf '%s' "$GUARD_OUT" | head -3)" ;;
esac

printf '%s\n' 'the shelf is svartalfaheim/<realm>/examples, and the repository ships svartalfaheim/examples/.' >"$T/shaped.md"
judge "$T/shaped.md"
if [ "$GUARD_RC" = 0 ]; then good "passes the shaped shelf and the repository's own examples"
else bad "passes the shaped shelf and the repository's own examples" "$(printf '%s' "$GUARD_OUT" | head -3)"; fi

printf '\nprivate-guard-variable: %s ok, %s failed\n' "$ok" "$fail"
[ "$fail" = 0 ]
