#!/usr/bin/env bash
# 0004-hoard-and-realms — one private root with two trees.
#
# Before: the hoard's parts sat at the ROOT of $YMIR_HOME (secrets · identity ·
# docs · data · memory · tenants · AGENTS.md), the workspaces lived in a second
# root ($YMIR_HOME/workspaces/) *and* inside the checkout (repo `workspace/`,
# repo `svartalfaheim/<realm>/`), and the Runes ledger had been copied twice.
#
# After — the layout `docs/workspaces.md` proposes:
#
#   $YMIR_HOME/
#   ├── hodd/            the operator's own: secrets · identity · docs · data · memory · tenants · AGENTS.md
#   └── svartalfaheim/   the realms: <realm>/{workspace/{personal,company},memory,runs}
#
# Idempotent: every step checks before it moves, and a move that would overwrite
# is refused rather than merged blindly.
set -u

H="${YMIR_HOME:-$HOME/Documents/Ymir}"
R="${YMIR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HOARD="$H/hodd"
moved=0; placed=0; skipped=0

row() { printf '  "%s","%s","%s"\n' "$1" "$2" "$3"; }

# ── 1. the hoard's parts move under hodd/ ────────────────────────────────────
mkdir -p "$HOARD" 2>/dev/null || true
for d in secrets identity docs data memory tenants; do
  if [ -e "$H/$d" ] && [ ! -e "$HOARD/$d" ]; then
    mv "$H/$d" "$HOARD/$d" && moved=$((moved+1))
  elif [ -e "$H/$d" ]; then
    skipped=$((skipped+1))
  fi
done
# the operator's private contract follows the hoard
if [ -f "$H/AGENTS.md" ] && [ ! -e "$HOARD/AGENTS.md" ]; then
  mv "$H/AGENTS.md" "$HOARD/AGENTS.md" && moved=$((moved+1))
fi

# ── 2. the realm tree ────────────────────────────────────────────────────────
REALM=""
[ -r "$HOARD/data/realm.md" ] && REALM="$(head -n1 "$HOARD/data/realm.md" 2>/dev/null | tr -d '[:space:]')"
if [ -z "$REALM" ] && [ -d "$H/svartalfaheim" ]; then
  REALM="$(find "$H/svartalfaheim" -mindepth 1 -maxdepth 1 -type d ! -name examples ! -name '.*' -printf '%f\n' 2>/dev/null | sort | head -n1)"
fi
REALM="${REALM:-work}"
REALM_DIR="$H/svartalfaheim/$REALM"

mkdir -p "$REALM_DIR/workspace/personal"/{me,life,development,inbox} \
         "$REALM_DIR/workspace/company"/{company,marketing,development,life,projects,companies} \
         "$REALM_DIR/memory/daily" "$REALM_DIR/runs" 2>/dev/null || true

# fold the old workspaces root in, by name, never overwriting
fold() {  # <src-dir> <dst-dir>
  local src=$1 dst=$2 n=0 e b
  [ -d "$src" ] || return 0
  mkdir -p "$dst" 2>/dev/null || true
  for e in "$src"/* "$src"/.[!.]*; do
    [ -e "$e" ] || continue
    b="$(basename "$e")"
    [ -e "$dst/$b" ] && continue
    mv "$e" "$dst/$b" 2>/dev/null && n=$((n+1))
  done
  placed=$((placed+n))
}
fold "$H/workspaces/personal"  "$REALM_DIR/workspace/personal"
fold "$H/workspaces/work"      "$REALM_DIR/workspace/company"
fold "$H/workspaces/companies" "$REALM_DIR/workspace/company/companies"
fold "$H/workspaces/memory"    "$REALM_DIR/memory"
# …and the copy that sat inside the checkout
fold "$R/workspace/personal"   "$REALM_DIR/workspace/personal"
fold "$R/workspace/work"       "$REALM_DIR/workspace/company"
fold "$R/workspace/companies"  "$REALM_DIR/workspace/company/companies"
fold "$R/workspace/memory"     "$REALM_DIR/memory"
fold "$R/svartalfaheim/$REALM/workspace/memory/daily"     "$REALM_DIR/memory/daily"
fold "$R/svartalfaheim/$REALM/workspace/development"      "$REALM_DIR/workspace/company/development"

# ── 3. the Runes ledger lands in the hoard's memory, and no entry is lost ────
LEDGER="$HOARD/memory/runes_audit.md"
mkdir -p "$HOARD/memory" 2>/dev/null || true
for stray in "$H/workspaces/memory/runes_audit.md" "$REALM_DIR/memory/runes_audit.md"; do
  [ -f "$stray" ] || continue
  [ "$stray" = "$LEDGER" ] && continue
  if [ ! -f "$LEDGER" ]; then
    mv "$stray" "$LEDGER" && moved=$((moved+1))
  elif cmp -s "$stray" "$LEDGER"; then
    rm -f "$stray" && moved=$((moved+1))          # identical: drop the copy
  else
    # Different: append only what the target lacks, then keep the target.
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      grep -qxF -- "$line" "$LEDGER" || printf '%s\n' "$line" >>"$LEDGER"
    done <"$stray"
    rm -f "$stray" && moved=$((moved+1))
  fi
done

# ── 4. report ────────────────────────────────────────────────────────────────
printf 'migration[1]{id,state}:\n  "0004-hoard-and-realms","applied"\n'
printf 'migration_result[4]{what,detail,count}:\n'
row "hoard" "$HOARD" "$moved"
row "realm" "$REALM_DIR" "$placed"
row "ledger" "$LEDGER" "$([ -f "$LEDGER" ] && printf 'present' || printf 'absent')"
row "left-alone" "$H" "$skipped"
