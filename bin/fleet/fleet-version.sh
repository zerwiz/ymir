#!/usr/bin/env bash
# fleet-version.sh — is the fleet on ONE version? (plan 51, Phase 2)
#
# The fleet is versioned together (law 5). This reports the three versions that
# drifted apart on 2026-09-23 — the tree, the npm install, and the published
# latest — and judges them, so a body on a different version can no longer go
# unnoticed. Offline-safe: an unreachable npm registry is reported, never a crash.
#
#   fleet-version.sh            # this machine + the published line, as TOON
#   fleet-version.sh --json
#   fleet-version.sh check      # exit 1 on drift; 0 when they agree
#   fleet-version.sh --version
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
MODE=toon
case "${1-}" in --json) MODE=json ;; check) MODE=check ;; esac

# the tree's declared version
TREE="$(node -p "require('$ROOT/package.json').version" 2>/dev/null || echo "")"

# the installed @zerwiz/ymir, wherever npm keeps its global root
INSTALLED=""
if command -v npm >/dev/null 2>&1; then
  _g="$(npm root -g 2>/dev/null)"
  [ -n "$_g" ] && INSTALLED="$(node -p "try{require('$_g/@zerwiz/ymir/package.json').version}catch(e){''}" 2>/dev/null || echo "")"
fi

# the published latest — network-optional
PUBLISHED=""
if command -v npm >/dev/null 2>&1; then
  PUBLISHED="$(npm view @zerwiz/ymir version 2>/dev/null || true)"
fi
[ -n "$PUBLISHED" ] || PUBLISHED="unreachable"

# ── content, not just labels (2026-10-23) ────────────────────────────────────
# Three labels can agree on a word that stopped meaning anything. Measured on this seat:
# the tree, the install and npm ALL said 0.1.53, while the two trees differed by 155 doors,
# 22 rules and 69 feature pages — the published copy had been frozen for 24 days. A
# label-agreement check cannot see that. So when a global copy exists, count the things.
CONTENT=""; CONTENT_NOTE=""
if [ -n "$INSTALLED" ]; then
  _groot="$(npm root -g 2>/dev/null)"
  GI="${_groot%/}/@zerwiz/ymir"
  if [ -d "$GI" ]; then
    _td=$(find "$ROOT/bin" -name '*.sh' 2>/dev/null | wc -l); _id=$(find "$GI/bin" -name '*.sh' 2>/dev/null | wc -l)
    _tr=$(ls "$ROOT"/RULES/[0-9][0-9]-*.md 2>/dev/null | wc -l); _ir=$(ls "$GI"/RULES/[0-9][0-9]-*.md 2>/dev/null | wc -l)
    _tf=$(ls "$ROOT"/docs/features/*.md 2>/dev/null | wc -l); _if=$(ls "$GI"/docs/features/*.md 2>/dev/null | wc -l)
    CONTENT_NOTE="doors ${_td}/${_id} · rules ${_tr}/${_ir} · feature pages ${_tf}/${_if} (tree/installed)"
    if [ "$_td" != "$_id" ] || [ "$_tr" != "$_ir" ] || [ "$_tf" != "$_if" ]; then CONTENT="drift"; else CONTENT="same"; fi
    unset _td _id _tr _ir _tf _if
  fi
  unset _groot GI
fi

# verdict — semver-ish via sort -V
newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]; }
# The order matters, and getting it wrong made a bump look like a fault: once the tree's
# version moves ahead, the INSTALLED copy is behind by definition — that is a release owed,
# not a broken seat. Only these are faults: an install NEWER than the tree, a published
# version newer than the tree, or three equal labels over two different trees.
VERDICT="in sync"; VERDICT_NOTE="tree, install, and publish agree"
if [ -z "$TREE" ]; then
  VERDICT="unknown"; VERDICT_NOTE="no package.json at $ROOT"
elif [ -n "$INSTALLED" ] && newer "$INSTALLED" "$TREE"; then
  VERDICT="drift"; VERDICT_NOTE="installed $INSTALLED is AHEAD of tree $TREE — this seat is not the tree it thinks"
elif [ "$PUBLISHED" != "unreachable" ] && newer "$PUBLISHED" "$TREE"; then
  VERDICT="behind"; VERDICT_NOTE="tree $TREE is behind published $PUBLISHED — pull the line forward"
elif [ "$PUBLISHED" != "unreachable" ] && newer "$TREE" "$PUBLISHED"; then
  VERDICT="ahead"; VERDICT_NOTE="tree $TREE is ahead of published $PUBLISHED — a RELEASE is owed (${CONTENT_NOTE:-no install to compare})"
elif [ "$CONTENT" = "drift" ]; then
  VERDICT="content drift"; VERDICT_NOTE="three equal labels over two different trees — $CONTENT_NOTE"
fi

if [ "$MODE" = json ]; then
  python3 - "$TREE" "$INSTALLED" "$PUBLISHED" "$VERDICT" "$VERDICT_NOTE" <<'PY'
import json, sys
tree, installed, published, verdict, note = sys.argv[1:6]
print(json.dumps({"tree": tree or None, "installed": installed or None,
                  "published": published, "verdict": verdict, "note": note}))
PY
  exit 0
fi

printf 'fleet_version[5]{scope,version,note}:\n'
printf '  "tree","%s","package.json in this repo"\n' "${TREE:-none}"
printf '  "installed","%s","@zerwiz/ymir in the global prefix"\n' "${INSTALLED:-none}"
printf '  "published","%s","npm latest"\n' "$PUBLISHED"
printf '  "verdict","%s","%s"\n' "$VERDICT" "$VERDICT_NOTE"
printf '  "content","%s","%s"\n' "${CONTENT:-unmeasured}" "${CONTENT_NOTE:-no global copy to compare — a clean skip, not a pass}"

if [ "$MODE" = check ] && { [ "$VERDICT" = "drift" ] || [ "$VERDICT" = "content drift" ]; }; then exit 1; fi
exit 0
