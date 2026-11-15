#!/usr/bin/env bash
# 0023-the-deny-list — seat the agnostic deny list in a home installed before 2026-11-14.
#
# WHY (plan 287 §6, RULES/42). The repository is 100 % agnostic: it carries the engine, the apps,
# the tools, the gates, the templates and the documents that teach them — never the operator's own
# life (people, clients, companies, mail domains, NDAs) and never an assumption about his fleet
# (host names, user names, tailnet names, a machine count). `bin/gates/agnostic-audit.sh` is the
# door that looks for them, and it reads its word list from the operator's home:
#
#   $YMIR_HOME/hodd/identity/public-deny.txt
#
# A fresh home receives it from the install (`bin/engine/home-seed.sh`, through the home contract).
# A home installed BEFORE this change has the door but not the file, so the audit would judge only
# the generic shapes and say so. This migration seats the SHAPE — the invented example entries —
# and then the operator replaces them with his own.
#
# THREE LAWS CARRIED HERE:
#   · Rule 42: anything the home must hold has a template in the repo, an install step and a
#     migration. This is the migration half.
#   · Rule 06: never overwrite. A file that already exists is left exactly as it is, byte for
#     byte — the operator's own list outranks every default.
#   · RULES/25: idempotent. Running it twice changes nothing the second time.
#
#   .agents/migrations/0023-the-deny-list.sh [--dry-run]
#
# Exit: 0 seated or already there · 2 usage. It never fails the update for a missing template —
# it says so and leaves the home as it found it.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=bin/vault/hoard-lib.sh
. "$ROOT/bin/vault/hoard-lib.sh"

say() { printf '0023: %s\n' "$1"; }

DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY=1 ;;
    *) printf 'error: unknown argument %s\nhelp: 0023-the-deny-list.sh [--dry-run]\n' "$a" >&2; exit 2 ;;
  esac
done

# THE ONE RESOLVER (Rule 07). A machine with no home is a clean skip that says so — there is
# nothing to seat, and nothing is guessed.
home=""
ymir_home_root home 2>/dev/null || true
[ -n "$home" ] || home="${YMIR_HOME:-}"
[ -n "$home" ] || { say "no home resolves on this machine — nothing to seat"; exit 0; }

dest="$home/hodd/identity/public-deny.txt"
template="$ROOT/hodd/identity/public-deny.txt.example"

if [ -f "$dest" ]; then
  say "already seated: hodd/identity/public-deny.txt — left exactly as it is (Rule 06)"
  exit 0
fi

if [ ! -f "$template" ]; then
  say "REFUSED — the shape hodd/identity/public-deny.txt.example does not ship in this tree"
  say "the audit still runs: it judges the generic shapes and says aloud that it read no words"
  exit 0
fi

if [ "$DRY" = 1 ]; then
  say "would seat hodd/identity/public-deny.txt from hodd/identity/public-deny.txt.example"
  exit 0
fi

mkdir -p "$home/hodd/identity" || { say "REFUSED — cannot create $home/hodd/identity"; exit 0; }
cp "$template" "$dest" || { say "REFUSED — the copy failed; the home is as it was"; exit 0; }
say "seated hodd/identity/public-deny.txt — invented entries; replace them with your own"
say "then: bin/gates/agnostic-audit.sh   (the census) · bin/gates/agnostic-audit.sh --list (the shape)"
exit 0
