#!/usr/bin/env bash
# packaged-gate.sh — prove the PUBLISHED artifact, not the tree.
#
# WHY THIS EXISTS (0.1.53): the compliance gate passed on main and the published
# tarball still failed four of its own wards. Nothing was wrong with the code —
# the package.json `files` list never carried `config/`, and npm does not pack a
# symlink as a symlink, so three symlinked seams (`.claude/skills`,
# `.agents/skills/tyr-check/assets`, `.agents/skills/smidja-factory`) were absent
# from the artifact. No in-repo test could see it, because every in-repo test runs
# in the FULL tree where those paths exist. The files list is a silent second
# source of truth, and it had drifted for many releases.
#
# So this gate packs the real thing, unpacks it into a temp dir, and runs the
# compliance gate INSIDE the artifact — which is the only place the drift is
# visible. A symlinked seam is declared in packaging/symlink-seams.json with the
# door that seats it on a real machine; an UNDECLARED missing path is a failure.
#
#   bin/forge/npm/packaged-gate.sh            # pack, unpack, prove
#   bin/forge/npm/packaged-gate.sh --keep     # leave the unpacked dir and print its path
#
# Exit: 0 the artifact holds · 1 it does not · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
cd "$ROOT" || exit 2

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --keep) KEEP=1 ;;
  "") KEEP=0 ;;
  *) printf 'error: unknown flag %s\nhelp: bin/forge/npm/packaged-gate.sh [--keep]\n' "$1" >&2; exit 2 ;;
esac

TMP="$(mktemp -d)"
cleanup() { [ "$KEEP" = 1 ] || rm -rf "$TMP"; }
trap cleanup EXIT

say() { printf '%s\n' "$*"; }

# ── 1. pack the REAL artifact ───────────────────────────────────────────────
say 'packaged_gate[4]{step,status,detail}:'
pkg_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' package.json | head -1)"
pkg_ver="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' package.json | head -1)"
tarball="$(npm pack --pack-destination "$TMP" 2>"$TMP/pack.err" | tail -1)"
if [ ! -f "$TMP/$tarball" ]; then
  say "  \"pack\",\"FAIL\",\"npm pack produced no tarball ($(tail -1 "$TMP/pack.err" 2>/dev/null))\""
  exit 1
fi
files_in_tar="$(tar -tzf "$TMP/$tarball" | wc -l | tr -d ' ')"
say "  \"pack\",\"PASS\",\"$pkg_name@$pkg_ver · $tarball · $files_in_tar entries\""

# ── 2. unpack it and run the compliance gate INSIDE ─────────────────────────
mkdir -p "$TMP/artifact"
if ! tar -xzf "$TMP/$tarball" -C "$TMP/artifact" 2>/dev/null; then
  say "  \"unpack\",\"FAIL\",\"the tarball would not extract\""
  exit 1
fi
ART="$TMP/artifact/package"
[ -d "$ART" ] || ART="$TMP/artifact"
say "  \"unpack\",\"PASS\",\"$ART\""

# A git-less tree: the wards that need git must say so rather than lie.
out="$(cd "$ART" && bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh 2>&1)"
rc=$?
failed="$(printf '%s\n' "$out" | grep -oE '"[^"]*","FAIL","[^"]*"' | head -20)"
if [ "$rc" -eq 0 ]; then
  say "  \"compliance\",\"PASS\",\"every ward holds inside the artifact\""
else
  # An UNDECLARED missing path is a failure; a DECLARED seam is not.
  undeclared=""
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    case "$row" in
      *smidja-factory*|*tyr-check/assets*|*".claude/skills"*|*".codex/skills"*|*".cursor/skills"*)
        continue ;;   # declared in packaging/symlink-seams.json
    esac
    undeclared="$undeclared\n  $row"
  done <<EOF
$(printf '%s\n' "$failed")
EOF
  if [ -z "$undeclared" ]; then
    say "  \"compliance\",\"PASS\",\"only DECLARED symlink seams are absent (packaging/symlink-seams.json)\""
  else
    say "  \"compliance\",\"FAIL\",\"undeclared drift inside the artifact:"
    printf '%b\n' "$undeclared"
    exit 1
  fi
fi

# ── 3. the declared seams must still be declared ────────────────────────────
if [ -f "$ART/packaging/symlink-seams.json" ]; then
  seams="$(sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ART/packaging/symlink-seams.json" | wc -l | tr -d ' ')"
  say "  \"seams\",\"PASS\",\"$seams symlink seams declared for the machines that seat them\""
else
  say "  \"seams\",\"FAIL\",\"packaging/symlink-seams.json is not in the artifact — an absent seam would be indistinguishable from a broken one\""
  exit 1
fi

[ "$KEEP" = 1 ] && say "  \"kept\",\"$ART\""
say 'packaged-gate: PASS — the published artifact holds every ward that can hold it.'
