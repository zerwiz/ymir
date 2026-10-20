#!/usr/bin/env bash
# logretta-ensure.sh — seat the council's roster on this machine.
#
# Plan 92's law, taken from plan 66 §7: **a feature is not done when its code exists; it
# is done when the install seats it.** The extension ships in `.pi/extensions/logretta/`,
# but a council with no stack is a loud skip — so the install has to leave one behind.
#
# What this does, and does NOT do:
#   · copies the TEMPLATE into <home>/config/logretta-stack.yaml when that file is ABSENT
#   · never overwrites an existing stack — the models on it are the operator's choice
#   · validates the stack by parsing it with the extension's own parser (node)
#   · reports, loudly, when the file is present but unreadable or invalid
#
# Usage:
#   logretta-ensure.sh status            # is the council seated? (exit 0 = yes)
#   logretta-ensure.sh ensure            # seat it if absent; validate either way
#   logretta-ensure.sh ensure --check    # print what ensure WOULD do, change nothing
#
# Exit: 0 seated/healthy · 1 a fault · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
TEMPLATE="$ROOT/.agents/config/logretta-stack.example.yaml"
PARSER="$ROOT/.pi/extensions/logretta/stack.ts"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; [ -n "${1-}" ] && exit 0 || exit 2 ;;
esac
CMD="${1-}"; shift || true
CHECK=0
for a in "$@"; do
  case "$a" in
    --check) CHECK=1 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/pi/logretta-ensure.sh [status|ensure] [--check]\n' "$a" >&2; exit 2 ;;
  esac
done

# The home, by the resolver — never a hardcoded path (Rule 07 / Rule 04).
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
HOME_DIR=""
if [ -n "${YMIR_HOME:-}" ]; then HOME_DIR="$YMIR_HOME"
elif command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR
fi

if [ -z "$HOME_DIR" ]; then
  printf 'logretta[1]{state,problem}:\n  "absent","no YMIR_HOME resolved — the stack has nowhere lawful to live"\n'
  exit 1
fi

STACK="$HOME_DIR/config/logretta-stack.yaml"

validate() {  # <path> → prints a problem, or nothing when valid
  local f=$1
  if ! command -v node >/dev/null 2>&1; then
    printf 'node is not on PATH, so the stack could not be parsed'
    return
  fi
  node --experimental-strip-types -e '
    const p = process.argv[1];
    const { readFileSync } = await import("node:fs");
    const { parseStack } = await import(process.argv[2]);
    try { parseStack(readFileSync(p, "utf8")); }
    catch (e) { console.log(e?.message ?? String(e)); }
  ' "$f" "$PARSER" 2>/dev/null
}

case "$CMD" in
  status)
    if [ ! -f "$STACK" ]; then
      printf 'logretta[2]{state,path}:\n  "absent","%s"\n  "remedy","bin/pi/logretta-ensure.sh ensure"\n' "$STACK"
      exit 1
    fi
    problem="$(validate "$STACK")"
    if [ -n "$problem" ]; then
      printf 'logretta[3]{state,path,problem}:\n  "invalid","%s","%s"\n  "remedy","fix the stack, then re-run: bin/pi/logretta-ensure.sh status"\n' "$STACK" "$problem"
      exit 1
    fi
    printf 'logretta[1]{state,path}:\n  "seated","%s"\n' "$STACK"
    exit 0
    ;;

  ensure)
    [ -f "$TEMPLATE" ] || { printf 'logretta[1]{state}:\n  "fault","no template at %s"\n' "$TEMPLATE"; exit 1; }

    if [ -f "$STACK" ]; then
      problem="$(validate "$STACK")"
      if [ -n "$problem" ]; then
        printf 'logretta[2]{state,path,problem}:\n  "invalid","%s","%s"\n' "$STACK" "$problem"
        exit 1
      fi
      printf 'logretta[1]{state,path}:\n  "kept","%s (already seated; never overwritten)"\n' "$STACK"
      exit 0
    fi

    if [ "$CHECK" = 1 ]; then
      printf 'logretta[1]{state,would}:\n  "absent","would copy the template to %s"\n' "$STACK"
      exit 0
    fi

    mkdir -p "$(dirname "$STACK")"
    cp "$TEMPLATE" "$STACK"
    problem="$(validate "$STACK")"
    if [ -n "$problem" ]; then
      printf 'logretta[2]{state,path,problem}:\n  "seeded-but-invalid","%s","%s"\n' "$STACK" "$problem"
      exit 1
    fi
    printf 'logretta[2]{state,path,next}:\n  "seeded","%s"\n  "next","name YOUR models in it (logretta_stack shows the roster)"\n' "$STACK"
    exit 0
    ;;

  *) printf 'error: unknown command %s\nhelp: bin/pi/logretta-ensure.sh [status|ensure] [--check]\n' "$CMD" >&2; exit 2 ;;
esac
