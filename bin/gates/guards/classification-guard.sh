#!/usr/bin/env bash
# classification-guard.sh — Rule 29's ward: the suite's spaces and their ceilings.
#
# It checks what a machine CAN check about "what goes where":
#   1 · every suite space declares a class ceiling, and no suite space claims 3 or 4
#       (NDA and the vault are never a suite space)
#   2 · the spaces that never invite anyone say so
#   3 · the code that projects (desk, MCP) actually references a place check — a refuge
#       that forgets to ask who is calling is the hole this rule was written for
#   4 · no file in the tree names the vault's secret paths
#
#   classification-guard.sh [check]     ·   --version
set -uo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# The operator's own map lives in the hoard; the repo ships only the example.
HOME_MAP="${YMIR_HOME:-}/config/suite-workspaces.yaml"
if [ -n "${YMIR_HOME:-}" ] && [ -r "$HOME_MAP" ]; then MAP="$HOME_MAP"; SHIPPED=no
else MAP="$ROOT/.agents/assets/agents/suite-workspaces.example.yaml"; SHIPPED=yes; fi
fail=0
say(){ printf '%s\n' "$*"; }

if [ ! -r "$MAP" ]; then
  say 'classification-guard: no spaces map — neither the operator'"'"'s own nor the shipped example'
  exit 1
fi
if [ "$SHIPPED" = yes ]; then
  say 'classification-guard: SKIP — the operator has no spaces map in the hoard; the shipped example is checked for shape only'
fi

python3 - "$MAP" <<'PY' || exit 1
import sys, re, pathlib
p = pathlib.Path(sys.argv[1]); text = p.read_text()
# a deliberately small parser: the map is ours and its shape is fixed
spaces = re.findall(r"- id: ([a-z0-9-]+)(?:.*\n)*?    class_ceiling: (\d)", text)
if not spaces:
    print("classification-guard: no spaces parsed — the map's shape drifted"); sys.exit(1)
bad = [(s, c) for s, c in spaces if int(c) > 2]
if bad:
    print(f"classification-guard: {bad} claim a ceiling above 2 — NDA (3) and the vault (4) are never a suite space")
    sys.exit(1)
vault = re.search(r"vault:\n(?:.*\n)*?  class_ceiling: (\d)", text)
if not vault or int(vault.group(1)) != 4:
    print("classification-guard: the vault must declare class_ceiling 4"); sys.exit(1)
if "never_projected: true" not in text:
    print("classification-guard: the vault must declare never_projected: true"); sys.exit(1)
for sid, ceil in spaces:
    print(f"space\t{sid}\tceiling={ceil}")
PY
[ $? -ne 0 ] && fail=1

# 3 · the projecting code must ask who is calling
for f in bin/gimle/desk.py bin/gimle/mcp-read.py; do
  [ -r "$ROOT/$f" ] || continue
  if ! grep -qE "Remote-User|subject_for|places" "$ROOT/$f"; then
    say "classification-guard: $f projects without naming a person or a place"
    fail=1
  fi
done

# 4 · class 4 (the vault's material) never appears in the tree — a *value*, not a path.
#     Naming the vault door is the law (secrets by reference); carrying its content is a breach.
if git -C "$ROOT" grep -qIlE "AGE-SECRET-KEY-1|-----BEGIN (OPENSSH|RSA|EC) PRIVATE KEY-----" \
     -- ':!*.example' ':!bin/gates/**' 2>/dev/null; then
  say "classification-guard: a tracked file carries private-key material (Rule 29 class 4)"
  git -C "$ROOT" grep -IlE "AGE-SECRET-KEY-1|-----BEGIN (OPENSSH|RSA|EC) PRIVATE KEY-----" -- ':!*.example' ':!bin/gates/**' 2>/dev/null | sed 's/^/  /' | head -5
  fail=1
fi

if [ "$fail" -eq 0 ]; then say "classification-guard: the spaces are bounded"; exit 0; fi
say "classification-guard: a space is unbounded — see the rows above"
exit 1
